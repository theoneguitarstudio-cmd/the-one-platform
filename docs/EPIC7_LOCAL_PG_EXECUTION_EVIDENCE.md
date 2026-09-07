# Epic7-F 家用本機 PostgreSQL 執行證據

日期：2026-09-07。起點 main / 2eac1b9e8d69d0e3628120121f9a4f7058457325，working tree CLEAN。
目錄：C:/Projects/the-one-platform-home-2eac1b9。application / migration candidate 仍為 d5f98434106797afc65c59953aa3bc61ba26ecb4。
本輪使用者明確授權既有 Docker image、全新本機隔離容器、合成 SQL / race / rollback / recovery 測試及至多一個本機 commit。
不含任何正式操作、push、部署或 Epic8。此前禁止 Docker 的文字是歷史，本輪僅此本機範圍已被明確授權取代。

## 已完成與驗收界線

現有 shipped-false candidate 可執行的本機計畫已接上真 PostgreSQL：33 個 case IDs PASS；P04/P05/P06/R04 維持 BLOCKED_AUTHORITY。
完整 37 IDs 不改號、不刪案。這是本機計畫所涵蓋分支的實測，不把原正向 activity、correction 或 R04 race 填成通過。
原 compileCase.fullCaseProven=false 與歷史 OFFLINE/NOT_EXECUTED 計畫欄位保留；實際執行結果另存本輪 artifacts，不竄改歷史證據。
P02 的早期拒絕不代表授權後欄位驗證。既有 A–E local 證據保留，不由本輪較小的分支測試替代全部原 AC。
可以提出具體的正式唯讀 Preflight 申請；尚未授權執行。Epic7 REMOTE CLOSED=NO、37 案 REMOTE NOT RUN。
coverage 替代／有限結案契約仍未批准；不把隔離策略自動當成 deferral。Epic5/6 REMOTE CLOSED、payment webhook NOT COMPLETE 不變。

## 實際環境與工具

Docker 在本輪開始前已運行約29小時，未重新啟動 Desktop。已列出原有 Supabase containers，沒有修改、停止或刪除它們。
只讀原本機 Auth schema metadata 作 bootstrap，未讀其資料列；這不是正式 Auth 備份。
固定既有 image：public.ecr.aws/supabase/postgres:17.6.1.166，
SHA-256 b3bfedb107413abb3b8cb0d0874b0414a1dceb3d55bc0c778de6ad22d1f7dc86。
所有新容器 --pull=never、network=none、無 published ports、無 mounts，PG 僅 /tmp Unix socket，listen_addresses 空。
最終短期測試 cluster 在建立時 autovacuum=off，以固定 catalog 背景條件；正式或既有開發設定未更動，observer 檢查未減項。

本輪新增 tools/epic7-local-engineering/pg-*.mjs 與 legacy-budget-L01～L04.json。
未改 application、34 migrations、原9份工具、原 manifests、package/lockfile 或 Product Decisions。
最終 Node 24.19.0；初期 elevated shell 的 Node22結果分開保留。ESLint 使用家用既有安裝，未下載／安裝依賴；
新repo沒有 React 安裝，通用 lint config 的版本偵測提示不代表本轮 JS 有錯誤。沒有 build。

## 逐案結果與預算

最終 run：epic7-pg-final-6530c4b1-c928-43dd-a104-211ee54633c7。
其 summary.json 與各 ID.json / ID-plan.json（legacy 另引用固定 SQL 與預算）包含 candidate、run、fixture hash、時間、DB identity、action結果、rollback/retention、獨立before/after與STOP。

- S01–S04、H01–H05、C01–C08、G01–G03、V01–V02、P01–P03：25 PASS。
- R01–R03：3 PASS；真正不同 backend 的 held-lock barrier，由 pg_blocking_pids 確認 waiter，再允許 winner commit。
  驗證反向 edge cycle、exact freeze request retry、freeze/edit race。按原 manifest 精確保留82/81/81列（包含trigger rows），不刪除immutable資料。
- L01–L04：4 PASS；15份既有 legacy suite 的受控本機接線，共122/133/141/131 = 527 SQL assertions。
  逐敘述量測後審查固定預算，再獨立重測；所有 public/auth 表均核對，未列 delta 固定0，變化點之間沿用前一值。
  原固定SQL與遞迴include hash、每步資料量、各表峰值都保存。這些舊fixture只允許全隔離本機，不能直接用作正式run-scoped executor。
- L05：1 PASS；獨立唯讀 repeatable-read reader 覆蓋94個 public/auth tables、run keys、全表與非run摘要、catalog及sequence。
- P04/P05/P06/R04：4 BLOCKED_AUTHORITY，0 fixture writes；没有假 enrollment、policy replacement、直接 activity/progress 寫入或 Epic8。

