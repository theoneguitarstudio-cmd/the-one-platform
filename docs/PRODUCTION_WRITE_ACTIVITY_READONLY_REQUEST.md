# PRODUCTION_WRITE_ACTIVITY_READONLY_REQUEST

## 2026-09-08 一次最小申請（公司再核對後，仍未執行）

請OWNER只核准本文件既有白名單的正式活動metadata查證，不含備份或停寫。
來源固定the-one-platform / ygxeihtcolpiulupieeq / ap-southeast-1，身份錯或可見性不足STOP。
兩次有界聚合相隔約60秒、總執行窗口最多90秒，單一SQL statement_timeout最多5秒；
只用transaction-local設定與read-only transaction，不改永久參數。逾時不重試，不cancel其他backend。
不讀原始query、自由文字、使用者資料/帳密或job command；catalog能力未存在就記UNKNOWN/不適用，不擴充scope。
[本機來源盤點](EPIC7_BACKUP_STORAGE_WRITE_SOURCE_REVIEW.md)與[Preview隔離計畫](THE_ONE_VERCEL_PREVIEW_SETUP.md)已補齊，
現在不能靠本機程式證明正式活動；先前preflight批准不延伸至本申請。
90秒短觀測不證明整段backup靜止，仍需實際hosting/操作者控制證據；本輪未連Production。
此批准也不授權建立Vercel Project或獨立Supabase，兩條工作線分開。

**PENDING OWNER APPROVAL，未連線。** 下一輪最小查證，不含backup/restore。
依據：[本機盤點](EPIC7_BACKUP_STORAGE_WRITE_SOURCE_REVIEW.md)。

先以既有受控登入重新確認 the-one-platform / ygxeihtcolpiulupieeq / ap-southeast-1；不relink、不貼帳密，身分錯STOP。
先前已完成preflight不延伸成本輪授權。

只申請：
1. 兩次相隔約60秒的有界pg_stat_activity聚合：backend_type/state/wait_event_type數量、交易年齡區間，排除本次observer，記可見性限制。active不直接等於writer。
2. pg_stat_database commits/rollbacks、tup_inserted/updated/deleted、stats_reset；public/auth/storage的pg_stat_all_tables n_tup_ins/upd/del聚合增量。只計數，不資料列；延遲/reset/重啟/權限限制均明列。
3. catalog檢查cron/pg_net等capability；僅已存在且可讀時取job ID、enabled、schedule、執行狀態/時間/總數。不讀command、jobname、username、host、return_message、payload/header/queues，不補裝extension。
4. pg_prepared_xacts數量/年齡區間、必要連線可見性metadata及有限表counts；不輸出交易識別字串或業務rows。

不取query text、function body、client IP、application_name自由文字、user identifiers、秘密/URL/Auth rows/provider logs。
不business RPC、不EXPLAIN ANALYZE不明SQL、不pg_stat_reset、不cancel/terminate、不改設定或啟動jobs。
無export/restore/migration/smoke/cleanup/push/deploy/網站/GitHub/Vercel操作。

輸出僅非秘密UTC、target、欄位白名單、scope、聚合結果及限制；完成STOP。
計數增長只證明觀測變動，不等於真學生；無增量也不能證明全窗口/未來無writer。
仍需hosting/runtime identity、排程與具名入口控制佐證，短觀測不是一致backup承諾。
若不足，回報缺口，不自行擴大或export；不含停寫授權。
