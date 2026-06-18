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
STATS_APP_DIR="$REPO_DIR/stats-app"

LEDGER_DEPLOY_DIR="/var/www/ledger.vaultwares.ca"
STATS_DEPLOY_DIR="/var/www/stats.vaultwares.ca"

echo "=== agent-ledger deploy: $(date -u) ==="

# 1. Pull latest
cd "$REPO_DIR"
git fetch origin main
git reset --hard origin/main
git submodule update --init --depth 1 vaultwares-themes

# 2. Generate JSON data from ledger events (consumed by site/ build)
echo "--- Generating JSON data ---"
pwsh -NoProfile -File scripts/update-work-impact.ps1
pwsh -NoProfile -File scripts/render-work-impact.ps1
pwsh -NoProfile -File scripts/render-agent-ledger.ps1

# 3a. Build site/ (legacy ledger.vaultwares.ca dashboard)
echo "--- Building site/ ---"
cd "$SITE_DIR"
npm ci --prefer-offline
npm run build

if [ -d "$LEDGER_DEPLOY_DIR" ] && [ ! -L "$LEDGER_DEPLOY_DIR" ]; then
    echo "--- Deploying site/ → $LEDGER_DEPLOY_DIR ---"
    rsync -a --delete --exclude '.well-known/' "$SITE_DIR/dist/" "$LEDGER_DEPLOY_DIR/"
else
    echo "--- Skipping $LEDGER_DEPLOY_DIR (missing or is a symlink) ---"
fi

# 3b. Build stats-app/ (new Work Impact dashboard for stats.vaultwares.ca)
echo "--- Building stats-app/ ---"
cd "$STATS_APP_DIR"
npm ci --prefer-offline
npm run build

if [ -d "$STATS_DEPLOY_DIR" ] && [ ! -L "$STATS_DEPLOY_DIR" ]; then
    echo "--- Deploying stats-app/ → $STATS_DEPLOY_DIR ---"
    rsync -a --delete --exclude '.well-known/' "$STATS_APP_DIR/dist/" "$STATS_DEPLOY_DIR/"
else
    echo "--- Skipping $STATS_DEPLOY_DIR (missing or is a symlink) ---"
fi

# 5. Reload nginx (if config changed)
if nginx -t 2>/dev/null; then
    sudo systemctl reload nginx
    echo "nginx reloaded"
fi

echo "=== Deploy complete ==="
