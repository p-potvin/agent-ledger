#!/usr/bin/env bash
# deploy.sh — Build and deploy agent-ledger site on greencloud-vps
# Called by vw-webhookd after a push to main, or run manually.
#
# Prerequisites:
#   - Node.js 20+ installed
#   - PowerShell (pwsh) installed for the render scripts
#   - /var/www/ledger.vaultwares.ca exists and is writable
#   - nginx vhost configured (see deploy/nginx-ledger.conf)

set -euo pipefail

REPO_DIR="/opt/sites/agent-ledger"
SITE_DIR="$REPO_DIR/site"
DEPLOY_DIR="/var/www/ledger.vaultwares.ca"

echo "=== agent-ledger deploy: $(date -u) ==="

# 1. Pull latest
cd "$REPO_DIR"
git fetch origin main
git reset --hard origin/main
git submodule update --init --depth 1 vaultwares-themes

# 2. Generate JSON data from ledger events
echo "--- Generating JSON data ---"
pwsh -NoProfile -File scripts/update-work-impact.ps1
pwsh -NoProfile -File scripts/render-work-impact.ps1
pwsh -NoProfile -File scripts/render-agent-ledger.ps1

# 3. Build the React site
echo "--- Building site ---"
cd "$SITE_DIR"
npm ci --prefer-offline
npm run build

# 4. Deploy to web root
echo "--- Deploying to $DEPLOY_DIR ---"
rsync -a --delete "$SITE_DIR/dist/" "$DEPLOY_DIR/"

# 5. Reload nginx (if config changed)
if nginx -t 2>/dev/null; then
    sudo systemctl reload nginx
    echo "nginx reloaded"
fi

echo "=== Deploy complete ==="
