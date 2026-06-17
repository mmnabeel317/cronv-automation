#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOMATION_DIR="${AUTOMATION_DIR:-$(dirname "$SCRIPT_DIR")}"

# Source environment config if available, but preserve AUTOMATION_DIR
# if it was already set (avoids env file overriding during local testing)
_SAVED_AUTOMATION_DIR="${AUTOMATION_DIR}"
ENV_FILE="${AUTOMATION_DIR}/config/cronv-automation.env"
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
fi
AUTOMATION_DIR="${_SAVED_AUTOMATION_DIR}"

REPO_LINK="${AUTOMATION_DIR}/repo/current"
OUTPUT_DIR="${AUTOMATION_DIR}/output"
CRONTAB_FILE="${OUTPUT_DIR}/crontab.txt"
HTML_OUTPUT="${OUTPUT_DIR}/crontab.html"
NGINX_HTML_PATH="${NGINX_HTML_PATH:-/var/www/html/crontab.html}"
CRONV_DURATION="${CRONV_DURATION:-31d}"
CRONV_TITLE="${CRONV_TITLE:-Periodic CI Jobs}"
CRONV_WIDTH="${CRONV_WIDTH:-150}"

log() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*"
}

log "Sync detected (hash: ${GITSYNC_HASH:-unknown}), regenerating visualization..."

mkdir -p "$OUTPUT_DIR"

# Step 1: Parse periodics YAML into crontab format
log "Parsing periodics YAML..."
if ! python3 "${SCRIPT_DIR}/parse_cron.py" "${REPO_LINK}" > "${CRONTAB_FILE}"; then
    log "ERROR: Parser failed, skipping HTML generation"
    exit 1
fi

JOB_COUNT=$(grep -cE '^[0-9@]' "${CRONTAB_FILE}" 2>/dev/null || echo 0)
log "Parsed ${JOB_COUNT} cron jobs"

if [[ "${JOB_COUNT}" -eq 0 ]]; then
    log "WARNING: No cron jobs found. Keeping existing visualization to avoid blank page."
    exit 0
fi

# Step 2: Generate HTML via cronv
FROM_DATE=$(date -u +"%Y/%m/%d")
log "Generating HTML (from: ${FROM_DATE}, duration: ${CRONV_DURATION})..."

if ! cat "${CRONTAB_FILE}" | cronv \
    --from-date="${FROM_DATE}" \
    --from-time=00:00 \
    --duration="${CRONV_DURATION}" \
    --title="${CRONV_TITLE}" \
    -w "${CRONV_WIDTH}" \
    -o "${HTML_OUTPUT}"; then
    log "ERROR: cronv failed to generate HTML"
    exit 1
fi

# Step 3: Copy to nginx serving path
if [[ -d "$(dirname "${NGINX_HTML_PATH}")" ]]; then
    cp -f "${HTML_OUTPUT}" "${NGINX_HTML_PATH}"
    log "Visualization deployed to ${NGINX_HTML_PATH}"
else
    log "WARNING: nginx directory $(dirname "${NGINX_HTML_PATH}") does not exist, skipping copy"
    log "HTML is available at ${HTML_OUTPUT}"
fi

log "Done. ${JOB_COUNT} jobs visualized (hash: ${GITSYNC_HASH:-unknown})"
