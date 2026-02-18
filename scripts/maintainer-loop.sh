#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# OpenClaw runtime tree in container. externalize-runtime-md.sh scans under this root.
OPENCLAW_REPO_DIR="${OPENCLAW_REPO_DIR:-/app}"
OBSIDIAN_VAULT_DIR="${OBSIDIAN_VAULT_DIR:-/workspace/vault}"
OBSTOOLS_DIR="${OBSTOOLS_DIR:-$OBSIDIAN_VAULT_DIR/ObsToolsVault}"
STATE_DIR="${STATE_DIR:-$OBSTOOLS_DIR/state}"
STATE_FILE="${STATE_FILE:-$STATE_DIR/openclaw_obsidian_state.json}"
QUEUE_FILE="${QUEUE_FILE:-$STATE_DIR/openclaw_obsidian_queue.json}"
SCAN_INTERVAL_SEC="${SCAN_INTERVAL_SEC:-60}"
INIT_EXTERNALIZE_MD="${INIT_EXTERNALIZE_MD:-1}"
MIGRATION_SUGGESTIONS_FILE="${MIGRATION_SUGGESTIONS_FILE:-$OBSTOOLS_DIR/specs/migration_suggestions.md}"
AGENT_EXECUTE_GUIDE_FILE="${AGENT_EXECUTE_GUIDE_FILE:-$OBSTOOLS_DIR/specs/agent_execute_guide.md}"

for bin in jq sleep date node; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "missing dependency: $bin" >&2
    exit 1
  fi
done

mkdir -p "$STATE_DIR"
"$SCRIPT_DIR/ensure-openclaw-config.sh"
"$SCRIPT_DIR/ensure-zh-tw-default.sh"
echo "[maintainer] init repo_dir=$OPENCLAW_REPO_DIR vault_dir=$OBSIDIAN_VAULT_DIR state_dir=$STATE_DIR init_externalize_md=$INIT_EXTERNALIZE_MD"

if [ ! -f "$STATE_FILE" ]; then
  jq -n \
    '{last_scan_at:null, files:{}, last_run:{changed_count:0, processed_count:0, error_count:0, status:"init"}}' \
    >"$STATE_FILE"
fi

if [ ! -f "$QUEUE_FILE" ]; then
  jq -n \
    '{updated_at:null, pending:[], deleted:[], retry_count:0, last_error:null}' \
    >"$QUEUE_FILE"
fi

if [ "$INIT_EXTERNALIZE_MD" = "1" ]; then
  "$SCRIPT_DIR/externalize-runtime-md.sh"
fi

