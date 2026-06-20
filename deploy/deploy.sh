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

# Pipelines are decoupled: a failure in one app's build does NOT abort
# the other. We capture per-app exit status, deploy only on success,
# and exit non-zero at the end if any pipeline failed.
SITE_STATUS="skipped"
STATS_STATUS="skipped"

build_and_deploy() {
    local name="$1" src_dir="$2" dest_dir="$3" status_var="$4"
    echo "--- Building $name ---"
    if ! ( cd "$src_dir" && npm ci --prefer-offline && npm run build ); then
        echo "!!! Build of $name failed — skipping deploy to $dest_dir" >&2
        printf -v "$status_var" '%s' "build-failed"
        return 1
    fi
    if [ ! -d "$dest_dir" ] || [ -L "$dest_dir" ]; then
        echo "--- Skipping $dest_dir (missing or is a symlink) ---"
        printf -v "$status_var" '%s' "dest-missing"
        return 0
    fi
    echo "--- Deploying $name → $dest_dir ---"
    if ! rsync -a --delete --exclude '.well-known/' "$src_dir/dist/" "$dest_dir/"; then
        echo "!!! rsync to $dest_dir failed" >&2
        printf -v "$status_var" '%s' "rsync-failed"
        return 1
    fi
    printf -v "$status_var" '%s' "ok"
}

# 3a. site/ → /var/www/ledger.vaultwares.ca (legacy)
build_and_deploy "site/"      "$SITE_DIR"      "$LEDGER_DEPLOY_DIR" SITE_STATUS  || true

# 3b. Regenerate stats-app's bundled data.json from the live API, then build.
#     The script writes src/lib/data.json which vite imports at build time.
echo "--- Regenerating stats-app data from /monitor/work-impact ---"
( cd "$STATS_APP_DIR" && node scripts/generate-data.mjs ) || \
    echo "!!! stats-app data regeneration failed; build will use last committed data.json" >&2

# 3c. stats-app/ → /var/www/stats.vaultwares.ca (new Work Impact dashboard)
build_and_deploy "stats-app/" "$STATS_APP_DIR" "$STATS_DEPLOY_DIR"  STATS_STATUS || true

echo "--- Pipeline summary: site=$SITE_STATUS stats-app=$STATS_STATUS ---"

# 5. Reload nginx (if config changed)
if nginx -t 2>/dev/null; then
    sudo systemctl reload nginx
    echo "nginx reloaded"
fi

echo "=== Deploy complete ==="
