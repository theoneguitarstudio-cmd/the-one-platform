# Epic7-F Executor 工程審查包

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

### 本次交付的精確範圍

| 元件 | 本輪交付 | 尚不能宣稱 |
| --- | --- | --- |
| schema.mjs | 固定候選、逐份 34 migration raw hashes 核對；從 source 收集 learning functions；28 表可觀測鍵定義 | 不是已部署內容證明；沒有替代原 preserved proof 或 live target attestation |
| compile.mjs | 25 個 S/H/C/G/V/P 拒絕範圍 SQL 計畫；參數 snapshot 避免後續負向 case 改到前面 payload；權限/函式矩陣、階層、內容、完整性、V2差異、角色拒絕 | 尚未經 PG 執行；原 AC 所有排列及 schema/driver 結果型別仍須真 DB 核對，fullCaseProven 永遠 false |
| R01–R03 | first-session lock barrier、兩 session 呼叫/預期結果的資料化 schedule，以及成功 winner/retry/loser 的預期保留數 | 尚無真多 session driver/barrier 證據；serial runner 固定拒絕這三案；不是 production C 許可 |
| P04/P05/P06/R04 | BLOCKED_AUTHORITY，無正向 SQL；無 replacement、enrollment、policy/grant/progress 捷徑 | 原成功/授權後分支仍未驗證，不用早期拒絕填 PASS |
| L01–L04 | 指定既有 legacy suite 與遞迴 include 的 raw source hashes，ISOLATED_ONLY | 不是新 per-run legacy fixture compiler；精確舊域預算/driver 接線仍未完成，不能把示例空 keys 說成0影響；serial runner 拒絕 |
| observe.mjs / L05 | 28 表參數化範圍查詢、public/auth inventory及整表SHA-256摘要query builder；獨立 snapshot 驗证、rollback 0殘留及隔離C exact keys/counts/兩次獨立讀取一致性 | 真正 catalog/all-table/unscoped/sequence collector尚未接線，不宣稱已讀正式94表；C核對需要另外完整未觸及範圍摘要 |
| session.mjs | begin/configure/savepoint、精確SQLSTATE/domain、row/value/DTO/逐checkpoint數量、timeout/cancel/late-connect close、rollback/close/observer錯誤保持FAIL | 真PG wire cancellation、ReadyForQuery/session role證明與實際transaction sentinel仍未驗證 |
| test-double.mjs | 程式內 branded 且方法不可替換的封閉記憶體替身；拒絕任意driver，即使caller寫ISOLATED_TEST_DOUBLE | 替身依計畫回應，**只測controller，不驗證SQL/domain或實際資料庫副作用** |
| evidence.mjs | plan/result/獨立observer/hash四檔，exclusive寫入、不覆蓋；37案compile bundle、tool hashes、大小/路徑及品牌綁定 | 無credentials/學生資料/raw driver errors；hash不是批准，Windows ACL還需實際環境驗證，不以mode 0600宣稱Windows已加密 |

### 數量、鍵與失敗條件

- 合成8個Auth身份，各自trigger產生profile與student role；另4個測試角色，使角色峰值12。
  移除4個合成身份的student role後最終角色8；這些刪除**只在未執行的隔離fixture準備計畫中**，
  不是事後清理稽核紀錄或正式角色。既有產品catalog同步trigger在新UUID無任何舊產品時才預期0影響，
  開始前碰撞與獨立全範圍核對不可省略。
- A為2 Levels / 3 Modules / 4 Nodes；B不同結構為1/1/1；V2重用stable identities但建立新resource revisions。
  Course/Draft各新增一條audit；每個新structure/content/freeze請求新增一receipt、一audit。
  相同請求重送用相同tuple去重；失敗/savepoint rollback不計新增；C winner才計新增，retry/loser不重複。
- profiles使用unique user_id、user_roles使用unique(user_id,role)，不冒稱兩者是PK；
  audit PK實際為DB產生的UUID，核對另記generated_id；預期tuple為actor/action/target/request_id。
  其餘版本關聯使用真composite identity，activity/request在shipped false下為0。
- 每個checkpoint保存預期數量與當時step index；controller讀取替身scopeCounts作比對，
  缺表、多行、少行均STOP。真正資料庫讀取方法仍須接線並驗證，不能用預期數值替代actual查詢。
- rollback模式要求全部run rows為0且整表/catalog/sequence摘要不變。
  C隔離提案要求expected keys/counts完全符合、獨立第二次snapshot相同，未觸及範圍不變；
  任何missing observer、unknown scope、殘留、cancel/rollback/close失敗保持FAIL，不DELETE/repair/reset sequence。
