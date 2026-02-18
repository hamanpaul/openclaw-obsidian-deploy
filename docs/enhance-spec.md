# OpenClaw `v2026.2.15` Orchestration-first 重構規格

Last updated: 2026-02-18

## 1. 目標與範圍

本規格將 `docs/enhance-plan.md` 轉為可直接實作的工程規格。  
目標是把本 repo 從「Dockerfile 內 clone/build OpenClaw」改為「先準備固定版本基底 image，再由本 repo 疊加 orchestration」。

### 1.1 In Scope

- 固定 OpenClaw 基底版本為 `v2026.2.15`
- 新增基底 image 準備腳本
- 將現行 Dockerfile 調整為薄包裝（thin wrapper）
- 調整 compose 與 `.env.example` 介面
- `externalize-runtime-md.sh` 容錯化（缺來源路徑不中斷）
- 新增 path mapping 文件
- 更新 README 部署與驗證流程

### 1.2 Out of Scope

- 不修改 OpenClaw 本體程式碼
- 不引入遠端 registry 發佈流程
- 不變更 `state/queue` JSON schema
- 不改寫 maintainer loop 核心任務邏輯

## 2. 現況與目標架構

### 2.1 現況

- `Dockerfile` 多階段建置並在 build 時 `git clone` + `pnpm build`
- `docker-compose.obsidian.yml` 透過 `OPENCLAW_REPO_GIT_URL/OPENCLAW_REPO_REF` 傳入 build args
- 部署對外網與上游 repo 可用性敏感，build 成本高

### 2.2 目標

- 基底 image 由本機 checkout `v2026.2.15` 後先行建置（例如 `openclaw:v2026.2.15`）
- 本 repo 的 Dockerfile 只做 orchestration 薄包裝
- compose 僅依賴薄包裝 image，不直接觸發 OpenClaw source build

## 3. 設計決策（Locked Decisions）

- 基底策略：local checkout + local build（`v2026.2.15`）
- 專案定位：orchestration-first（compose/scripts/config-template）
- externalize 策略：保留功能 + 強化容錯（warning, 不 fail）
- mapping 文件範圍：host/container volume 與 externalize 路徑對應

## 4. Public Interfaces 變更

## 4.1 新增環境變數

| 變數 | 預設值 | 用途 |
| --- | --- | --- |
| `OPENCLAW_BASE_IMAGE` | `openclaw:v2026.2.15` | 薄包裝 Dockerfile 的 `FROM` 基底 |
| `OPENCLAW_BASE_IMAGE_DOCKERFILE` | `/home/paul_chen/ref/code/openclaw/Dockerfile` | 建立基底 image 的來源 Dockerfile |
| `OPENCLAW_BASE_IMAGE_CONTEXT` | `/home/paul_chen/ref/code/openclaw` | 建立基底 image 的 build context |

## 4.2 廢棄環境變數

- `OPENCLAW_REPO_GIT_URL`
- `OPENCLAW_REPO_REF`

處理方式：
- 從 `.env.example` 移除
- README 明確標示 deprecated
- 若殘留於本地 `.env`，流程不依賴其值

## 4.3 新增腳本介面

檔案：`scripts/prepare-openclaw-base-image.sh`

輸入：
- `OPENCLAW_BASE_IMAGE`（可覆蓋）
- `OPENCLAW_BASE_IMAGE_DOCKERFILE`（可覆蓋）
- `OPENCLAW_BASE_IMAGE_CONTEXT`（可覆蓋）

責任：
- 驗證 context 與 Dockerfile 存在
- 驗證來源 repo 版本可對應 `v2026.2.15`（以 tag 或版本輸出檢查）
- 執行 `docker build -t "${OPENCLAW_BASE_IMAGE}" ...`
- 輸出可讀日志與結果摘要

退出碼：
- `0`：成功
- `2`：參數或路徑錯誤
- `3`：版本檢查失敗
- `4`：docker build 失敗

## 5. 檔案級實作規格

## 5.1 `Dockerfile`

目標：
- 移除 clone/build OpenClaw 段落
- 改為薄包裝模式

規格：
- `FROM ${OPENCLAW_BASE_IMAGE}`（透過 `ARG OPENCLAW_BASE_IMAGE`）
- 保留/補充必要工具（`jq`, `ripgrep`, `fd-find`, `yq`, `rsync`, `tzdata`, `python3`）
- `COPY scripts /ops/scripts`
- `COPY config-template/... /home/node/.openclaw/...`
- 保持 `USER node` 與 gateway 預設入口兼容

