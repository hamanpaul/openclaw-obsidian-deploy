# Path Mapping (Host <-> Container)

Last updated: 2026-02-18

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

## Externalize Source Contract

`scripts/externalize-runtime-md.sh` 掃描以下容器內來源（若缺失僅 warning，不中斷）：

- `${OPENCLAW_REPO_DIR:-/app}/skills`
- `${OPENCLAW_REPO_DIR:-/app}/.agents/skills`
- `${OPENCLAW_REPO_DIR:-/app}/docs/reference/templates`

externalize 目的地：

- `${OPENCLAW_EXTERNAL_MD_DIR:-/workspace/vault/openclaw}`

manifest 目的地：

- `${MANIFEST_FILE:-/workspace/vault/ObsToolsVault/state/openclaw_md_manifest.json}`

## 驗證建議

```bash
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml config
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-maintainer /bin/bash -lc 'echo "$OPENCLAW_REPO_DIR"; ls -la /workspace/vault/ObsToolsVault/state'
```
