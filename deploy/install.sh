#!/bin/bash
# Builds and swaps in a new release, migrates and restarts. Run as root inside
# the container, after the source has been unpacked into /opt/portermills/src.
set -euo pipefail
home=/opt/portermills

su - portermills -c "$home/src/deploy/build.sh"

rm -rf "$home/app.new"
cp -a "$home/build/prod/rel/portermills" "$home/app.new"

systemctl stop portermills || true
rm -rf "$home/app.old"
[ -d "$home/app" ] && mv "$home/app" "$home/app.old"
mv "$home/app.new" "$home/app"
su - portermills -c "$home/app/bin/migrate"
systemctl start portermills

for _ in $(seq 1 30); do
  if curl -fsS -o /dev/null http://127.0.0.1:2310/assets/phoenix/phoenix.min.js; then
    echo "Server is up."
    exit 0
  fi
  sleep 1
done
echo "Server did not come up; see: journalctl -u portermills" >&2
exit 1
