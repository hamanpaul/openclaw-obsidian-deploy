# openclaw-obsidian-deploy

純部署 repo，僅保留 OpenClaw + Obsidian 維護所需檔案，已移除個人資料依賴（auth token、私人筆記、操作紀錄）。

目前最終 image 採 **all-in-one runtime**：`docker run openclaw-obsidian:test` 時，會自動啟動 `maintainer + gateway + obs + ops + serialwrap`；`docker compose` 仍保留分拆 sidecar 的操作模式。

## 內容

- `Dockerfile`：以 `OPENCLAW_BASE_IMAGE` 為基底的薄包裝映像。
- `docker-compose.obsidian.yml`：維護服務部署（maintainer + gateway）與可選 `obs` / `ops` / `serialwrap` sidecar。
- `.env.example`：部署參數範本（無個資）。
- `build-context/external-sources/`：Docker build 前由腳本產生的外部 source snapshot。
- `scripts/`：基底映像建置、外部 source staging、一鍵 smoke 測試、掃描、外部化、主循環、一鍵打包腳本。
- `docs/path-mapping.md`：host/container 路徑對映說明。
- `docs/plan.md` / `docs/tasks.md` / `docs/todo.md` / `docs/test-plan.md`：本次 o-pi3 遷移與驗證文件。

## 個資邊界

- 不含 `.env`、`~/.openclaw`、`logs/`、任何筆記內容。
- 認證資料僅透過容器掛載 `OPENCLAW_CONFIG_HOST_DIR` 讀取，不進 repo。

## 快速部署（本機可重建）

1) 建立環境檔：

```bash
/bin/cp ./.env.example ./.env
```

2) 編輯 `.env`（至少改這些）：

- `OBSIDIAN_VAULT_HOST_DIR`
- `OPENCLAW_CONFIG_HOST_DIR`
- `OPENCLAW_DOCKER_USER`
- `OPENCLAW_BASE_IMAGE`
- `OPENCLAW_BASE_IMAGE_GIT_URL`
- `OPENCLAW_DEFAULT_MODEL`
- `OPENCLAW_DEFAULT_PROFILE_ID`
- `OPENCLAW_ENABLE_TELEGRAM_PLUGIN`

可選但建議一併確認：

- `CUSTOM_CLAW_TOOLS_GIT_URL`
- `CUSTOM_SKILLS_GIT_URL`
- `OBSIDIAN_HEADLESS_CONFIG_HOST_DIR`（若要啟用 `obs` profile）
- `PICOCLAW_WORKSPACE_HOST_DIR`
- `OPS_COMPANION_CONFIG_HOST_DIR`（若要啟用 `ops` profile）
- `SERIALWRAP_GIT_URL`
- `SERIALWRAP_PROFILES_HOST_DIR`（若要啟用 `serialwrap` profile）
- `SERIALWRAP_STATE_HOST_DIR`
- `SERIALWRAP_HOST_DEV_DIR`（要吃實體 serial 裝置時設成 `/dev`）

3) 準備 OpenClaw 基底映像（固定 `v2026.2.15`）：

```bash
./scripts/prepare-openclaw-base-image.sh
```

若未提供 `OPENCLAW_BASE_IMAGE_CONTEXT`，腳本會自動從 `OPENCLAW_BASE_IMAGE_GIT_URL` 抓取正確 tag 到本機 cache，再直接 build 成 `openclaw:v2026.2.15`。

4) 產生外部 source snapshot（`custom-claw-tools` + `custom-skills`）：

```bash
./scripts/prepare-external-sources.sh
```

產出會落在 `build-context/external-sources/`，並帶一份 `manifest.json` 記錄使用的 repo / ref / commit。

5) 建置 orchestration 映像並啟動核心服務：

```bash
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml build
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml up -d
```

若你要直接用 **單一 image 啟整套 service**，可改用：

```bash
docker run --rm -it \
  -p 18789:18789 \
  -p 45450:45450 \
  -v "$PWD/.runtime/vault:/workspace/vault" \
  -v "$PWD/.runtime/openclaw:/home/node/.openclaw" \
  -v "$PWD/.runtime/obsidian-headless:/home/node/.config/obsidian-headless" \
  -v "$PWD/.runtime/picoclaw-workspace:/home/node/.picoclaw/workspace" \
  -v "$PWD/.runtime/picoclaw-ops-companion:/home/node/.config/picoclaw-ops-companion" \
  -v "$PWD/.runtime/serialwrap/profiles:/home/node/.config/serialwrap/profiles" \
  -v "$PWD/.runtime/serialwrap/state:/home/node/.local/state/serialwrap" \
  -v "$PWD/.runtime/serialwrap/dev:/host-dev" \
  openclaw-obsidian:test
```