- 新session模型sentinel是adapter所報temporary-row before/inside/outside狀態及獨立after值；
  **本輪未產生真正PG sentinel實證**。原四檔核心的Course sentinel及其既有測試證據未改。

### 驗證與本機 artifact

- Node 24.19.0；70 PASS / 0 FAIL；ESLint exit 0。使用既有 offline tripwire，禁止network/process/env-file入口。
- 初次編譯找到race變數作用域錯誤；後續source-include regex跳脫錯誤也已修正，沒有放寬路徑檢查。
  另新增回歸測試抓住並固定payload共用變動，以及拒絕偽裝offline的driver注入。
- 最終控制流程 evidence：`artifacts/remote-smoke/epic7-local-engineering/a63b66d2-c7be-4151-acd5-1d76b706d6e9`。
- 最終37案計畫與逐檔工具hash、測試log、verification：
  `artifacts/remote-smoke/epic7-local-engineering/compiled-0ad3ffdf-9db8-4383-820f-5782f724863e`。這些ignored artifacts僅含合成內容／摘要，沒有SQL執行紀錄冒充正式結果。
- 歷史計數不改寫：原73項安全測試與先前7項policy tests沿用各自歷史紀錄，本輪新測試為70項。
  Epic7 REMOTE CLOSED=NO；coverage contract仍PROPOSED/PENDING APPROVAL。

### 下一步工程與真正阻礙

先建立可驗證的獨立本機PG runtime（本輪未啟動全機Docker），再在新隔離目標完成：
1. 從受信任內容／runtime attestation取得driver，實際SQL parameter/result映射、server timeout/cancel與session綁定。
2. 執行本輪SQL初版並修正domain斷言、trigger-generated actual inventory；完成L01–L04精確本次預算。
3. 真正rollback sentinel與獨立collector、R01–R03 lock-barrier多session、未知commit結果核對。
這些仍是工程缺件，並非宣称「只欠正式操作者簽名」。目前不請求正式讀取／備份／部署／smoke授權。


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

## 本次增量與下一步（政策已確認，工程仍有缺件）

D1–D5 已接受，正式操作仍全部 NO。保留上輪四檔安全核心與 review manifest 原 bytes；
本輪新增相鄰 [owner-policy](../tools/epic7-owner-policy.mjs) 及其針對性測試，
不加入原 executor 封閉四檔目錄、不修改 preserved 白名單、不執行原 73 tests / ValidateOnly。
此工具只是離線規劃檢查，沒有 transport、CLI 執行入口、credentials 或授權 token。
其結果不能傳成原 executor 的可信 proof，不能將 caller metadata 視為正式觀察。
原 manifest retention=PENDING / approval=NOT_APPROVED 仍正確：每次 run 的保管、期限與批准尚未存在，
不因 D4 原則接受而改為已批准。

A：本輪已完成 37 ID 分類、原 NOT RUN/未核准 deferral 一致性、1h recovery 條件與失敗邊界測試。
下一輪工程優先按原 schema 交付逐案 fixture compiler/trigger 預算與 observer query 設計、
PG session timeout/cancel/失聯狀態及可信 approval 綁定；可以先寫無連線設計與 mock，
實際 driver/獨立 PG 多 session 驗證尚未完成。不是等待使用者逐條除錯。
本輪不假稱此政策檢查補完了正式 executor，也不把純模擬升格為正式安全證明。

B：未來需唯讀取得 Supabase exact name/ref/region、當前 migration IDs/catalog/roles、
部署來源/受保護 hash 證據、可還原時點與 managed inventory，供實際 writer 綁定與恢復流程選型；
Vercel account/team/project/repo/branch/auto-deploy/build 供版本及流量切換確認。
目前連線只見 together-stories（使用者回報，非本輪再查），The One identity UNKNOWN；
不重問 GitHub App Configure、不以 push 探測。本輪沒有上述唯讀授權，不發請求。

C：backup/export、真實 restore、migration、deployment、remote smoke、
正式 committed fixture 例外、cleanup 分別需要使用者對具體計畫核准，現在 NO。
受控工具可以未來操作不等於自動批准；須記載 plan/target/candidate/case/manifest hash、
時間窗、操作人、備份條件、預期留下資料與 STOP 處置。核准人固定為使用者，
既有 runbook 的原地恢復第二位 operator 確認仍適用。

### 本次增量驗證紀錄（2026-09-07）

