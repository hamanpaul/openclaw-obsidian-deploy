# Docker Orchestration 技術規格 (Enhance Spec)

## 1. 基礎映像檔規格 (Base Image Spec)

*   **Base OS:** `node:22-bookworm-slim` 或 `python:3.12-slim-bookworm` (擇一擴充另一環境)。
*   **User:** 建立與 Host 一致的非 root 用戶：
    ```dockerfile
    RUN groupadd -g 1000 appgroup && useradd -u 1000 -g appgroup -m -s /bin/bash appuser
    ```
*   **System Dependencies:**
    `git`, `cron`, `curl`, `jq`, `openssh-client`, `build-essential` (供 python native package), `tzdata` (確保時區正確，預設設定 `Asia/Taipei`)。
*   **App Dependencies & Source Code:**
    在 Dockerfile 的 `RUN` 階段中，以 `appuser` 身分執行：
    ```dockerfile
    # 建立目錄並從 Github Clone 您的專案
    RUN git clone https://github.com/hamanpaul/custom-claw-tools.git ~/custom-claw-tools
    RUN cd ~/custom-claw-tools/picoclaw-ops-companion && npm install && npm run build
    RUN pip install garmindb --user
    # 安裝其他必要的 python requirements...
    ```

## 2. 掛載對應規格 (Volume Mapping)

所有從 `sensitive_backup.tar.gz` 解壓縮的資料與 Vault，都必須嚴格對應到 Container 內 `appuser` 的 Home 目錄。

**`docker-compose.yml` 範例映射：**
```yaml
volumes:
  # 機敏設定檔與 Token
  - ./host_data/home/.config:/home/appuser/.config
  - ./host_data/home/.picoclaw:/home/appuser/.picoclaw
  - ./host_data/home/.garmin.env:/home/appuser/.garmin.env
  - ./host_data/home/.GarminDb:/home/appuser/.GarminDb
  - ./host_data/home/.ssh:/home/appuser/.ssh:ro # SSH Keys (唯讀)
  # 歷史資料庫庫存 (Garmin)
  - ./host_data/home/HealthData:/home/appuser/HealthData
  # Obsidian Vault 本體
  - /path/to/real/vault:/workspace/vault
```

## 3. 服務架構與 Entrypoint 設計

由於 Docker 不鼓勵在單一容器內執行完整的 Systemd，我們將這些服務解耦為三個邏輯容器（它們共用同一個 Image 以節省資源）：

### Service 1: `gateway`
*   **Command:** `picoclaw gateway`
*   **Ports:** `3322:3322` (Local Home Listen Port), `45450:45450` 等等。

### Service 2: `listeners`
為了在一個容器內跑多個常駐監聽程式 (如 `fami-ghome`, `ops-companion-listener`, `obs-auto-moc-listener`)，我們可以：
1. 使用 `supervisord` 配置檔來啟動並監控它們。
2. 或撰寫一個簡單的 `entrypoint.sh`，背景執行並監控：
   ```bash
   #!/bin/bash
   ~/custom-claw-tools/fami-ghome/bin/fami-ghome serve &
   ~/custom-claw-tools/picoclaw-ops-companion/bin/picoclaw-ops-companion-listen &
   ~/custom-claw-tools/obs-auto-moc/bin/obs-auto-moc-listen &
   wait -n
   ```

### Service 3: `cron-worker`
*   **Command:** 將所有的 user cronjobs 寫入一個檔案（例如 `crontab.txt`），然後啟動 cron。
    ```bash
    crontab ~/custom-claw-tools/scripts/crontab.txt && cron -f
    ```
*   **Cron 內容範例：**
    ```cron
    0 8 * * * cd ~/custom-claw-tools/famiclean-skill/skills/fami-claw-skill/scripts && python3 famiclean.py --env-file ~/.config/fami-ghome-live/.env check-threshold --force-notify
    0 20 * * * cd ~/custom-claw-tools/famiclean-skill/skills/fami-claw-skill/scripts && python3 famiclean.py --env-file ~/.config/fami-ghome-live/.env check-threshold
    0 8,20 * * * ~/custom-claw-tools/health-tracker/bin/health-tracker-garmin --runtime-config ~/.config/health-tracker/garmin-runtime.json sync-and-ingest
    ```

## 4. 關鍵挑戰與解決方案
*   **SSH 與 Git 權限**：掛載 `.ssh/` 必須確保權限正確 (`chmod 600`)，否則 `obsidian_git_backup.sh` 會被 Git/SSH 拒絕。可以在啟動腳本內加入 `chmod 600 ~/.ssh/id_ed25519*` 作為防護。
*   **Docker 內部路徑 (Path Dependencies)**：必須確保所有 `custom-claw-tools` 內的程式碼都使用相對路徑，或是讀取環境變數 (如 `$HOME`)，避免寫死 `/home/haman/`。
