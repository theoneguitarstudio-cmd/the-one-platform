# Epic7 Remote Smoke Plan — 設計階段，全部 NOT RUN

候選：`d5f98434106797afc65c59953aa3bc61ba26ecb4`；規劃日期 2026-09-06。
前置查證與 migration hashes 見 [readiness evidence](EPIC7_REMOTE_READINESS_EVIDENCE.md)。
本文件不授權 production migration、fixture、smoke、cleanup 或 restore。
後續 [本機 tooling](EPIC7_F_LOCAL_TOOLING_EVIDENCE.md) 與 [37-case coverage](EPIC7_F_CASE_COVERAGE.md)
已完成離線 ValidateOnly／isolated rehearsal；沒有 production writer。以下 NOT RUN 指正式案例。
依 [Scope](EPIC7_SCOPE_DEFINITION.md)、[Local Execution](EPIC7_LOCAL_EXECUTION.md)、
[Security](SECURITY.md) 與 [recovery runbook](REMOTE_BACKUP_RECOVERY_RUNBOOK.md) 設計。

## 實際入口與禁止事項

只採用候選已實作入口（public schema；參數 UUID 是 identity，不是 authority）：

| RPC | 參數型別 | 角色／用途 |
| --- | --- | --- |
| learning_create_course | uuid,text,text,uuid,text | active Admin/Super Admin，建立 Course/Map |
| learning_create_draft | uuid,uuid | active Admin/Super Admin，建立版本 |
| learning_put_structure | uuid,integer,uuid,jsonb | active Admin/Super Admin，exact revision/request 與 structure |
| learning_put_content | uuid,integer,uuid,jsonb | active Admin/Super Admin，版本內容／關係 |
| learning_freeze_version | uuid,integer,uuid | active Admin/Super Admin，完整性通過才 freeze |
| learning_inspect_version | uuid | active Admin/Super Admin，minimal inspection |
| learning_set_activity | uuid,uuid,integer,uuid,jsonb | active Student **且** private course-use authority 通過 |
| learning_get_own_activity | uuid,uuid | 同上，只讀 auth.uid() 的 activity |

`private.learning_course_use_authorized(uuid,uuid,uuid,uuid)` 在候選 **回傳 false**。
production 禁止更換其 body、建立假 enrollment/寬鬆 entitlement、設 bypass claim/GUC、
增加 grant 或暫停 guard 來跑正向測試。local regression scripts 有合成 authority replacement，
**不可直接指向 remote 執行**。離線 ValidateOnly／local adapter 已完成；production executor 仍需獨立 review，
並驗證 target/SHA/latest/transaction sentinel/residue/error handling 才能提執行申請。

## 共同前置與證據格式

所有案例均需 G0：另行明確授權 exact target `ygxeihtcolpiulupieeq`、候選 SHA、已部署 34-file chain/latest
`20260906000500`、BR-1/2/3、具名 operator、reviewed harness、manifest、預期 retained evidence 及時間窗。
G0 目前不成立；本輪沒有執行任何案例。

- F：後續核准的**rollback-only**合成 fixture，兩個 course、各自 map，A 有兩個 Levels、三個 Modules、四個 Nodes；
  B 使用不同階層且共享 Skill/contributor 只作語意 reuse。A 有多 Resource Node、text-only Node、Objectives、
  advisory edges、作者 credit、capability descriptor、V1/V2。fixture 可取材於 [local fixture](../scripts/epic7-fixtures.mjs)，
  但必須拆除任何 policy replacement，不能未 review 整份搬往 production。
- 身份：合成 active Admin/Super Admin、Teacher、只有 attribution 的 Creator、兩個 Student，以及 inactive/role-loss 對照。
  fixture owner 的角色建置另受授權；測試 RPC 用 authenticated actor context，不以 postgres 呼叫成功冒充 app authority。
  不使用真實學生、不寄信、不呼叫媒體/provider/payment API、不加入正式 enrollment。
- E：每案記錄 run/case ID、UTC、target/SHA/migration latest、session role（不含 token）、合成 UUID manifest、
  請求摘要、expected/actual SQLSTATE/domain result、scope-specific counts/digests、transaction/rollback sentinel；不輸出原始 PII/locator。
  單純「被拒」不能證明未達到的下游驗證。例如 deny-only helper 先拒絕後，不能聲稱 forged-field validator 已在 remote 通過。
