# Epic7-F Independent Preflight & Deployment Linkage Evidence

前輪稽核：**COMPLETE WITH WARN / EVIDENCE GAPS**。正式執行：**NOT READY / NOT AUTHORIZED**。
後續本機工具、演練、版本重現與恢復準備見 [本機工具證據](EPIC7_F_LOCAL_TOOLING_EVIDENCE.md)。
下列數值保留前輪的查證時間，不冒稱本輪重新查閱遠端。
查證日期：2026-09-06；時間基準為 UTC，彙整快照 `2026-09-06T13:34:25Z`。
這是本輪唯讀及靜態稽核紀錄，不是部署、backup、smoke 或 cleanup 授權。

## 1. 基線與證據來源

| 項目 | 本輪結果 |
| --- | --- |
| Branch | `main` |
| 候選 HEAD | `d5f98434106797afc65c59953aa3bc61ba26ecb4` |
| 本機 origin/main 參照 | `588811d1d5617788b162f4e0a275d64d6a248dce` |
| 實際遠端 main | 同上；`git ls-remote --exit-code origin refs/heads/main` 及 GitHub branch GET 均確認 |
| ahead / behind | `5 / 0`；沒有 fetch、pull、push 或改寫歷史 |
| 進入時 working tree | CLEAN；index 無變更 |
| 本輪輸出 | 本文件及 [smoke 計畫](EPIC7_REMOTE_SMOKE_PLAN.md)，兩份未 staged 文件 |
| Repository | `github.com/theoneguitarstudio-cmd/the-one-platform`；Git remote 與 GitHub API 相符 |

依序閱讀 Current Work、Project Status、Canonical Roadmap、Product Decisions，
並核對 [Scope](EPIC7_SCOPE_DEFINITION.md)、[Local Execution](EPIC7_LOCAL_EXECUTION.md)、
[Security](SECURITY.md)、[Migration Plan](MIGRATION_PLAN.md)、
[P2 evidence](P2_REMOTE_CLOSURE_EVIDENCE.md) 與 [recovery runbook](REMOTE_BACKUP_RECOVERY_RUNBOOK.md)。
本輪結果以實際 Git、現有授權 GitHub API、Supabase CLI 2.116.0、Vercel connector、
檔案 metadata 與候選 SQL 為來源；原始工具結果留在本次任務紀錄。
沒有把秘密、backup 內容或學生資料複製進文件。

Local Execution 最後修改 commit 是候選 HEAD；其相對連結可解析，列出的 migration、
local helper、regression entry points 均存在。它是可重現入口加上既有執行紀錄，
並非每個測試都有獨立、版本化的完整 stdout artifact。本輪沒有重跑測試或 build。
既有 219 application tests、1,480 + 237 SQL assertions、六個 concurrency scenarios、
36 security predicates、Epic5/6 ValidateOnly 15/16 PASS 均保留為 **LOCAL 歷史證據**。
49 tooling tests 已包含於 219，不重複加總；D 的 75 assertions 在 E 擴為 79。

## 2. 資料庫部署與網站部署

P2 `Remote Deployment PASS` 涵蓋 **Supabase schema migration 與 Epic5/6 domain smoke**。
P2 evidence 明載 operator deployment handoff、29/29 parity、兩個 production JSON artifacts，
並將 closure 限定於 deployed schema / tested domain smoke scope。
沒有獨立 application deployment log、網站 URL、平台 project 或 release ID 可支持網站部署 PASS。
因此 P2 不能作為網站已部署或 main 自動部署的證明。

本輪正式 DB identity 已查證：`the-one-platform` / `ygxeihtcolpiulupieeq`，
`ap-southeast-1`，`ACTIVE_HEALTHY`。來源為目前 CLI `projects list`，只輸出匹配目標的 metadata；
與 `supabase/.temp/project-ref`、P2 artifacts/evidence 的 ref 相符。
既有管理憑證能讀取此目標 backup metadata 及 timed READ ONLY catalog；沒有借用其他專案憑證。

網站存在與否、實際部署平台／帳戶／project／production branch：**尚未查證**。
目前可見範圍沒有 The One 網站部署證據，不能推論網站必定不存在。

## 3. 推送連動查證範圍

