# Path Mapping (Host <-> Container)

Last updated: 2026-04-08

## 目的

本文件定義 `openclaw-obsidian-deploy` 內部主要路徑對映，供部署、除錯與 externalize 行為追蹤。

## Mapping Table

| logical_name | host_path | container_path | producer | consumer | notes |
| --- | --- | --- | --- | --- | --- |
| Obsidian Vault Root | `${OBSIDIAN_VAULT_HOST_DIR}` | `/workspace/vault` | Host user / Obsidian | maintainer, gateway, scripts | 所有 vault 相關資料入口 |
| OpenClaw Config | `${OPENCLAW_CONFIG_HOST_DIR}` | `/home/node/.openclaw` | Host user / OAuth login | openclaw runtime, gateway | auth 與 profile 持久化，不進 image layer |
| ObsTools Root | `${OBSIDIAN_VAULT_HOST_DIR}/ObsToolsVault` | `/workspace/vault/ObsToolsVault` | maintainer scripts | maintainer scripts | 規格、狀態與任務輔助檔 |
| State Dir | `${OBSIDIAN_VAULT_HOST_DIR}/ObsToolsVault/state` | `/workspace/vault/ObsToolsVault/state` | `maintainer-loop.sh` | `maintainer-loop.sh`, `scan-vault-hash.sh` | 包含 `state/queue/manifest` |
| Queue File | `${OBSIDIAN_VAULT_HOST_DIR}/ObsToolsVault/state/openclaw_obsidian_queue.json` | `/workspace/vault/ObsToolsVault/state/openclaw_obsidian_queue.json` | `maintainer-loop.sh` | `maintainer-loop.sh` | 待處理變更清單與重試資訊 |
| State File | `${OBSIDIAN_VAULT_HOST_DIR}/ObsToolsVault/state/openclaw_obsidian_state.json` | `/workspace/vault/ObsToolsVault/state/openclaw_obsidian_state.json` | `maintainer-loop.sh` | `maintainer-loop.sh`, `scan-vault-hash.sh` | 掃描 baseline 與最後執行狀態 |
| Manifest File | `${OBSIDIAN_VAULT_HOST_DIR}/ObsToolsVault/state/openclaw_md_manifest.json` | `/workspace/vault/ObsToolsVault/state/openclaw_md_manifest.json` | `externalize-runtime-md.sh` | maintainer scripts / operators | externalized markdown 對照清單 |
| Externalized Markdown Root | `${OBSIDIAN_VAULT_HOST_DIR}/openclaw` | `/workspace/vault/openclaw` | `externalize-runtime-md.sh` | openclaw runtime / operators | OpenClaw 來源 markdown 的 vault 映射根目錄 |
| OpenClaw Runtime Tree | N/A (image filesystem) | `${OPENCLAW_REPO_DIR:-/app}` | base image (`openclaw:v2026.2.15`) | `externalize-runtime-md.sh`, runtime commands | 來源掃描目錄：`skills/`, `.agents/skills/`, `docs/reference/templates/` |
| External Source Snapshot | `${OPENCLAW_EXTERNAL_SOURCES_DIR:-./build-context/external-sources}` | `/opt/external-sources` | `scripts/prepare-external-sources.sh` | Docker build, optional sidecars | `custom-claw-tools` / `custom-skills` / `serialwrap` 快照與 manifest |
| Imported Runtime Skills | N/A (image filesystem) | `/app/skills` | Docker build from external snapshot | OpenClaw runtime, `externalize-runtime-md.sh` | 目前會匯入 `famiclean` 與 `ops-companion` skill 內容 |
| Imported Agent Skills | N/A (image filesystem) | `/app/.agents/skills` | Docker build from external snapshot | operators, `externalize-runtime-md.sh` | 目前會匯入 `test-playbook` 與 `serialwrap-mcp` |
| Serialwrap Tool Root | N/A (image filesystem) | `/home/node/.paul_tools` | Docker build from external snapshot | `openclaw-obsidian-serialwrap`, operators | 由 `hamanpaul/serialwrap` 安裝出的 daemon / CLI / MCP wrapper |
| Obsidian Headless Config | `${OBSIDIAN_HEADLESS_CONFIG_HOST_DIR:-./.runtime/obsidian-headless}` | `/home/node/.config/obsidian-headless` | Host user / `obsidian-headless` auth | `openclaw-obsidian-sync` | `obs` profile 所需 auth token 與 sync config |
| PicoClaw Workspace | `${PICOCLAW_WORKSPACE_HOST_DIR:-./.runtime/picoclaw-workspace}` | `/home/node/.picoclaw/workspace` | Host user / operator | `openclaw-obsidian-ops-companion` | `ops` companion 使用的 workspace 與 artifact 根目錄 |
| Ops Companion Config | `${OPS_COMPANION_CONFIG_HOST_DIR:-./.runtime/picoclaw-ops-companion}` | `/home/node/.config/picoclaw-ops-companion` | Host user / operator | `openclaw-obsidian-ops-companion` | 包含 TOTP secret 與 companion config |
| Serialwrap Profiles | `${SERIALWRAP_PROFILES_HOST_DIR:-./.runtime/serialwrap/profiles}` | `/home/node/.config/serialwrap/profiles` | Host user / operator | `openclaw-obsidian-serialwrap` | profile YAML 與 `OPI.env` 等 login env 檔，首次可由容器 seed 預設模板 |
| Serialwrap State | `${SERIALWRAP_STATE_HOST_DIR:-./.runtime/serialwrap/state}` | `/home/node/.local/state/serialwrap` | serialwrap daemon | `openclaw-obsidian-serialwrap`, operators | socket / lock / WAL / logs 都落在這裡 |
| Serialwrap Host Dev Mirror | `${SERIALWRAP_HOST_DEV_DIR:-./.runtime/serialwrap/dev}` | `/host-dev` | Host user | `openclaw-obsidian-serialwrap` | 要吃真實 USB serial 時設成 `/dev`，供 `/host-dev/serial/by-id` 探測 |

## Externalize Source Contract

`scripts/externalize-runtime-md.sh` 掃描以下容器內來源（若缺失僅 warning，不中斷）：

- `${OPENCLAW_REPO_DIR:-/app}/skills`
- `${OPENCLAW_REPO_DIR:-/app}/.agents/skills`
- `${OPENCLAW_REPO_DIR:-/app}/docs/reference/templates`

其中 `/app/skills` 與 `/app/.agents/skills` 會在 image build 時再額外注入：

- `custom-claw-tools/famiclean-skill/skills`
- `custom-claw-tools/picoclaw-ops-companion/skills`
- `custom-skills/test-playbook`
- `custom-skills/serialwrap-mcp`

externalize 目的地：

- `${OPENCLAW_EXTERNAL_MD_DIR:-/workspace/vault/openclaw}`

manifest 目的地：

- `${MANIFEST_FILE:-/workspace/vault/ObsToolsVault/state/openclaw_md_manifest.json}`

## 驗證建議

```bash
./scripts/prepare-external-sources.sh
cat ./build-context/external-sources/manifest.json | jq '.'
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml config
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml --profile obs --profile ops --profile serialwrap config
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-maintainer /bin/bash -lc 'echo "$OPENCLAW_REPO_DIR"; ls -la /workspace/vault/ObsToolsVault/state'
```
