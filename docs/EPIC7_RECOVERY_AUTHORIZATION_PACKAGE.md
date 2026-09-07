# Epic7-F 備份／復原驗證授權包（待核准，未執行）

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

## 本次按 D2 / D3 收斂的工程判定

**目前能否證明最多損失一小時：UNKNOWN，因此正式 gate STOP。**
這不是宣稱技術上做不到，而是現有 repository 沒有完整、當前、可還原的證據。
2026-09-05 三檔不同時刻的 logical dumps 不能作今日 recovery point，
也沒有 Auth、Storage bytes、migration history 與全服務切換的完整證明。
下方原 `C:/TheOneBackups/...` 位置只是历史提案，**不再是公司電腦上的預設新備份位置**。
既有 runbook BR-2 容許較嚴格 owner 上限，本案現在採 1h；不能套 24h 或自行用例外放寬。

### 證明方式與不合格時的處理

1. 在另行核准唯讀盤點後，建立包含與排除項目、資料相依、實際服務使用清單。
2. 先證明 The One 控制保存空間，記錄非秘密的加密方式/狀態、授權角色、保管責任、保留/到期處置與金鑰取用程序。
   金鑰值不入文件；先以無秘密合成檔驗證加解密與授權取用，正式備份仍需另次核准。
3. 審查可維持一致的輸出方式。三次各自 dump 不當成共同快照；需可驗證 snapshot 或另批准停寫窗口。
   並行合法寫入、Auth/Storage 與外部付款等相依無法對齊則 STOP。
4. 在另批准的隔離還原驗證後，記錄真正可恢復的最舊一致資料時點 T、UTC 時計及取證時間 G；
   須有 0 <= G−T <= 3600 秒，且各必要服務一致。不能用檔案 LastWrite、copy 完成或備份按鈕時間代替 T。
   正式執行前重算，超時就 STOP；不自動 export 更新。
5. 一次近時點備份只支持當次 gate，不能證明明天任何事故都符合 1h。
   持續保障須證明最大排程間隔 + 輸出/可用延遲 + 監測/失敗窗口仍在上限內，
   有失敗告警、可恢復時點檢測與停止風險操作的程序；不能把「每小時開始備份」等同最多損失一小時。
6. DB drill 僅證明那組資料可載入；整站還要逐項通過下方服務清單、版本/安全/流量驗證，
   記錄實際可恢復時間與損失窗口，使用者核准後才重開寫入。1h 是損失上限，不是承諾一小時修好網站。

### 方案（均未啟用；不要求購買）

| 方案 | 可用條件與證明 | 成本／限制 |
| --- | --- | --- |
| The One 已有加密外接儲存／自有備份空間 | 證明所有權、加密、ACL、可用容量、保管人、保留、還原可讀；接近操作時點的一致 logical set | 若已有合格設備可不新增支出；人工維護與離線可用性成本，現有設備是否存在 UNKNOWN；公司機器不得預設當永久或明文暫存 |
| The One 已持有合格雲端空間 | 沿用既有付費額度與受限權限；傳输/落地加密、取用與完整還原實證 | 是否已有合格空間 UNKNOWN；額度、流量費與保留限制先確認，不能保證零費用 |
| 現有方案已含可用 managed recovery / PITR | 核對 entitlement、實際啟用、最新可還原時間與保留、隔離恢復證據；仍補 Auth/Storage/網站相依 | 是否已包含 UNKNOWN；WAL-G 能力或歷史 PITR flag 不足以證明目前可用 |
| 必要才評估新增儲存／PITR／較高方案 | 先證明上述現有方法不能穩定滿足 1h，再比較能力與完整事故恢復 | 有持續訂閱、儲存/流量與演練運算費可能；實際價格、資格與增額 UNKNOWN，未查價亦未購買 |

### 本機已可檢查與尚缺的工程

新增 [離線條件檢查](../tools/epic7-owner-policy.mjs) 驗證 1h 邊界、未來/無效時間、
自控加密保存、保管/權限/保留/一致性/可還原條件、全服務 inventory 缺項；
輸入都是合成 metadata，不讀 backup、不連線。
即使 SIMULATED_REQUIREMENTS_MET，executionAllowed=false、brPass=false、
continuousRecoveryProven=false；不是可信證據收集器或正式授權 gate。

