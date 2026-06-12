# openclaw-obsidian-deploy

Public-first Docker packaging for OpenClaw.

這份 README 只講 **最短可用指令**：

1. 如何安裝
2. 如何建立容器
3. 如何掛載 sensitive / 個人化資料
4. 如何登入 OpenClaw（OAuth / API key）
5. 如何備份與還原

## 1. 安裝

```bash
git clone https://github.com/your-org/openclaw-obsidian-deploy.git
cd openclaw-obsidian-deploy
cp .env.example .env
```

## 2. 建立 host 掛載目錄

### 最小 base runtime

```bash
mkdir -p ./mounts/openclaw-config ./mounts/openclaw-workspace ./backup
sed -i 's#^OPENCLAW_CONFIG_HOST_DIR=.*#OPENCLAW_CONFIG_HOST_DIR=./mounts/openclaw-config#' .env
sed -i 's#^OPENCLAW_WORKSPACE_HOST_DIR=.*#OPENCLAW_WORKSPACE_HOST_DIR=./mounts/openclaw-workspace#' .env
```

### addon example（可選）

```bash
mkdir -p ./mounts/openclaw-addons-config ./mounts/openclaw-addons-workspace
sed -i 's#^OPENCLAW_ADDONS_CONFIG_HOST_DIR=.*#OPENCLAW_ADDONS_CONFIG_HOST_DIR=./mounts/openclaw-addons-config#' .env
sed -i 's#^OPENCLAW_ADDONS_WORKSPACE_HOST_DIR=.*#OPENCLAW_ADDONS_WORKSPACE_HOST_DIR=./mounts/openclaw-addons-workspace#' .env
```

## 3. 掛載用途

| 變數 | 建議內容 | 性質 |
| --- | --- | --- |
| `OPENCLAW_CONFIG_HOST_DIR` | `.openclaw` 設定、OAuth / token、cron store | **sensitive** |
| `OPENCLAW_WORKSPACE_HOST_DIR` | notes、memory、匯出文件、runtime state | **個人化 / stateful** |
| `OPENCLAW_ADDONS_CONFIG_HOST_DIR` | addon example 的 `.openclaw` | **sensitive** |
| `OPENCLAW_ADDONS_WORKSPACE_HOST_DIR` | addon example 的 workspace | **個人化 / stateful** |

原則只有一條：

- **所有 sensitive / 個人化資料都放在 host mount，不放進 image。**

## 4. 建立 base 容器

### build

```bash
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml build
```

### up

```bash
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml up -d
```

### 檢查狀態

```bash
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml ps
curl -fsS http://127.0.0.1:${OPENCLAW_GATEWAY_PORT:-18789}/healthz
```

### 常用操作

```bash
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml logs -f openclaw-quickstart
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml exec -it openclaw-quickstart bash
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml restart
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml down
```

## 5. 登入 OpenClaw

### OAuth：GitHub Copilot

```bash
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml exec -it openclaw-quickstart \
  node /app/openclaw.mjs models auth login-github-copilot --profile-id github-copilot:github --yes
```

### OAuth / API key：通用 provider flow

```bash
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml exec -it openclaw-quickstart \
  node /app/openclaw.mjs models auth login --provider <provider> --method <method> --set-default
```

常見用法：

- OAuth：`--method oauth`
- API key：`--method api-key`

### 直接貼 token

```bash
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml exec -it openclaw-quickstart \
  node /app/openclaw.mjs models auth paste-token --provider <provider> --profile-id <provider>:manual
```

### 設定預設模型

```bash
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml exec -it openclaw-quickstart \
  node /app/openclaw.mjs models set <provider>/<model>
```

### 列出可用模型

```bash
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml exec -it openclaw-quickstart \
  node /app/openclaw.mjs models list
```

## 6. 建立 addon example 容器（可選）

### build

```bash
docker compose --env-file ./.env -f ./docker-compose.addons.example.yml build
```

### up

```bash
docker compose --env-file ./.env -f ./docker-compose.addons.example.yml up -d
```

### 檢查狀態

```bash
docker compose --env-file ./.env -f ./docker-compose.addons.example.yml ps
curl -fsS http://127.0.0.1:${OPENCLAW_ADDONS_GATEWAY_PORT:-18790}/healthz
cat "${OPENCLAW_ADDONS_WORKSPACE_HOST_DIR:-./mounts/openclaw-addons-workspace}/addons-example/state/heartbeat.json"
```

### 關閉

```bash
docker compose --env-file ./.env -f ./docker-compose.addons.example.yml down
```

## 7. 備份 sensitive / 個人化資料

### 先停容器

```bash
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml down
docker compose --env-file ./.env -f ./docker-compose.addons.example.yml down 2>/dev/null || true
```

### 備份 base mount

```bash
tar -C ./mounts -czf "./backup/openclaw-config-$(date -u +%Y%m%dT%H%M%SZ).tar.gz" openclaw-config
tar -C ./mounts -czf "./backup/openclaw-workspace-$(date -u +%Y%m%dT%H%M%SZ).tar.gz" openclaw-workspace
```

### 備份 addon mount（如果有用）

```bash
tar -C ./mounts -czf "./backup/openclaw-addons-config-$(date -u +%Y%m%dT%H%M%SZ).tar.gz" openclaw-addons-config
tar -C ./mounts -czf "./backup/openclaw-addons-workspace-$(date -u +%Y%m%dT%H%M%SZ).tar.gz" openclaw-addons-workspace
```

## 8. 還原 sensitive / 個人化資料

### 建回目錄

```bash
mkdir -p ./mounts/openclaw-config ./mounts/openclaw-workspace
mkdir -p ./mounts/openclaw-addons-config ./mounts/openclaw-addons-workspace
```

### 還原 base mount

```bash
tar -xzf ./backup/openclaw-config-<timestamp>.tar.gz -C ./mounts
tar -xzf ./backup/openclaw-workspace-<timestamp>.tar.gz -C ./mounts
```

### 還原 addon mount（如果有用）

```bash
tar -xzf ./backup/openclaw-addons-config-<timestamp>.tar.gz -C ./mounts
tar -xzf ./backup/openclaw-addons-workspace-<timestamp>.tar.gz -C ./mounts
```

### 重建容器

```bash
docker compose --env-file ./.env -f ./docker-compose.quickstart.yml up -d
docker compose --env-file ./.env -f ./docker-compose.addons.example.yml up -d
```

## 9. 一鍵 smoke test

### base

```bash
./scripts/deploy-smoke.sh --down-after
```

### addon example

```bash
COMPOSE_FILE=./docker-compose.addons.example.yml \
SERVICE_NAME=openclaw-addons-example \
HEALTH_URL=http://127.0.0.1:${OPENCLAW_ADDONS_GATEWAY_PORT:-18790}/healthz \
./scripts/deploy-smoke.sh --down-after
```

## 10. 相關文件

- `docs/path-mapping.md`
- `docs/enhance-plan.md`
- `docs/enhance-spec.md`
- `docs/failed-design-exp.md`