所有 rollback 案獨立確認 run rows=0、整表與catalog/sequence一致。Race 兩次獨立讀取的key/count/content完全符合manifest，unexpected residue=0。
Actor/role、Course/Map/version/Node/resource/receipt/audit/activity/request 預算源自每案計畫且已實測。
L01～L04的預算僅本機fixture數量，不冒稱正式94表run-scope已可安全寫入。

## 真實失敗控制與復原

故障 run：epic7-pg-failures-80dcb2fc-8891-436e-8437-e506746aa767，13項 PASS。
實際測連線失敗、server timeout、aborted transaction、savepoint、錯rows、schema/version漂移、sentinel隔離、terminated backend後rollback失敗、
COMMIT後SQL錯誤及真正COMMIT後連線中斷。未知提交結果保持STOP；另一session查實際狀態，不用rollback抹掉已提交資料。
故障probe的合成已提交identity明列在artifact，保留在本輪容器；不是unexpected production residue或cleanup授權。

synthetic recovery 使用另一全新相同image無網路cluster，來源僅本輪新合成DB。
驗證schema/data、95表（含migration history）、extensions、roles、FK與有效ACL；不只比row counts。
ACL比對展開NULL/default ACL及grantor/grantee/privilege/grantable，不能以raw表示差異推論權限變動，也不忽略真grants差異。
SQL失敗保持STOP；正式可恢復時點與1h資料損失上限仍UNKNOWN。完整Auth/Storage/application/domains/traffic/secrets/connections等仍未驗證。
Synthetic DB restore不是The One完整事故恢復，未使用正式backup。

## 保留的失敗與修正

1. legacy-f7ee5780 的L03 CLIENT_DEADLINE：原psql條件式include與分段互相干擾。
   新增嚴格set/unset/if/else/endif解析，未知directive拒絕；不是移除fixture guard。6項parser/parameter回歸PASS。
2. cases-b561dee5 的C04 CATALOG_CHANGE：row與sequence未變；15:21:55.945–15:21:59.753 UTC內有多表autovacuum（約15:21:56.99）。
   原FAIL保留，沒有忽略catalog欄位。另建固定背景的短期cluster完成完整回歸；正式背景條件仍須另查。
3. schema fingerprint的PG char串接型別錯誤，已明確cast為text；只影響本機查詢。
4. synthetic recovery raw ACL表示差異，改為完整有效ACL比較並重測；沒有補GRANT湊PASS。
5. 已提交故障probe的固定email在重跑撞唯一鍵，改為run UUID email；舊資料保留，不DELETE。

## 下一步與授權

下一步為 owner 審閱並另行核准 exact The One target 的正式唯讀 Preflight，核對實際hosting、Supabase版本／catalog／authority、backup/recovery與服務inventory。
目前工具刻意沒有接受正式URL/credentials的transport入口。本機SQL、失敗與保留邏輯不是正式啟動器批准；正式adapter/操作契約須依唯讀事實及另次範圍審查。
正式備份、真實restore、migration、deployment、smoke、cleanup各自仍需批准。P04/P05/P06/R04的真authority與完整驗收缺口不能由本機測試豁免。
不開始Epic8、不重問D1–D5、不重新查已證實的GitHub App All repositories。

## 最終檢查

Synthetic recovery 最終 run：epic7-synthetic-recovery-9d17a25d-83e4-41fc-948b-c7bc63065d4b，5項檢查PASS，包括bulk ON_ERROR_STOP失敗後另一連線確認未提交schema不存在。
新增工具ESLint無errors/warnings（通用React dependency偵測提示另述）；parser 6/6、真PG故障13/13 PASS。
Preserved ValidateOnly PASS：269個受保護檔案、34 migration hashes及固定c61/d5內容鏈仍完整，未弱化hash/版本檢查。
所有正式connections/SQL/writes=0。沒有安裝、下載image、push或Epic8。

本輪先前6個新合成containers在驗證後均確認client sessions=0並停止，未刪除容器／資料；原開發containers未更動。
處置證據：artifacts/remote-smoke/epic7-home-local-final/container-disposition.json。

最後安全審查另加函式ACL/owner、role屬性及extension版本指紋，對新afd769ec target完整重測33 PASS / 4 BLOCKED；故障新增函式ACL漂移，最終13/13 PASS。
原target指紋只可建立一次，禁止重新seal消除漂移。最後第7個新container已停止且未刪除。
故障測試最後獨立核對新增Auth/profile/user_roles各2列，共6列且只有明列UUID，其餘全表、catalog與sequence不變；unexpected=0。
證據：最終fault run的independent-retention.json及epic7-home-local-final/final-target-disposition.json。
