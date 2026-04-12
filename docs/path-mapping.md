# Path Mapping (Host <-> Container)

Last updated: 2026-04-12

## Purpose

This repo now deploys a **single all-in-one container**. The image contains OpenClaw, `custom-claw-tools`, and `custom-skills`; host mounts provide auth, notes, configs, SSH material, and mutable runtime state.

## Main mapping table

| Logical name | Host path | Container path | Notes |
| --- | --- | --- | --- |
| Canonical OpenClaw Workspace | `${OPENCLAW_WORKSPACE_HOST_DIR}` | `/workspace` | OpenClaw workspace root; AGENTS and workspace-root aliases live here |
| Home-compatible Workspace Mirror | `${OPENCLAW_WORKSPACE_HOST_DIR}` | `/home/appuser/.picoclaw/workspace` | keeps older home-based tools pointed at the same host workspace |
| Raw Vault Mirror | `${OBSIDIAN_VAULT_HOST_DIR}` | `/workspace/vault` | optional secondary mount kept for backward compatibility and manual inspection |
| OpenClaw Config | `${OPENCLAW_CONFIG_HOST_DIR}` | `/home/appuser/.openclaw` | auth profiles, models, cron store, canvas state |
| User Config | `${USER_CONFIG_HOST_DIR}` | `/home/appuser/.config` | obsidian-headless sync/auth config, fami-ghome env, health-tracker runtime config, gws CLI auth/config |
| PicoClaw Home | `${PICOCLAW_HOME_HOST_DIR}` | `/home/appuser/.picoclaw` | runtime workspace, logs, legacy home-compatible state |
| User Local | `${USER_LOCAL_HOST_DIR}` | `/home/appuser/.local` | mounted writable local state; startup recreates helper links in `.local/bin` |
| Garmin DB | `${GARMIN_DB_HOST_DIR}` | `/home/appuser/.GarminDb` | Garmin DB runtime state |
| Garmin env file | `${GARMIN_ENV_HOST_FILE}` | `/home/appuser/.garmin.env` | GarminDB CLI env file |
| Gemini config dir | `${GEMINI_CONFIG_HOST_DIR}` | `/home/appuser/.gemini` | Gemini CLI env/config directory; startup also reads `GOOGLE_API_KEY` here to wire OpenClaw's Google provider |
| Health Data | `${HEALTH_DATA_HOST_DIR}` | `/home/appuser/HealthData` | synced health data |
| SSH | `${SSH_DIR_HOST_DIR}` | `/home/appuser/.ssh` | mounted read-only |
| OpenClaw runtime tree | image filesystem | `/app` | built OpenClaw runtime |
| Custom claw tools source | image filesystem | `/home/appuser/custom-claw-tools` | cloned into image at build time |
| Custom skills source | image filesystem | `/home/appuser/custom-skills` | cloned into image at build time |
| Runtime skill root | image filesystem | `/home/appuser/.agents/skills` | materialized skill directories consumed by OpenClaw |
| Repo-local skill shim | symlink in image | `/app/.agents/skills -> /home/appuser/.agents/skills` | keeps maintainer/externalize scan path stable |
| Legacy home alias | symlink in image | `/home/haman -> /home/appuser` | preserves hardcoded upstream paths |

## Vault-side derived paths