Node 24.19.0；只對新增 owner-policy 兩檔執行既有 offline tripwire 下的 Node test 與 ESLint。
7 tests PASS / 0 FAIL；ESLint exit 0；git diff --check PASS。37 案檢查是讀原 JSON/文件核對 ID 和分類，沒有執行案例。
原 executor 四檔／review manifest、preserved tools、application、package/lockfile、34 migrations 本輪未改。
正式 DB connections=0、正式 SQL=0、正式 write=0；未連 Vercel/Supabase、未 backup/restore/deploy/cleanup。
本次新增工具 raw SHA-256（供本機 diff 審查，不是簽核或原 preserved 證據）：

- tools/epic7-owner-policy.mjs: `09f98642483c350d4171fc2f94d5e4cddbc548e3f44675b3471e80084baa5732`
- tools/epic7-owner-policy.test.mjs: `e7a94a66aead2738f28ea144a1c2ace970de0c5c801688c347823e639170b37f`

## 歷史紀錄：以下保留本次 owner 決策之前的時點


狀態：**本機安全核心可供審查；無 production transport；正式 NOT RUN / NOT AUTHORIZED。**
本輪起點 `0af06802dbeb2fcd614d33db3e64c441fe711be4`；application/migration candidate
仍為 `d5f98434106797afc65c59953aa3bc61ba26ecb4`，保存點 c61cdb6 不变。
這是安全控制流程與格式的工程交付，並非完成37案正式SQL runner，也不是操作批准。
Epic5/6 REMOTE CLOSED、Epic7 A–E LOCAL CLOSED、Epic7 REMOTE CLOSED=NO、payment webhook NOT COMPLETE 均保持。

## 實作與信任邊界

- [contracts.mjs](../tools/epic7-executor/contracts.mjs)：固定目標、實際 preserved 驗證整合、run/版本/34 migration 與工具內容核對、合成 manifest 白名單及預算。
- [simulate.mjs](../tools/epic7-executor/simulate.mjs)：封閉的記憶體 transaction 狀態機、deadline/cancellation、停止後限定 rollback/close/observer、非秘密 artifacts。
- [reconcile.mjs](../tools/epic7-executor/reconcile.mjs)：與 writer 結果分離的前後快照核對；key、fingerprint、逐表數量、未列範圍、catalog、sequence、外部副作用。
- [safety.test.mjs](../tools/epic7-executor/safety.test.mjs)：只測本輪新功能；錯誤目標/內容/權限/預算、交易、回滾、逾時、取消、殘留、secret、證據偽造等。
- [review manifest](EPIC7_EXECUTOR_REVIEW_MANIFEST.json)：本輪四檔 raw SHA-256；審查時須從受信任的本機 commit/diff 取得。它是 review bytes identity，不是操作者簽名。

新檔放 tools/epic7-executor，因原 preserved validator 對 scripts/tests 等目錄採封閉白名單。
沒有改白名單、原驗證器、九份歷史工具、舊manifest、case JSON、application、34 migrations。
新工具**不是**c61時的SQL/build受測工具，不能沿用那時的hash或宣稱其正式測試已通過。

`proveLocalContent()` 先比對原驗證器固定 SHA-256，再直接呼叫其既有 verify()。
固定c61→d5 Git object鏈、269受保護檔案與舊raw hashes仍由原工具驗證。
整合測試只因新增executor要證明此路徑可用而執行，不重跑換機CLI或舊完整測試。
產生不可由JSON/SHA/舊receipt偽造的程序內 proof；每次模擬再查實際檔案hash及未列新增檔。
applicationHash 是保存內容的排序path→blob hash摘要，不是網站部署release證明。

本輪工具及review manifest仍是待審code信任起點；自算hash不能證明自身未遭共同竄改。
正式接線前，工程必須從經核准的commit建立唯讀固定工作副本、鎖定工具/manifest及依賴，
並重新驗 preserved內容。不得接受caller自由填的SHA、核准boolean或事後重算manifest來消除漂移。

## 目標及版本觀察契約

唯一規劃目標：The One `the-one-platform` / `ygxeihtcolpiulupieeq` / `ap-southeast-1`。
名稱、ref、region三者須精確相符。正式smoke要的是已部署**34份**且latest=`20260906000500`；
歷史29份/latest20260904001100不是現況證明，也不是可跳過的差異。handoff/main只代表本機bundle。

模擬輸入包含 source、runId、observedUTC、target、candidate、latest、完整migrations hash map、
applicationHash、historicalToolHashes、executorHashes、authority。缺項、多項、過期、未来時間、
錯run、錯target、任一版本/hash差異、非SHIPPED_FALSE一律STOP。
五分鐘僅為合成attestation的新鮮度控制，不改BR-2/RPO政策，正式時間窗須另經工程審查。

