# Epic7 Backup / Recovery 執行準備 — 2026-09-08

狀態：**計畫完成供審閱；執行前置仍 BLOCKED，未執行任何 export / restore。**
起點 main / 389c5485c77464943937ca4b08e3a7780e63d665，工作目錄 CLEAN。
本輪僅本機唯讀 storage/CLI/image 查證及文件；production connections=0。
依據：[本次之前的正式查證](EPIC7_PRODUCTION_READONLY_PREFLIGHT.md)、[canonical recovery policy](REMOTE_BACKUP_RECOVERY_RUNBOOK.md)、[既有授權包](EPIC7_RECOVERY_AUTHORIZATION_PACKAGE.md)、[P2證據](P2_REMOTE_CLOSURE_EVIDENCE.md)、[本機synthetic證據](EPIC7_LOCAL_PG_EXECUTION_EVIDENCE.md)。
OWNER本人最終核准、The One自控加密空間、最多1h損失、immutable優先隔離等決策不重問、不放寬。

## 1. 本機儲存實查與尚缺事實

2026-09-08 Asia/Taipei 本機快照：C NTFS可用52,091,383,808 bytes（約48.5 GiB）；D NTFS可用1,510,242,758,656 bytes（約1406.5 GiB）。
E/F/H/I為removable但size/free=0，沒有可用媒體證據；未掛載的NTFS系統分割區不作備份建議。
Get-BitLockerVolume回CimException；manage-bde -status C:與D:均明確Access denied，要求系統管理員權限。
這是Windows讀取權限不足，不是自動核准審查拒絕，也**不是已證明磁碟未加密**。沒有觸發UAC、修改設定或查recovery key。
C:/TheOneBackups的owner為目前win帳戶，但ACL繼承Users讀取及Authenticated Users修改；不符合僅指定operator存取。
C:/Projects有同類廣泛權限，且是程式位置，不作正式dump位置。D根目錄也有Users/Authenticated Users權限，不能直接新建繼承目錄即宣告合格。
C:/Users/win的ACL較窄（本人/System/Admin與一個capability SID），仍有未核定principal及C加密未明，不直接採用。
目錄attributes沒有EFS Encrypted；Compressed不是加密。家用電腦由使用者指認，但Windows檔案owner不等於The One法律/營運保管證明。
**沒有找到已可證明合格的位置。** 不改ACL、不開BitLocker、不買設備、不移動/雜湊/讀取舊正式dump。

只有指定磁碟確定加密保護有效、解鎖/復原能力由OWNER控制、路徑ACL核定且空間通過後，才建議新建：
`<verified-encrypted-root>/TheOneBackups/epic7-<UTC>-<run-id>/`。
這是條件式命名，**不是已批准實際路徑**。D空間較多不代表D已合格；本輪不建立目錄。
落地前須核對整條路徑無reparse/symlink轉向、不在repo/同步分享資料夾；子目錄有效ACL不含未批准群組。
只允許具名owner/operator與必要System/Admin，記錄管理員仍具存取能力。ACL變更須另行批准，本次不默認執行。
容量採下一輪讀取的actual database sizes與dump估計，至少容納export、restore展開、暫存、logs與保留餘裕；
提議reserve=max(10 GiB, 3倍相關DB實體大小)作保守起點，logical大小可能更大，必須監看剩餘容量，不足STOP，不以舊550KB直接估算。

**Docker的真實資料落地也要加密。** network none不加密Docker writable layer、VHD、host TEMP、pagefile或crash dump。
本輪settings-store已知磁碟位置欄位未回傳位置，Docker backing storage路徑/加密仍UNKNOWN；不能假設dump在加密D就能安全restore到未驗證C。
下一輪須在任何真實bytes進入前證明Docker持久層、暫存/日誌與可能swap所在位置的加密/ACL，或審閱不落地記憶體方案及host swap風險；本案不自動移Docker磁碟。

## 2. 下一輪輸入／輸出範圍