尚缺：將可信非秘密取證來源與當次計畫/manifest/approval 綁定、可用一致快照與 managed prerequisites 的
可執行流程、實際服務相依與維護/停寫接線、隔離演練證明。工程須先完成設計與受影響的本機測試。
下方 Database/Auth/Storage/application/domains/secrets/connections/extensions/history/reopening
及 Realtime/Edge Functions 的 UNKNOWN 均保留；只有可信盤點證明沒使用才能標已確認不適用。

## 歷史紀錄：以下保留本次 owner 決策之前的時點


日期：2026-09-06。候選 `d5f98434106797afc65c59953aa3bc61ba26ecb4`。
本文件只準備下一輪操作，**不代表 operator 同意、RPO 同意、backup export、真實資料 restore 或 migration 授權**。
依 [canonical runbook](REMOTE_BACKUP_RECOVERY_RUNBOOK.md) 與
[P2 recovery provenance](P2_REMOTE_CLOSURE_EVIDENCE.md)，不另外定義較寬鬆 gate。

## 已取得與尚未取得的證據

只查已知目錄 `C:/TheOneBackups/2026-09-05-pre-epic6-smoke` 的三個 SQL 與 metadata，
沒有掃描其他專案或全機。此目錄沒有獨立 manifest。未載入任何正式 backup 至本機測試環境。
hash 計算讀取 bytes，但沒有輸出 dump 內容、資料列、密碼或 credentials。

| File | Bytes | LastWrite UTC | SHA-256 |
| --- | ---: | --- | --- |
| roles.sql | 370 | 2026-09-05 14:37:16.128 | `168A95A9C745AF5ED4679751F90419AC9DC434240A213B03E32A06D5664C2308` |
| schema.sql | 550007 | 2026-09-05 14:38:27.116 | `DEBECDABFBCFC6437252287324993E228BB1F5A3F49A710167DF0C3603D26F76` |
| data-public.sql | 6914 | 2026-09-05 14:39:01.210 | `19C576386CBB1B5CAD107E6B002CD5D669982CE288CF8118D42719BD3AEBD9BF` |

來源 project/ref/產生程序以 P2 已記錄的成功 CLI 三次 export、當時 ref/parity/aggregate 及 operator handoff 為依據。
以上 hash 是**本輪首次在此 evidence 記錄的 bytes identity**，不是備份建立時簽署的 hash，也不是完整可恢復證明。
不同時刻的三次 export 並非單一跨檔 snapshot；P2 的當時空業務表證據可沿用為歷史說明，
不能推論目前仍無寫入或新備份必然跨檔一致。

僅解析結構 metadata：schema 包含 private schema 定義；沒有 auth.users DDL；
data-public 沒有 auth.users data；schema/data 均未含 supabase_migrations history 的建立／資料。
這組備份不含 Storage object bytes，也不能恢復完整 Auth/平台設定。
檔案 attributes 顯示 Compressed／Archive，不能據此認定加密；磁碟加密、存取控制及保留政策尚無適用證據。
P2 接受過 verified logical restore 的 operator handoff，但未提供已填妥的 restore destination/operator/RTO template。

| Gate | 可沿用 | 本次需更新 |
| --- | --- | --- |
| BR-1 | 已驗證過 logical 方法的歷史 handoff、已知來源/ref、檔案存在/hash、scope metadata | 當次 usable set、加密位置、與當前 Auth/FK/roles/extensions 相符的 restore 證據；不是一律重做所有演練 |
| BR-2 | runbook 預設 24h；significant writes/financial reconciliation 等條件要求 1h 或具名書面例外 | 既有最舊檔於 2026-09-06 14:37:16 UTC 達 24h，已不能作之後執行的 fresh set；實際新 recovery point、RPO/寫入情況待具名 owner 確認 |
| BR-3 | runbook 的 R0–R6、forward-fix 與 history preservation 原則 | 具名 operator、已驗證 destination、事故時 write freeze/traffic/Auth/Storage/其他服務、app rollback release 及安全檢查程序 |

目前 BR-1/BR-3 **UNKNOWN / NOT PASS**；舊 set 在上述時間後 BR-2 **不符合預設時效**。
不以「沒有 PITR」要求購買方案，不以三檔存在直接核准 deployment。

## 下一輪請核准的範圍與欄位

