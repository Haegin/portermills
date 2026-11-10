#!/bin/bash
# One-time setup of a fresh Debian 13 container for the server. Run as root
# inside the container. Safe to re-run: existing secrets are kept.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q --no-install-recommends \
  postgresql build-essential autoconf m4 libncurses-dev libssl-dev \
  git curl ca-certificates unzip openssl gnupg

# Cloudflare's apt repo, for cloudflared (the tunnel is configured separately).
if ! command -v cloudflared >/dev/null; then
  mkdir -p --mode=0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
    > /etc/apt/sources.list.d/cloudflared.list
  apt-get update -q
  apt-get install -y -q cloudflared
fi

id portermills >/dev/null 2>&1 ||
  useradd --system --create-home --home-dir /opt/portermills --shell /bin/bash portermills

# mise builds the Erlang and Elixir versions pinned in .tool-versions.
if [ ! -x /opt/portermills/.local/bin/mise ]; then
  su - portermills -c 'curl -fsSL https://mise.run | sh'
fi

# Database and settings. The env file is written once and never overwritten.
if [ ! -f /etc/portermills/env ]; then
  db_pass=$(openssl rand -hex 24)
  if su postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='portermills'\"" | grep -q 1; then
    su postgres -c "psql -q -c \"ALTER ROLE portermills PASSWORD '$db_pass'\""
  else
    su postgres -c "psql -q -c \"CREATE ROLE portermills LOGIN PASSWORD '$db_pass'\""
  fi
  su postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='portermills_prod'\"" | grep -q 1 ||
    su postgres -c "createdb -O portermills portermills_prod"

  install -d -m 0750 -o root -g portermills /etc/portermills
  umask 027
  cat > /etc/portermills/env <<ENV
# Read by the release on every command (see server/rel/env.sh.eex).
DATABASE_URL=ecto://portermills:${db_pass}@localhost/portermills_prod
SECRET_KEY_BASE=$(openssl rand -base64 48 | tr -d '\n')
GUARDIAN_SECRET=$(openssl rand -base64 48 | tr -d '\n')
PHX_HOST=api.portermills.net
PORT=2310
PHX_SERVER=true
LANG=C.UTF-8
SMTP_HOST=smtp.fastmail.com
SMTP_PORT=465
# Your Fastmail login and an app password with SMTP access.
SMTP_USERNAME=
SMTP_PASSWORD=
MAIL_FROM=app@portermills.net
ENV
  chgrp portermills /etc/portermills/env
  echo "Wrote /etc/portermills/env; fill in SMTP_USERNAME and SMTP_PASSWORD."
fi

install -m 0644 "$(dirname "$0")/portermills.service" /etc/systemd/system/portermills.service
systemctl daemon-reload
systemctl enable portermills.service
