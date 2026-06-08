#!/usr/bin/env bash
# deploy-async.sh — webhook-safe wrapper around deploy.sh.
#
# Why this exists:
#   GitHub gives webhook receivers ~10 seconds to respond. The synchronous
#   deploy (git pull + npm ci + vite build + rsync) takes much longer, so
#   every push to main showed up as a 504 on the GitHub webhook page even
#   though the deploy itself succeeded.
#
# This wrapper:
#   1. Takes a non-blocking lock (skips if another deploy is already running).
#   2. Forks the real deploy into the background, fully detached.
#   3. Returns exit 0 immediately so the webhook handler can respond 200.
#
# Wire vw-webhookd to call THIS script instead of deploy.sh.

set -euo pipefail

REPO_DIR="/opt/sites/agent-ledger"
DEPLOY="$REPO_DIR/deploy/deploy.sh"
LOCKFILE="/var/lock/agent-ledger-deploy.lock"
LOGFILE="/var/log/agent-ledger-deploy.log"

# Non-blocking lock — if a deploy is already running, exit cleanly.
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "deploy-async: another deploy is in progress, skipping" >&2
    exit 0
fi

# Detach the real deploy. setsid + nohup + redirect + & + disown means the
# child survives this process exiting and won't keep stdout/stderr open to
# the webhook handler.
mkdir -p "$(dirname "$LOGFILE")"
setsid nohup bash "$DEPLOY" >>"$LOGFILE" 2>&1 < /dev/null &
disown

# The lock fd (9) is inherited by the child via setsid, so the lock stays
# held for the duration of the real deploy. flock releases it when the
# child exits.

echo "deploy-async: dispatched $(date -u +%FT%TZ), log at $LOGFILE"
exit 0
