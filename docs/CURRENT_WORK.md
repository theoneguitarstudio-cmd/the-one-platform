# Current Work

## 2026-09-08 正式唯讀 Preflight（最新）

OWNER 本輪已明確核准 Supabase 唯讀查證，已完成；不延伸至任何正式寫入。
起點 main / 1829886a49f4436e966e55afed7f333175d290e8，working tree CLEAN。
結果 WARN：The One name/ref/region匹配；remote29/local34，local-only5/remote-only0，latest remote20260904001100。
Epic7的24表/20函式皆未部署，既有依賴及Epic5/6唯讀安全PASS，未發現已查範圍意外變更。
正式authority未部署；P04/P05/P06/R04正向仍BLOCKED，不標37案通過。
當前無列出的managed recovery point、PITR=false，最新已知logical檔約49.5h；1h保障未證明。
BR-1/3 UNKNOWN，BR-2 FAIL；下一步B：準備正式Backup/Recovery供另次審閱，現在停止。
完整結果、限制、時間與證據hash見[本次正式唯讀證據](EPIC7_PRODUCTION_READONLY_PREFLIGHT.md)。
Epic7 REMOTE CLOSED=NO；Epic5/6 REMOTE CLOSED；payment webhook NOT COMPLETE；不開始Epic8。
未export/restore/migrate/smoke/cleanup/push/deploy；無需OWNER重新登入。
下方各輪紀錄保留歷史時點，其「唯讀尚未授權／尚未執行」不再是現行狀態。


## 2026-09-07 家用本機 PostgreSQL 執行更新（現行）

本輪起點 main / 2eac1b9e8d69d0e3628120121f9a4f7058457325，家用新repo起點CLEAN。
使用者本輪明確授權本機既有Docker image／新隔離container／合成SQL、race與recovery；此前Docker禁止僅在此本機範圍被取代。
現有本機計畫33個case IDs PASS，P04/P05/P06/R04因真authority不存在保持BLOCKED；不是37個完整正向分支PASS。
真PG session、timeout/rollback/斷線、R01–R03雙session、逐步fixture預算及獨立residue已實測；legacy 527斷言、故障13項、parser6項PASS。
詳見[本機實測與剩餘界線](EPIC7_LOCAL_PG_EXECUTION_EVIDENCE.md)。本機分支的PASS不替代原AC、正式coverage或完整服務復原。
下一步可提出owner核准正式唯讀Preflight的具體申請；尚未執行。正式transport不在本機工具中開放，後续須依實際target事實及另次批准審查。
Epic7 REMOTE CLOSED=NO、37案REMOTE NOT RUN；coverage/有限結案仍未批准，Epic5/6 REMOTE CLOSED、payment webhook NOT COMPLETE不變。
不push、不正式操作、不Epic8。下方各輪記錄保留歷史時點；本機Docker與工程進度以本節及新evidence為準。


## 2026-09-07 現行：獨立讀取計畫與正式就緒審查

本輪起點 `6f54f9727fe76e7ae701537573372072c0e72c33`（較49b7d23新），指定交接repo起點CLEAN。
新增獨立殘留讀取計畫／結果驗證、37案預算審查與拒絕升級READY的離線檢查。
**28項新測試PASS，ESLint PASS；正式DB connections / SQL / writes = 0。**
原application/migration、package/lockfile、accepted roadmap與既有測試證據不變。

**工程仍BLOCKER，Epic7 REMOTE CLOSED=NO；尚未到可執行Remote Preflight。**
真正PG driver、逐案SQL與trigger預算驗證、R01–R03多連線、L01–L04精確舊域預算、
實際rollback與獨立observer仍未完成。這些仍由Codex負責，不稱為只等正式核准。
本機Docker兩個pipe均不可用；啟動既有Docker Desktop的動作被自動核准審查拒絕：
先前禁止啟動Docker演練，本次要求不足以撤銷。沒有啟動或換方法繞過，未下載映像。
下一步需明確允許本機引擎／純合成隔離測試範圍後，繼續上述工程；不需要正式帳密。