| 來源 | 狀態 | 結果與可見範圍 | 剩餘限制 |
| --- | --- | --- | --- |
| Git remote / GitHub repository GET | 已查證 | owner `theoneguitarstudio-cmd`；repo `the-one-platform`；public；default branch main；現有 credential 回報 admin/push/read 權限 | 沒有測試 push |
| owner GET | 已查證 | owner type `User`，不是 Organization | 組織層 webhook 不適用於這個 owner |
| repository CI 設定 | 目前可見範圍未找到 | 無 `.github/workflows`、GitLab CI、CircleCI、Jenkinsfile、`vercel.json`、`.vercel/project.json` | 外部平台可不依賴 repo 設定檔 |
| Git hooks | 已查證 | core.hooksPath 未設定；`.git/hooks` 只有 14 個 `.sample`，沒有 active hook | 只讀取，未執行 hooks |
| GitHub Actions workflows / runs | 目前可見範圍未找到 | 兩個 GET 200、total 0；per_page=100，無下一頁；Actions enabled、allowed_actions=all | 空歷史不等於外部整合不存在 |
| repository webhooks | 目前可見範圍未找到 | hooks GET 200、空陣列、無下一頁；涵蓋此 repo 可管理 webhook | 不涵蓋 GitHub Apps 自身的 webhook |
| environments / deployments | 目前可見範圍未找到 | GET 200、空集合、無下一頁 | 外部流程不一定寫 GitHub deployment 紀錄 |
| 實際 remote main 的 checks/status | 目前可見範圍未找到 | check-runs total 0；combined status total 0 | combined state=pending 是零 status 的回應，不是已找到 pending build |
| main branch / rules | 已查證 | GET 200；protected=false；有效 branch rules 空陣列 | 只證明目前 Git 規則，不證明無 push 副作用 |
| GitHub Pages | 目前可見範圍未找到 | repository has_pages=false；Pages GET 404 | 不涵蓋其他 hosting |
| GitHub Apps | Vercel 已安裝；Repository access = All repositories（使用者提供證據） | `螢幕擷取畫面 2026-09-06 222300.png` 為 repo Settings；補充 `223229.png`、`223234.png`（同日同檔名前綴）顯示帳戶 theoneguitarstudio-cmd、Vercel 與 All repositories | 安裝與授權範圍已確認；實際 The One hosting project/repo/branch/build/auto-deploy 尚未查證，不能推論 main push 安全或網站部署狀態 |
| 現有 Vercel connector | 目前可見範圍未找到 | list_teams 只有 together-stories Project；該 team projects list 只有連到另一個 repo 的 together-stories | 未讀取／修改那個 project 詳細設定；不能當作 The One 證據，也不涵蓋未知個人/team scope |
| The One hosting repository link / branch / build override / root directory | 尚未查證 | 沒有已識別的 The One hosting project 可供查閱 | 需要 owner 指認實際 hosting project，或確認尚未建立網站部署 |

覆蓋界線是此 repository 管理 API、目前 main、此 checkout/hooks 及現有 hosting connector。
不要求證明所有未知帳戶都沒有 automation。App 安裝與 All repositories 授權已有使用者頁面證據；
剩餘精確缺口是實際 hosting project、repository/branch 連結及 main push 自動部署行為。
**main push 是否觸發 build/deployment/migration 仍未完全確定。**

## 4. 五份 migration 與不可變基線

以下 SHA-256 逐一由 `git show HEAD:<path>` 的原始 bytes 計算，並與 working file bytes 比對，全部相同。
原始 29 個 migration 的 Git blob ID 在 approved baseline 與候選 HEAD **全部相同**。
本機 SQL 檔案數 34；本輪沒有更動任何 migration。

| 檔名 | SHA-256 |
| --- | --- |
| `20260906000100_learning_course_versions.sql` | `ea13b605b7d0fc54a237ef2c901c9ccb35f41c0bb9e8e0a58af591c6ac2ac8fb` |
| `20260906000200_learning_hierarchy.sql` | `20ab7f8114f9d8d1b352275494b8f31f5c6151ab1cb8df8b587dbee8a75e2a55` |
| `20260906000300_learning_content_freeze.sql` | `9e5c2253bbcafce4661ab5ae6f5017866a07a320fe02b206b32c91785db1c2f8` |
| `20260906000400_learning_self_activity.sql` | `64d9d2eeed9f049f1e129552c1261457ed70404ba70e57cb02e57456ec555af0` |
| `20260906000500_learning_freeze_graph_validation.sql` | `89c671af5ba816029f4d2de8a6e8a6c222e8de69589d6dd70026b117d965d103` |