| Logical name | Host path | Container path | Producer |
| --- | --- | --- | --- |
| Notes Root | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes` | `/workspace/notes` | canonical notes root for maintainer loop, git backup, and OpenClaw exports |
| ObsTools Root | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes/ObsToolsVault` | `/workspace/notes/ObsToolsVault` | obsidian design-management rules |
| State Dir | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes/ObsToolsVault/state` | `/workspace/notes/ObsToolsVault/state` | maintainer loop |
| Queue File | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes/ObsToolsVault/state/openclaw_obsidian_queue.json` | `/workspace/notes/ObsToolsVault/state/openclaw_obsidian_queue.json` | maintainer loop |
| State File | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes/ObsToolsVault/state/openclaw_obsidian_state.json` | `/workspace/notes/ObsToolsVault/state/openclaw_obsidian_state.json` | maintainer loop |
| Manifest File | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes/ObsToolsVault/state/openclaw_md_manifest.json` | `/workspace/notes/ObsToolsVault/state/openclaw_md_manifest.json` | `externalize-runtime-md.sh` |
| OpenClaw Notes Root | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes/claw` | `/workspace/notes/claw` | claw-specific generated notes and artifacts |
| OpenClaw Memory Dir | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes/claw/memory` | `/workspace/notes/claw/memory` | daily memory files plus backward-compatible `memory/MEMORY.md` alias |
| OpenClaw Memory File | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes/claw/MEMORY.md` | `/workspace/notes/claw/MEMORY.md` | canonical curated long-term memory |
| User File | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes/claw/USER.md` | `/workspace/notes/claw/USER.md` | user profile |
| Soul File | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes/claw/SOUL.md` | `/workspace/notes/claw/SOUL.md` | agent soul/profile |
| Research Dir | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes/claw/research` | `/workspace/notes/claw/research` | morning research outputs |
| Health Dir | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes/claw/health` | `/workspace/notes/claw/health` | health-management outputs |
| Externalized Markdown Root | `${OPENCLAW_WORKSPACE_HOST_DIR}/notes/claw/openclaw` | `/workspace/notes/claw/openclaw` | `externalize-runtime-md.sh` |

## Workspace-root aliases

Container startup keeps these workspace-root aliases aligned with the canonical `notes/claw` locations:

| Workspace root path | Target |
| --- | --- |
| `/workspace/memory` | `/workspace/notes/claw/memory` |
| `/workspace/MEMORY.md` | `/workspace/notes/claw/MEMORY.md` |
| `/workspace/USER.md` | `/workspace/notes/claw/USER.md` |
| `/workspace/SOUL.md` | `/workspace/notes/claw/SOUL.md` |

Container startup also keeps the legacy nested memory entry aligned:

| Legacy path | Canonical target |
| --- | --- |
| `/workspace/notes/claw/memory/MEMORY.md` | `/workspace/notes/claw/MEMORY.md` |

## Runtime-generated internal files

| Logical name | Container path | Backing mount |
| --- | --- | --- |
| supercronic crontab | `/home/appuser/.local/state/openclaw/supercronic.crontab` | `${USER_LOCAL_HOST_DIR}` |
| OpenClaw cron store | `/home/appuser/.openclaw/cron.json` | `${OPENCLAW_CONFIG_HOST_DIR}` |
| Supervisor socket | `/home/appuser/.cache/supervisor/supervisor.sock` | image/local runtime dir |

## Externalize scan contract

`scripts/externalize-runtime-md.sh` scans:

- `/app/skills`
- `/app/.agents/skills`
- `/app/docs/reference/templates`

and writes externalized markdown into:

- `/workspace/notes/claw/openclaw`

with manifest at:

- `/workspace/notes/ObsToolsVault/state/openclaw_md_manifest.json`

## Operational notes

- Container startup briefly runs as root to fix ownership on writable bind mounts, then supervisord runs each managed service as `appuser`.
- If a previous deployment populated `notes/claw/memory/MEMORY.md`, startup migrates that content into the canonical `notes/claw/MEMORY.md` file and recreates the legacy nested path as a compatibility alias.
- If host config is missing, wrappers keep the service **running in wait mode** or scheduled jobs **skip cleanly** instead of crashing the whole container.
- obsidian-headless sync config is expected at `${USER_CONFIG_HOST_DIR}/obsidian-headless/sync/<vault-id>/config.json`.
- `USER_LOCAL_HOST_DIR` is intentionally mounted even though helper binaries live there; startup rehydrates the required symlinks on every boot.

## Validation

```bash
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml config
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec openclaw-obsidian supervisorctl status
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec openclaw-obsidian /bin/bash -lc 'ls -ld /app/.agents/skills /home/appuser/.agents/skills'
```
