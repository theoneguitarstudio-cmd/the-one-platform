# Project Status

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

本次僅增量本機政策檢查與文件：不改 application／migration／歷史 evidence。上輪安全核心仍在 96d206a，73 tests 不重跑。
後續正式接線、可信取證、逐案 SQL 與全服務還原工程未完成；不能稱為只差批准。

## 歷史紀錄：以下保留本次 owner 決策之前的時點


Status date: 2026-09-06 (Epic7 local closure; P2 remote evidence remains dated 2026-09-05)

This file is the canonical engineering-status record for The One 2.0. Product
sequencing is canonical in [CANONICAL_ROADMAP.md](CANONICAL_ROADMAP.md), and
accepted product rules are canonical in
[PRODUCT_DECISIONS.md](PRODUCT_DECISIONS.md).

## Epic status

| Epic | Scope | Status |
| --- | --- | --- |
| Epic 0 | Foundation | **CLOSED** |
| Epic 1 | Auth / Roles | **CLOSED** |
| Epic 2 | Teacher Public Discovery | **CLOSED** |
| Epic 3 | Trial Flow | **CLOSED** |
| Epic 4 | Commerce | **CLOSED** |
| Epic 5 | Entitlement & Lesson Credit | **REMOTE CLOSED** |
| Epic 6 | Scheduling & Booking | **REMOTE CLOSED** |
| Epic 7 | Learning Map Core | **LOCAL CLOSED A–E; F local readiness tooling COMPLETE; production F NOT AUTHORIZED / NOT RUN** |

The verified production smoke baseline is branch `main`, with Git `HEAD` and
`origin/main` at `899906b556b4dc282538920baec8cdfb0546f6df` (ahead/behind 0/0).
This documentation reconciliation follows that execution baseline.

## Epic 7 baseline and local closure

Current phase: **Approved Planning Baseline ESTABLISHED → LOCAL A–E COMPLETE → F LOCAL TOOLING COMPLETE → STOP BEFORE PRODUCTION**.
All four Product Owner decisions are **APPROVED** and recorded
in [Epic 7 Scope Definition](EPIC7_SCOPE_DEFINITION.md): additive legacy Stage /
course Level separation, representative initial content, advisory prerequisites
with separate access and Self Complete, and joined-course workspace boundaries.

Scope package: **APPROVED BASELINE ESTABLISHED** by pushed documentation commit
`588811d1d5617788b162f4e0a275d64d6a248dce`, following the preparation SHA
`82b1f25e6db3075c4d619c19440e4e94d20891c8`. Neither is the historical smoke SHA.

The subsequent Product Owner instruction authorizes autonomous LOCAL A–E,
with per-slice checks and local commits; F production remains NOT AUTHORIZED. A contracts,
B hierarchy, C immutable content, D owner activity/internal inspection and E
local validation are complete. Actual evidence is recorded in
[Epic 7 Local Execution](EPIC7_LOCAL_EXECUTION.md).
Epic7-A–F are internal slices, not new Epics.

- Five additive migrations; local test/repository chain **34**, latest
  `20260906000500`; original 29 migration files unchanged. No remote migration.
- **219 application tests**, **1,480 assertions in 39 SQL suites**, **237 further
  Epic7 SQL assertions**, and **six independent-session race scenarios** PASS.
- All 24 new tables deny raw application access. All 20 new functions pass
  owner/search-path/grant review; function and trigger lint reports zero errors.
- Clean rebuild and populated 29 → 34 upgrade PASS; all 13 populated legacy /
  Commerce / Entitlement / Scheduling table snapshots remain identical.
- ESLint/typecheck PASS; `next build --webpack` PASS. Default Turbopack could
  not spawn a worker on this host (OS error 5).
- Current/staged diff checks PASS. The new applied migration 002 retains two
  whitespace-only lines under the no-applied-migration-edit rule.
- Shipped learner authority denies use until Epic8 policy exists. Positive
  progress tests use synthetic isolated authority fixtures only.
- No Student Workspace, Creator CMS, formal verification/assessment, enrollment
  engine, new UI or route. Local commits are not pushed. Epic7 is not REMOTE CLOSED.

## Epic7-F local readiness preparation

Post-preservation note (2026-09-07 Asia/Taipei): F tooling/evidence was saved locally
in `c61cdb6c757499b875fc9e9f41657f8b2c1a4ef1`; historical test candidate stays d5f9843.
Fixed preserved-content verification is separate from the original HEAD guard;
it grants no execution authority. Recovery service/drill distinctions and phased
coverage/retention terms are proposals, not accepted closure conditions.
Earlier A–E Turbopack failure and push-ready statements are historical; later F
isolated builds passed, while hosting/push safety remains unverified/unapproved.