| 欄位 | 具體提案／目前狀態 |
| --- | --- |
| 正式唯讀 export source | Supabase `the-one-platform` / `ygxeihtcolpiulupieeq` / ap-southeast-1；執行前再驗 identity |
| Candidate / migration set | d5f9843；完整五檔 hash 見 [readiness](EPIC7_REMOTE_READINESS_EVIDENCE.md)；不改歷史 34 檔 |
| 預設 export scope | 既有 CLI logical roles、application schema（含 public/private）、public data；不宣稱全平台備份 |
| 排除範圍 | Auth data、Storage bytes、migration history、平台 secrets/config；新驗證若出現 auth references，先 STOP，不以假 auth rows 補救 |
| 新 storage proposal | `C:/TheOneBackups/epic7-f-<approved-run-id>`；在核准的加密磁碟／容器內，限具名 operator ACL；加密方式、key custodian、retention、到期處理目前 **PENDING**，不能先寫未加密正式 dump |
| Isolated restore destination | 提案為新建 Docker 容器 `theone-epic7-recovery-<approved-run-id>`，PG 17.6 相符 image、獨立資料目錄、network none、無 published ports；來源 repo/開發 DB/production 都不是 restore target。實際 container ID/image digest/資料目錄須在下一輪建立後 attestation |
| Managed schema prerequisite | recovery destination 須先有相容 auth.users/helpers/roles/extensions；其來源/hash、建立方式及與 source shape 的差異先 review。不能只恢復 public data 而略過 FK 依賴 |
| Operator identity / approval reference | **UNKNOWN / NOT APPROVED**；不可填入推測姓名或代簽 |
| 可接受資料損失 / RPO | **PENDING owner confirmation**；不自行核准 1h 或 24h 為接受損失 |
| Migration execution | 另一步明確授權；backup/restore proof 不自動授權正式 migration |
| Production overwrite | **禁止**；任何 production restore、PITR、reset 均不在本包提案範圍 |

## 分步成功與停止条件

1. **唯讀重新驗 identity、Git/SQL hashes、migration IDs 與 reference scope。**
   來源須精確匹配 ygxeihtcolpiulupieeq；核對 auth.users references 是否為空、private/application data scope、
   extensions/roles 及 snapshot consistency。目標漂移、未知依賴或正在寫入而無一致性方案，STOP。
   三次 export 的一致性需具名 freeze/window 或已 review snapshot 機制；本輪不自行設定 production write freeze。
2. **加密位置與 operator/RPO 完成後，才執行新 export。**
   已驗證的 CLI 命令模板（下一輪核准後執行，本輪未執行）：
   `supabase db dump --linked --role-only -f <approved-external-directory>/roles.sql`；
   `supabase db dump --linked -f <approved-external-directory>/schema.sql`；
   `supabase db dump --linked --data-only --schema public -f <approved-external-directory>/data-public.sql`。
   執行前檢查 link exact ref；使用現有 approved credential，不列印連線字串。任何 command 非零、空檔、
   不一致 scope 或未接受的 circular-FK warning 都 STOP，不繼續 migration。
3. **完成非秘密 backup manifest。**
   記錄 source ref/name/region、開始/成功完成 UTC、CLI/pg_dump/PG 版本、三檔 SHA-256/bytes、
   snapshot/window、包含/排除 schemas、migration IDs與檔案 hash、Auth reference 處置、加密/ACL/retention、
   operator與approval ID、warning disposition。manifest 不包含密碼、dump row 或 key。
4. **先 review restore input，再對新隔離 destination 演練。**
   確認 source/target 明顯不同、容器 label/ID/network/data directory、encrypted input 的唯讀掛載與暫存處理。
   roles/schema dump 需先與已存在 managed objects 比對，決定已驗證的 logical restore 順序；
   不盲目以 `ON_ERROR_STOP=0` 忽略重複角色／DDL 錯誤，也不 disable triggers/RLS/session_replication_role。
   若 P2 的實際成功 restore procedure 能補齊且仍相容，直接沿用 review 後的 procedure，不重新發明。
   **現有三檔不足以在未補 managed Auth 與 migration history 設計前核准一條無條件 restore 指令。**
5. **Migration history 恢復必須可追溯。**
   history 不在三檔內。下一輪須取得 exact source ID manifest；僅在新 recovery target，核對恢復 schema 與原始 29 檔後，
   按 reviewed procedure 重建相符 metadata，或使用完整 source history 的另核准 export。
   不以任意 29 個 ID 掩蓋 schema差異；這不是對 production 執行 migration repair，也不允許改正式 history。