SQL 路徑為 `supabase/migrations/`。本輪逐份讀取實際 SQL，結論如下。

| Migration | 實際操作與完整性 | 相依與風險 |
| --- | --- | --- |
| 001 | 新 Course/Map/publication；唯一 course slug、同 course/map 複合 FK、每 map 一個 draft；Admin 建立 RPC 與 audit append | public/private、auth.users(id)、auth.uid、app_role、active/role helpers、audit_logs；course advisory lock、map row lock |
| 002 | 新穩定 Level/Module/Node 與 version placements、receipts；相同 course/publication/parent；正數且唯一 sibling order；draft revision/idempotency | 001；draft row lock；deferred unique constraints 在 RPC 返回前恢復 immediate；兩個既有 whitespace WARN 保留 |
| 003 | 新 Resources/revisions、Objectives、Skills、contributors/credits、advisory prerequisites、capability descriptors；完整 freeze | DROP 的是 001 新表 state CHECK，再加入 draft/frozen CHECK 及 freeze stamps；沒有 DROP 舊表。每 Node >=1 Objective、>=1 Resource；可全 text。DAG edits/freeze 使用同一 draft lock |
| 004 | 新 self activity/requests；既有使用權限缺席時 fail closed；Admin minimal inspection；Course retention trigger | auth.users、同版本 Node/Resource FK；course FOR SHARE、subject advisory lock、activity row lock；只有個人 self-report，無商業或正式成果寫入 |
| 005 | 新 private freeze graph trigger，freeze 當下重新查整張 DAG | 003 publication/edges；遞迴 UNION 終止循環查找；沒有取代舊域函式或放寬授權 |

- 五份各自 `BEGIN/COMMIT`，不是跨五檔的單一交易。中途失敗不能假設前檔已回滾；
  依 runbook 的 R1/R2 保留證據、停止、新 forward-fix，不 repair/reset。
- 沒有 migration-time backfill、舊 Stage rekey、商業資料轉換、TRUNCATE 或 DELETE 舊資料。
  RPC body 的 INSERT/UPDATE 是將來呼叫時的行為；DELETE trigger 分支及 ON DELETE RESTRICT
  是保護契約，不能誤報成部署時刪除。ALTER TABLE 作用於這五份新建的 Epic7 表。
- 新 24 表全部 RLS，raw privileges 對 PUBLIC/anon/authenticated/service_role 全撤銷。
  八個 public SECURITY DEFINER RPC 明確 postgres owner、空 search_path、只 grant authenticated；
  12 個 private helper/trigger functions 無 application EXECUTE，為 invoker 且空 search_path。
  private function owner 取決於 deployment session；目前查閱角色為 postgres，實際 rollout 仍須核對執行角色。
- service_role 的 BYPASSRLS 不等於 SQL table/EXECUTE grant；這條新鏈沒有給它 raw writer。
  Teacher 或 contributor attribution 不產生建構、使用、營收、review 或 assessment 權限。
- composite FKs 阻擋跨課程／版本引用；activity 的 subject 只取 auth.uid()，不存在可代填學生的參數。
  receipt 綁 actor/key/payload/revision；開啟、Self Complete、Skills/capabilities 都不寫正式成果。
- frozen publication、關係與穩定 metadata/revisions 有不可變／保留 guards；V2 不重綁 V1。
  外部 provider_ref 是 descriptor，不能宣稱外部媒體 bytes 因此永遠不變。
- CREATE FK 會觸及既有 auth.users 的鎖；新表 ALTER/索引建構及 event triggers 也有 DDL 鎖與執行成本。
  大 DAG 的 reachability 可能昂貴。既有本機六種 race PASS 不是正式流量／鎖等待測量。
  未進行 production lock probe、DDL dry run 或負載測試；將來 rollout 需有時間窗與 bounded timeout 決策。

