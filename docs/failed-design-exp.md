# 失敗設計經驗整理：`wip/openclaw-allinone-runtime-20260409`

## 一句話結論

這次失敗不是「做不動」，而是**把原本鎖定好的 orchestration-first 重構，做成了另一個題目：reproducible all-in-one runtime**。功能越做越完整，但方向已經和原始設計脫鉤。

## 證據來源

| 類型 | 證據 | 觀察 |
| --- | --- | --- |
| log | `git log --oneline` | 本次實作幾乎集中在單一提交：`3268cd9 Add reproducible all-in-one OpenClaw runtime` |
| diff | `git diff --stat main...HEAD` | 共 `19 files changed, 1215 insertions(+), 36 deletions(-)`，不是薄包裝微調，而是整體設計擴張 |
| 原始設計文件 | `docs/enhance-plan.md`, `docs/enhance-spec.md` | 需求已明確鎖定為 **orchestration-first / thin wrapper / 維持 maintainer+gateway 主流程** |
| 本次實作文件 | `README.md`, `docs/plan.md`, `docs/test-plan.md` | 文件已同步改寫成 **all-in-one runtime + obs/ops/serialwrap + external source snapshot** |

## 原本要解的題目

從 `docs/enhance-plan.md` 與 `docs/enhance-spec.md` 看，原始題目其實很清楚：

1. 先把 OpenClaw `v2026.2.15` 做成固定 base image。
2. 本 repo 只負責 orchestration：`compose + scripts + config-template`。
3. `Dockerfile` 改成 thin wrapper，不再 clone/build OpenClaw source。
4. `externalize-runtime-md.sh` 只做容錯強化，不改 deploy 主體。
5. README / path mapping 補齊，讓部署流程可重建。

原始規格甚至把範圍鎖死了：

- **In scope**：base image、thin wrapper、compose/env 調整、externalize 容錯、path mapping、README。
- **Out of scope**：不改 OpenClaw 本體、不改 maintainer loop 核心邏輯、不擴張成新的 runtime 產品設計。

也就是說，這次本來應該是**部署重構**，不是**執行模型重設計**。

## 實際上做成了什麼

從 diff 與當前檔案可見，本次實作實際落點已經變成另一套設計：

### 1. README 已改寫成 all-in-one runtime 故事

`README.md` 明確寫出：

- `docker run openclaw-obsidian:test` 會自動啟動 `maintainer + gateway + obs + ops + serialwrap`
- `docker compose` 只是不拆 sidecar 的另一種操作模式

這和原本「本 repo 只做 orchestration 薄包裝」已經不是同一個定位。

### 2. Dockerfile 從 thin wrapper 變成 runtime assembly layer

目前 `Dockerfile` 不只做薄包裝，還額外承擔了：

- copy `build-context/external-sources`
- 注入 `custom-claw-tools` / `custom-skills`
- 安裝 `obsidian-headless`
- 安裝 `serialwrap`
- build `picoclaw-ops-companion`
- 將 entrypoint 改成 `/ops/scripts/runtime-bootstrap.sh`
- 對外 expose `18789 45450`

原始 spec 的 `Dockerfile` 需求是 `FROM ${OPENCLAW_BASE_IMAGE}` + copy scripts/config；現在則已經變成**一個會組裝多個能力並決定 runtime 啟動策略的 image**。

### 3. Compose 從兩服務 orchestration 擴成多 profile 服務面

`docker-compose.obsidian.yml` 新增了：

- `openclaw-obsidian-sync` (`obs`)
- `openclaw-obsidian-ops-companion` (`ops`)
- `openclaw-obsidian-serialwrap` (`serialwrap`)

也新增了對應的 volume、ports、healthcheck、profile、host state path 與多組 env。這已經不是單純把既有 maintainer/gateway 搬到 base image 上，而是**把 repo 的責任面往 runtime product orchestration 再往外推了一圈**。

### 4. 測試與文件也跟著驗證新題目

`docs/test-plan.md` 已把以下內容視為驗收結果：

- external source snapshot
- `obs` / `ops` / `serialwrap` 啟動
- final image all-in-one runtime
- `docker run` 單容器自動拉起多 service