完整新增審查：[EPIC7_REMOTE_EXECUTION_READY_REVIEW](EPIC7_REMOTE_EXECUTION_READY_REVIEW.md)。
商業發行路徑：[EPIC7_TO_LAUNCH_PATH](EPIC7_TO_LAUNCH_PATH.md)，僅PROPOSAL，Epic7～13不重編。
新證據：`artifacts/remote-smoke/epic7-local-engineering/review-71762026-e4b5-4227-88b5-a94fd20632f9/`。
本輪未重跑原73安全測試、70 controller tests、ValidateOnly、全SQL或build；不push、不正式操作、不Epic8。

以下保留各輪歷史紀錄；涉及「現在不用做任何事」或舊下一步者，以本節和新就緒審查為準。

## 2026-09-07 續作：離線 SQL 計畫與連線安全工程

本次基線 `49b7d23c12f751476a251d8b91ac1930ab04e510`，在指定交接專案工作。
新增 tools/epic7-local-engineering 七檔；**70 項新增離線測試 PASS、ESLint PASS**。
沒有重跑原 73 safety tests、preserved ValidateOnly、完整 SQL suite 或 build。
正式 DB connections / SQL / writes 全為 0；未 push、部署、啟動 Docker 或實作 Epic8。

已完成 37 ID 的離線計畫整理、參數化 SQL 初版、28 表資料鍵／trigger 峰值／逐步數量核對、
連線逾時／晚到取消／角色與連線漂移停止契約、獨立回滾／隔離保留核對及非秘密證據。
**這是離線編譯與控制流程測試，不是 37 案 domain SQL 已執行或完整正式 executor。**
原 application/migration candidate d5f9843、preserved c61、原四檔安全核心及所有歷史結果不變。

本機限制已實查：`docker --host npipe:////./pipe/docker_engine version` 回覆 PIPE_NOT_FOUND；
同端點 image inventory 也不可用。PATH 未找到 psql/postgres。未改 Docker context、未啟動引擎、
未下載 image、未建立容器、未要求管理員權限或安裝依賴。
下一步需先有可用且 scope 已確認的本機隔離 PostgreSQL，工程再完成真實 driver、
rollback/lock/cancel、逐案 SQL 與 legacy 預算實測；不能把未完成接線寫成只等正式批准。
若需操作者介入，只需先確認 Docker Desktop 本機引擎畫面與可用隔離環境，不需正式帳密或 Vercel 重查。

完整說明見 [executor 工程審查包](EPIC7_EXECUTOR_ENGINEERING_REVIEW.md)。


## 2026-09-07 owner 決策更新（現行；非正式操作授權）

本次依使用者明確指示記錄，起點為 `96d206a4cd413efe48c01ebed16f67f07489f266`。
只從本次開始生效；下方舊提案、時間戳、candidate、測試結果及未授權紀錄保留歷史意義。
完整現行原則見 [owner 決策](EPIC7_OWNER_DECISIONS.md)。

- 最後核准人：使用者本人；Codex／受控工具可在未來受核准的具體範圍操作。此刻各項正式操作仍 NO。
- 正式備份限 The One 自己控制的加密空間；任職公司的電腦／磁碟／儲存不是預設長期保存位置。
- 可接受資料損失上限 **1 小時**，執行前盡量更近；未證明可滿足則 STOP，不自動買服務。
- committed／immutable 測試資料預設只放已核准隔離環境；這是策略接受，不是任何一次建立／執行／處置的批准。
- The One Vercel hosting identity **UNKNOWN**；目前連線僅見 together-stories。GitHub App All repositories 證據不必重查。

37 案全部 **REMOTE NOT RUN**；Epic7 **REMOTE CLOSED=NO**。
coverage 替代與有限結案契約仍 **PROPOSED / PENDING APPROVAL**，不隨隔離策略接受而自動通過。
舊 73 safety tests、preserved ValidateOnly 與歷史 SQL/build 證據本輪不重跑。

下一個工程步驟：逐案 fixture/compiler 與獨立 observer 的 schema/trigger 映射、PG transport 失敗契約；先純本機設計及測試。
本次已新增離線 policy/coverage/recovery 條件檢查，仍不是完整正式 executor。使用者現在不用做任何事。

## 歷史紀錄：以下保留本次 owner 決策之前的時點


Read this file first in every new ChatGPT or Codex conversation.