> `Dockerfile` 能決定 image 內要放哪些 service 與預設啟動命令，但 **build 階段本身不會留下常駐 service**。真正一起拉起來的是 `docker run` / `docker compose up` 那一刻。
> 最新 image 會先做一次 runtime bootstrap：即使 `.runtime/*` 是被 Docker 自動建成 `root:root`，也會先修到 `OPENCLAW_DOCKER_USER` 再降權啟動 service。

若你要「只建立 container，不立即啟動」，請改用：

```bash
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml create
```

之後再啟動：

```bash
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml start
```

6) 看狀態與日誌：

```bash
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml ps
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml logs --tail=120 openclaw-obsidian-maintainer
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml logs --tail=120 openclaw-obsidian-gateway
```

7) 登入 GitHub Copilot（runtime）：

```bash
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-maintainer node /app/openclaw.mjs models auth login-github-copilot --profile-id github-copilot:github --yes
```

> OAuth/auth 僅寫入掛載的 `OPENCLAW_CONFIG_HOST_DIR`，不進 image layer。

8) Telegram 設定（channel + pairing）：

```bash
# 加入 Telegram channel（使用新 token，勿貼進 repo）
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-gateway \
  node /app/openclaw.mjs channels add --channel telegram --account default --token "<telegram-bot-token>"

# 查看待配對請求（在 Telegram 對 bot 發訊息後會出現 code）
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-gateway \
  node /app/openclaw.mjs pairing list telegram

# 核准配對（code 例：7LU2CZ3H）
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-gateway \
  node /app/openclaw.mjs pairing approve telegram 7LU2CZ3H --notify
```

9) 確認 `main` agent 預設模型（部署會自動設定，避免回退到 `anthropic/*`）：

```bash
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-maintainer \
  node /app/openclaw.mjs models status --agent main --json
```

## 可選 sidecar：`obs` / `ops` / `serialwrap`

### 啟用 `obs` profile

`obs` 會使用 `custom-skills/obs-service-wsl-handler` 作為容器內同步腳本來源，並依賴：

- `OBSIDIAN_HEADLESS_CONFIG_HOST_DIR`
- image 內已安裝的 `obsidian-headless` (`ob`)
- 若 sync config / auth token 缺失，container 會留下 incident log 並停止，避免無限 restart loop

啟動方式：

```bash
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml --profile obs up -d openclaw-obsidian-sync
```

### 啟用 `ops` profile

`ops` 會使用 `custom-claw-tools/picoclaw-ops-companion` build 後的 `dist/index.js` 啟動 loopback listener，並依賴：

- `PICOCLAW_WORKSPACE_HOST_DIR`
- `OPS_COMPANION_CONFIG_HOST_DIR`

啟動方式：

```bash
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml --profile ops up -d openclaw-obsidian-ops-companion
```

預設只綁到 host loopback：`127.0.0.1:${PICOCLAW_OPS_LISTEN_PORT:-45450}`。

### 啟用 `serialwrap` profile

`serialwrap` 會將 `hamanpaul/serialwrap` runtime 安裝到 image 內的 `/home/node/.paul_tools`，並以 sidecar daemon 啟動：

- `SERIALWRAP_PROFILES_HOST_DIR`
- `SERIALWRAP_STATE_HOST_DIR`
- `SERIALWRAP_HOST_DEV_DIR`

首次啟動若 `SERIALWRAP_PROFILES_HOST_DIR` 為空，容器會 seed `default.yaml`，並額外建立 `OPI.env.example`；若要啟用 `op3-template` / `COM0`，請將它改名為 `OPI.env` 後填入實際帳密，再把 `default.yaml` 的 target 對到你的 serial device。

若只做 wiring / daemon health 驗證，可保留預設的 `SERIALWRAP_HOST_DEV_DIR=./.runtime/serialwrap/dev`。若要真的接手 host serial 裝置，請改成：

```bash
SERIALWRAP_HOST_DEV_DIR=/dev
```

啟動方式：

```bash
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml --profile serialwrap up -d openclaw-obsidian-serialwrap
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-serialwrap \
  /home/node/.paul_tools/serialwrap-mcp --tool serialwrap_ping --params '{}'
```

## 單一 image 自動啟動的環境開關

