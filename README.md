# openclaw-obsidian-deploy

純部署 repo，僅保留 OpenClaw + Obsidian 維護所需檔案，已移除個人資料依賴（auth token、私人筆記、操作紀錄）。

## 內容

- `Dockerfile`：建置 OpenClaw 維護映像（建置時自動 `git clone`）。
- `docker-compose.obsidian.yml`：維護服務部署。
- `.env.example`：部署參數範本（無個資）。
- `scripts/`：掃描、外部化、主循環、一鍵打包、指令紀錄腳本。

## 個資邊界

- 不含 `.env`、`~/.openclaw`、`logs/`、任何筆記內容。
- 認證資料僅透過容器掛載 `OPENCLAW_CONFIG_HOST_DIR` 讀取，不進 repo。

## 快速部署

1) 建立環境檔：

```bash
/bin/cp ./.env.example ./.env
```

2) 編輯 `.env`（至少改這三項）：

- `OBSIDIAN_VAULT_HOST_DIR`
- `OPENCLAW_CONFIG_HOST_DIR`
- `OPENCLAW_DOCKER_USER`

3) 建置與啟動：

```bash
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml build
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml up -d
```

4) 看狀態與日誌：

```bash
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml ps
/usr/bin/docker compose --env-file ./.env -f ./docker-compose.obsidian.yml logs -f openclaw-obsidian-maintainer
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

## Repo 命名建議

`openclaw-obsidian-deploy`