**合成輸入一律source=SYNTHETIC_ONLY。提供PRODUCTION也不能執行。**
本輪沒有live collector：正式接線須由已核准且可驗證來源的control-plane讀取確認name/ref/region；
另在實際SQL連線確認其綁定目標、DB/role/session、同時段migration history與catalog。
不能把使用者填的JSON、URL含ref、`current_database()`或另一個連線的正確回報当成實際writer identity。
遠端migration history未必包含檔案SHA：必須把exact IDs/names/catalog與已審deploy/source manifest連結，
不能宣稱catalog直接提供了原SQL檔案hash。網站release及build artifact來源也須另證明，不能只看Git SHA字串。

## 執行次序及停止行為

1. 取得實際本機proof、核對當次工具與manifest；任何錯誤尚未建立writer。
2. 核對當次attestation及案例分支，簽核/BR/時間窗的正式gate尚未接線，本輪永遠不可執行正式操作。
3. 獨立reader取得開始前快照；run UUID/key已存在或無法觀察，停止，不覆寫。
4. 開transaction；確認session/role及active狀態。合成角色只模擬authenticated，不等於真正DB角色測試。
5. 在transaction寫入manifest內的一筆合成Course作sentinel，writer讀得到，另一durable讀取路徑讀不到。
   此筆計入同一manifest/案例預算，不是額外未列資料。
6. 只執行已列案例，逐步deadline、expected rows、transaction/session/role/SQLSTATE/domain核對。
   拒絕分支模型記錄42501/course_use_denied，在savepoint處理後transaction仍有效；不實作或更換authority。
7. R模式ROLLBACK；C提案僅在記憶體模擬COMMIT，逐key/fingerprint核對預期保留。不能稱為正式C授權。
8. 關閉writer後新建observer身份與connection身份，從durable狀態讀取，不接收writer的PASS或after值。
9. 任一錯誤保持FAIL，後續case不再開始。只允許已開始交易的失敗處理、關閉與獨立觀察；不自動重試case。

每step bounded deadline；timeout先取消待執行工作，晚到動作不得再寫入。取消未確認仍FAIL。
rollback失败即使close隱含放棄未提交內容、observer看到0，也**不能**變PASS。
COMMIT成功但回覆丟失歸類UNKNOWN，獨立觀察保留實際結果，不用rollback口號掩蓋已提交資料。
close失敗、observer失敗或不獨立、快照不全、相同counts但key/hash不同均STOP。

模型能驗证這些控制分支；不能證明PG的wire cancel、backend pid、lock/session/statement timeout、
失聯後真正rollback或交易隔離。正式transport須有伺服端timeout與cancel/termination確認，不能只有Promise.race。

## Fixture manifest格式

`exampleManifest()` 產生隨機UUID、無郵件/電話/登入資料的**示例身份清單**，不是可直接執行的SQL fixture。
格式由validateManifest在runtime嚴格核對；不接受任意附加欄位、SQL、URL、credentials或row body。

| 欄位 | 約束 |
| --- | --- |
| format / runId / candidate / target | 格式1、UUIDv4、固定候選、固定目標；不接受caller切換環境 |
| approval / label | 永遠NOT_APPROVED；epic7-synthetic-<run UUID>，不得使用真實學生標籤 |
| cases | 原37個ID的子集合，唯一、明確shipped/denial分支；未到達的成功分支不能冒稱PASS |
| actors | 最多12；UUID、固定synthetic-UUID alias、role/state；不含真實身份或憑證 |
| scopes | 最多2 Course/Map，各最多2版本、4 Nodes；獨立UUID，不與actor混用 |
| tables | 28個明列表，必須齊全，未使用表也列rows=[]；超過任何固定提案上限即STOP |
| rows | key(UUID陣列)、actor/course/map/version/node、caseId、label、fingerprint；不放row內容 |
| ceiling / expectedRetained | 原草案逐表上限；R預期0，C提案等於本次精確列出的rows數，不能把上限當作已留下數量 |
| retention | decision=PENDING、custodian/until=UNKNOWN、NO_DELETE_OR_REPAIR；不能把草案轉為已核准 |