source固定為the-one-platform / ygxeihtcolpiulupieeq / ap-southeast-1。
先用既有登入的projects list重新驗三項身分，再以explicit ref的唯讀catalog/history核對remote29/latest20260904001100與本機34/五檔hash。
身分、未預期ID、物件形狀或憑證異常即STOP。禁止自動relink；`db dump --help`在CLI2.116.0本機確認支援--linked、--project-ref、--role-only、--schema、--file。
下一輪只沿用既有受控登入；密碼不作命令參數、不打印URL/token、不用--debug/--dry-run曝露連線資訊。
先核對CLI實際使用的本機pg_dump/image已存在且匹配；不能讓CLI隱式pull。若不能確認no-pull行為，STOP，不能偷偷下載或改用未審工具。

| 預計檔案 | 包含 | 不包含／限制 |
| --- | --- | --- |
| roles.sql | 既有CLI role-only輸出；核對實際角色清單 | 不保證含managed roles；不攜出production登入密碼/key，內容受敏感資料等級保管 |
| schema.sql | CLI既有application schema（public/private及實際輸出的依賴DDL） | managed Auth/Storage schema通常排除；不得把它視為完整cluster schema |
| data-public.sql | public資料，含實際catalog/config/history表的應用資料 | 不包含auth rows、private資料、Storage bytes或supabase_migrations |
| source-metadata.json | 同一致性窗口的exact history IDs/names、schema/owner/ACL/extension/FK/sequence metadata及摘要 | 不含帳密、業務rows；statement原文與秘密值不輸出 |
| managed-prerequisites.sql + prerequisites-manifest.json | 經審閱、只供隔離target的managed角色/extension/Auth必要DDL、原始來源/hash與適用差異 | 不是假users，不由image版本相同推論完整相容；不是正式全Auth備份 |
| manifest.json + SHA256SUMS.txt | 每檔bytes/SHA-256、UTC與台北時間、source/target、版本、scope、snapshot窗口、approval/保管/期限 | 不含秘密；manifest本身hash放SHA256SUMS，清單不自我hash |
| source-validation.json / restore-validation.json / disposition.json | 逐表counts/digests、constraints/security比對、STOP、隔離target及處置 | 真實row內容不入repo或對話；原始錯誤log可能PII，只限加密保管 |

既有三個未執行命令模板（`<approved-directory>`未填時不得執行）：

```text
supabase db dump --linked --project-ref ygxeihtcolpiulupieeq --role-only -f <approved-directory>/roles.sql
supabase db dump --linked --project-ref ygxeihtcolpiulupieeq -f <approved-directory>/schema.sql
supabase db dump --linked --project-ref ygxeihtcolpiulupieeq --data-only --schema public -f <approved-directory>/data-public.sql
```

三個命令各自開始/exit/完成時間以UTC保存，再換算Asia/Taipei；檔案採唯一run目錄且exclusive建立，禁止覆寫舊set。
文件皆完成、exit0、非空後用既有Get-FileHash -Algorithm SHA256取得原始bytes雜湊；不經文字轉碼、複製後重算並比較。
所有stdout/stderr先留加密受限位置；只輸出審閱過非秘密摘要，禁止把dump印到聊天或git diff。
manifest最低欄位：runId、approvedPlanCommit、approvalReference、operator/custodian、sourceRef/name/region、sourcePG/CLI/pg_dump/image版本、
local/remoteID集合、每檔開始/結束/size/hash、Tquiet/TfirstExport/TlastExport/Tverified/Tresume、futureMigrationTime=null、
scopeIncluded/excluded、sourceInventoryHash、snapshotMode、encryption/ACL證據、storageRoot、targetID/dataDirectory/image、
retentionExpiry、restore結果與STOP。未取得欄位用null/UNKNOWN，不能填PASS佔位。

## 3. 最小scope的硬性適用條件

上一輪Auth users=0、Storage buckets/objects=0、private無表，是**那一刻**，不能沿用成下一次export事實。
新窗口須核對所有Auth相關資料表/必要managed狀態與public→auth FK、Storage及private/其他必要schema，不只auth.users一張表。
若必要Auth資料、Storage內容、private資料或其他非public必要資料存在，三檔方案**在export前STOP**；改提完整scope方案供審，不造假身份補FK。
public循環FK表若非空，禁止沿用舊空表warning豁免；先明確設計含post-data constraints的順序/可延遲約束，不能disable triggers/RLS/session_replication_role。
現行最小分支以新鮮證據確認該循環資料scope為空才可用schema→data。其他合法public資料保留、逐表比對，不假設全庫空。
本輪無法讀出新的managed schema，因此prerequisites內容要在下一輪**開始export前**用當前唯讀來源核對/定版/hash；schema-only取證需列入該輪核准範圍。
只建立實際需要且與source一致的managed role屬性、Auth table/types/functions與extensions；密碼由隔離本機trust Unix socket替代，這是隔離連線差異，不改source。
若CLI/schema-only方法排除所需Auth DDL，或image不具所需extension，STOP回報具體缺項；不默認下載、不補fake auth rows、不猜DDL。