## 5.2 `docker-compose.obsidian.yml`

目標：
- 不再依賴 repo clone build args

規格：
- build args 移除 `OPENCLAW_REPO_GIT_URL/OPENCLAW_REPO_REF`
- 改傳 `OPENCLAW_BASE_IMAGE` 給薄包裝 Dockerfile
- 維持現有服務：
  - `openclaw-obsidian-maintainer`
  - `openclaw-obsidian-gateway`
- 維持現有 volume 與 state 路徑語意

## 5.3 `.env.example`

規格：
- 新增 `OPENCLAW_BASE_IMAGE=openclaw:v2026.2.15`
- 新增 `OPENCLAW_BASE_IMAGE_DOCKERFILE`
- 新增 `OPENCLAW_BASE_IMAGE_CONTEXT`
- 移除 `OPENCLAW_REPO_GIT_URL`
- 移除 `OPENCLAW_REPO_REF`

## 5.4 `scripts/externalize-runtime-md.sh`

目標：
- 路徑缺失時不中斷部署

規格：
- 若 `skills/.agents/docs/reference/templates` 任一路徑不存在：
  - 輸出 warning（含缺失路徑）
  - 不中斷腳本
- 若最終無可 externalize 檔案：
  - 仍產出合法 manifest：`{"generated_at":"...","entries":[]}`
  - exit code 為 `0`

## 5.5 `scripts/maintainer-loop.sh`

規格：
- 不改核心流程與資料格式
- 僅補充必要註解/日志，說明 `OPENCLAW_REPO_DIR` 來源與 externalize 依賴

## 5.6 `README.md`

規格：
- 更新部署流程為兩段式：
  1. 先建立 base image
  2. 再 build + up orchestration image/service
- 補 runtime OAuth 原則：
  - 認證只落在掛載的 `~/.openclaw`
  - 不寫入 image layer

## 5.7 `docs/path-mapping.md`（新檔）

最小欄位：
- logical_name
- host_path
- container_path
- producer
- consumer
- notes

至少覆蓋：
- vault 掛載
- config 掛載
- state/queue/manifest
- externalize source 與 destination

## 6. 資料流（Data Flow）

1. `prepare-openclaw-base-image.sh` 建立 `openclaw:v2026.2.15`
2. 本 repo Dockerfile 以該 image 為 base 建立 orchestration image
3. compose 啟動 maintainer + gateway
4. maintainer loop 掃描 vault -> queue/state -> 呼叫 agent
5. externalize 腳本在初始化時同步 markdown 並更新 manifest

## 7. 失敗模式與修復

| Failure | 檢測 | 行為 | 修復 |
| --- | --- | --- | --- |
| base image 不存在 | `docker images` 無 tag | compose/build 失敗 | 先跑 `prepare-openclaw-base-image.sh` |
| base context 不存在 | 腳本 precheck | exit `2` | 修正 `OPENCLAW_BASE_IMAGE_CONTEXT` |
| 版本非 `v2026.2.15` | 版本檢查 | exit `3` | checkout 正確 tag 後重試 |
| externalize 缺來源路徑 | 路徑檢查 | warning + continue | 補路徑或接受空 manifest |
| OAuth 未持久化 | 重啟後 auth 消失 | 使用體驗退化 | 確認 `OPENCLAW_CONFIG_HOST_DIR` 掛載 |

## 8. 測試與驗收

## 8.1 必跑命令

```bash
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml config
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml up -d
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml ps
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml logs --no-log-prefix --tail=200 openclaw-obsidian-maintainer
docker compose --env-file ./.env -f ./docker-compose.obsidian.yml logs --no-log-prefix --tail=200 openclaw-obsidian-gateway
```

## 8.2 驗收標準

- `docker compose config` 成功，且設定不再依賴 `OPENCLAW_REPO_GIT_URL/REF`
- 兩服務成功啟動並維持 healthy/穩定運行
- externalize 在有/無來源路徑兩情境都能產出預期結果
- OAuth 可在 runtime 登入，重啟容器後仍存在（volume 持久化）

## 9. 相容性與遷移策略

1. 使用者先更新 `.env` 為新介面
2. 建立 base image
3. 重新 build orchestration image
4. `up -d` 後跑驗收命令

回滾策略：
- 若新流程失敗，可回退至前一版 branch 的 Dockerfile/compose
- state/queue schema 不變，可直接沿用既有資料

## 10. 實作完成定義（DoD）

- 上述檔案改動全部完成
- 測試與驗收全部通過
- 文件可獨立引導新環境部署，且不需額外口頭說明