key是待SQL compiler綁定的合成身份tuple；有複合PK/非UUID audit主鍵的表，正式compiler須依實際schema
轉成可驗證的PK或唯一request/actor/run predicate，並處理DB產生的audit identity。
本輪沒有聲稱任意UUID tuple已是該表的合法PK，也沒有由fingerprint反推SQL。
示例配置32筆identity摘要（6個Auth/6個profile，2Course/2Map/4publication/8Node/2receipt/2audit），
不是完整hierarchy/resource/role rows；不能執行它冒稱37案fixture完成。
正式逐案compiler仍須算入trigger產生的profile/role/audit/receipt、建構順序與所有FK，避免重複計帳。

P04–P06/R04成功分支固定拒絕，activity/request兩表不得配置正向資料；R01–R04跨session必須C提案。
原完整C草案上限見coverage，不代表這些數量已獲批准。R04成功用的activity預算保留在草案，當前不可使用。

## 獨立殘留核對與證據

observer格式包含run、獨立observer/connection UUID、UTC、writer已關閉、28表逐key/fingerprint，
以及未列範圍/catalog/sequence摘要、外部副作用數。不同snapshot須來自不同reader identity。
R模式逐表0；C模式逐key、fingerprint及exact count相同。缺表、重复key、身份碰撞、任何非預期新增、
刪除、修改、未列範圍變更、sequence/catalog變更、外部副作用一律FAIL。

正式observer還需要工程編譯actual catalog中的完整touched/legacy/auth inventory及run predicate；
不能把模型的28表與一個unscopedDigest說成已完成正式94表查詢，也不能把全站其他合法寫入當成smoke殘留。
正式執行前須使用核准一致性窗口或可證明分離的run scope，無法歸因就UNKNOWN/STOP。
WAL/log/sequence/API不由ROLLBACK保證消失；sequence差異不得setval抹除。

每次模擬保存於ignored `artifacts/remote-smoke/epic7-executor-preparation/<run UUID>/`：

- result.json：時間、固定target/candidate、case IDs、manifest hash、內容/工具hash、before/after、steps/results、rollback/retention/residue、STOP codes、production=0。
- observer.json：獨立reconciliation結果與snapshot hashes；未能取得observer為null，總結果保持FAIL/UNKNOWN。
- fixture.json：僅經驗證的合成metadata；輸入不合規時null，不回顯惡意/秘密內容。
- hashes.json：上述3檔SHA-256。輸出目錄已存在則拒絕，保留失敗紀錄，不覆蓋舊結果。

只保存內部不可變且白名單驗證的結果。raw Error/SQL stdout/連線字串/學生資料不進artifact；
使用受控STOP code。正式collector將來仍須審查redaction、限制檔案權限、截斷及fail-on-logging-error。

## 本輪安全測試與合理停止點

以明確Node 24.19.0執行新測試，避免不同shell的Node22路徑差異：

```powershell
node --import ./scripts/epic7-readiness-offline-tripwire.mjs --test --test-isolation=none tools/epic7-executor/safety.test.mjs
node --import ./scripts/epic7-readiness-offline-tripwire.mjs node_modules/eslint/bin/eslint.js tools/epic7-executor/contracts.mjs tools/epic7-executor/reconcile.mjs tools/epic7-executor/simulate.mjs tools/epic7-executor/safety.test.mjs
```

只在本輪code改動後跑此新增測試，不跑完整SQL、並行演練、雙build、舊ValidateOnly CLI。
新整合測試內呼叫原verify是驗證新executor無法跳過其安全入口，並非重做交接。
正式DB connections=0、正式SQL=0、正式write=0。具體結果記於本輪新增工具evidence附錄及ignored本機log。

**剩餘工程，不是假稱只等operator：**

1. 受信任live identity/deployment/migration/catalog收集器與同一writer連線綁定；新工具review後的固定副本啟動器。
2. 每案SQL/RPC compiler、真實actor/role/savepoint sentinel、合成schema PK/FK/trigger映射與精確預算。
3. PG transport的server-side timeout/cancel/session close、獨立observer SQL、transaction rollback/residue真實驗證。
4. C多連線race編排與同一manifest下不可變保留；本輪模型不是race測試。P04–P06/R04成功branch等真實authority再補，不能加stub。
5. 將具名批准、當次BR/backup時間、核准case/retention清單與正式啟動器整合成不可由caller boolean偽造的授權gate。
6. 依實際hosting與managed Auth/Storage等inventory補完並在另授權隔離環境驗證全服務復原。

上述正式接線應在本包審查後另行進行；現在沒有任何production adapter或可傳URL的入口。
本輪已完成在無正式連線/無真實資料/無核准C策略下可合理審查的安全核心与契約，未宣稱executor全面完成。