while true; do
  now_utc="$(date -u +%FT%TZ)"

  scan_json="$("$SCRIPT_DIR/scan-vault-hash.sh")"
  changed_json="$(jq '.changed' <<<"$scan_json")"
  deleted_json="$(jq '.deleted' <<<"$scan_json")"
  current_json="$(jq '.current' <<<"$scan_json")"

  changed_count="$(jq 'length' <<<"$changed_json")"
  deleted_count="$(jq 'length' <<<"$deleted_json")"
  echo "[maintainer] scan changed=$changed_count deleted=$deleted_count ts=$now_utc"

  if [ "$changed_count" -eq 0 ] && [ "$deleted_count" -eq 0 ]; then
    tmp_state="$(mktemp)"
    jq \
      --arg ts "$now_utc" \
      '.last_scan_at = $ts
      | .last_run = {changed_count:0, processed_count:0, error_count:0, status:"idle"}' \
      "$STATE_FILE" >"$tmp_state"
    mv "$tmp_state" "$STATE_FILE"
    sleep "$SCAN_INTERVAL_SEC"
    continue
  fi

  current_tmp_before="$(mktemp)"
  changed_tmp_before="$(mktemp)"
  changed_before_meta_tmp="$(mktemp)"
  printf '%s\n' "$current_json" >"$current_tmp_before"
  printf '%s\n' "$changed_json" >"$changed_tmp_before"
  jq -n \
    --slurpfile current "$current_tmp_before" \
    --slurpfile changed "$changed_tmp_before" \
    '($current[0] // {}) as $current
    | ($changed[0] // []) as $changed
    | reduce ($changed[]?) as $path ({}; .[$path] = ($current[$path] // null))' \
    >"$changed_before_meta_tmp"
  rm -f "$current_tmp_before" "$changed_tmp_before"

  jq -n \
    --arg ts "$now_utc" \
    --argjson changed "$changed_json" \
    --argjson deleted "$deleted_json" \
    '{updated_at:$ts, pending:$changed, deleted:$deleted, retry_count:0, last_error:null}' \
    >"$QUEUE_FILE"

  changed_lines="$(jq -r '.[0:200][] | "- " + .' <<<"$changed_json")"
  deleted_lines="$(jq -r '.[0:200][] | "- " + .' <<<"$deleted_json")"

  if [ -z "$changed_lines" ]; then
    changed_lines="- (none)"
  fi
  if [ -z "$deleted_lines" ]; then
    deleted_lines="- (none)"
  fi

  prompt="$(cat <<EOF
執行 Obsidian 維護任務，使用 skills: obsidian。

規則來源：
- $OBSTOOLS_DIR/*.md
- $MIGRATION_SUGGESTIONS_FILE
- $AGENT_EXECUTE_GUIDE_FILE

處理要求：
1. 僅處理變更或刪除的筆記。
2. 允許直接更新 migration_suggestions.md 與 agent_execute_guide.md。
3. state 檔僅可寫入 $STATE_DIR。
4. 其餘檔案維持最小必要變更。

變更檔案：
$changed_lines

刪除檔案：
$deleted_lines
EOF
)"

  agent_cmd=(node /app/openclaw.mjs agent --thinking low --message "$prompt")
  if [ -n "${OPENCLAW_AGENT_ID:-}" ]; then
    agent_cmd+=(--agent "$OPENCLAW_AGENT_ID")
  fi

  if "${agent_cmd[@]}"; then
    post_scan_json="$("$SCRIPT_DIR/scan-vault-hash.sh")"
    post_current_json="$(jq '.current' <<<"$post_scan_json")"
    post_current_tmp="$(mktemp)"
    printf '%s\n' "$post_current_json" >"$post_current_tmp"
    touched_count="$(jq -n \
      --slurpfile before "$changed_before_meta_tmp" \
      --slurpfile after "$post_current_tmp" \
      '($before[0] // {}) as $before
      | ($after[0] // {}) as $after
      | [($before | to_entries[]) as $entry
        | $entry.key as $path
        | $entry.value as $before_meta
        | ($after[$path] // null) as $after_meta
        | select($before_meta == null or $after_meta == null or ($before_meta.sha256 != $after_meta.sha256))
      ] | length')"
    rm -f "$changed_before_meta_tmp" "$post_current_tmp"

    if [ "$changed_count" -gt 0 ] && [ "$touched_count" -eq 0 ]; then
      echo "[maintainer] agent_no_effect changed=$changed_count touched=$touched_count"
      retry_count="$(jq -r '.retry_count // 0' "$QUEUE_FILE")"
      next_retry=$((retry_count + 1))
      jq -n \
        --arg ts "$now_utc" \
        --argjson changed "$changed_json" \
        --argjson deleted "$deleted_json" \
        --argjson retry "$next_retry" \
        --arg err "agent_no_effect" \
        '{updated_at:$ts, pending:$changed, deleted:$deleted, retry_count:$retry, last_error:$err}' \
        >"$QUEUE_FILE"

      tmp_state="$(mktemp)"
      jq \
        --arg ts "$now_utc" \
        --argjson changed_count "$changed_count" \
        --arg err "agent_no_effect" \
        '.last_scan_at = $ts
        | .last_run = {
            changed_count:$changed_count,
            processed_count:0,
            error_count:1,
            status:"failed",
            error:$err
          }' \
        "$STATE_FILE" >"$tmp_state"
      mv "$tmp_state" "$STATE_FILE"
    else
    current_tmp="$(mktemp)"
    new_files_tmp="$(mktemp)"
    printf '%s\n' "$post_current_json" >"$current_tmp"

    jq -n \
      --arg ts "$now_utc" \
      --slurpfile current "$current_tmp" \
      'reduce (($current[0] // {}) | to_entries[]) as $entry ({}; .[$entry.key] = {
        sha256:$entry.value.sha256,
        mtime:$entry.value.mtime,
        last_processed_at:$ts,
        status:"synced"
      })' \
      >"$new_files_tmp"

    jq -n \
      --arg ts "$now_utc" \
      --slurpfile files "$new_files_tmp" \
      --argjson changed_count "$changed_count" \
      '{last_scan_at:$ts,
        files:($files[0] // {}),
        last_run:{
          changed_count:$changed_count,
          processed_count:$changed_count,
          error_count:0,
          status:"success"
        }}' \
      >"$STATE_FILE"

    rm -f "$current_tmp" "$new_files_tmp"

    jq -n \
      --arg ts "$now_utc" \
      '{updated_at:$ts, pending:[], deleted:[], retry_count:0, last_error:null}' \
      >"$QUEUE_FILE"
    fi
  else
    rm -f "$changed_before_meta_tmp"
    retry_count="$(jq -r '.retry_count // 0' "$QUEUE_FILE")"
    next_retry=$((retry_count + 1))

    jq -n \
      --arg ts "$now_utc" \
      --argjson changed "$changed_json" \
      --argjson deleted "$deleted_json" \
      --argjson retry "$next_retry" \
      --arg err "agent_run_failed" \
      '{updated_at:$ts, pending:$changed, deleted:$deleted, retry_count:$retry, last_error:$err}' \
      >"$QUEUE_FILE"

    tmp_state="$(mktemp)"
    jq \
      --arg ts "$now_utc" \
      --argjson changed_count "$changed_count" \
      --arg err "agent_run_failed" \
      '.last_scan_at = $ts
      | .last_run = {
          changed_count:$changed_count,
          processed_count:0,
          error_count:1,
          status:"failed",
          error:$err
        }' \
      "$STATE_FILE" >"$tmp_state"
    mv "$tmp_state" "$STATE_FILE"
  fi

  sleep "$SCAN_INTERVAL_SEC"
done
