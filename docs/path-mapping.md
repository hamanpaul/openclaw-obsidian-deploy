# Path Mapping (Public Quickstart and Addon Example)

Last updated: 2026-04-12

## Purpose

This repository now documents a **public-first** Docker layout:

1. a generic all-in-one OpenClaw base image
2. a public addon example
3. synthetic local fixtures that contain no personal data

## Quickstart mapping

| Logical name | Host path | Container path | Notes |
| --- | --- | --- | --- |
| OpenClaw config mount | `${OPENCLAW_CONFIG_HOST_DIR}` | `/home/appuser/.openclaw` | populated on first boot by `ensure-openclaw-config.sh`; default points to the synthetic quickstart fixture |
| Workspace mount | `${OPENCLAW_WORKSPACE_HOST_DIR}` | `/workspace` | safe synthetic workspace for local smoke tests by default; can be replaced with your own mounted data |
| OpenClaw runtime tree | image filesystem | `/app` | built OpenClaw runtime |
| Skill install target | image filesystem or mounted runtime state | `/home/appuser/.agents/skills` | base image keeps this path stable for optional addon skills |
| Addon root | image filesystem | `/opt/openclaw-addons` | public extension point for extra bins, skills, and supervisor configs |

## Addon example mapping

| Logical name | Host path | Container path | Notes |
| --- | --- | --- | --- |
| Addon config mount | `${OPENCLAW_ADDONS_CONFIG_HOST_DIR}` | `/home/appuser/.openclaw` | independent from the quickstart mount; default points to the synthetic addon fixture |
| Addon workspace mount | `${OPENCLAW_ADDONS_WORKSPACE_HOST_DIR}` | `/workspace` | receives the example heartbeat file |
| Example heartbeat state | `build-context/local-test/addons-example/workspace/addons-example/state` | `/workspace/addons-example/state` | written by the addon example process |

## Runtime-generated files

| Logical name | Container path | Notes |
| --- | --- | --- |
| OpenClaw config | `/home/appuser/.openclaw/openclaw.json` | copied from `config-template/openclaw.json` when missing |
| OpenClaw models config | `/home/appuser/.openclaw/agents/main/agent/models.json` | copied from `config-template/agents/main/agent/models.json` when missing |
| Cron store | `/home/appuser/.openclaw/cron.json` | configured even when the quickstart image does not seed any jobs |
| Supervisor socket | `/home/appuser/.cache/supervisor/supervisor.sock` | used by `supervisorctl` and `container-systemctl.sh` |
| Example heartbeat | `/workspace/addons-example/state/heartbeat.json` | public addon example output |

## Extension contract

The public base image keeps three extension points:

| Extension point | Path | Expected content |
| --- | --- | --- |
| extra binaries | `/opt/openclaw-addons/bin` | executable files symlinked into `.local/bin` and `/usr/local/bin` |
| extra skills | `/opt/openclaw-addons/skills` | directories containing `SKILL.md` |
| extra supervisor programs | `/etc/supervisor/conf.d/*.conf` | additional `supervisord` program definitions |

## Operational notes

- The base image only manages `openclaw-gateway` by default.
- The addon example adds one extra program, `addons-example-heartbeat`, through `/etc/supervisor/conf.d/addons-example.conf`.
- `ensure-zh-tw-default.sh` remains available, but it is **opt-in** through `OPENCLAW_BOOTSTRAP_AGENTS_FILE=1`.
- No public compose file in this repo depends on personal notes, personal auth caches, device paths, or private backups.