## 4. 一小時：恢復點不等於檔案mtime

A 檔案完成時間只是輸出完成；B 真正恢復點T是資料一致狀態；C 三次dump各有獨立交易/快照；D 持續writer會使三檔不一致。
CLI目前help沒有共同--snapshot選項；不能自行把三次dump標成同一秒snapshot。未驗證共享snapshot技術不當作已可執行fallback。
本次建議**受控靜止窗口**：先排空/阻止所有相關writer及schema/role變更，記Tquiet；三檔及source metadata/digests在同一窗口完成，確認始終無寫入。
這是「狀態在窗口不變」的證明，並非三個pg_dump共享snapshot。保守以T=Tquiet計齡。
僅前後counts相等或當下pg_stat_activity沒writer，不足以證明整段無写入；還需具名操作人的入口/worker控制與觀測。

提議預留**15分鐘停寫窗口**：目標10分鐘內完成export，另5分鐘核對/恢復入口；這是待核准上限，不是已量測SLA。
需暫停註冊/Auth變動、Teacher/Trial管理、下單/付款確認、Entitlement/Scheduling操作、worker/排程/外部writer與手動DDL。
純讀頁面若與上述入口可安全分離可保留；登入也可能寫Auth session，不能保證「網站完全不受影響」。不得只停網頁而遺留其他writer。
The One hosting、入口/worker、maintenance操作與rollback方法仍UNKNOWN，因此目前**無法承諾可實際停寫或不停網站**。
OWNER未來須批准具體入口控制方法、開始/截止時間、影響、恢復程序。禁止以GRANT/REVOKE、改RLS或設DB全域read-only繞過未知入口。
若證明尚未開放任何writer且能維持窗口，才可記「不用額外停網站寫入」；不從空表推導。
到10分鐘未完成停止後續export；取消/關閉讀取、保留partial為FAILED，不自動重試。依預先核准的原入口恢復程序在15分鐘內退出窗口；未知恢復結果立即通知OWNER，不自動延長停寫。
還原drill在來源窗口關閉後進行，不把網站一直停到drill完成。建議先預留30分鐘drill觀察時間，但不承諾耗時；超時停止target工作並保存失敗狀態。

未來migration gate要求 `0 <= migration開始UTC - T <= 3600秒`；每份實際apply前再核對，建議在T+45分鐘前開始以留餘裕。
clock未知/未來時間、scope缺漏、窗口不成立、drill失敗或>3600秒都STOP。mtime/copiedAt不能代替T。
**條件成立時可滿足當次1h要求，但現在未證明**。完整BR-1/3或OWNER審閱若超過1h，該set可留作drill證據，不能留作之後migration的fresh gate。
下一輪只有backup/drill，不包含migration；等migration另批准時很可能需再核准近時點backup。一次備份不保證持續1h事故保障。

## 5. 隔離restore drill程序（只規劃，不建立container）

本輪只read-only image inspect，固定既有linux/amd64 image確實存在：
`sha256:b3bfedb107413abb3b8cb0d0874b0414a1dceb3d55bc0c778de6ad22d1f7dc86`（歷史PG17.6）。
下一輪再次attest image/server_version_num=170006、來源PG相容，不用latest/pull。

1. **先保管後資料**：核定加密backup、Docker持久層/TEMP/log/swap與ACL、足夠容量、operator/retention/處置；任一UNKNOWN不得接收真實bytes。
2. 新target名稱 `theone-epic7-recovery-<run-id>`，label標明recovery run與source ref，記錄實際64字元container ID；與source、既有開發/合成容器完全不同。
   建立模板：`docker --host npipe:////./pipe/docker_engine create --pull=never --network=none --restart=no --name <new-name> --label theone.recovery.run=<run-id> --entrypoint /bin/bash <fixed-image-sha256> -c "sleep infinity"`。
   不加-p/-P/host network/socket mount/production env；不掛正式目錄寫入。檢查network=none、PortBindings空、mounts空、固定image與entrypoint；再啟動這個新target。
