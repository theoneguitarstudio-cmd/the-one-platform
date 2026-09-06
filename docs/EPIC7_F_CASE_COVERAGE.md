# Epic7-F 37 案例覆蓋對照

候選 `d5f98434106797afc65c59953aa3bc61ba26ecb4`；本輪未提交工具，版本 hash 見 [manifest](EPIC7_F_TOOLING_MANIFEST.json)。

案例 ID 與原 [smoke plan](EPIC7_REMOTE_SMOKE_PLAN.md) 一致，未刪除或重編。LOCAL PASS 指對應已實際執行的本機 suite/assertions 或 catalog 證據；不代表原計畫的 production harness 已執行。詳細前置／操作／證據／保留規則仍以原計畫逐案文字為準。

狀態：所有 REMOTE NOT RUN；沒有 DEFERRED BY APPROVED CONTRACT，沒有虛構核准。沒有 NOT APPLICABLE 來抹去案例。P04/P05/P06/R04 的正向正式分支 BLOCKED；其他正式分支仍需 G0。早期工具 timeout 的 LOCAL FAIL 保留在 evidence，不計為 PASS。

本機腳本入口固定為 `node scripts/epic7-readiness-rehearse.mjs --create-isolated --epic7` 或 `--legacy`；工具自行建立並銷毀本輪 network-none target，不能傳入 production URL。