若你直接 `docker run openclaw-obsidian:test`，可用以下變數控制哪些 service 自動起：

- `OPENCLAW_AUTOSTART_MAINTAINER`
- `OPENCLAW_AUTOSTART_GATEWAY`
- `OPENCLAW_AUTOSTART_OBS`
- `OPENCLAW_AUTOSTART_OPS`
- `OPENCLAW_AUTOSTART_SERIALWRAP`

預設全部為 `1`。

## Control UI

- URL：`http://localhost:${OPENCLAW_GATEWAY_PORT:-18789}`
- 預設 token：`${OPENCLAW_GATEWAY_TOKEN:-local-dev-token}`
- 若要關閉 HTTP token-only 連線：`.env` 設 `OPENCLAW_CONTROL_UI_ALLOW_INSECURE_AUTH=0` 後重啟 compose。

## 完整部署指令

```bash
cd /home/paul_chen/prj_pri/openclaw-obsidian-deploy

cp .env.example .env
# 編輯 .env，至少設定：
# - OBSIDIAN_VAULT_HOST_DIR
# - OPENCLAW_CONFIG_HOST_DIR
# - OPENCLAW_DOCKER_USER
# - OPENCLAW_BASE_IMAGE
# - OPENCLAW_BASE_IMAGE_GIT_URL
# - OPENCLAW_DEFAULT_MODEL
# - OPENCLAW_DEFAULT_PROFILE_ID
# - OPENCLAW_ENABLE_TELEGRAM_PLUGIN

./scripts/prepare-openclaw-base-image.sh
./scripts/prepare-external-sources.sh

docker compose --env-file ./.env -f ./docker-compose.obsidian.yml build

# 只建立 container（不啟動）
# docker compose --env-file ./.env -f ./docker-compose.obsidian.yml create

# 建立並啟動（常用）
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml up -d

# (可選) 啟用 obs / ops / serialwrap sidecar
# docker compose --env-file ./.env -f ./docker-compose.obsidian.yml --profile obs up -d openclaw-obsidian-sync
# docker compose --env-file ./.env -f ./docker-compose.obsidian.yml --profile ops up -d openclaw-obsidian-ops-companion
# docker compose --env-file ./.env -f ./docker-compose.obsidian.yml --profile serialwrap up -d openclaw-obsidian-serialwrap

docker compose --env-file ./.env -f ./docker-compose.obsidian.yml ps
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml logs --tail=120 openclaw-obsidian-maintainer
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml logs --tail=120 openclaw-obsidian-gateway

# (可選) OAuth 登入
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-maintainer \
  node /app/openclaw.mjs models auth login-github-copilot --profile-id github-copilot:github --yes

# Telegram channel + pairing
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-gateway \
  node /app/openclaw.mjs channels add --channel telegram --account default --token "<telegram-bot-token>"
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-gateway \
  node /app/openclaw.mjs pairing list telegram
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-gateway \
  node /app/openclaw.mjs pairing approve telegram <pairing-code> --notify

# 確認 main agent 預設模型（部署會自動設定）
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-maintainer \
  node /app/openclaw.mjs models status --agent main --json

# 停止服務
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml down
```

## 一鍵 Smoke 測試

```bash
./scripts/deploy-smoke.sh --env-file ./.env
```

常用選項：

- `--skip-base-image`：略過基底映像建置。
- `--skip-external-sources`：略過外部 source snapshot。
- `--down-after`：檢查完成後自動 `compose down`。
- `--tail 200`：自訂 logs tail 行數。
- `--no-logs`：只做 build/up/ps，不輸出 logs。
- 啟動前會先檢查 `OPENCLAW_CONFIG_HOST_DIR` 是否存在，且在 `OPENCLAW_DOCKER_USER` 與目前登入使用者一致時可寫入。

## 部署故障排除

- `Unknown channel: telegram`
  - 部署啟動時會由 `/ops/scripts/ensure-openclaw-config.sh` 自動啟用 `telegram` plugin（可用 `.env` 的 `OPENCLAW_ENABLE_TELEGRAM_PLUGIN=0` 關閉）。
- `missing ob command`
  - 代表 image 未安裝 `obsidian-headless`，請確認 `.env` 的 `OPENCLAW_INSTALL_OBSIDIAN_HEADLESS=1`，重新 build 後再啟用 `obs` profile。
- `missing picoclaw-ops-companion build output`
  - 代表 `build-context/external-sources/` 尚未準備好，或 `custom-claw-tools` snapshot 未包含 `picoclaw-ops-companion`。
  - 先重跑：