3. 在新target內由postgres執行initdb，獨立`/tmp/theone-recovery-data`；pg_ctl只監聽`/tmp` Unix socket、listen_addresses空，新DB名`theone_recovery_<run-id>`只允許已驗證字元。
   實際target identity包含run marker、containerID/image、database/data_directory/backend/version。禁止接受DB URL或任意existing container。
4. 先restore managed prerequisites的角色與extension/type/Auth依賴，再roles.sql，再schema.sql，最後data-public.sql及history procedure。
   postgres等initdb已有角色先作exact屬性比對，依審閱restore plan只執行尚未建立者；原backup bytes/hash保持不變，任何調整必須有逐敘述對應與理由。
   不用--no-owner悄悄忽略owner，不忽略duplicate object/error，不把synthetic腳本直接套真實dump。
5. Auth schema/helpers要來自經核對的實際compatible DDL；最小分支沒有Auth資料時仍需正確Auth PK/FK/helpers。發現非空必要Auth就停止最小方案，不造假users。
   Extension name/schema/version與角色ownership逐項比對；managed權限差異不能因「只有本機」就略過。
6. 以`psql -X -v ON_ERROR_STOP=1`經docker exec -i/stdin從加密input傳入，不在shell argument/log印SQL。角色等transaction限制分開review；可交易的schema/data階段使用明確交易。
   不執行任意\!、program COPY、未審include、外部連線或秘密locator；dump中的必要psql版本指令逐項allowlist，不盲刪指令。
   任何exit非零立即STOP，記phase/SQLSTATE，後续data/history/驗證不得當PASS。部分已完成phase保留原況；不是整段一定rollback。
7. **Migration history**：三檔不含history。由同窗口source-metadata的29個實際ID/name與來源schema/原29檔證據確認後，僅在新target建立相符metadata；不套Epic7五檔，不執行production repair。
   精確source history schema及statement欄位語意先review；若沒有完整statements，不捏造其內容。ID/name重建只能標「metadata reconstruction」，不能稱history bytes完整還原。
   若目的要求完整history recovery，必須另列並批准完整history export檔案，不能讓最小分支冒稱完成這項要求。
8. 第二個獨立target session讀取所有included表counts及穩定排序row摘要、sequence值、FK/check/unique驗證、policy、有效table/column/function/default ACL、owner、role、extension與function/trigger shape。
   source基準必須來自同一靜止窗口；後續已恢復寫入的live DB不能作相同時點比較。摘要只留加密位置；聊天只報PASS/FAIL/count，避免PII及低熵值可猜測hash外傳。
   明列OID/pid/internal stats等不可跨cluster比較欄位；有效ACL展開NULL/default與grantee/grantor/privilege/grantable，保留所有真權限差異，不能寬鬆忽略。
9. 47 public表只是上一輪baseline；下一次以actual included inventory完整覆蓋，缺表/多表/遺漏scope、FK invalid、hash mismatch、owner/RLS/ACL漂移皆FAIL。
   005 Epic7不存在是正常；不在drill套五份migration或跑37案。僅驗新DB可連線與catalog/資料完整性，不向外發Auth郵件/付款/媒體請求。
10. 完成或失敗皆關閉session、核對新target無client後停止新target；**停止不等於刪除真實資料**。
    提案backup保留7天、drill target及原始錯誤log保留最多24h以供審阅；期限/保管人須OWNER核准。
    到期處置另列exact container ID、資料層/加密input/log範圍供批准；不自動prune/delete、不能承諾docker rm等於SSD安全抹除。到期尚未批准應通知，不自動續期為永久保存。
    不touch舊containers、舊backup或source；失敗保留在核定加密隔離位置，不能DELETE修到PASS。

