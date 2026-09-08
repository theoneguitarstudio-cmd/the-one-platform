# EPIC7_BACKUP_RECOVERY_EXECUTION_REQUEST

## 2026-09-08 公司場景補充

本申請仍PENDING OWNER APPROVAL，沒有export/restore批准。
[公司再核對](EPIC7_BACKUP_STORAGE_WRITE_SOURCE_REVIEW.md)未找到可證明The One自控的合格加密位置；
不請OWNER去修改公司Windows加密/ACL，不把公司repo/TEMP/Docker當正式backup中繼。
請指定The One自己控制的私人/專用位置後再由工程核對；下方家用UI/容量/路徑不是公司已可用證據。
寫入入口仍需[最小唯讀活動查證](PRODUCTION_WRITE_ACTIVITY_READONLY_REQUEST.md)，不能靠Preview project尚未建立推論沒有writer。
Preview準備不授權本申請，也不需要為看網站把正式資料匯出到測試環境。

**PENDING OWNER APPROVAL**

這是待審申請，不是執行授權。對應[工程計畫](EPIC7_BACKUP_RECOVERY_EXECUTION_PLAN.md)。
目前尚不能開始：備份與Docker資料落地的加密/權限未證明，真正停寫入口尚未確認。核准不得略過這些條件。

## 只申請這一件事

在指定加密位置及一致性窗口確認後，從正式The One讀取一套新的logical backup，
保存到OWNER控制的位置，再在家中全新、無網路、不開port的Docker裡做一次資料庫還原驗證。
這次不申請migration，不改正式資料庫，不更新網站，也不執行remote smoke。

| OWNER要知道的事 | 本次提案 |
| --- | --- |
| 來源 | the-one-platform / ygxeihtcolpiulupieeq / ap-southeast-1；開始前重新核對 |
| 會做什麼 | 先驗來源/加密/權限/輸入範圍，讀取backup，記時間與檔案指紋，隔離還原後逐表及權限比對 |
| 會改正式DB嗎 | **NO**：不執行正式DDL/DML/repair或restore；export會使用正式DB讀取資源，不能保證零負載 |
| 會停網站嗎 | **UNKNOWN**：依實際writer決定；全窗口可靠無writer可不額外停網站，有writer先核定控制/恢復方法才定時限，不沿用15分鐘猜測 |
| 為何停寫 | 三次匯出不是同一快照；須確保整段資料不變，才能證明一致恢復點。實際控制方法未知時不開始 |
| 產生什麼 | roles.sql、schema.sql、data-public.sql、核對後的managed prerequisites與source metadata、manifest/SHA256、還原/處置紀錄 |
| 排除什麼 | 真實Auth資料、Storage檔案、平台秘密、網站/網域、完整migration statements；若這些是當前不可排除的DB依賴，在export前停止並另提scope |
| 資料位置 | **尚未核定**；待確認加密root下的TheOneBackups/epic7-UTC-run-id；不直接使用舊C:/TheOneBackups |
| 誰能讀 | OWNER及本次指定operator，必要System/Admin亦須明列；不放Git、聊天、公司或公共同步空間 |
| 演練位置 | 全新固定image的本機Docker；它的資料層/TEMP/swap也須先證明加密，否則不匯入 |
| 完成後 | 關閉連線並停止本次新container；建議backup留7天，drill資料/log最多24h；實際期限須核准，刪除另列清單批准 |
| 失敗時 | 立即停止後續步驟、保留受限加密證據，不修正式資料、不忽略error、不自動重試或刪資料；依事先核准方式退出停寫窗口 |
| 一小時要求 | 以真正一致恢復點計算，不以檔案完成時間計算；本次驗證結束若已超時，之後migration仍需另核准fresh backup |
| 不涵蓋 | 不恢復正式網站、不建立正式recovery project、不授權push/deploy/Epic8，不宣告BR-3或Epic7正式結案 |

## 開始前需要填妥的具體資料

- 已證明由The One控制且加密的實際backup路徑：**未提供**。
- Docker資料層及暫存的合格加密位置：**未證明**。
- 此次operator/custodian（OWNER最終核准人已確定，不重問）：**待具名**。
- 所有實際寫入入口的控制/恢復方法、截止時間與取消門檻：**未確認**；不默認有Vercel網站或維護按鈕。
- 保留7天/24h及後續處置提案：**待核准**。

OWNER先看Windows「設定 → 隱私權與安全性 → 裝置加密」的狀態（開啟/關閉/頁面不存在；不點金鑰、不改設定、不跑PowerShell），
並指定要保管The One資料的位置。若磁碟未加密或ACL不合格，改設定仍需另外明確批准；本申請不自動包含這些變更。

以上缺件補齊並經工程核對後，OWNER只需核准**這一套備份＋隔離還原驗證，含明列停寫窗口與保管條款**。
只回覆「核准」不能將未知位置、未知維護操作或未審Auth資料範圍自動變成已批准。
本輪不要求你貼帳密，不要求自行處理SQL，也不現在開始backup。

## 一次批准的完整順序

[儲存/入口盤點](EPIC7_BACKUP_STORAGE_WRITE_SOURCE_REVIEW.md)及[下一轮最小唯讀申請](PRODUCTION_WRITE_ACTIVITY_READONLY_REQUEST.md)列明尚缺事實。
可無缺件一次核准執行：**NO**；申請設計已收斂，仍 **PENDING OWNER APPROVAL**。

1. 重新確認source identity、catalog/history、export scope與必要managed prerequisites。
2. 確認實際writer、在途交易及schema/role/Auth的一致性控制，可靠靜止才記Tquiet。控制方法必須事先具體核准，未知STOP。
3. 核定OWNER控制的加密路徑、具名ACL、Docker/TEMP/log/swap落地與容量後，才建立新logical backup。
4. 同窗口source metadata、manifest、每檔bytes/SHA256、真正recovery point及保管/期限完整保存；結束窗口並按核准方法恢復入口。
5. 使用核對過既有image，在新無網路/無ports Docker target隔離restore，不以production為target。
6. 獨立核對scope、摘要、FK、roles/extensions、有效ACL/RLS/history procedure；錯誤STOP，不忽略或以假資料补齊。
7. 更新BR-1/2/3的實際evidence與缺口，不能將DB-only自動當全服務BR-3 PASS；1h以一致T而非mtime計。
8. 關閉連線，只停止這次新container，保留受限evidence，STOP。無migration/deployment/remote smoke/production restore/cleanup。

補齊具體位置、控制/恢復、時限、operator及retention後，OWNER可一次核准整套，不必逐條處理SQL。
空泛核准不能填補未知事實；不授權改Windows/ACL或未審的正式write path。