- 負向 SQL 用 reviewed savepoint/subtransaction 捕捉錯誤；最後外層必須 ROLLBACK。
  成功 case 不可自動 COMMIT；最後獨立 session 查 manifest/residue，而非只信同一 transaction 的查詢。

## 清理／保留分類

| 類別 | 設計與允許的後續處理 |
| --- | --- |
| R：rollback-only | 所有 fixture/content/freeze/audit/request 寫入均未提交，由同一外層 transaction ROLLBACK；這是交易回滾，不是繞過 immutable trigger 刪除已提交資料。預期 operational=0、immutable=0、unexpected=0，須獨立查證 |
| C：committed concurrency fixture | 多 session 要看見共同資料，不能共享另一 session 未提交的 fixture。需另核准永久/有政策保留的 Course/Map/identity/frozen rows、actor references、receipts/audit manifest。沒有核准就 NOT RUN，不許以零 residue 標準假裝能清除 |
| P：待真實 course-use authority | 正向 progress 及其 race 目前 NOT RUN / policy prerequisite absent。不能修改 production policy 以消除限制。保留 local 測試結果為 LOCAL，不標 remote PASS |
| Unexpected residue | manifest 外資料、跨學生／版本變更、部分寫入、rollback 後存留或未核准 committed fixture；任何一項使 smoke FAIL，保留證據並依 runbook處理，不立即 DELETE/repair |

沒有公共 cleanup/delete RPC 可以刪除 stable identities、frozen versions、receipts 或依賴 actor。
audit 保存遵守 canonical recovery policy，不能因 catalog 沒有 user trigger 就獲得刪除授權。
可清理範圍目前僅 R 類未提交資料的回滾及非 DB 的合成臨時檔（仍依授權）；
**沒有預先授權的 committed production data cleanup**。C 類預期保留數由實際 reviewed manifest 逐表計算，
不可在 fixture 尚未定案時捏造數字。若業務不能接受永久合成資料，C 案留在已核准隔離環境，remote coverage 明示缺口。

## 案例矩陣

每案共同前置 G0、共同證據 E；下表補充個別條件／角色／操作與斷言／證據／保留。
**以下全部 NOT RUN；PASS 只會由後續真實執行 artifact 產生。**