6. **恢復驗證成功門檻。**
   核對角色/owner/defaults、managed auth helpers/PK/FKs、extensions、migration/schema一致性、RLS/raw grants、
   exact rls_auto_enable 窄例外及所有舊/新域的相容性；資料 counts/digests 在 private evidence 中比對，報告不輸出 PII。
   任何 restore error、缺 Auth reference、FK failure、未解釋漂移、明細不一致均 FAIL/STOP。
   合成 local 演練不等於此真實 backup 恢復驗證；Storage/Auth API/流量切換也不能由 DB-only restore 宣告 PASS。
7. **BR 更新 → 另行審核正式 migration。**
   只在 BR-1/2/3、實際最新 recovery point、app compatibility、五檔 rollout window 及 operator migration approval 都齊備時，
   才提出 production migration 執行申請。每檔交易界線與 R1/R2 STOP/forward-fix 保留；不自動推送或網站部署。
8. **演練資料處置。**
   真實資料 recovery 容器的銷毀、解密暫存與 log retention 都須包含於下一輪授權；不能沿用本輪 synthetic container disposal 授權。
   新備份依核准 retention 保留，不把 dump/credentials 放 Git；不恢復覆蓋正式 source。

最小 operator 決定集中為：具名 operator/approval、現有 P2 drill record、加密位置與 custodian、
RPO/一致性窗口，以及上述新隔離 restore scope。這些是操作授權／證據缺口，不要求 operator 手動逐條除錯。
本輪沒有 export、真實資料 restore、migration 或 deployment。

## 提交後收斂：兩條復原路徑（待審，非執行授權）

本節為 c61cdb6 保存後追加，不改寫前述 P2/本機測試結果。以下所有操作 NOT RUN；BR-1/3
仍 UNKNOWN、BR-2 不可沿用舊 set。Docker drill 成功不等於 BR-3 PASS。

### P2 可沿用證據及缺件

限定查閱 repository 的 P2 evidence、recovery template、已引用 artifacts 與指定 backup directory。
[P2 provenance](P2_REMOTE_CLOSURE_EVIDENCE.md) 明載 restore 成功來源為 operator handoff，沒有原執行
timestamp、destination、RTO、approval ID 或 completed template。相關 artifacts 只有已記錄的 smoke
結果，沒有找到可直接重用的完整 restore 命令／目的地／工具版本 log。這不是重開 P2 closure。
可沿用：當時 exact ref、29/29、空業務表 aggregate、三個 dump exits 成功、兩個 remote smoke PASS、
logical method 的歷史 handoff。不可推論：目前 Auth 為空、dump 跨檔一致、PG restore target 曾驗證為 Docker、
或任意今日 destination 已驗證。缺件由工程方將現有方法補成 reviewed procedure；不要求操作者逐條除錯。

### 路徑一：隔離 logical 可還原性測試

目的只限證明特定輸入可恢復 DB 範圍。前置是完整 source manifest、合法資料處理授權、加密位置、
來源與目的地相容性 review；輸入為三檔及另行核准的 managed prerequisites/history evidence。
目的地為前述新 network-none PG 17.6 容器提案，目前未建立、未 attested、未驗證。
操作順序沿用前述 1–6、8：先 inventory，補相容 prerequisites，再按 reviewed 順序 roles/schema/data/history，
核对 error-free restore、FK、counts/digests、RLS/grants、migration identity，最後依已核准方式處置真實資料。
未補相容 Auth 或 history 就 STOP；不提供跳過 dependency errors 的一鍵命令。

範圍拆解：