這代表本次驗證在工程上是認真而完整的；但驗證的是**新題目**，不是原本那題。

## 核心偏差在哪裡

### 1. 問題定義被偷換了

原始題目：**把 build/deploy 變乾淨、可重建、可追溯。**  
實際題目：**把多個能力收斂成一個可攜 all-in-one runtime。**

這不是「順手多做一點」，而是目標函數改了。

### 2. 邊界失守：build / orchestration / runtime product 混在一起

這次提交把以下原本應該分開思考的事情揉成同一批：

- base image build strategy
- orchestration wrapper
- external source snapshot 管理
- optional service packaging
- single-container startup policy
- runtime bootstrap / permission fixup

結果就是每個單點看起來都合理，但合在一起後，repo 的角色從「部署 repo」膨脹成「整套 runtime 組裝與啟動策略 repo」。

### 3. 文件同步得太完整，反而把 drift 藏起來了

這次不是「文件沒更新」，而是**文件更新得太成功**：

- `README.md` 改成 all-in-one runtime 故事
- `docs/plan.md` / `docs/tasks.md` / `docs/test-plan.md` 都補上新設計

所以 branch 內部看起來很一致，但它一致的是**偏離後的新設計**，不是原本鎖定的設計。這使得「看起來很完整」反而成為誤導訊號。

### 4. 單一大型提交讓設計偏差難以及時踩煞車

`main...HEAD` 的 diff 是 19 個檔案、1215 行新增，而且幾乎濃縮在一顆提交。這種粒度對「確認方向有沒有跑掉」非常不友善，因為 reviewer 容易變成只檢查局部正確性，而不是整體題目是否已被改寫。

## 為什麼會讓人覺得「完全對不上想法」

因為這次分支交出的不是一個「更好的版本」，而是一個**不同類型的答案**。

原本想要的是：

- repo 定位更收斂
- build / deploy 責任更單純
- 可重建性更好
- 不碰過多 runtime product decision

最後交出的卻是：

- image 自己決定多服務啟動策略
- repo 需要管理更多 runtime dependency
- sidecar / all-in-one 兩種模型並存
- 外部 source、serialwrap、obs、ops 一起被拉進核心設計

所以不對勁的感受，不是來自某個腳本寫壞，而是來自**設計回答了別的問題**。

## 這次失敗值得保留的正面收穫

雖然方向失焦，但有幾個訊號仍然有價值：

1. `prepare-openclaw-base-image.sh` 這條主線是對的。
2. 原始 spec 其實已經夠清楚，問題不在需求太模糊。
3. 測試與文件補得很完整，代表執行力不是問題，真正要修的是 scope discipline。
4. `all-in-one runtime`、`obs/ops/serialwrap`、external source snapshot 這些不是不能做，而是**不該混進這一輪 orchestration-first 重構**。

## 重開時的硬限制

下一輪若要避免重演，建議先把以下幾條當成 guardrail：

1. **先鎖 repo 定位**：這輪只做 orchestration-first，不碰 all-in-one runtime product 化。
2. **任何新增 service / profile / persistent mount / entrypoint 啟動策略，都先視為 out-of-scope**，除非另外開題。
3. **先做最小閉環**：base image -> thin wrapper -> compose/env cleanup -> externalize hardening -> docs。
4. **驗收要多一條「是否仍符合 `docs/enhance-plan.md` / `docs/enhance-spec.md`」**，不能只驗證 smoke test 有沒有過。
5. **提交切小**：至少拆成 base image、Dockerfile/compose、externalize、docs 幾段，避免單顆大提交吞掉設計審查。

## 新分支建議帶走什麼

如果要「砍掉重練」，**建議只帶走本檔**，其餘 all-in-one runtime 相關變更不要直接續用。

可帶去新分支的不是這次的實作，而是這次的結論：

- 原始方向其實沒問題
- 問題在於 scope 漂移
- 重開時要先守住 orchestration-first 邊界

## 最後判斷

這次不是單純「重構失敗」，而是**設計偏題**。  
因此正確處理不是在原分支上繼續補，而是：

1. 先把偏題原因文件化。
2. 回到乾淨 base。
3. 僅保留失敗經驗，重新實作原本那個較小、較準確的題目。
