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
