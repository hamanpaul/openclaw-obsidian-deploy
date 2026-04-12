# OpenClaw Ecosystem 部署重構計畫 (Stateless Image + Stateful Mounts)

## 摘要
本計畫旨在解決先前 `all-in-one runtime` 導致架構過度耦合的問題。新的部署策略將嚴格區分「程式碼（Code）」與「狀態（State）」。
我們將透過 `Dockerfile` 打造一個包含所有工具鏈（OpenClaw, PicoClaw, GarminDB, 自建 Github Repos）的 **無狀態基底映像檔 (Stateless Base Image)**，並透過 `docker-compose` 結合 `-v` 掛載機制，將所有機敏資料、個人設定與 Vault 注入容器內，實現「本地安全測試、遠端無縫上線」的 Orchestration-first 架構。

## 目標 (Goals)
1. **統一個體化映像檔**：一個 Docker Image 內含 Python/Node.js 雙環境、GarminDB、以及從 GitHub 動態拉取的 `custom-claw-tools` 等自建服務。
2. **狀態完全抽離**：將 `~/.config`, `~/.picoclaw`, `~/.GarminDb`, `.env` 等機敏設定，以及 Obsidian Vault，全數透過 Host Volume 映射至容器內的 `/home/appuser/`。
3. **本地沙盒測試**：允許在本機端，使用測試 Vault 與設定進行 `docker-compose up` 測試，確保所有排程與監聽器正常運作。
4. **優雅的服務管理**：取代裸機的 `systemd user services`，改用 Docker 原生的微服務管理方式（透過拆分 Compose Services 或使用輕量級 Supervisor 守護行程）。

---

## 執行階段 (Phases)

### Phase 1: 設計與建構 Base Image (Dockerfile)
*   **選擇基底**：採用 Debian 或 Ubuntu 作為基底，安裝 Node.js (v22) 與 Python (3.12+)。
*   **拉取程式碼 (Stateless)**：在 `RUN` 階段安裝系統級依賴（git, cron, curl）並直接從 GitHub clone `custom-claw-tools` 等專案，執行 `npm install` 與 `pip install`。
*   **設定權限**：建立非 root 使用者 `appuser` (UID 1000/GID 1000)，確保寫入 Host 掛載目錄時不會發生權限錯亂。

### Phase 2: 狀態抽離與路徑映射設計 (Volume Mapping)
*   **機敏資料包準備**：將從 Orangepi3 抽取的 `sensitive_backup.tar.gz` 在本機解壓縮至獨立目錄（如 `./host_data/home/`）。
*   **定義 docker-compose.yml**：設定對應的 `-v` 參數。

### Phase 3: 服務與排程 Orchestration (Service Management)
在裸機上，我們依賴 Systemd 來管理服務。在 Docker 中，我們將在 `docker-compose.yml` 中使用同一個 Image，但賦予不同的啟動指令（Command）來達成微服務化：
1.  **Gateway 容器**：專職執行 `picoclaw gateway`。
2.  **Listener 容器**：執行 `fami-ghome`, `obs-auto-moc-listener`, `picoclaw-ops-companion-listener` 等常駐程式。
3.  **Cron 容器**：專職啟動 `cron -f`，負責執行 Garmin 同步、Fami 瓦斯通知、Obsidian Git 備份等定時任務。

### Phase 4: 本地測試與驗證 (Local Sandbox Validation)
*   於本機準備測試用的 `.env` 與假的 Obsidian Vault。
*   執行 `docker-compose up --build`，驗證容器是否能正確掛載路徑，API 是否能在本機 port 正常回應 (`curl localhost:45450/health`)。

### Phase 5: 遠端部署 (Production on OrangePi3)
*   將通過測試的 `Dockerfile` 與 `docker-compose.yml` 推送到 Orangepi3。
*   在 Orangepi3 掛載真實的 `sensitive_backup` 內容，全面由 Docker 接管。
