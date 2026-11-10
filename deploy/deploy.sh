#!/bin/bash
# Deploys a commit (default HEAD) to the server container. Run from the repo
# on your Mac:  deploy/deploy.sh [REF]
# Override the Proxmox host and container with DEPLOY_HOST / DEPLOY_CT.
set -euo pipefail
host=${DEPLOY_HOST:-woden}
ct=${DEPLOY_CT:-208}
ref=${1:-HEAD}

cd "$(git rev-parse --show-toplevel)"
echo "Deploying $(git rev-parse --short "$ref") to container $ct on $host"

git archive --format=tar "$ref" |
  ssh "$host" "pct exec $ct -- bash -c 'rm -rf /opt/portermills/src && install -d -o portermills -g portermills /opt/portermills/src && tar -x --no-same-owner -C /opt/portermills/src && chown -R portermills:portermills /opt/portermills/src'"

ssh "$host" "pct exec $ct -- /opt/portermills/src/deploy/install.sh"