| 項目 | 已知／輸入來源 | 缺口與 STOP |
| --- | --- | --- |
| roles | role-only dump；schema owner/grants 另比對 | 不能假設 roles dump 含 managed roles/passwords；先對照 destination，衝突不忽略 |
| public/private schema | 舊 schema 含 private；application DDL | 完整 object inventory/defaults/extensions 比對由工程交付 |
| public data | public-only dump | 當前 rows/FK/跨檔一致性須另授權唯讀確認；不能沿用舊空表結論 |
| private data | data-public 未涵蓋 | schema 存在不代表其資料已備份；若有必要資料須擴充已核准 export scope，否則 STOP |
| Auth helpers/roles/extensions | 歷史 catalog 與本機 PG image 只證明當時相容性線索 | 正式 source shape/version 與 managed prerequisite 來源/hash/安裝方式未完整記錄；本機 auth schema 不可冒稱正式 restore 輸入 |
| Auth references | P2 當時 auth.users=0；新 24 表含 Auth FK | 今日 references 未查；三檔不含 Auth data，不造假 users 補 FK |
| migration history | 原 29 檔及歷史 exact IDs 可作比對 | 三檔未含 history；另核准完整 history export 或 reviewed metadata 重建，僅 recovery target；逐 ID/DDL 驗證，不能任填29 IDs |
| Storage/secrets/config | 明確排除 | DB-only 成功不證明媒體、登入、連線、Functions/Realtime/完整服務可用 |

### 路徑二：正式事故恢復服務

這條路徑目前僅有待審決策與工程流程，沒有已驗證目的地。runbook BR-3 原文：
“Will restoration run in the Supabase Dashboard or through an approved Management API procedure?”；
“An untested or unspecified destination fails BR-3.”
另 Restore drill policy 要求 “staging or dedicated recovery project”，並驗證 application connection、
Storage/configuration gaps、both smoke harnesses、RPO/RTO 與 teardown approval。
因此僅 Docker DB restore 的提案不滿足該完整平台 drill 與 BR-3；不得用它替代或默改 runbook。

| BR-3 問題 | 路徑一能證明什麼 | 正式事故仍缺／成功條件 |
| --- | --- | --- |
| 具名 operator、Dashboard/approved API | 無正式平台操作 | 姓名/approval及可執行平台程序未提供；工程整理既有可用方法供具名負責人核准 |
| 覆寫/新 recovery project | 明確不覆寫source的新本機容器 | 正式目的地尚未選定/驗證；本包禁止覆寫source。若提新 recovery project需另核准，不在本輪建立 |
| 時點/PITR | 特定logical輸入的一致性 | 可用實際recovery point待查；不由walg推論PITR；選在首次bad transaction前，需接受損失窗口 |
| downtime/write freeze | 無流量的synthetic/drill環境 | 事故owner決定範圍、開始/停止時間；工程先列受影響API/workers/jobs與停止/重開順序，不能現在執行freeze |
| traffic/DNS/connection/Auth/Storage/Functions/Realtime/extensions/replicas/secrets | DB相容性部分 | 實際hosting與各服務inventory/切換及驗證程序缺；credentials只在approved secret store處理，不寫文件 |
| parity/security/connectivity/Epic5/Epic6 smoke後重開 | DB catalog/digest部分 | 具名owner確認上述全數PASS、實測RPO/RTO、服務/媒體/登入/寫入路徑後才重開；smoke仍需另授權 |

事故提議順序：R0–R6分類與證據保留 → 具名事故owner核准必要write freeze → 優先評估forward-fix/
相容app rollback → 不可恢復時核准recovery point/損失與目的地（runbook要求第二位operator approval）
→ reviewed平台還原及服務切換 → parity/security/資料完整性/登入媒體與app連線/smoke → 具名簽核重開寫入。
任一destination、必要服務或驗證未知就 STOP，保留停寫/受限服務策略，由事故owner處理；不能以Docker成功跳過。
本輪沒有事故、未啟動此流程。更完整logical平台恢復替代若有需要，必須先review政策修訂，不擅自降低BR-3。

### 保存、加密與時間（2026-09-06 本機唯讀快照）

評估時間：2026-09-06 **15:55:04 UTC / 23:55:04 Asia/Taipei**。
已知目錄 ACL owner 為 DESKTOP-AFP7QM6\\win；Administrators/SYSTEM FullControl，Users ReadAndExecute，
Authenticated Users Modify（另有繼承權限）。目錄 attributes 為 Directory, Compressed, NotContentIndexed。
這不是「限具名operator ACL」或加密證明；BitLocker/EFS/密鑰保管證據未提供。不讀密鑰、不改ACL、不移動檔案。
待審可行方案：由owner指定已驗證加密磁碟或加密容器，再限具名operator/必要系統帳戶；工程提供驗證紀錄，
custodian、復原key流程、retention期限與到期處置由owner核准。本機帳戶owner不等於操作授權人。