| ID | 個別前置 | 角色與操作／預期結果 | 個別證據 | 清理／保留 |
| --- | --- | --- | --- | --- |
| S01 | 已部署候選 | 唯讀 operator 查 24 表 RLS/raw grants、8 public/12 private functions、owner/search_path；完全符合候選 | catalog exact signature/ACL diff，含原有窄 rls_auto_enable 例外 | 只讀，0 |
| S02 | F identities | anon/authenticated/service_role 嘗試 raw SELECT/DML 及 private EXECUTE，均拒絕；TRUNCATE 僅查 privilege metadata 應為 false，不實際執行；不能把 bypassrls 當 grants | permission result 與零 changed rows；TRUNCATE privilege=false | R；先 review 最小 fixture 範圍，發現多餘權限立即停止，不試刪 |
| S03 | F roles | Teacher、Creator、Student、inactive Admin、移除角色 Admin 呼叫建構/inspection，拒絕；active Admin/Super Admin 成功 | 角色矩陣、SQLSTATE、scope digest | R |
| S04 | F publication | Admin inspection 不含 provider_ref、content body、linked Auth IDs、learner data 或 delivery token | DTO key allowlist | R |
| H01 | F 兩課程不同結構 | Admin create_course/create_draft/put_structure；階層正確、沒有硬編碼 5/6 Levels 或 Teacher owner | minimal hierarchy JSON、course scoped identities | R |
| H02 | 兩課程及兩版本 | Admin 跨 course/map/version parent、Node/reference 混用，拒絕 | exact FK/domain errors；原結構 digest 不變 | R |
| H03 | 有至少兩個 siblings | Admin 合法 reorder 成功；重複/非正 position 拒絕 | order/revision、失敗前後 digest | R |
| H04 | 同 map draft 已存在 | Admin 再建立不同 draft 拒絕；exact create retry 不重複；不同 actor/payload identity retry 拒絕 | publication/map/audit scoped counts | R |
| H05 | 成功 structure/content request | Admin exact retry 返回同 revision；同 key 不同 payload、stale revision 拒絕 | receipt scope、revision、audit count 不重複 | R |
| C01 | 空 draft Node | Admin 保存 0 Resource draft 成功；尚未宣稱 publish-ready | draft inspection/counts | R |
| C02 | Objective-only Node | Admin freeze 拒絕 incomplete_curriculum，無 partial state/receipt/audit | freeze前後三類 digest | R |
| C03 | Resource-only Node | Admin freeze 同樣拒絕缺 Objective | 相同 rollback 斷言 | R |
| C04 | 每 Node Objective + 1 text Resource | Admin freeze 成功；無影片/PDF/audio 固定組合要求 | frozen stamps、Node minimum counts | R |
| C05 | 多 Resource Node | Admin 同課程 revision 重用、多連結排序/用途有效；跨課程 resource revision 拒絕 | exact node/version/resource links | R |
| C06 | Objective/Skill mappings | Admin 同 course/node Objective binding；shared Skill 可跨課程語意重用，既有 Skill definition 改寫拒絕 | mapping IDs、definition digest | R |
| C07 | 兩個 contributor，包括 Teacher/Creator | Admin 建立 credit snapshot 成功；署名者自身不取得 construction/use/revenue 權限 | credit display snapshot、negative role results、無商業寫入 | R |
| C08 | Optional capability descriptor | Admin 建立四種已支援 code 的 metadata；非法 result/reviewer/quota 欄位拒絕；descriptor 不產生 review/assessment/eligibility | payload key validation、無 workflow/formal rows | R |
| G01 | 同 publication 至少三 Node | Admin 保存 advisory edges 成功；自環、多節 cycle、跨 version/course edges 拒絕 | edges digest、cycle error | R |
| G02 | 完整 F | Admin freeze 完整 hierarchy/DAG 成功；空 Level/Module/缺 Node 版本拒絕 | structural completeness、原子 revision/receipt | R |
| G03 | 完整 DAG 正常入口 | Admin freeze 後圖保持 acyclic；005 trigger存在，local corruption test已有證據 | catalog trigger binding + 正常 freeze 結果 | R；不在 production owner 直寫循環或停 trigger 來造 corruption |
| V01 | frozen V1 | Admin RPC 再改 V1 拒絕；exact freeze retry 仍回原結果；app direct INSERT/UPDATE/DELETE 拒絕 | state/rows/revisions/receipts 不變 | R；owner corruption/guard bypass 留在 local |
| V02 | frozen V1，新增 V2 draft | Admin 建立不同標題/placement/new resource revision 後 freeze；V1 與 V2 各自可 inspection、舊引用不重綁 | V1 before/after digest 與 V2 差異 | R |
| P01 | F frozen Node，shipped policy=false | active Student get/set 均 course_use_denied；沒有 recommended/unjoined 的 0% map 或 activity | 兩個 RPC result、activity/request 0 | R |
| P02 | F frozen Node、兩 Student | Student 提交其他 subject／formal outcome 欄位或取其他學生資料，不能越權；目前會先被 course-use gate 擋住 | denied/no writes；下游 field validator 未 remote 覆蓋的標記 | R；細部 validator coverage 由 local 保留 |
| P03 | F actors | Teacher/Creator/Admin 非 Student role、inactive/role-loss Student 使用 progress，拒絕；service_role 無 EXECUTE | student_required 或 permission error；zero write | R |
| P04 | 真實、另行核准的 course-use authority；候選目前不具備 | owner Student opened/resume/revisit/Self Complete set/clear 成功，opening 不自動 complete；沒有觀看或 advisory 強制門檻 | owner/version/Node resource/revision/result | P，現在 NOT RUN；不把 Epic8 實作加入 E7 migration blocker |
| P05 | P04、兩 Student/V1/V2 | 跨學生／課程／版本／Node resource 拒絕，V2 不複製或覆寫 V1；lost eligibility/history retained | exact owner DTO、before/after digest | P；不能偽造 policy 或直接修改 production eligibility |
| P06 | P04 | 所有 Nodes 自報完成仍不產生 VERIFIED/mastery/assessment/certificate/legacy Stage completion | formal domain scoped counts/digests 不變 | P；沒有正式 authority 時不得標 remote PASS |
| R01 | C shared draft | 兩 Admin sessions 反向 DAG edges 競爭；序列化後 cycle/stale 一方拒絕，最終 acyclic | session timing、commits/errors、graph/revision | C，需先核准 retained manifest |
| R02 | C complete draft，同 actor/key | 兩 sessions 同 freeze retry；一致 revision，只有一次成功 transition/receipt/audit | independent sessions、unique scoped receipt | C |
| R03 | C complete draft | freeze vs edit 競爭；無 half freeze，stale/immutable 拒絕、合法結果一致 | lock ordering、final immutable digest | C |
| R04 | P04 + C actor fixture | 競爭首次 activity writes，exact old retry after correction，跨 Node 相同 request key race | 三種 session outcomes、receipt/revision/no overwrite | P + C；現在 NOT RUN |
| L01 | G0，獨立 approved legacy rollback fixture | 既有 Teacher discovery/capability/1–5 Stage 與 Trial participant/assessment 邊界回歸，不映射新 Levels | old FK definitions + synthetic behavior、privacy assertions | R；真實舊資料只用最小必要 readonly digest |
| L02 | G0，同上 | 既有 Commerce checkout/payment boundary/idempotency 回歸；不呼叫真 payment provider | existing assertions、order/payment/audit transactional evidence | R；webhook NOT COMPLETE 不改狀態 |
| L03 | G0，同上 | 既有 Entitlement fulfillment/reserve/consume/release、service authority 與 ledger append-only 回歸 | approved Epic5 case matrix/residue categories | R；不是授權直接重跑 Epic5 runner |
| L04 | G0，同上 | 既有 Scheduling booking/cancel/reschedule/fixed/flexible/Makeup/lock 回歸 | approved Epic6 matrix與transaction evidence | R；不是授權直接重跑 Epic6 runner |
| L05 | 所有核准 R/C 案結束 | independent readonly observer 查 manifest/all touched tables/actors/audit，分類 operational、expected retained immutable、unexpected；核對legacy未變 | signed-off manifest、zero unexpected、exact retained inventory | R 應 0/0/0；C 按已核准保留數，不能統稱 cleanup=zero |

