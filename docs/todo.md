# 遷移 todo

## P0 - 可重建性

- [x] 讓 base image 可自動從 upstream tag 建立
- [x] 讓外部 source 可自動 stage 到 Docker build context
- [x] 用本機暫存 env 跑通 `docker compose config`
- [x] 用本機 build 實際產出 wrapper image

## P1 - 能力對齊

- [x] 最終 image 在 `docker run` 時自動拉起整套 service
- [x] 匯入 `famiclean` skill
- [x] 匯入 `ops-companion` skill
- [x] 匯入 `test-playbook`
- [x] 匯入 `serialwrap-mcp`
- [x] 匯入 real `serialwrap` runtime（`hamanpaul/serialwrap`）
- [x] 新增 `obs` profile
- [x] 新增 `ops` profile
- [x] 新增 `serialwrap` profile
- [x] 補齊 `obs` runtime 暫存掛載 smoke 驗證（terminal failure clean exit）
- [x] 補齊 `ops` runtime 暫存掛載 smoke 驗證（loopback listener）
- [x] 補齊 `serialwrap` runtime 暫存掛載 smoke 驗證（daemon health ping + seeded profiles）

## P2 - 文件與驗證

- [x] 更新 `README.md`
- [x] 更新 `docs/path-mapping.md`
- [x] 新增 `docs/plan.md`
- [x] 新增 `docs/tasks.md`
- [x] 新增 `docs/test-plan.md`
- [x] 以本機實際 build / compose 結果回填文件中的驗證輸出