## 5. 本輪遠端唯讀結果

在 identity/API access 確認後，使用已安裝 CLI 的 `db query --linked --project-ref ygxeihtcolpiulupieeq`。
SQL 僅含 `BEGIN READ ONLY`、`SET LOCAL statement_timeout='10s'`、部分加 `lock_timeout='3s'`、
bounded SELECT 與 `ROLLBACK`。驗證回應明示 `transaction_read_only=on`，query_role=postgres。
未讀取學生資料、未呼叫業務 RPC。CLI 印出 `Initialising login role...`，屬連線管理訊息；
沒有提交 DDL/DML，也不以 SQL 結果推論供應商內部連線機制完全沒有 metadata 副作用。
一次 multiline CLI argument 返回空 rows，未用它作 PASS 證據；改成單行等義 readonly SQL 後取得下列結果。

| 項目 | 已查證結果 |
| --- | --- |
| Migration history | 29 IDs；latest `20260904001100` |
| 比對本機 34 IDs | local-only 5，恰為上列 001–005；remote-only 0；既有 29 IDs 完全相符 |
| PostgreSQL | 17.6；支援此鏈使用的 `UNIQUE NULLS NOT DISTINCT`；所需內建 UUID/hash/advisory functions 均存在 |
| Schemas | public/private/auth 存在；目前 postgres 有 public/private CREATE，沒有 auth CREATE（此鏈不需要） |
| Roles | postgres、anon、authenticated、service_role 存在；app_role 為 student/teacher/admin/super_admin |
| Core dependencies | auth.users PK(id)、auth.uid()、private.current_user_is_active()、private.current_user_has_role(app_role[]) 存在；必要 EXECUTE、auth.users REFERENCES、audit_logs INSERT 對目前角色為 true |
| Audit shape | actor_user_id/action/target_type/target_id/after_snapshot 等欄位與型別相符；id、before/after snapshots、created_at defaults 存在；未找到 audit table user triggers；沒有因此給予 cleanup 刪除權 |
| New namespace collision | SQL 抽取的 24 table names、20 function names，catalog 同名數都為 0 |
| Extensions | plpgsql、pg_stat_statements、uuid-ossp、pgcrypto、supabase_vault、btree_gist；未建立或更改 extension |
| Existing RLS event hook | ensure_rls / ddl_command_end / enabled O / exact CREATE TABLE, CREATE TABLE AS, SELECT INTO；rls_auto_enable()、event_trigger、postgres、只 search_path=pg_catalog，符合既有窄例外 |

Legacy `learning_map_stages` 的 **全部 referencing FK catalog rows 恰為四筆，均 validated**：

| Table.column | ON DELETE |
| --- | --- |
| teacher_stage_capabilities.stage_number | RESTRICT |
| student_profiles.current_stage | SET NULL |
| lesson_records.stage_number | SET NULL |
| assessments.primary_stage | SET NULL |

沒有額外 referencing FK。這是 metadata 相容性 PASS，不是 remote migration apply PASS，
也不是既有資料內容／全部 schema 漂移／production load 的完整證明。
Local populated 29→34 的 13 份完整 row snapshots 不變仍為既有本機回歸證據。

## 6. 建置證據分開判讀

