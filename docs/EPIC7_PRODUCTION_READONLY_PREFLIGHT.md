# Epic7 Production Read-Only Preflight — 2026-09-08 Asia/Taipei

結果：**WARN；唯讀查證完成，正式 migration gate NOT READY。下一步 B：準備正式 Backup / Recovery 供另行審閱。**

## 授權、版本與時間

OWNER 本次明確批准 exact The One target 的 Production Read-Only Preflight；不含 export、restore、migration、smoke、cleanup、push、部署、GitHub/Vercel 操作或 Epic8。
工作目錄 C:/Projects/the-one-platform-home-2eac1b9；起點 main / 1829886a49f4436e966e55afed7f333175d290e8，working tree CLEAN。
application/migration candidate 仍 d5f98434106797afc65c59953aa3bc61ba26ecb4；沒有修改 application、migration、package/lockfile 或 Product Decisions。
首次成功身分查證 2026-09-07T15:59:25.981Z（Asia/Taipei 2026-09-07 23:59:25.981）；完成 2026-09-07T16:09:27.378Z（Asia/Taipei 2026-09-08 00:09:27 GMT+8）。跨午夜不是兩次部署。
本輪使用已存在 Supabase CLI 2.116.0 與既有管理登入，不需 OWNER 重新登入。新 checkout 沒有 local project link；每次 SQL 明確帶 --linked --project-ref ygxeihtcolpiulupieeq，沒有 relink。

## 當前身分與 migration

控制台 projects list 已獨立確認 **the-one-platform / ygxeihtcolpiulupieeq / ap-southeast-1 / ACTIVE_HEALTHY**，完全匹配後才執行 DB SELECT。
PostgreSQL 17.6；database=postgres；query role=postgres。連線透過指定 project 的 Management API，不從舊文件或 current_database 單独推定目標。
正式29份、latest 20260904001100；本機34份、latest 20260906000500；local-only5、remote-only0。29個ID及名稱與本機逐一相同，沒有重複或異常ID。
預定 rollout 只有以下五份；**本輪沒有 apply**：

| Migration | 本機原始 SHA-256 |
| --- | --- |
| `20260906000100_learning_course_versions.sql` | `ea13b605b7d0fc54a237ef2c901c9ccb35f41c0bb9e8e0a58af591c6ac2ac8fb` |
| `20260906000200_learning_hierarchy.sql` | `20ab7f8114f9d8d1b352275494b8f31f5c6151ab1cb8df8b587dbee8a75e2a55` |
| `20260906000300_learning_content_freeze.sql` | `9e5c2253bbcafce4661ab5ae6f5017866a07a320fe02b206b32c91785db1c2f8` |
| `20260906000400_learning_self_activity.sql` | `64d9d2eeed9f049f1e129552c1261457ed70404ba70e57cb02e57456ec555af0` |
| `20260906000500_learning_freeze_graph_validation.sql` | `89c671af5ba816029f4d2de8a6e8a6c222e8de69589d6dd70026b117d965d103` |

本機34份 raw SHA-256 全部符合 preserved manifest；29份歷史 Git blobs 與P2 baseline 899906b556b4dc282538920baec8cdfb0546f6df 全同。
首次把Git LF blob直接與Windows工作檔bytes比較，23份不等，先暫停正式查詢；本機追查確認既有Git attributes指定CRLF。
29/29 Git blobs相同、差別全部僅CRLF，34/34既有raw hash亦相同，沒有更改或降低hash檢查。初始失敗與解析證據均保留。
正式history目前有 version/name/statements，已只取statements數量及MD5，不讀出SQL內容；沒有原始來源SHA欄位。
**不能把儲存statement摘要、ID或本機Git SHA當作正式部署原始檔案SHA證明**；完整遠端SQL內容漂移未在本輪逐statement重建比對。

## Schema / security / contract