| 時間類型 | UTC | Asia/Taipei | 解讀 |
| --- | --- | --- | --- |
| roles LastWrite | 2026-09-05 14:37:16.128 | 2026-09-05 22:37:16.128 | 不是獨立recovery-point證明 |
| schema LastWrite | 2026-09-05 14:38:27.116 | 2026-09-05 22:38:27.116 | 同上 |
| data-public LastWrite | 2026-09-05 14:39:01.210 | 2026-09-05 22:39:01.210 | 同上 |
| successful backup/recovery point | 精確跨檔時點未提供 | 未提供 | P2記錄成功exits，不表示同一snapshot；需新manifest |
| 最舊檔達24h | 2026-09-06 14:37:16.128 | 2026-09-06 22:37:16.128 | 評估時已超過；不能以mtime替代成功recovery point |
| 未來migration執行時間 | 未核准/未排定 | 未核准/未排定 | 執行前重新計算，不能延用評估時間 |

五檔是additive/no backfill，歷史靜態分析不顯示financial reconciliation；但當前significant writes未知。
BR-2默认24h只在適用條件已查明時使用；有significant writes/既有data reconciliation/financial-credit
invariants變更時依原文1h或具名書面例外。不能因本鏈additive就推論當前24h必定適用。
owner可接受損失仍PENDING，年齡門檻不等於RPO同意；一致性窗口起迄須同時記UTC/Asia-Taipei。

### 集中待操作者決定（全部未核准）

1. 誰負責執行、事故判斷與復原簽核？具名operator/backup custodian/第二核准人與approval ID未提供。
2. 備份放哪裡、誰能讀、誰保管解密能力、多久刪除？前述外部加密位置是提案，現有ACL不符合提案。
3. 最多能損失多久資料？能否提供一致性窗口，如何停止相關寫入？工程先提供相依服務清單，owner決定損失與影響。
4. 先核准隔離可還原性drill的exact inputs/target/disposal，或補現有P2完整record供重用？兩者皆不自動核准正式事故restore。

## 公司本機工程準備：服務相依清單與復原順序

本節僅來自repository靜態查閱，沒有讀正式.env、dump或正式服務。
[executor工程審查包](EPIC7_EXECUTOR_ENGINEERING_REVIEW.md)的記憶體回滾模型不屬於任何restore證據。

### A：DB logical drill 與 B：網站事故恢復

A的交付門檻：已批准的完整輸入清單/檔案hash/一致性時間/加密保管，已審managed prerequisites，
目的地與來源精確不同，按reviewed角色→schema→資料→history處理順序，零error、FK/安全/數量digest一致。
原三檔沒有Auth資料、Storage bytes、migration history；private data涵蓋也未知。
有缺項先停，不能補假users、忽略重複物件錯誤或停RLS/trigger去恢復。A只證明指定DB範圍。

B還必須恢復登入、檔案、網站release、連線與流量，經安全/功能測試後才能重新接受寫入。
以下表格是一份工程操作依賴與成功標準，不是現在可以照做的正式指令。

