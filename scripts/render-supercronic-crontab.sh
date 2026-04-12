#!/usr/bin/env bash
set -euo pipefail

source /ops/scripts/runtime-common.sh

mkdir -p "$(dirname "$SUPERCRONIC_CRONTAB_PATH")"

cat >"$SUPERCRONIC_CRONTAB_PATH" <<EOF
SHELL=/bin/bash
PATH=${PATH}
HOME=${HOME}
TZ=${OPENCLAW_CRON_TZ}

${OBSIDIAN_SYNC_HEALTHCHECK_CRON:-*/2 * * * *} /ops/scripts/run-obsidian-sync-healthcheck.sh
${OBSIDIAN_GIT_BACKUP_CRON:-*/15 * * * *} /ops/scripts/run-obsidian-git-backup.sh
${OBS_AUTO_MOC_PIPELINE_CRON:-*/2 * * * *} /ops/scripts/run-obs-auto-moc-pipeline.sh
${HEALTH_TRACKER_GARMIN_CRON:-15 8,20 * * *} /ops/scripts/run-health-tracker-sync.sh
${FAMI_GHOME_MORNING_CRON:-0 8 * * *} /ops/scripts/run-fami-ghome-threshold.sh --force-notify
${FAMI_GHOME_EVENING_CRON:-0 20 * * *} /ops/scripts/run-fami-ghome-threshold.sh
EOF