從五份SQL抽取的24個表名和20個函式名，正式catalog全不存在，符合未部署狀態；含System Course、Map、Level、Module、Node、Resource、Objective、Skill、prerequisite、version、activity與authority。
既有public業務表47張與前29份migration的表名集相同，沒有缺表、多表或未啟用RLS的表；private沒有資料表。
保存37個policy metadata摘要、156個public/private函式形狀；其中147個來源可對應application函式均postgres owned，沒有意外owner。
只取得catalog/形狀/函式內文摘要，不取得真實資料內容；這是已查範圍相容性，不是全schema語意/負載/網站release一致性證明。
public/private/auth、app_role四角色值、auth.users PK(id)、auth.uid、active/role helpers、audit欄位及必要operator權限相容。
所需btree_gist及既有六個extensions可見；舊Stage referencing FKs恰為四筆且validated，delete策略與歷史相同。
ensure_rls / ddl_command_end / enabled O / 三個expected tags、postgres owner、零參數event_trigger、唯一search_path=pg_catalog仍匹配窄例外。
Epic5與Epic6只呼叫既有preflightSql純字串產生器，再執行其catalog SELECT；**沒有執行runner main、任何smoke case或fixture**。
兩者required RPC missing、RLS missing、不允許raw DML grants、private mutating helper application EXECUTE及unsafe search_path計數均0，唯讀安全PASS。

## Authority 與最小 aggregate

正式 private.learning_course_use_authorized 目前**不存在／未部署**；不得寫成已呼叫它而回傳false。
本機候選仍shipped false；P04/P05/P06/R04正向分支仍BLOCKED，未建立enrollment、假學生、progress或放寬policy。這不是此次preflight失敗，也不授權Epic8。
唯讀計數：learning_map_stages=5；auth.users、public_profiles、teacher_profiles、user_roles、bookings、lesson_credit_reservations、lessons、entitlements、orders均0。
另查Storage buckets=0、objects=0；這只是當下metadata/data-count，不代表未來或其他外部媒體永不存在。
沒有讀姓名、email、電話、訂單明細或學習內容。没有將資料庫空表推論為不需recovery。

## Backup / Recovery

2026-09-07T16:05:09.6436237Z（Asia/Taipei 2026-09-08 00:05:09）既有backup metadata：backups清單0、physical backup metadata無可用時間點、pitr_enabled=false、walg_enabled=true。
WAL-G flag不是可恢復時點；目前可用recovery point及時間 **UNKNOWN**。最新已知外部三檔仍在 C:/TheOneBackups/2026-09-05-pre-epic6-smoke：

| File | Bytes | LastWrite UTC |
| --- | ---: | --- |
| roles.sql | 370 | 2026-09-05T14:37:16.128Z |
| schema.sql | 550007 | 2026-09-05T14:38:27.116Z |
| data-public.sql | 6914 | 2026-09-05T14:39:01.210Z |

只讀已知backup root各日期資料夾的三種檔案metadata，沒有讀dump內容／hash dump／export。最新檔亦約49.5小時前。
檔案mtime不等於一致recovery point；上述三檔跨時點、缺Auth/Storage/history及全服務恢復範圍的歷史限制仍在。
The One自控的合格加密儲存、custodian/ACL/retention及完整可驗證事故目的地 **UNKNOWN**；沒有把家用路徑當成加密或所有權證明，也沒改ACL/儲存/服務設定。

| Gate | 當次狀態 | 缺件 |
| --- | --- | --- |
| BR-1 | UNKNOWN / NOT PASS | 當前usable restore path、合格加密保存及適用還原證據 |
| BR-2 | FAIL / NOT PASS | 無可證明小於1h的一致恢復點；已知舊檔超時 |
| BR-3 | UNKNOWN / NOT PASS | 已驗證正式事故destination、具名操作責任與完整服務恢復/切換/重開驗證 |

OWNER最大1h資料損失保持；**一小時保障UNKNOWN／未證明**，不是放寬24h、不是要求購買、也不是宣稱技術上做不到。
P2當時BR PASS及Epic5/6 REMOTE CLOSED保留歷史有效性；本機synthetic DB restore不等於正式The One完整事故恢復。