| ID | 驗證目的 | LOCAL 證據／狀態 | REMOTE 方法／狀態 | 角色 | 需提交 | 不可變保留 | 額外核准 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S01 | 唯讀 operator 查 24 表 RLS/raw grants、8 public/12 private functions、owner/search_path；完全符合候選 | [source](../scripts/epic7-database-review.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; catalog exact signature/ACL diff，含原有窄 rls_auto_enable 例外；REMOTE NOT RUN | 唯讀 | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| S02 | anon/authenticated/service_role 嘗試 raw SELECT/DML 及 private EXECUTE，均拒絕；TRUNCATE 僅查 privilege metadata 應為 false，不實際執行；不能把 bypassrls 當 grants | [source](../scripts/epic7-readiness-effects.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; permission result 與零 changed rows；TRUNCATE privilege=false；REMOTE NOT RUN | anon/authenticated/service_role | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| S03 | Teacher、Creator、Student、inactive Admin、移除角色 Admin 呼叫建構/inspection，拒絕；active Admin/Super Admin 成功 | [source](../scripts/epic7-database-review.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; 角色矩陣、SQLSTATE、scope digest；REMOTE NOT RUN | Teacher、Creator、Student、inactive | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| S04 | Admin inspection 不含 provider_ref、content body、linked Auth IDs、learner data 或 delivery token | [source](../scripts/epic7-database-review.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; DTO key allowlist；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| H01 | Admin create_course/create_draft/put_structure；階層正確、沒有硬編碼 5/6 Levels 或 Teacher owner | [source](../supabase/tests/database/learning_structure.test.sql)；LOCAL PASS | G0 + reviewed RPC/catalog harness; minimal hierarchy JSON、course scoped identities；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| H02 | Admin 跨 course/map/version parent、Node/reference 混用，拒絕 | [source](../supabase/tests/database/learning_structure.test.sql)；LOCAL PASS | G0 + reviewed RPC/catalog harness; exact FK/domain errors；原結構 digest 不變；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| H03 | Admin 合法 reorder 成功；重複/非正 position 拒絕 | [source](../supabase/tests/database/learning_structure.test.sql)；LOCAL PASS | G0 + reviewed RPC/catalog harness; order/revision、失敗前後 digest；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| H04 | Admin 再建立不同 draft 拒絕；exact create retry 不重複；不同 actor/payload identity retry 拒絕 | [source](../supabase/tests/database/learning_structure.test.sql)；LOCAL PASS | G0 + reviewed RPC/catalog harness; publication/map/audit scoped counts；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| H05 | Admin exact retry 返回同 revision；同 key 不同 payload、stale revision 拒絕 | [source](../supabase/tests/database/learning_structure.test.sql)；LOCAL PASS | G0 + reviewed RPC/catalog harness; receipt scope、revision、audit count 不重複；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| C01 | Admin 保存 0 Resource draft 成功；尚未宣稱 publish-ready | [source](../scripts/epic7-content.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; draft inspection/counts；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| C02 | Admin freeze 拒絕 incomplete_curriculum，無 partial state/receipt/audit | [source](../scripts/epic7-content.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; freeze前後三類 digest；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| C03 | Admin freeze 同樣拒絕缺 Objective | [source](../scripts/epic7-content.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; 相同 rollback 斷言；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| C04 | Admin freeze 成功；無影片/PDF/audio 固定組合要求 | [source](../scripts/epic7-content.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; frozen stamps、Node minimum counts；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| C05 | Admin 同課程 revision 重用、多連結排序/用途有效；跨課程 resource revision 拒絕 | [source](../scripts/epic7-content.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; exact node/version/resource links；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| C06 | Admin 同 course/node Objective binding；shared Skill 可跨課程語意重用，既有 Skill definition 改寫拒絕 | [source](../scripts/epic7-content.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; mapping IDs、definition digest；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| C07 | Admin 建立 credit snapshot 成功；署名者自身不取得 construction/use/revenue 權限 | [source](../scripts/epic7-content.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; credit display snapshot、negative role results、無商業寫入；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| C08 | Admin 建立四種已支援 code 的 metadata；非法 result/reviewer/quota 欄位拒絕；descriptor 不產生 review/assessment/eligibility | [source](../scripts/epic7-content.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; payload key validation、無 workflow/formal rows；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| G01 | Admin 保存 advisory edges 成功；自環、多節 cycle、跨 version/course edges 拒絕 | [source](../scripts/epic7-closure.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; edges digest、cycle error；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| G02 | Admin freeze 完整 hierarchy/DAG 成功；空 Level/Module/缺 Node 版本拒絕 | [source](../scripts/epic7-closure.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; structural completeness、原子 revision/receipt；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| G03 | Admin freeze 後圖保持 acyclic；005 trigger存在，local corruption test已有證據 | [source](../scripts/epic7-closure.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; catalog trigger binding + 正常 freeze 結果；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| V01 | Admin RPC 再改 V1 拒絕；exact freeze retry 仍回原結果；app direct INSERT/UPDATE/DELETE 拒絕 | [source](../scripts/epic7-closure.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; state/rows/revisions/receipts 不變；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| V02 | Admin 建立不同標題/placement/new resource revision 後 freeze；V1 與 V2 各自可 inspection、舊引用不重綁 | [source](../scripts/epic7-closure.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; V1 before/after digest 與 V2 差異；REMOTE NOT RUN | Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| P01 | active Student get/set 均 course_use_denied；沒有 recommended/unjoined 的 0% map 或 activity | [source](../scripts/epic7-progress.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; 兩個 RPC result、activity/request 0；REMOTE NOT RUN | active | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| P02 | Student 提交其他 subject／formal outcome 欄位或取其他學生資料，不能越權；目前會先被 course-use gate 擋住 | [source](../scripts/epic7-progress.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; denied/no writes；下游 field validator 未 remote 覆蓋的標記；REMOTE NOT RUN | Student | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| P03 | Teacher/Creator/Admin 非 Student role、inactive/role-loss Student 使用 progress，拒絕；service_role 無 EXECUTE | [source](../scripts/epic7-progress.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; student_required 或 permission error；zero write；REMOTE NOT RUN | Teacher/Creator/Admin | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| P04 | owner Student opened/resume/revisit/Self Complete set/clear 成功，opening 不自動 complete；沒有觀看或 advisory 強制門檻 | [source](../scripts/epic7-progress.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; owner/version/Node resource/revision/result；REMOTE NOT RUN / BLOCKED（真實 authority 缺席） | owner | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| P05 | 跨學生／課程／版本／Node resource 拒絕，V2 不複製或覆寫 V1；lost eligibility/history retained | [source](../scripts/epic7-progress.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; exact owner DTO、before/after digest；REMOTE NOT RUN / BLOCKED（真實 authority 缺席） | 跨學生／課程／版本／Node | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| P06 | 所有 Nodes 自報完成仍不產生 VERIFIED/mastery/assessment/certificate/legacy Stage completion | [source](../scripts/epic7-progress.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; formal domain scoped counts/digests 不變；REMOTE NOT RUN / BLOCKED（真實 authority 缺席） | 所有 | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| R01 | 兩 Admin sessions 反向 DAG edges 競爭；序列化後 cycle/stale 一方拒絕，最終 acyclic | [source](../scripts/epic7-concurrency.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; session timing、commits/errors、graph/revision；REMOTE NOT RUN | 兩 | 是，僅本機演練 | C：需核准 manifest | 是，未核准 |
| R02 | 兩 sessions 同 freeze retry；一致 revision，只有一次成功 transition/receipt/audit | [source](../scripts/epic7-concurrency.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; independent sessions、unique scoped receipt；REMOTE NOT RUN | 兩 | 是，僅本機演練 | C：需核准 manifest | 是，未核准 |
| R03 | freeze vs edit 競爭；無 half freeze，stale/immutable 拒絕、合法結果一致 | [source](../scripts/epic7-concurrency.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; lock ordering、final immutable digest；REMOTE NOT RUN | freeze | 是，僅本機演練 | C：需核准 manifest | 是，未核准 |
| R04 | 競爭首次 activity writes，exact old retry after correction，跨 Node 相同 request key race | [source](../scripts/epic7-progress-concurrency.regression.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; 三種 session outcomes、receipt/revision/no overwrite；REMOTE NOT RUN / BLOCKED（真實 authority 缺席） | 競爭首次 | 是，僅本機演練 | C：需核准 manifest | 是，未核准 |
| L01 | 既有 Teacher discovery/capability/1–5 Stage 與 Trial participant/assessment 邊界回歸，不映射新 Levels | [source](../scripts/epic7-local-db.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; old FK definitions + synthetic behavior、privacy assertions；REMOTE NOT RUN | 既有 | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| L02 | 既有 Commerce checkout/payment boundary/idempotency 回歸；不呼叫真 payment provider | [source](../scripts/epic7-local-db.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; existing assertions、order/payment/audit transactional evidence；REMOTE NOT RUN | 既有 | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| L03 | 既有 Entitlement fulfillment/reserve/consume/release、service authority 與 ledger append-only 回歸 | [source](../scripts/epic7-local-db.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; approved Epic5 case matrix/residue categories；REMOTE NOT RUN | 既有 | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| L04 | 既有 Scheduling booking/cancel/reschedule/fixed/flexible/Makeup/lock 回歸 | [source](../scripts/epic7-local-db.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; approved Epic6 matrix與transaction evidence；REMOTE NOT RUN | 既有 | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |
| L05 | independent readonly observer 查 manifest/all touched tables/actors/audit，分類 operational、expected retained immutable、unexpected；核對legacy未變 | [source](../scripts/epic7-local-db.mjs)；LOCAL PASS | G0 + reviewed RPC/catalog harness; signed-off manifest、zero unexpected、exact retained inventory；REMOTE NOT RUN | independent | 否，rollback-only／唯讀 | R：回滾後不得有未預期存留 | 是，未核准 |

## 證據與完整性限制

- 最終 Epic7 run：`epic7-f-local-d504bec278231e3310de221033fd4b06`，23 structure + 29 lock + 237 existing Epic7 + 19 new runtime assertions，六種 independent-session races，以及 94 個 public/auth table count/digest 回滾比對。
- Legacy run：`epic7-f-local-a5fda7855a60095c32e912e07db7672a`，39 suites / 1480 assertions；L01–L04 對應其中 Teacher/Trial/Commerce/Entitlement/Scheduling suite，不是重跑 production Epic5/6 smoke。Legacy run 的 observer 是當時六個關鍵表 count；完整 94-table digest observer 在最終 Epic7 run 驗證，不混為同一次結果。
- L05 的獨立 observer 與 committed manifest 以最終 Epic7 run 為本機證據；原計畫的正式 release 後 reconciliation 未執行。
- P04/P05/P06/R04 沿用已核准 local fixture contract，授權 stub 只存在新 synthetic container／rollback transaction，恢復 shipped false 後再做 security review；不直接用 superuser 寫進度冒充 Student。Production 不允許套用這個 fixture。
- G03 的 corrupted graph guard 是既有 local-only corruption regression，不能搬到 production；正式僅 catalog binding + 正常 freeze 路徑。
- H/C/V 複合目的由 structure/content/closure 三套共同支持，不以單一 source 連結宣稱每個排列組合都被窮舉。S03 亦由 progress role-loss/inactive tests 支持；S02 補新 runtime role denials。
- 實際 source 類別與逐案 sequence/trigger/transaction/lock/API 風險宣告在 [machine manifest](../scripts/epic7-readiness-cases.json)。

## 保存後驗收草案（NOT APPROVED；不改37案原要求）

歷史版本：application/migrations d5f9843；上述最終local run及工具manifest原bytes保存於c61cdb6。
本節只有分支分析/待審條款，所有REMOTE仍NOT RUN；原表LOCAL PASS不是混合案例每一正式分支已驗證。
正式拒絕分支目前也沒有新執行證據。case ID的R前綴代表race案例，不等於資料處置R（rollback-only）；
R01–R04的跨session fixture屬C（committed）。

| 案例/分支 | 原要求及正式仍應驗證 | 本機證據/版本 | 合法前置與目前阻礙 | 提案處理/實際結果/approval |
| --- | --- | --- | --- | --- |
| P04 denial | 無course-use authority時get/set拒絕、activity/request零寫入；不可冒稱opened成功 | d5 + preserved tools progress regression拒絕分支 | G0、reviewed actors/harness；目前G0未成立 | 第一期正式查拒絕與零影響，與P01共享證據需註明；REMOTE NOT RUN / NOT APPROVED |
| P04 success | opened/resume/revisit/self-complete set/clear；opening不自動complete、advisory非強制 | 同版本synthetic authority + authenticated Student RPC；LOCAL PASS | 真實approved authority；候選false，成功分支BLOCKED | 第二期在真實authority接通且學生開放前補驗；現在NOT RUN / NOT APPROVED |
| P05 denial | 無authority／失去資格須拒絕、不泄漏/改寫他人資料；不能以早期deny證明下游scope validator | local progress ownership/eligibility fixtures；LOCAL PASS | G0；正式可驗early deny，但合法success上下文缺 | 第一期只報已到達拒絕；REMOTE NOT RUN / NOT APPROVED |
| P05 authorized scope/history | 兩Student、兩Course、V1/V2與Node/resource隔離；資格喪失history保留 | 同版本synthetic正向與version isolation；LOCAL PASS | approved eligible→lost lifecycle及history fixture，未具備 | 第二期補跨subject/course/version、V1不重綁、lost-history；NOT RUN / NOT APPROVED |
| P06 denial | deny-only操作不得產生formal-domain rows；不是成功self-complete後的語意證明 | local denied writes及formal domain checks | G0；早期deny不能到達all-completed狀態 | 第一期可記零formal影響；REMOTE NOT RUN / NOT APPROVED |
| P06 completed semantics | all Nodes self-complete後仍無VERIFIED/mastery/assessment/certificate/legacy Stage completion | local authorized fixture全部Nodes完成後assertions；LOCAL PASS | P04 success與完整Node fixture，未具備 | 第二期必驗formal counts/digests不變；NOT RUN / NOT APPROVED |
| R04 denied concurrent calls | 同時denied get/set不能繞過authority、不能留下activity/receipt | 既有local負向與race是分開證據；未聲稱專門remote denied-race已跑 | G0 + reviewed multi-session harness；尚需工程實作此分支 | 第一期提案，不能替代正向race；REMOTE NOT RUN / NOT APPROVED |
| R04 successful races | 首次競爭寫入、correction後old retry、跨Node同key；receipt/revision/no overwrite | d5 progress-concurrency三情境LOCAL PASS，local stub才可到達 | 真實authority + C retained manifest；皆未核准 | 第二期學生開放前補驗全部三情境；NOT RUN / NOT APPROVED |

分期條款草案：Phase 1僅可接受明確列出的shipped deny-only正式結果與local-only成功分支證據作為
「有限範圍驗證紀錄」，不自動滿足完整Epic7 REMOTE CLOSED。原scope未授權此替代；若reviewer要用它
支持結案，須另審最小修訂：逐列原AC/缺失分支、證據接受範圍、補驗責任與禁止學生開放的release gate。
本文件不覆蓋scope或先行核准修訂；未接受則完整closure維持pending。
Phase 2觸發：任何真實course-use authority整合，或準備向學生開放get/set activity，以較早者為準。
Codex/工程負責上述P04成功、P05隔離及lost-history、P06語意、R04三race與相關拒絕回歸；
產品/驗收負責人批准coverage，release owner驗證全部指定artifact及residue後才可開放。具名負責人待填。
這不授權Epic8 implementation，也不取消其獨立scope/權限審查。

## C類fixture與保留條款草案（NOT APPROVED）

R01 shared draft、R02 freeze retry、R03 freeze/edit、R04 activity races都需要已提交、跨session可見的
基礎fixture；獨立連線不能讀另一transaction未提交資料。各race的成功transaction也會commit。
下面是**一次完整四案run的待審總上限**，不是已存在正式資料數量、不是執行授權或已實作的enforced budget。
executor須在寫入前展開逐表預算與expected delta；不能符合上限就先改提案送審，不自動加量。

| 表/種類 | 一次run提議上限 | 依賴/保留 |
| --- | ---: | --- |
| auth.users / profiles / user_roles | 12 / 12 / 24 | 合成actors；按實際approved角色最小化；不得刪actor造成audit/FK破壞 |
| system_courses / learning_maps / curriculum_publications | 2 / 2 / 4 | 每課程map、V1/V2，不當作課程發佈授權 |
| curriculum_stages / learning_modules / learning_nodes | 4 / 6 / 8 | stable identities，version references保存 |
| curriculum_stage_versions / learning_module_versions / learning_node_versions | 8 / 12 / 16 | frozen placements不可承諾刪除 |
| learning_resources / learning_resource_versions / learning_node_resources | 10 / 20 / 40 | descriptor不呼叫外部provider，無真媒體/secret |
| learning_objectives / learning_objective_versions / learning_objective_skills | 8 / 16 / 16 | 每frozen Node至少Objective/Resource；不固定媒體組合 |
| learning_skills / content_contributors / learning_author_credits | 4 / 4 / 16 | shared語意/署名，不授予權限 |
| learning_capabilities / learning_node_capability_attachments / learning_node_prerequisites | 8 / 16 / 16 | metadata/DAG；不能產生workflow或eligibility |
| learning_mutation_receipts / audit_logs | 64 / 64 | 只計本run新增；exact retry不增加；append-only evidence保留 |
| learning_self_activity / learning_activity_requests | 16 / 32 | R04真實authority前置；owner/version/request identity不可混用 |
| 其他舊域資料 | 0新增/0變更 | baseline seeds不計新增；任何未列寫入先STOP，不借用業務真資料 |

工程須用UUID隨機分配器產生未執行run manifest：run-id、每個actor/course/map/publication/node/resource/
request UUID、表/角色/用途/版本、case歸屬、expected counts/digests、上限、保留分類；查collision只可在另授權
唯讀前置階段，collision則重送manifest而非覆寫。owner核准manifest hash/retention/期限/存取者後才能創建。
目前正式UUID/run-id未分配，沒有正式fixture已存在的宣稱。

待選方案A：正式保留C資料。須明確接受stable/frozen/audit/receipts及actor依賴長期存在；無公共cleanup RPC，
不能承諾測後全刪；到期要合法產品/政策處置，不能owner SQL刪audit。未核准永久保留不是預設可執行方案。
待選方案B：C案例只在已核准隔離環境演練。保留LOCAL/ISOLATED證據，production concurrency coverage明示缺口；
需acceptance reviewer批准最小替代契約，不能以隔離PASS冒稱REMOTE PASS。兩方案均未選定/未核准。
Unexpected residue一律FAIL/STOP，獨立session核對全部manifest表及legacy digests，記expected immutable/
operational/unexpected；不立即DELETE/repair，不停RLS/trigger、不reset sequence。sequence/WAL/API等影響
另列，不假設rollback全消失；真實資料處置也不可借用已核准synthetic container disposal。

## 正式executor工程責任（尚未交付，不只差簽名）

須交付固定target/candidate及已部署34/latest檢查、當次BR與時間窗驗證、approved case/retention manifest
hash核對、最小actor fixture及role context、transaction sentinel/savepoint、bounded statement/lock/session
timeout、任何error停止後續依賴、rollback失敗不輸出PASS、連線關閉、獨立residue reconciliation、
case/UTC/session/SQLSTATE/digest/retained inventory artifacts、redaction與fail-closed regression。
新增budget/UUID/collision/retention方案須可被工具驗證，不能只靠文書。此工作將來需另授權，
本輪保留production固定拒絕，未新增writer；舊37IDs/原AC/所有REMOTE NOT RUN不變。