Current F local preparation is recorded separately in [tooling evidence](EPIC7_F_LOCAL_TOOLING_EVIDENCE.md),
[coverage](EPIC7_F_CASE_COVERAGE.md), and [recovery package](EPIC7_RECOVERY_AUTHORIZATION_PACKAGE.md).
It includes offline ValidateOnly, local target protections, synthetic rehearsal and pinned-tool builds;
it does not authorize push, production export/restore/migration/deployment/smoke/cleanup.
All 34 migrations and application business logic remain unchanged. Epic7 is not REMOTE CLOSED.

## 公司本機 executor 工程準備（2026-09-07）

新增[可審查安全核心](EPIC7_EXECUTOR_ENGINEERING_REVIEW.md)：實際preserved內容整合、固定target/version、
manifest預算、記憶體transaction sentinel、timeout/失敗停止、獨立殘留核對、白名單artifacts。
本輪測試只證明新工具的合成控制流程，不能替代PostgreSQL/37案domain/production證據。
原工具/migrations/application均未改；A–E及P2歷史結果不變。
正式transport、逐案SQL/actor/PK compiler、可信live觀察與完整服務復原仍需工程交付及另行授權。
coverage/保留草案未接受；[集中決策單](EPIC7_OWNER_DECISIONS.md)只問owner可決定的事項。

## Historical P2 remote closure state — not a fresh Epic7 preflight

- **P2 Remote Closure: COMPLETE — 2026-09-05**.
- Remote Deployment: **PASS**, target `ygxeihtcolpiulupieeq`.
- Migration parity: **29 local / 29 remote; local-only 0 / remote-only 0**.
- Local and remote latest: `20260904001100`
  (`20260904001100_harden_commerce_service_role_authority.sql`).
- Backup/recovery: **BR-1 PASS / BR-2 PASS / BR-3 PASS** at the approved
  operation gates, using the verified logical recovery method. Freshness must
  be rechecked for any future operation; no restore was rerun for closure docs.
- Epic 5 production smoke: **15 PASS / 0 FAIL / 0 SKIP; Overall PASS**.
  Run: `remote-smoke-epic5-20260905140007-98c7d02e`.
  Security PASS; Cleanup PASS; operational residue 0; immutable expected
  evidence 0; unexpected evidence 0.
- Epic 6 production smoke: **16 PASS / 0 FAIL / 0 SKIP; Overall PASS**.
  Run: `epic6-smoke-20260905144629-8e8710f0`.
  Security PASS; Cleanup PASS; operational/unexpected residue 0; immutable
  expected evidence 0. Both artifacts contain no errors.
- [P2 Remote Closure Evidence](P2_REMOTE_CLOSURE_EVIDENCE.md) records evidence
  provenance, timestamps, backup metadata, artifact hashes, and gate review.

## Closure decision and next step

The required sequence is complete: backup/restore capability verification →
remote migration preflight → remote deployment → Epic 5 production smoke →
Epic 6 production smoke → closure documentation. Both Epics satisfy the
canonical schema/smoke criteria for **REMOTE CLOSED**.

Next: **STOP for operator review of F local tooling → separately authorized recovery/production gates** under
[Canonical Roadmap](CANONICAL_ROADMAP.md). No automatic remote operation or
Epic 8–13 implementation is authorized.

Non-blocking operational follow-up: retain the external backups and smoke
artifacts, maintain restore drills, and revalidate logical recovery when data
is populated. The circular-FK dump warning involved tables verified empty at
preflight. Managed backup/PITR coverage must not be inferred from logical dumps.

## Production payment boundary

Production payment-provider webhook processing is **NOT COMPLETE**. It does not
block schema migration deployment, but it blocks full production payment
closure.

## AI handoff contract

At the start of a new ChatGPT or Codex conversation, read in this order:

1. [CURRENT_WORK.md](CURRENT_WORK.md)
2. [PROJECT_STATUS.md](PROJECT_STATUS.md)
3. [CANONICAL_ROADMAP.md](CANONICAL_ROADMAP.md)
4. [PRODUCT_DECISIONS.md](PRODUCT_DECISIONS.md)
5. Relevant Epic, security, migration, and domain documents.

Repository documentation is the canonical project source of truth.
Conversation memory is supplemental only. Do not renumber Epic 7+, redefine an
accepted product decision, or promote future scope into a current blocker. If
repository evidence conflicts with this status file, report the discrepancy
instead of guessing or silently changing either source.
