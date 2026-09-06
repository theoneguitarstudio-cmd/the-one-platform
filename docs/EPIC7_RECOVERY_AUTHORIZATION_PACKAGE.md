# Epic7-F 備份／復原驗證授權包（待核准，未執行）

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