## 停止點與保留界線

沒有發現已查範圍的意外migration/object/security變更；完整源碼hash/全服務release漂移仍不可由此推論排除。
暫時本機分析命令有一次括號語法錯誤，未發正式查詢，修正一次性命令後完成；沒有修改任何工具或業務程式。
最初身分stdout/stderr合併導致JSON解碼拒絕；分離兩個stream後完整解析stdout成功，未弱化既有CLI parser。
正式提交的SQL僅SELECT/catalog/aggregate；沒有業務RPC、DDL、DML、備份匯出、restore、PITR、migration、smoke、cleanup、push或部署。
此陳述描述本輪提交命令，不宣稱供應商查詢log/statistics或內部連線管理零metadata活動。
**下一步B：準備正式Backup/Recovery的可審阅操作包**，补一致時點、The One自控加密保存、適用復原及全服務目的地；本輪不執行下一步。
完成這些gate後才可提出Remote Migration授權；沒有自動授權正式adapter或smoke。coverage/有限結案仍未批准，37案REMOTE NOT RUN，Epic7 REMOTE CLOSED=NO。
Epic5/6 REMOTE CLOSED；production payment-provider webhook NOT COMPLETE；不開始Epic8。OWNER目前不需登入或操作。

## 非秘密證據

Run ID epic7-production-readonly-20260907；詳細JSON位於ignored本機目錄 artifacts/remote-smoke/epic7-production-readonly-20260907/，不是隨Git自動攜出的檔案。
本文件版本化主要觀察結果；下列SHA-256綁定本機詳細證據，未攜出時不得假稱另一電腦持有原artifact。

| Artifact | SHA-256 |
| --- | --- |
| `aggregate.json` | `644009ac4c44eef714c88fc499a75d88f75206052da1cd84c9d1ea1268dd6e2a` |
| `backup-metadata.json` | `720c1eb221439cf46670e9cf5964e47d5dc3798f6d4354f21faf65b376e9f9be` |
| `catalog-local-review.json` | `066b95fb1c7485ac607fe7d14ed83342941af6862c16e838b4b95a86ea3a7f8c` |
| `dependencies-catalog.json` | `6f942db31df9af042e5f8662654b015acf7b6f77b637e6bf5bdac63e13b59dbc` |
| `epic5-security.json` | `303c7817c7d0f305d44eab150f8872a65f84c2538d1c67cb9ab895b638858c18` |
| `epic6-security.json` | `0524b9cf39232ae5e60dd694515d37503ea98c5602075f2cc9d9c9c8ca2ce0c3` |
| `epic7-objects.json` | `4c42723c1f9b2bd619a8aa0c62f382c6b33e03cc68583f7bb85e7d053a37336b` |
| `historical-source-comparison.json` | `fe46e5ba6e4d45b0210d60b637faf055bd80426504d2136c7a64653a8b0ef71c` |
| `historical-source-line-ending-analysis.json` | `f00d5eb8cfce5296f4ec70cd7324dc92d84fae770a19e312ba2b8d039c112f59` |
| `history.json` | `7d048bbe7f45f50f0e9bc21d946df1f762e399bc4f78c58ee86a6301c84eb788` |
| `identity.json` | `0bbf772c3367df9088b7defb244d696acaafe26c0eec49c6825678cb690f48cf` |
| `local-backup-files.json` | `f45087fefacbe0296a548dd817ee3944bc9afca5f8f56cfac7eceeb4c666aa49` |
| `local-migrations.json` | `46c80f8efb9b04eae7df75e372c0b9500e552d1b0da2aad6fafc787a30d23793` |
| `preserved-migration-hashes.json` | `70f61a5d0f87bbeec7715461401c0e53b6a77faa40c0e696c02d54f89147e75e` |
| `summary.json` | `8415c6ca194494dd4ae9f25c73c01ef708075abdb98740c9b9d29600ec194d14` |

本輪文件另做diff/link/conflict/secret檢查；沒有重跑本機SQL、build或production smoke。
