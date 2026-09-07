# EPIC7_BACKUP_RECOVERY_EXECUTION_REQUEST

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
| 會停網站嗎 | **尚待確認**：建議最多15分鐘停止會寫資料的功能；可安全分離的唯讀頁面保留。無法安全分離就不能保證網站不中斷 |
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
- 所有寫入入口的控制/恢復方法及允許的15分鐘時窗：**未確認**；不默認有Vercel網站或維護按鈕。
- 保留7天/24h及後續處置提案：**待核准**。

OWNER可先提供BitLocker「狀態」頁面或由管理員執行唯讀status的結果（不要開啟/傳送復原金鑰），
並指定要保管The One資料的位置。若磁碟未加密或ACL不合格，改設定仍需另外明確批准；本申請不自動包含這些變更。

以上缺件補齊並經工程核對後，OWNER只需核准**這一套備份＋隔離還原驗證，含明列停寫窗口與保管條款**。
只回覆「核准」不能將未知位置、未知維護操作或未審Auth資料範圍自動變成已批准。
本輪不要求你貼帳密，不要求自行處理SQL，也不現在開始backup。
