# 以 OpenClaw v2026.2.15 為基底的部署重構計畫（Orchestration-first）

## 摘要

目標是把本 repo 從「在 Dockerfile 內 clone/build OpenClaw」改成「先準備固定版本基底 image，再由本 repo 疊加 orchestration 能力」。

- 基底版本固定為 `v2026.2.15`
- 保留既有 `compose/scripts` 維護流程
- `externalize-runtime-md.sh` 保留功能並強化容錯
- 新增 path mapping 文件，明確記錄 host/container 與腳本路徑對映

## 變更範圍

- `Dockerfile`
- `docker-compose.obsidian.yml`
- `.env.example`
- `README.md`
- `scripts/externalize-runtime-md.sh`
- `scripts/maintainer-loop.sh`（僅必要環境變數說明與容錯訊息，不改核心流程）
- `scripts/prepare-openclaw-base-image.sh`（新增）
- `docs/path-mapping.md`（新增）

## 設計決策（已鎖定）

- 基底策略：本地 checkout `v2026.2.15` 後 build 成固定 image（例如 `openclaw:v2026.2.15`）
- 本 repo 定位：只做 orchestration（compose + scripts + config-template）
- externalize：保留功能、強化容錯（缺來源路徑只警告）
- mapping 文件範圍：容器掛載與腳本路徑對應

## 介面與設定變更（Public Interfaces）

### 新增 env

- `OPENCLAW_BASE_IMAGE`（預設 `openclaw:v2026.2.15`）
- `OPENCLAW_BASE_IMAGE_DOCKERFILE`（預設 `/home/paul_chen/ref/code/openclaw/Dockerfile`，可覆蓋）
- `OPENCLAW_BASE_IMAGE_CONTEXT`（預設 `/home/paul_chen/ref/code/openclaw`，可覆蓋）

### 移除或標註廢棄 env

- `OPENCLAW_REPO_GIT_URL`
- `OPENCLAW_REPO_REF`

### Compose 調整

- `docker-compose.obsidian.yml` 的 `image` 改用 `OPENCLAW_BASE_IMAGE` 衍生的薄包裝結果
- 不再依賴 Dockerfile 內 `git clone` 參數

### 新增腳本介面

- `scripts/prepare-openclaw-base-image.sh`
  - 非互動式建立基底 image
  - 流程含 tag 檢查、build、版本輸出

## 實作步驟

1. 建立基底 image 準備腳本。
2. 精簡本 repo `Dockerfile` 成薄包裝：`FROM ${OPENCLAW_BASE_IMAGE}` + 複製 `scripts/` 與 `config-template/`。
3. 調整 compose 參數與 `.env.example`，移除 repo clone 相關參數。
4. externalize 腳本容錯化：
   - 掃描來源不存在時記錄 warning。
   - 仍產出合法 manifest（空 entries）並返回成功。
5. 新增 `docs/path-mapping.md`，定義：
   - host 路徑到 container 掛載
   - `OPENCLAW_REPO_DIR` 實際值與掃描來源
   - externalize 輸出路徑與 state 路徑
6. 更新 README：
   - 先建基底 image，再 build orchestration image
   - OAuth 登入流程維持 runtime volume（不進 image layer）

## 測試案例與驗收

- `docker compose config` 可成功展開，且不需 `OPENCLAW_REPO_GIT_URL/REF`
- `scripts/prepare-openclaw-base-image.sh` 在 `v2026.2.15` checkout 可產出目標 image tag
- `docker compose up -d` 後：
  - `openclaw-obsidian-maintainer` 正常啟動
  - `openclaw-obsidian-gateway` 正常啟動
- externalize 測試：
  - 有來源路徑時可外部化並產生 manifest entries
  - 缺來源路徑時不中斷，manifest 為空陣列且有 warning
- OAuth 驗證：
  - `models auth login-github-copilot` 在 runtime 可執行，認證落在掛載的 `~/.openclaw`

## 風險與對策

- 風險：基底 image 與 orchestration 依賴工具版本不一致
  - 對策：薄包裝層只補必要工具，並在 README 列出最低需求
- 風險：不同環境 `OPENCLAW_BASE_IMAGE_CONTEXT` 路徑不同
  - 對策：全部參數化，預設值可覆蓋
- 風險：externalize 路徑在未來版本變動
  - 對策：把掃描路徑集中為可配置 env，並在 mapping 文件明確維護

## 假設與預設

- `v2026.2.15` 來源由本機 checkout 取得，不依賴遠端預建 image
- 基底 image 命名預設為 `openclaw:v2026.2.15`
- orchestration image 仍可命名為 `openclaw-obsidian:local`
- 不修改既有 state/queue 資料格式
