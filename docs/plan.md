# o-pi3 等價 Docker 化遷移計畫

## 目標

把目前 o-pi3 上的 OpenClaw / Obsidian / companion 工作流轉成可在本機直接重建的 Docker 部署，同時保留：

- `runtime behavior + config parity`
- volume-based state / auth / notes 掛載
- `obs` / `ops` / `famiclean` 相關能力
- 後續可延伸的 `serialwrap` / `COM0` 參考面

## 核心來源

- OpenClaw 基底：`openclaw/openclaw@v2026.2.15`
- o-pi3 custom services：`hamanpaul/custom-claw-tools`
- WSL / skill / test 參考：`hamanpaul/custom-skills`
- workspace notes 參考：`hamanpaul/obsidian_vault`

## 實作策略

1. **先解決可重建性**
   - `prepare-openclaw-base-image.sh` 自動抓 upstream tag、在本機建出 `openclaw:v2026.2.15`
   - `prepare-external-sources.sh` 把 `custom-claw-tools` / `custom-skills` stage 到 repo build context
2. **再解決能力對齊**
   - 將 `famiclean` / `ops-companion` 注入 `/app/skills`
   - 將 `test-playbook` / `serialwrap-mcp` 注入 `/app/.agents/skills`
   - 以 compose profile 加入 `obs` / `ops` sidecar
3. **最後做文件與驗證**
   - 補齊 `docs/tasks.md` / `docs/todo.md` / `docs/test-plan.md`
   - 用 smoke + compose config + optional profile 啟動驗證本機行為

## 交付物

- `Dockerfile`
- `docker-compose.obsidian.yml`
- `.env.example`
- `scripts/prepare-openclaw-base-image.sh`
- `scripts/prepare-external-sources.sh`
- `scripts/obs-sync-entrypoint.sh`
- `scripts/ops-companion-entrypoint.sh`
- `docs/path-mapping.md`
- `docs/tasks.md`
- `docs/todo.md`
- `docs/test-plan.md`

## 三軌執行模型

### 1. 開發軌

- 匯入 `custom-claw-tools` / `custom-skills` 的必要能力
- 對齊 `obs` / `ops` / `famiclean`
- 保留 `serialwrap-mcp` 作為後續 UART/COM0 能力入口

### 2. 部署軌

- 讓 build 不依賴手動 checkout
- 讓外部 source 可以在 build 前自動 stage
- 讓 `obs` / `ops` 以 profile 啟用，不影響核心 maintainer/gateway

### 3. 測試軌

- 先驗證 deterministic build / config / path mapping
- 再驗證 compose 啟動、volume wiring、skills 注入
- 最後驗證 optional profile 與文件一致性
