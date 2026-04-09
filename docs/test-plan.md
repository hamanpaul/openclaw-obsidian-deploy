# o-pi3 遷移測試計畫

本文件依 `custom-skills/test-playbook` 的原則設計：**先盤點系統，再做風險矩陣，再決定測試層與 harness**。

## 1. 系統盤點

### Actors

| Actor | 角色 | Side effect owner |
| --- | --- | --- |
| `openclaw-obsidian-maintainer` | 掃描 vault、更新 queue/state、呼叫 agent | `ObsToolsVault/state/*` |
| `openclaw-obsidian-gateway` | 提供 OpenClaw gateway 與 control UI | `/home/node/.openclaw` |
| `openclaw-obsidian-sync` (`obs`) | 執行 Obsidian headless sync | `~/.config/obsidian-headless`, sync log, incident log |
| `openclaw-obsidian-ops-companion` (`ops`) | 提供 approval / execution backend | `~/.config/picoclaw-ops-companion`, `~/.picoclaw/workspace` |
| `openclaw-obsidian-serialwrap` (`serialwrap`) | 提供 serialwrap daemon / MCP bridge / COM0 profile bootstrap | `~/.config/serialwrap/profiles`, `~/.local/state/serialwrap`, `/host-dev` |
| Docker build | 匯入外部 source 並注入 skills | `/app/skills`, `/app/.agents/skills`, `/opt/external-sources` |

### 持久化面

- `OPENCLAW_CONFIG_HOST_DIR`
- `OBSIDIAN_VAULT_HOST_DIR`
- `OBSIDIAN_HEADLESS_CONFIG_HOST_DIR`
- `PICOCLAW_WORKSPACE_HOST_DIR`
- `OPS_COMPANION_CONFIG_HOST_DIR`
- `SERIALWRAP_PROFILES_HOST_DIR`
- `SERIALWRAP_STATE_HOST_DIR`
- `SERIALWRAP_HOST_DEV_DIR`
- `build-context/external-sources/manifest.json`

### 非同步與邊界

- base image build vs wrapper image build
- compose profile 開關（核心服務 / `obs` / `ops` / `serialwrap`）
- volume mount 與 host path 權限
- runtime skills externalize

## 2. 風險矩陣

| Surface | 風險 | 建議測試層 | Oracle |
| --- | --- | --- | --- |
| base image 自動抓 tag | 抓錯版本 / clone 失敗 | integration | `prepare-openclaw-base-image.sh` exit code + image tag |
| 外部 source snapshot | stage 缺目錄 / ref 漂移 | integration | `build-context/external-sources/manifest.json` |
| Docker build skill 注入 | skills 沒被 copy 到 `/app/*skills` | integration | container 內目錄內容 |
| compose 核心服務 | maintainer / gateway 起不來 | e2e | `docker compose ps` + logs |
| `obs` profile | 缺 `ob` / 缺 auth config | functional | sidecar logs + clear error message |
| `ops` profile | dist 未 build / config 缺漏 | functional | sidecar logs + listener 啟動 |
| `serialwrap` profile | daemon 起不來 / profile dir 沒 seed / host dev mirror 錯誤 | functional | `serialwrap_ping` + seeded profile files + warning message |
| 文件 drift | README / path mapping 與實作不一致 | doc audit | command / env / path 一致性 |

## 3. 測試層分配

### Unit / Static

- `bash -n scripts/*.sh`
- YAML / compose 片段結構檢查

### Integration

- `./scripts/prepare-openclaw-base-image.sh`
- `./scripts/prepare-external-sources.sh`
- `docker compose --env-file ./.env -f ./docker-compose.obsidian.yml config`
- `docker compose --env-file ./.env -f ./docker-compose.obsidian.yml --profile obs --profile ops --profile serialwrap config`

### E2E

- build wrapper image
- `up -d` 啟動 maintainer + gateway
- 確認 injected skills 已進入 container

### Functional

- 啟動 `obs` profile，驗證 `obs-sync-entrypoint.sh`
- 啟動 `ops` profile，驗證 `ops-companion-entrypoint.sh`
- 啟動 `serialwrap` profile，驗證 daemon health / seeded profile / clear hardware warning
- 驗證 control UI 與 model default 不回退

## 4. Harness / 測試前置