| 部分 | repository能確認 | 正式現況/缺項 | 事故時需交付與驗證 |
| --- | --- | --- | --- |
| Database | migration定義public/private業務、RLS/grants、immutable history；歷史ref/name/region可作expected identity | 當前schema、row scope、recovery point、managed backup/PITR/plan=UNKNOWN | 具名事件負責人判斷forward-fix優先；必要restore須另外批准、核對輸入/目的地/時間與資料完整性 |
| Auth | src/modules/auth/actions.ts、auth callback/confirm、src/lib/supabase、auth.users FK；登入/註冊/重設密碼等有程式路徑 | providers、SMTP、redirect allowlist、目前users、managed schema版本、Auth backup coverage=UNKNOWN | 登入服務和DB恢復點一致；真實Auth依賴不能假造；核對redirect/登入/登出/重設流程及權限，避免演練發信 |
| Storage | 本輪src靜態搜尋未找到Storage SDK操作；SECURITY定義未來私人資源要求 | 真正bucket/objects/政策/外部媒體平台使用=UNKNOWN，未找到程式碼不等於沒用 | 清點有無資料及object backup；DB-only不恢復檔案。必要object/簽名讀取/權限另驗證 |
| Application | package.json Next16.3.3，auth/teachers/trials/commerce/entitlements/scheduling Server Actions與payment webhook拒絕邊界 | 正式release ID、部署位置、rollback release、相容性=UNKNOWN | 固定compatible release；核對舊app是否理解新schema/enum/權限。UNKNOWN不得直接rollback app |
| Domains/traffic | NEXT_PUBLIC_SITE_URL為環境名稱，repo沒有正式域名/traffic切換證據 | DNS/CDN/domain owner、網站URL、流量入口、maintenance能力=UNKNOWN | 工程補入口清單、切換/驗證/回退順序；owner批准停寫影響與重新開放。不能推測改DNS就足夠 |
| Env/secrets | 僅從source知道NEXT_PUBLIC_SUPABASE_URL、NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY、NEXT_PUBLIC_SITE_URL、SUPABASE_SERVICE_ROLE_KEY、MANUAL_BANK_TRANSFER_INSTRUCTIONS | 正式值/保管位置/rotation責任=UNKNOWN；本輪未讀值 | approved secret store到正確runtime，對target/權限作非秘密核對；不得把value寫進文件/聊天或artifact |
| Connection strings | server/browser Supabase client經env及server-only分界建立 | 真正DB host、pooler、TLS/session模式、連線切換清單=UNKNOWN | 對實際連線核對target/role/region證據，隔離舊writer與新destination，重新建立連線後驗證；不在文件保存URL/password |
| Extensions | 20260831000400宣告extensions.btree_gist；其餘managed相依不能只由此推出 | 正式完整extension/role/helper inventory=UNKNOWN | source/destination name/schema/version/owner相容性及權限逐項核對；缺managed物件STOP |
| Realtime / Edge Functions | 本輪src未找到.channel()/realtime/functions.invoke，repo無supabase/functions或config.toml | 是否有Dashboard建立的Function、publication、排程、webhook=UNKNOWN | 實際使用才納入inventory，核對程式版本、觸發來源、重複處理風險及停/重開順序；不能自行標N/A |
| Migration history | 本機34檔固定manifest；歷史正式29/latest20260904001100 | 當前正式history=UNKNOWN；三檔備份未包含history | exact IDs+schema/deploy證據核對，缺資料不能任填34/29；restore target metadata重建需review，production repair另屬例外授權 |
| Reopening writes | recovery runbook要求安全/連線/完整性及Epic5/6 smoke後簽核 | 尚無本次驗證或全服務drill=UNKNOWN | 具名owner看完全部證據批准，解除限制按下列順序分批；任何未知仍停在受限狀態 |

靜態搜尋範圍為src及supabase受追蹤檔，不涵蓋平台端設定或使用者另有的系統；UNKNOWN不由舊P2附件補成PASS。

### 工程可先確定的停寫/恢復相依順序（未啟動）

1. 記錄事故時點、異常範圍與R0–R6分類，先保留證據；單純preflight失败不做restore。
2. 在owner批准的事故措施下，先阻止相關寫入入口：auth註冊/修改/密碼路徑、Teacher/Trial管理，
   Commerce付款確認/訂單、Entitlement操作、Scheduling訂位/取消/改期/完成，以及實際存在的外部jobs/API。
   src/modules各actions.ts是已知入口，不是完整部署流量清單；還須盤點外部client/worker/Dashboard操作。
   payment webhook目前拒絕，但不能藉此推論整個平台沒有其他入站寫入。
3. 核對停止新請求並排空/取消active writer；保留Auth/外部回呼安全策略，不能只停網頁而留下worker。
4. 優先評估forward-fix或經相容性證明的app rollback。必要資料復原才依runbook第二位operator批准，
   選定首次異常之前且實際可恢復的時間/目的地，處理跨檔一致性與可接受損失。
5. 按approved程序恢復DB及managed依賴/history；另恢復Auth/Storage/Functions/Realtime等實際必要服務。
6. 設定正確secret引用/連線→部署compatible app至核准目的地→先在受限流量下驗證登入、資源讀取、安全、資料一致性及smoke。
7. 確认無舊writer指錯目的地、無重播付款/訂位副作用、無未查明殘留，量測實際恢復時間與遺失窗口。
8. owner簽核後才切正式traffic、按依賴重開write/API/jobs並監測；任一失敗停止後續步驟，重新分類，不能自動修資料。

現有schema及source不足以交付「可直接按下就能恢復整站」的命令。
補live inventory、managed Auth/history procedure、transport與全服務drill是工程工作；不能只寫等待operator。
owner要決定的僅責任人、加密保管/可讀者、能接受的資料損失時間與測試保留位置。
