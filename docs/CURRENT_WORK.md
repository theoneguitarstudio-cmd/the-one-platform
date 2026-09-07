# Current Work

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