| 項目 | 結果與適用範圍 |
| --- | --- |
| Next | package.json、pnpm-lock.yaml、已安裝 package 都是 16.3.3；installed engines Node >=20.9.0 |
| 本輪工具 | Node 24.19.0；PATH pnpm 11.19.0；packageManager 宣告 pnpm 10.34.5，不把兩者混為同版 |
| Scripts | build=`next build`；dev/start/lint/typecheck/test；沒有 prebuild/postbuild |
| 設定 | next.config.ts 為空設定；沒有 .nvmrc/.node-version/.npmrc；pnpm-workspace.yaml 記錄 ignoredBuiltDependencies sharp/unrs-resolver，未改動 |
| 版本相符的 CLI guide | 已安裝 Next 16.3.3 的 `node_modules/next/dist/docs/01-app/03-api-reference/06-cli/next.md`：build 預設 Turbopack，`--webpack` 為另一條命令 |
| 既有 Webpack | `node node_modules/next/dist/bin/next build --webpack`；本機 Windows，既有 E 紀錄 PASS / 31 static pages；.next/BUILD_ID mtime 2026-09-06 12:39:59 UTC、diagnostics 已到 static-generation |
| Build 與 commit | 既有 E gate 在 D commit `3f0072b...` 加 E 工作內容時執行，再由候選 HEAD 收錄。D→HEAD 的 src/package/lock/next.config 比對只有 learning-map README；無 application/build-source 差異。不是本輪對 clean d5f checkout 的新 build |
| Webpack log 限制 | repository 沒有獨立完整 stdout artifact；Local Execution 是版本化結果紀錄，.next 只佐證輸出存在；當時 Node/pnpm exact version 未記錄在該文件，不能倒推為本輪版本 |
| 既有 Turbopack | 同 build command 移除 --webpack；Windows worker spawn OS error 5，sandbox 與提升權限 retry 都失敗；不是 application 語意失敗的證明 |
| Turbopack logs | `%LOCALAPPDATA%/Temp/next-panic-b4d2fda890759718c062f31afe18b060.log` (12:37:20 UTC) 與 `next-panic-cce29e06210d5b2fe9bf5426e9c2d1d3.log` (12:38:49 UTC)，各 1542 bytes；globals.css → node pooled process → access denied |
| 正式平台 command/root/Node/install override | 尚未查證；也沒有正式平台相容性 PASS |

本輪不 rerun build，不讀取或輸出 .env 值，不改 scripts/依賴/設定。
後續若需補測，先界定離線或隔離本機 build、移除正式憑證來源並 review 最小範圍；不能用正式部署試驗。
建置缺口阻擋**網站部署**及「push 會連動網站」時的推送安全判斷，
不單獨阻擋這五份不依賴 Node build 的 DB schema migration 靜態稽核。

## 7. BR-1 / BR-2 / BR-3：當次 readiness 未全數通過

API 本輪回應 `backups:null`、`physical_backup_data:{}`、`pitr_enabled:false`、`walg_enabled:true`。
這是功能 metadata，不是可用 recovery point。只讀取外部檔名、大小、mtime；沒有 dump/hash backup 內容或匯出。
目前列舉 `C:/TheOneBackups` 既有日期子目錄，最新三件套仍是：
`C:/TheOneBackups/2026-09-05-pre-epic6-smoke`。

| File | Bytes | Last write UTC | 至彙整快照約略年齡 |
| --- | ---: | --- | --- |
| roles.sql | 370 | 2026-09-05 14:37:16.128 | 22h57m |
| schema.sql | 550007 | 2026-09-05 14:38:27.116 | 22h56m |
| data-public.sql | 6914 | 2026-09-05 14:39:01.210 | 22h55m |

| Gate | 本次判定 | 原因／解除條件 |
| --- | --- | --- |
| BR-1 | UNKNOWN / 不可視為 PASS | P2 明確接受過 verified logical restore handoff，檔案也仍存在；本輪未取得可重用的具名 drill/target record、加密儲存證據及當次 scope 適用性。依現行 runbook，單靠檔案 metadata 不足證明目前 usable path |
| BR-2 | 24h 年齡檢查目前 PASS；release gate 尚未確立 | 此 additive chain 不轉換資料或 financial invariants；最舊檔於 2026-09-06 14:37:16 UTC 達 24h。significant writes/RPO 的當次條件未有紀錄；若需 1h，現有檔案不合格。實際 execution time 必須重驗，不能沿用快照 |
| BR-3 | UNKNOWN / 不可視為 PASS | P2 的 operational restore PASS 是歷史 handoff；repo 未找到 completed recovery template，缺當次具名 operator、已驗證 destination、覆寫/新 project、downtime/write freeze、traffic/Auth/Storage/其他服務及 release compatibility 處理 |