- 使用臨時 host dir 建立：
  - fake vault
  - fake `~/.openclaw`
  - fake `~/.config/obsidian-headless`
  - fake `~/.config/picoclaw-ops-companion`
  - fake `~/.picoclaw/workspace`
  - fake `~/.config/serialwrap/profiles`
  - fake `~/.local/state/serialwrap`
  - fake host `/dev` mirror dir
- 不新增測試框架；沿用現有 shell script + docker compose

## 5. 優先順序

1. deterministic：script syntax、source snapshot、compose config
2. build：base image、wrapper image
3. core runtime：maintainer + gateway
4. optional runtime：`obs` / `ops` / `serialwrap`
5. 文件對齊：README、path mapping、todo / plan / tasks

## 6. 驗證命令

```bash
bash -n scripts/*.sh
./scripts/prepare-openclaw-base-image.sh
./scripts/prepare-external-sources.sh
cat ./build-context/external-sources/manifest.json | jq '.'
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml config
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml --profile obs --profile ops --profile serialwrap config
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml build
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml up -d
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml ps
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml logs --tail=120 openclaw-obsidian-maintainer
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml logs --tail=120 openclaw-obsidian-gateway
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml --profile serialwrap up -d openclaw-obsidian-serialwrap
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-serialwrap \
  /home/node/.paul_tools/serialwrap-mcp --tool serialwrap_ping --params '{}'
```

## 7. 待回填結果

- base image build 成功：
  - `openclaw:v2026.2.15`
  - image id: `sha256:e4225276200e3a61ae51d54d6d79c78f482dc6c8d24e34d67e0795989d7675d3`
- wrapper image build 成功：
  - `openclaw-obsidian:test`
  - image id: `sha256:a8af45233c32ec8c4c1282d3060f32bf4f9e48caa0b1e4b23ed79b23fda6514b`
- 外部 source snapshot 成功：
  - `custom-claw-tools@60cb919852d9283a0a4615a9457909b849cb78a1`
  - `custom-skills@6211a5a4e6af7a2d0ea9717cea64f1b56bb872af`
  - `serialwrap@c889019700280837ba98dd7a53999f95861e75f8`
- `docker compose --profile obs --profile ops --profile serialwrap config` 成功展開
- core services 臨時 smoke：
  - `openclaw-obsidian-maintainer` / `openclaw-obsidian-gateway` 均可啟動
  - `maintainer` 在臨時空 config 下仍完成 `externalized markdown files: 82`
  - 後續失敗點為預期中的缺 auth：`No API key found for provider "github-copilot"`（因測試 env 未掛入真實 auth store）
- `obs` profile 臨時 smoke：
  - 缺 sync config / token 時會留下 incident log，並輸出 `obs sync stopped on terminal config failure; inspect incident log/config before restarting`
  - 已避免先前的 crash loop；容器會 clean exit，不再反覆重啟
- `ops` profile 臨時 smoke：
  - sidecar 可正常啟動
  - loopback listener 回應 `HTTP/1.1 404 Not Found`（`/` 非有效 endpoint，但 listener 已起）
  - logs 顯示 `ops companion loopback listener started`
- `serialwrap` profile 臨時 smoke：
  - sidecar 可正常啟動並通過 healthcheck
  - `serialwrap_ping` 回傳 `{\"id\":1,\"ok\":true,\"pong\":true}`
  - 首次啟動會 seed `default.yaml`、`brcm.env` 與 `OPI.env.example`
  - 若尚未把 host `/dev` 映射進來，logs 會清楚提示 `device discovery dir not found: /host-dev/serial/by-id`
- final image all-in-one runtime：
  - 直接 `docker run openclaw-obsidian:test` 會自動啟動 `maintainer`、`gateway`、`ops`、`serialwrap`
  - `obs` 在缺 sync config/token 的情況下會 clean exit 並留下 incident log，不會拖垮整個 container
  - container 內可觀察到 `maintainer-loop.sh`、`openclaw-gateway`、`picoclaw-ops-companion`、`serialwrapd.py`
  - `serialwrap_ping` 在 all-in-one 模式下同樣通過
  - host 端 `http://127.0.0.1:<mapped-gateway-port>/` 可回應 OpenClaw Control UI，`http://127.0.0.1:<mapped-ops-port>/` 會回 `404 unknown endpoint: /`，表示 listener 已起
  - fresh bind mount 即使先被 Docker 建成 `root:root`，runtime bootstrap 也會先修正 `/workspace/vault`、`/home/node/.openclaw`、`obsidian-headless`、`ops`、`serialwrap` 相關目錄權限後再降權啟動
