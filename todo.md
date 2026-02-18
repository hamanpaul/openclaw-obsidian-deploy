# TODO - OpenClaw `v2026.2.15` Orchestration-first 重構

Last updated: 2026-02-18
Branch: `enhancement/openclaw-v2026-2-15-orchestration-plan`
Reference:
- `docs/enhance-plan.md`
- `docs/enhance-spec.md`

## Goal

完成部署重構：以固定基底 image（`openclaw:v2026.2.15`）承載 OpenClaw 本體，本 repo 僅維持 orchestration（compose/scripts/config）。

## Definition of Done

- [ ] `Dockerfile` 不再 clone/build OpenClaw source
- [ ] `docker-compose.obsidian.yml` 不再依賴 `OPENCLAW_REPO_GIT_URL/OPENCLAW_REPO_REF`
- [ ] 新增並驗證 `scripts/prepare-openclaw-base-image.sh`
- [ ] `externalize-runtime-md.sh` 在缺路徑情境下 warning + continue
- [ ] `README.md`、`docs/path-mapping.md` 完整更新
- [ ] 驗收命令全部通過

## Phase 0 - Baseline 與盤點

### Tasks

- [ ] 盤點 `OPENCLAW_REPO_*` 在 repo 的所有使用位置
- [ ] 盤點 `OPENCLAW_REPO_DIR` 與 externalize 來源路徑假設
- [ ] 建立重構前驗證命令與對照輸出（compose config/ps/logs）

### Dependencies

- 無

### Acceptance

- [ ] baseline 命令可重現目前行為
- [ ] 所有目標檔案與變數使用點完成清單化

## Phase 1 - Base Image Workflow

### Tasks

- [ ] 新增 `scripts/prepare-openclaw-base-image.sh`
- [ ] 定義腳本輸入 env：`OPENCLAW_BASE_IMAGE*`
- [ ] 實作路徑與版本 precheck（`v2026.2.15`）
- [ ] 實作 build 流程與 exit code 規範

### Dependencies

- Phase 0

### Acceptance

- [ ] 可成功產生 `openclaw:v2026.2.15`
- [ ] 失敗時有明確錯誤碼與可行修復提示

## Phase 2 - Dockerfile/Compose/.env 重構

### Tasks

- [ ] `Dockerfile` 改為薄包裝：`FROM ${OPENCLAW_BASE_IMAGE}`
- [ ] 移除 Dockerfile 中 clone/build OpenClaw source 流程
- [ ] `docker-compose.obsidian.yml` 移除 repo clone args
- [ ] `.env.example` 新增 `OPENCLAW_BASE_IMAGE*`，移除 `OPENCLAW_REPO_*`

### Dependencies

- Phase 1

### Acceptance

- [ ] `docker compose ... config` 成功
- [ ] compose 設定中不再出現 `OPENCLAW_REPO_GIT_URL/OPENCLAW_REPO_REF`

## Phase 3 - Script Hardening

### Tasks

- [ ] `scripts/externalize-runtime-md.sh` 增加缺路徑容錯
- [ ] 無來源時仍輸出合法 manifest（`entries: []`）
- [ ] `scripts/maintainer-loop.sh` 補必要說明（不改核心邏輯）

### Dependencies

- Phase 2

### Acceptance

- [ ] externalize 在缺來源路徑下不 crash
- [ ] maintainer loop 與原行為相容

## Phase 4 - 文件同步

### Tasks

- [ ] 更新 `README.md` 為兩段式部署（base image -> orchestration）
- [ ] 新增 `docs/path-mapping.md`
- [ ] 補文件交叉連結：plan/spec/path-mapping/todo
- [ ] 記錄 OAuth runtime persistence 原則

### Dependencies

- Phase 3

### Acceptance

- [ ] 新環境僅依文件即可完成部署
- [ ] 路徑對映與 volume 語意可追溯

## Phase 5 - 驗收與回歸

### Tasks

- [ ] 執行 compose config/啟動/狀態/日誌檢查
- [ ] 驗證 maintainer + gateway 啟動穩定性
- [ ] 驗證 OAuth runtime 登入與重啟持久化
- [ ] 記錄風險與回退步驟

### Dependencies

- Phase 4

### Acceptance

- [ ] 所有必跑命令通過
- [ ] 驗收標準全部達成
- [ ] 回退流程文件化可操作

## 驗收命令清單

```bash
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml config
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml up -d
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml ps
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml logs --no-log-prefix --tail=200 openclaw-obsidian-maintainer
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml logs --no-log-prefix --tail=200 openclaw-obsidian-gateway
```

## 風險追蹤

- [ ] base image/工具鏈版本不一致
- [ ] externalize 路徑未覆蓋新版本 layout
- [ ] 使用者沿用舊 env 導致預期外行為

## 完成後輸出物

- [ ] code changes（Dockerfile/compose/scripts/.env.example/README）
- [ ] `docs/path-mapping.md`
- [ ] 驗收紀錄（命令與關鍵輸出摘要）