依 runbook，UNKNOWN 是 remote deployment STOP gate；這不重開 Epic5/6 closure。
若既有 restore evidence 足夠，應提供其**非秘密 metadata**給本輪復用審查，而不是要求重跑 destructive restore。
若需要新 backup，後續須另授權對此 exact linked target 執行既有三個 logical dump 操作：
`db dump --linked --role-only -f <external>/roles.sql`、
`db dump --linked -f <external>/schema.sql`、
`db dump --linked --data-only --schema public -f <external>/data-public.sql`。
這會讀取／匯出正式 DB 並在已核准加密外部位置寫檔，本輪**未執行**；Auth data/Storage 等 scope 缺口須先記錄，
不能把 public-only dump 宣稱全平台 recovery。若非正式 restore 驗證確實不足，另提已命名隔離 recovery target、
操作角色及涵蓋範圍的授權；不能自行 restore 至任何目標。

## 8. Smoke、格式與 action-specific readiness

[Epic7 Remote Smoke Plan](EPIC7_REMOTE_SMOKE_PLAN.md) 是設計，全部案例 **NOT RUN**。
使用現有八個 RPC 與資料模型；不新增 business API。production 不能複製 local fixture 的 policy replacement。
rollback-only、committed race fixtures、expected retained evidence 與 unexpected residue 分開。
缺獨立 remote harness/ValidateOnly、race retention 核准與 deny-only progress acceptance 記錄，
因此計畫完成不等於 remote smoke 技術齊備。

| 檢查 | 結果 |
| --- | --- |
| working diff `git diff --check` | PASS；新文件另做含 untracked 內容的 whitespace/conflict check |
| staged `git diff --cached --check` | PASS，index 空 |
| `git diff --check 588811d..d5f9843` 完整範圍 | WARN / command exit 2，僅 002 lines 47/54 trailing whitespace；未調規則或改 migration |
| 文件相對檔案連結 | PASS，26 個 relative-file targets（本輪兩份文件與 Local Execution）；不把未查外部 URL/anchor 當作 link PASS |
| 授權差異 | 僅兩份本輪文件，沒有 source/migration/config/product decision/index 變更 |

| 動作 | 技術條件是否齊備 | 精確缺口 |
| --- | --- | --- |
| Git push | **NO（機械 Git 條件符合）** | main fast-forward、push permission 與 branch rules 可讀，但 Apps/hosting 連動尚未封閉；不執行試推 |
| DB migration | **NO** | candidate/remote dependencies 已查；BR-1/3、當次 BR-2、具名 rollout/recovery record 尚缺。與網站 build 無直接相依 |
| Application deployment | **NO** | 實際 hosting/project/release/root/branch/build/install/Node overrides 未確認；缺相符平台 build evidence |
| Remote smoke | **NO** | 未部署 Epic7 schema；缺 reviewed remote harness/ValidateOnly、fixture/retention contract、progress boundary acceptance；BR 與執行授權未齊 |

最小 operator action（不索取 token/密碼/key，不要求手動除錯）：

1. Vercel App 安裝與 All repositories 授權範圍均已有使用者提供的頁面證據；
   不再要求查同一 GitHub 授權頁面，不需另外證明所有未知帳戶不存在 automation。
2. 若 The One 已有網站，指認實際 hosting 帳戶/team/project，提供該 project 的 Git linkage、production branch、
   root/build/install/Node 設定及 deployment metadata 唯讀存取；若尚未部署，記錄這個範圍事實。
   現有 together-stories connector 無此目標，不能替代。不要建立或 link 新 project。
3. 指認現有 P2 非秘密 recovery/drill record 與具名 operator，完成當次 recovery template 的缺欄；
   如需補 backup/drill，下一輪另授權其 exact target/scope。Supabase ref/name/parity/catalog 查證本輪已由工具完成，**不需要 operator 重跑**。

本輪實際授權及執行：PUSH=NO；REMOTE MIGRATION=NO；APPLICATION DEPLOYMENT=NO；
REMOTE SMOKE/CLEANUP=NO；BACKUP EXPORT/RESTORE=NO；STAGE/COMMIT=NO。
Epic7 A–E 保持 LOCAL CLOSED，既有 WARN 不隱藏；F remote closure 尚未成立。
Epic5/Epic6 REMOTE CLOSED；production payment-provider webhook **NOT COMPLETE**，不回升為 Epic5/6 blocker。
未改 Product Decisions／Epic 編號、未開始 Epic8–13。完成本輪後 STOP，等待分項授權。