```bash
./scripts/prepare-external-sources.sh
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml build
```

- `prepare-openclaw-base-image.sh` 回報找不到 local checkout
  - 現在可以直接依賴 `OPENCLAW_BASE_IMAGE_GIT_URL` 自動抓取 upstream tag，不必手動先準備 `/home/paul_chen/ref/code/openclaw`。
- `serialwrap` logs 提示 `device discovery dir not found`
  - 代表你還在用預設的 stub host dev 目錄。若要讓 `COM0` / `op3-template` 接到真實 serial 裝置，請把 `.env` 改成：

```bash
SERIALWRAP_HOST_DEV_DIR=/dev
```

- `serialwrap` 只出現 `OPI.env.example`
  - 這是預期的 bootstrap 行為。請把它改名為 `OPI.env`，並填入 `SW_OPI_U` / `SW_OPI_P`，再依你的裝置更新 `default.yaml`。
- `No API key found for provider "anthropic"`
  - 部署啟動時會自動將 `main` agent 預設模型設為 `OPENCLAW_DEFAULT_MODEL`（預設 `github-copilot/gpt-5-mini`）。
- `Container restarting` 且提到無法寫入 `/home/node/.openclaw/openclaw.json`
  - 這是 host 掛載目錄權限問題，無法在 Dockerfile 直接修復。
  - 修正方式：

```bash
sudo chown -R <uid>:<gid> <OPENCLAW_CONFIG_HOST_DIR>
```

  - 例如 `.env` 是 `OPENCLAW_DOCKER_USER=1000:1000`：

```bash
sudo chown -R 1000:1000 /home/paul_chen/.openclaw
```

- `maintainer` 重複重啟且出現 `jq: Argument list too long`
  - 這個 repo 已在 `scripts/maintainer-loop.sh` 修正（改用暫存檔 + `jq --slurpfile`）。
  - 若仍看到舊錯誤，請重新 build/recreate：

```bash
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml build
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml up -d --force-recreate
```

- Telegram 回覆出現 `400 {"message":"","code":"invalid_request_body"}`
  - 先在 Telegram 對話送 `/new` 重開 session，再重試。
- CLI 顯示 `gateway connect failed: Error: pairing required`
  - 這通常發生在容器內以 LAN 位址連 gateway，裝置尚未配對。
  - 改用 loopback + token 執行命令（避開 LAN 配對流程）：

```bash
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-gateway \
  node /app/openclaw.mjs logs --url ws://127.0.0.1:18789 --token "${OPENCLAW_GATEWAY_TOKEN:-local-dev-token}" --plain
```

- `maintainer` 顯示 `agent_no_effect` 且回報 `skills: obsidian` 不存在
  - 這是任務提示詞指定了未安裝 skill，不是容器崩潰。
  - 建議修正 `scripts/maintainer-loop.sh` prompt（移除 `skills: obsidian`）或安裝對應 skill。

## 一鍵打包（遷移重建）

不含 auth：

```bash
./scripts/package-rebuild-bundle.sh
```

包含 auth（會打包 `~/.openclaw`）：

```bash
./scripts/package-rebuild-bundle.sh --with-auth
```

## 變數遷移

以下變數已廢棄，不再用於 build OpenClaw 本體：

- `OPENCLAW_REPO_GIT_URL`
- `OPENCLAW_REPO_REF`

以下變數為新的本機可重建 workflow 入口：

- `OPENCLAW_BASE_IMAGE_GIT_URL`
- `OPENCLAW_BASE_IMAGE_CACHE_DIR`
- `OPENCLAW_EXTERNAL_SOURCES_DIR`
- `OPENCLAW_EXTERNAL_CACHE_DIR`
- `CUSTOM_CLAW_TOOLS_GIT_URL`
- `CUSTOM_CLAW_TOOLS_REF`
- `CUSTOM_SKILLS_GIT_URL`
- `CUSTOM_SKILLS_REF`
- `SERIALWRAP_GIT_URL`
- `SERIALWRAP_REF`
- `SERIALWRAP_PROFILES_HOST_DIR`
- `SERIALWRAP_STATE_HOST_DIR`
- `SERIALWRAP_HOST_DEV_DIR`

## 相關文件

- `docs/plan.md`
- `docs/tasks.md`
- `docs/todo.md`
- `docs/test-plan.md`
- `docs/enhance-plan.md`
- `docs/enhance-spec.md`
- `docs/path-mapping.md`
- `todo.md`