## Current phase

**Epic 7 — Learning Map Core: LOCAL CLOSED (A–E); F LOCAL READINESS TOOLING COMPLETE; STOP BEFORE PRODUCTION**

Approved Planning Baseline **ESTABLISHED** at
`588811d1d5617788b162f4e0a275d64d6a248dce`. The Product Owner subsequently
authorized autonomous LOCAL A → E with a gate after each slice. A–E are complete
locally; non-blocking format/build-environment warnings are recorded in
[execution contracts and closure evidence](EPIC7_LOCAL_EXECUTION.md)
and [approved scope](EPIC7_SCOPE_DEFINITION.md). Subsequently authorized F local
tooling/rehearsal is complete; see [current evidence](EPIC7_F_LOCAL_TOOLING_EVIDENCE.md).
Push and all production backup/restore/deployment/migration/smoke/cleanup remain **NOT AUTHORIZED**.

## Completed P2 baseline

**P2 — Remote Closure of Epic 5 / Epic 6: COMPLETE (2026-09-05)**

Epic 5 and Epic 6 are **REMOTE CLOSED**. Remote Deployment, BR-1/BR-2/BR-3,
migration parity at that historical gate (29 local / 29 remote, no differences), both production smoke
runs, and closure documentation are complete. Remote latest is `20260904001100`.
The verified execution baseline is `899906b556b4dc282538920baec8cdfb0546f6df`.
See [Project Status](PROJECT_STATUS.md) and
[P2 Remote Closure Evidence](P2_REMOTE_CLOSURE_EVIDENCE.md).

## Next canonical step

公司本機工程準備更新（2026-09-07）：[executor安全核心與審查包](EPIC7_EXECUTOR_ENGINEERING_REVIEW.md)
已新增，僅記憶體合成安全流程，無production transport、無正式SQL。原preserved驗證器/候選/34 migrations不變。
下一步是審閱新安全核心、coverage/retention提案與[白話決策單](EPIC7_OWNER_DECISIONS.md)，
再按明確授權補live collector、逐案SQL compiler、PG/獨立observer接線與復原驗證；這些是剩餘工程，
不是只有operator簽名。正式操作、Epic8、push/deploy仍未授權，Epic7 REMOTE CLOSED=NO。

以下保存更新與舊STOP描述保留其歷史時點：

Post-preservation update (2026-09-07 Asia/Taipei): the original F tools/evidence
were saved locally at `c61cdb6c757499b875fc9e9f41657f8b2c1a4ef1`, not pushed.
The tested application/migration candidate remains `d5f98434106797afc65c59953aa3bc61ba26ecb4`.
Use `node scripts/epic7-preserved-validation.mjs --validate-only` for fixed-content
offline verification after preservation; prerequisites and limitations are in
[the appended verification record](EPIC7_F_LOCAL_TOOLING_EVIDENCE.md).
Recovery drill versus service recovery and per-branch coverage/retention proposals
are now explicit in the linked existing documents; all remain NOT APPROVED.
The following uncommitted wording describes the original preparation snapshot.

STOP for review of the uncommitted F local tools, [37-case coverage](EPIC7_F_CASE_COVERAGE.md)
and [recovery authorization package](EPIC7_RECOVERY_AUTHORIZATION_PACKAGE.md).
All 34 migration files remain unchanged. Previous F read-only evidence confirms remote 29,
latest `20260904001100`; this local-tooling task did not query or modify production.
User-provided GitHub screenshots confirm Vercel App installation for
theoneguitarstudio-cmd and Repository access = All repositories. Actual hosting
project/repository/branch linkage and main-push deployment behavior remain unverified.
Do not request the same GitHub authorization page again. Local commits/tools have not been pushed.
Next: review production coverage/retention, named recovery operator/encryption/RPO and
exact backup/isolated-restore scope before any separate authorization. Do not start Epic8–13.
Preserve [Canonical Roadmap](CANONICAL_ROADMAP.md) numbering and Product Decisions.

Production payment-provider webhook processing is **NOT COMPLETE**. It blocks
full production payment closure, not this completed schema/smoke remote closure.
Future remote operations still require fresh backup/recovery and approval gates.
Never modify an applied migration, including `20260901000600`.
