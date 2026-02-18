# openclaw-obsidian-deploy

純部署 repo，僅保留 OpenClaw + Obsidian 維護所需檔案，已移除個人資料依賴（auth token、私人筆記、操作紀錄）。

## 內容

- `Dockerfile`：以 `OPENCLAW_BASE_IMAGE` 為基底的薄包裝映像。
- `docker-compose.obsidian.yml`：維護服務部署（maintainer + gateway）。
- `.env.example`：部署參數範本（無個資）。
- `scripts/`：基底映像建置、一鍵 smoke 測試、掃描、外部化、主循環、一鍵打包腳本。
- `docs/path-mapping.md`：host/container 路徑對映說明。

## 個資邊界

- 不含 `.env`、`~/.openclaw`、`logs/`、任何筆記內容。
- 認證資料僅透過容器掛載 `OPENCLAW_CONFIG_HOST_DIR` 讀取，不進 repo。

## 快速部署（兩段式）

1) 建立環境檔：

```bash
/bin/cp ./.env.example ./.env
```

2) 編輯 `.env`（至少改這些）：

- `OBSIDIAN_VAULT_HOST_DIR`
- `OPENCLAW_CONFIG_HOST_DIR`
- `OPENCLAW_DOCKER_USER`
- `OPENCLAW_BASE_IMAGE`
- `OPENCLAW_BASE_IMAGE_CONTEXT`
- `OPENCLAW_BASE_IMAGE_DOCKERFILE`
- `OPENCLAW_DEFAULT_MODEL`
- `OPENCLAW_DEFAULT_PROFILE_ID`
- `OPENCLAW_ENABLE_TELEGRAM_PLUGIN`

3) 先建 OpenClaw 基底映像（固定 `v2026.2.15`）：

```bash
./scripts/prepare-openclaw-base-image.sh
```

4) 建置 orchestration 映像並啟動服務：

```bash
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml build
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml up -d
```

若你要「只建立 container，不立即啟動」，請改用：

```bash
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml create
```

之後再啟動：

```bash
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml start
```

5) 看狀態與日誌：

```bash
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml ps
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml logs --tail=120 openclaw-obsidian-maintainer
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml logs --tail=120 openclaw-obsidian-gateway
```

6) 登入 GitHub Copilot（runtime）：

```bash
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-maintainer node /app/openclaw.mjs models auth login-github-copilot --profile-id github-copilot:github --yes
```

> OAuth/auth 僅寫入掛載的 `OPENCLAW_CONFIG_HOST_DIR`，不進 image layer。

7) Telegram 設定（channel + pairing）：

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

8) 確認 `main` agent 預設模型（部署會自動設定，避免回退到 `anthropic/*`）：

```bash
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml exec -it openclaw-obsidian-maintainer \
  node /app/openclaw.mjs models status --agent main --json
```

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
# - OPENCLAW_BASE_IMAGE_CONTEXT
# - OPENCLAW_BASE_IMAGE_DOCKERFILE
# - OPENCLAW_DEFAULT_MODEL
# - OPENCLAW_DEFAULT_PROFILE_ID
# - OPENCLAW_ENABLE_TELEGRAM_PLUGIN

./scripts/prepare-openclaw-base-image.sh

docker compose --env-file ./.env -f ./docker-compose.obsidian.yml build

# 只建立 container（不啟動）
# docker compose --env-file ./.env -f ./docker-compose.obsidian.yml create

# 建立並啟動（常用）
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml up -d

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
- `--down-after`：檢查完成後自動 `compose down`。
- `--tail 200`：自訂 logs tail 行數。
- `--no-logs`：只做 build/up/ps，不輸出 logs。
- 啟動前會先檢查 `OPENCLAW_CONFIG_HOST_DIR` 是否存在，且在 `OPENCLAW_DOCKER_USER` 與目前登入使用者一致時可寫入。

## 部署故障排除

- `Unknown channel: telegram`
  - 部署啟動時會由 `/ops/scripts/ensure-openclaw-config.sh` 自動啟用 `telegram` plugin（可用 `.env` 的 `OPENCLAW_ENABLE_TELEGRAM_PLUGIN=0` 關閉）。
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

## 相關文件

- `docs/enhance-plan.md`
- `docs/enhance-spec.md`
- `docs/path-mapping.md`
- `todo.md`