## 本機證據與 remote coverage 的界線

- Structure/locks：[structure SQL](../supabase/tests/database/learning_structure.test.sql)、
  [global lock contract](../supabase/tests/database/global_lock_order_contract.test.sql)。
- Content/freeze：[content regressions](../scripts/epic7-content.regression.mjs)、
  [closure regressions](../scripts/epic7-closure.regression.mjs)、
  [content races](../scripts/epic7-concurrency.regression.mjs)。
- Progress：[progress regressions](../scripts/epic7-progress.regression.mjs)、
  [progress races](../scripts/epic7-progress-concurrency.regression.mjs)。
- Upgrade/security：[populated upgrade](../scripts/epic7-populated-upgrade.mjs)、
  [database review](../scripts/epic7-database-review.mjs)。
- Legacy smoke scope：[Epic5 plan](EPIC5_REMOTE_SMOKE_PLAN.md)、[Epic6 plan](EPIC6_REMOTE_SMOKE_PLAN.md)。

上述入口是 local-only reproduction/evidence source，不是可貼到 production 執行的指令。
本 plan 沒有替完整 positive-progress 或 concurrency remote coverage 宣告 PASS。
需要 operator / acceptance reviewer 明確記錄：shipped deny boundary 的 remote gate、只能 local 驗證的正向分支、
以及 immutable race fixture 的可接受保留方式；若不接受此 coverage，相關 smoke gate 保持 pending。
這是驗證方法與授權的缺口，不重新開啟產品四項決策，不把完整 Epic8/9/CMS/課程素材建置變成 E7 schema 部署 blocker。

執行前須重新 review harness 與 ValidateOnly、完整 migration manifest、target/role、BR、時間窗、
所有 fixture writes、rollback failure handling、獨立 residue 查詢；任一不符就停止該案例及其依賴。
只有已批准的案例有真實 artifact 且 residue 完整 reconciliation 後，才評估 remote closure；
不得單憑此計畫或舊 LOCAL PASS 將 Epic7 標為 REMOTE CLOSED。