既有pg-recovery.mjs固定syntheticOnly與34份chain，且使用合成全DB dump；**不是這次29份真backup執行器**。
保持原工具guard，不偽造synthetic manifest、不降低hash/版本檢查。下一次以本計畫受控逐步命令執行，實際inputs/hash/target審查合格才開始。
已讀既有synthetic result：95表/5項PASS，來源與target均合成，fullServiceRecovery=false；本輪不重跑，不轉成真restore PASS。

## 6. BR gate checklist與整站復原

| Gate | PASS的必要證據 | 目前 |
| --- | --- | --- |
| BR-1 | 新backup完整完成、清楚scope與一致點、The One加密保存/存取、特定輸入在相容非production target成功還原且符合宣稱範圍 | UNKNOWN / NOT PASS；最小DB-only drill不代表未涵蓋Auth/Storage已備份 |
| BR-2 | 每次migration前以真正T計算<=3600秒，clock可靠、scope一致、drill已成功；不是檔案mtime | NOT PASS；目前無新set，舊49.5h是上一輪時點，不是今日freshness |
| BR-3 | 具名operator、事故目標/方式、可恢復T、停寫/停機/流量影響及全服務驗證與重開流程皆已記錄並證實可用 | UNKNOWN / NOT PASS；Docker DB drill無法單獨通過 |

| 整站項目 | migration前須寫清楚 | 現況／下一份證據 |
| --- | --- | --- |
| Database | R0–R6分類、forward-fix優先、核准restore方式/目的地與損失窗口 | 本機drill可規劃；正式事故destination UNKNOWN；原地restore另需第二operator |
| Auth | 真schema/data/providers/session/SMTP/redirect復原及驗證 | 上次users0不代表設定可恢復；不寄信，實際設定/還原程序UNKNOWN |
| Storage | bucket/object與外部media備份、ACL/簽名讀取恢復 | 上次buckets/objects0；下次確認；不把DB-only稱檔案backup |
| application | hosting account/project、目前/rollback release與相容性 | UNKNOWN；不查Vercel/GitHub、不推送試驗 |
| domains / traffic | 真入口、停寫控制、DNS/CDN/維護與回復命令 | UNKNOWN；必須先界定才可核准15分鐘影響 |
| env / secrets | 核定secret store、custodian、restore/rotation及部署引用 | 值不入文件；目前保管/完整恢復UNKNOWN |
| connection strings | source/target/TLS/pooler與舊writer隔離、重連驗證 | 不記值；目前全服務切換UNKNOWN |
| extensions | exact版本/schema/owner與可離線建立相容套件 | 上輪catalog及本機image可沿用取材，下一輪核對實際來源 |
| migration history | 同窗口29 IDs/來源檔案與schema對照、reconstruction/完整export區別 | 不repair source、不造34IDs |
| reopen writes | parity/資料/security/連線及另核准Epic5/6 smoke、Auth/Storage/app驗證後OWNER簽核 | 正式事故流程未實測；本輪不啟動 |

Realtime/Edge Functions/jobs若實際使用亦須納入，不從repo沒呼叫推導N/A。
15分鐘backup窗口恢復入口與真正事故restore後重開是兩種程序；後者要求完整BR-3及事故核准，不能互相代替。

## 7. 可批准程度與本輪檢查

[白話 execution request](EPIC7_BACKUP_RECOVERY_EXECUTION_REQUEST.md)狀態只為PENDING OWNER APPROVAL。
這輪已完成不匯出資料即可做的計畫、storage可見性查證、CLI help、image存在核對及文件一致性；沒有新增validation tooling，因此只做文件link/conflict/secret/diff檢查。
目前不能宣稱「只差一句核准便可無條件執行」：加密/ACL/保管與Docker落地、真正停寫入口仍缺外部事實；不能自行更改這些設定來湊齊。
下一輪實際來源inputs的prerequisite/hash審查是明列先決步驟，若變化超出本最小scope則先停，不在owner已批准名義下擴大export。
Epic7 REMOTE CLOSED=NO；P04/P05/P06/R04保持BLOCKED；Epic5/6 REMOTE CLOSED、payment webhook NOT COMPLETE，不開始Epic8。

本輪文件驗證：5份文件、59個相對連結PASS；conflict/常見secret patterns無發現；git diff --check PASS。沒有重跑37案、SQL/race/build/preserved validation。
