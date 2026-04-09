# 遷移 tasks

| Track | Task | Source of truth | 主要輸出 |
| --- | --- | --- | --- |
| build | 自動化 OpenClaw base image | `openclaw/openclaw@v2026.2.15` | `prepare-openclaw-base-image.sh` |
| build | 自動化外部 source snapshot | `custom-claw-tools`, `custom-skills` | `prepare-external-sources.sh`, `build-context/external-sources/manifest.json` |
| runtime | 匯入 `famiclean` / `ops-companion` skill | `custom-claw-tools/*/skills` | `/app/skills` |
| runtime | 匯入 `test-playbook` / `serialwrap-mcp` | `custom-skills/*` | `/app/.agents/skills` |
| service | 提供 `obs` profile | `custom-skills/obs-service-wsl-handler` | `openclaw-obsidian-sync` |
| service | 提供 `ops` profile | `custom-claw-tools/picoclaw-ops-companion` | `openclaw-obsidian-ops-companion` |
| docs | 更新 host/container mapping | deploy repo + external snapshot | `docs/path-mapping.md` |
| docs | 產出遷移文件 | 本 repo | `docs/plan.md`, `docs/tasks.md`, `docs/todo.md` |
| test | 產出測試設計文件 | `custom-skills/test-playbook` | `docs/test-plan.md` |
| quality | 收斂 source code 風險 | implementation diff | `/review` 驗收入口 |

## 建議多工分派

1. **開發**
   - Dockerfile / skill injection / entrypoint scripts
2. **部署**
   - compose / env / README / path mapping
3. **測試**
   - smoke、risk matrix、test plan、log/verification command
