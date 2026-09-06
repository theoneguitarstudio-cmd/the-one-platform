# Epic7-F Local Readiness Tooling Evidence

2026-09-06：**本機工具準備完成；正式執行未授權；Epic7 REMOTE CLOSED = NO。**
候選 application/migration SHA：`d5f98434106797afc65c59953aa3bc61ba26ecb4`。
新工具是未提交版本，以 [tooling manifest](EPIC7_F_TOOLING_MANIFEST.json) 的 SHA-256 綁定。
Branch main、local origin/main `588811d1d5617788b162f4e0a275d64d6a248dce`、ahead/behind 5/0 未變。
實際 remote main 沿用前輪 ls-remote/API 證據，本輪未重新查空集合 API，亦未 push。

## GitHub Apps：使用者提供的新證據

使用者提供的 `螢幕擷取畫面 2026-09-06 222300.png`，確認
**theoneguitarstudio-cmd/the-one-platform 的已授權 GitHub Apps 清單包含 Vercel**，右側有 Configure。
這是使用者提供的設定頁截圖，不是本輪 agent API 查證或 hosting deployment artifact。
使用者再提供 `螢幕擷取畫面 2026-09-06 223229.png` 與 `螢幕擷取畫面 2026-09-06 223234.png`：
帳戶為 theoneguitarstudio-cmd，App 為 Vercel，Repository access 顯示 **All repositories**。
App 已安裝與程式庫授權範圍兩項均有使用者提供的頁面證據，不再要求重查同一授權頁面。
剩餘缺口是 The One 實際 Vercel account/team/hosting project、repository/branch 連結及 build/auto-deploy。
截圖不證明網站專案存在或不存在，也不確認 main push 行為；頁面的示意部署圖片不算 The One 部署證據。
push 安全仍未通過。未操作 Configure、Save 或建立 Vercel project。

## 交付與本機命令

| 工具 | 責任 |
| --- | --- |
| [readiness](../scripts/epic7-readiness.mjs) | 預設／--validate-only 純離線；HEAD、migration hashes、37 IDs、來源與宣告，executionAllowed=false；不 import DB adapter |
| [case manifest](../scripts/epic7-readiness-cases.json) | 37 原 ID 的前置、角色、LOCAL/REMOTE、commit/retention/side effects、未核准延後 |
| [local adapter](../scripts/epic7-readiness-local.mjs) | 固定本機 Docker named pipe、精確 image/container/name/label/process、network none、無 mount/port；DB run marker/data directory |
| [rehearsal](../scripts/epic7-readiness-rehearse.mjs) | 建立自己的新 target、合成 bootstrap／原 migrations／既有 tests、記錄 FAIL、限定 owned container disposal |
| [existing helper](../scripts/epic7-local-db.mjs) | 加入顯式 EPIC7_F_TARGET_MANIFEST 分支；未設定時舊 local helper 行為保留；本輪未操作其四個既有 DB |
| [safety tests](../scripts/epic7-readiness.regression.mjs) | 29 個 offline/參數/hash/target/DB marker 拒絕測試 |
| [process tripwire](../scripts/epic7-readiness-offline-tripwire.mjs) | 真實 CLI 子程序攔截 fetch/socket/http/child process/.env 讀取；觸發即失敗 |
| [effects regression](../scripts/epic7-readiness-effects.regression.mjs) | 19 個合成 runtime/privilege assertions，補 S02/S03/H03/H04/H05/C08；不執行 TRUNCATE |
| [build reproduction](../scripts/epic7-readiness-build.mjs) | 無 .env 的 disposable source copy、pinned pnpm、test/lint/typegen/typecheck/兩種 build |

離線：`node scripts/epic7-readiness.mjs --validate-only`；省略 flag 也是 ValidateOnly。
工具測試：`node --test scripts/epic7-readiness.regression.mjs`。
本機演練：`node scripts/epic7-readiness-rehearse.mjs --create-isolated --epic7` 或 `--legacy`。
身份查閱：`node scripts/epic7-readiness.mjs --local-manifest <this-run-target.json>`，不因此執行 smoke。
隔離 build：`node scripts/epic7-readiness-build.mjs --isolated-copy`，需先取得 integrity-verified pnpm 10.34.5。

`--production` 固定拒絕；**沒有 production adapter**。不接受 --yes、DB URL 或環境密碼作為授權。
未來 writer 必須另經 target/SHA/hash、當次 BR、case set、fixture/retention、具名 operator approval review。
本輪交付拒絕入口與要求，不宣稱 remote writer 已可執行。

## 實際結果及 artifacts

Artifacts 在 ignored `artifacts/remote-smoke/`，沒有正式 dump；每次 result.json/log hashes 保留成功及失敗。

| Evidence | 結果 |
| --- | --- |
| ValidateOnly | PASS，37 IDs，executionAllowed=false；真實 CLI 在 network/process/.env tripwire 下通過，無 DB/SQL/Auth/sequence/migration/cleanup |
| Safety tests | 29/29 PASS：production/--yes/localhost URL、hash/HEAD drift、缺來源、錯 image/name/label/ID/network/port/mount/process/DB marker 都拒絕 |
| 最終 Epic7 | `epic7-f-local-d504bec278231e3310de221033fd4b06`：23 structure + 29 lock + 237 existing Epic7 + 19 new assertions、六種 races、security/disposal 全 PASS |
| 最終 legacy | `epic7-f-local-a5fda7855a60095c32e912e07db7672a`：39 SQL suites / 1480 assertions PASS |
| 最終 application/build | `epic7-f-build-8ed822b9a9737785`：24 files / 219 tests、lint/typegen/typecheck、Turbopack/Webpack 全 exit 0 |
| 新工具 ESLint | PASS；涵蓋新 scripts 與修改的 helper |

原 SQL coverage 1717 + 新 assertions 19 = 1736；重跑的 52 structure/lock 已包含於 legacy 1480，不重複加總。
49 smoke tooling tests 包含於 219。37 計畫 rows 是 coverage 分類，不是 assertion 數。
逐案 [coverage matrix](EPIC7_F_CASE_COVERAGE.md) 保留 REMOTE NOT RUN；沒有捏造 approved deferral。

### 保留失敗與最小工具修正

- `epic7-f-local-0c9b24abe1b2d46dba77f8bc80d3b26c` 在 60s batch timeout 中止；
  `epic7-f-local-35dadfe4f49d3c099aa3e24ead8d8058` 在 180s 中止。Fixed checkout hold 從 assertion 30
  進展至 68，未出現對應 not-ok business assertion。兩次 overall FAIL 保留，owned disposal PASS。
  工具改為 SQL batch 600s、外層 suite 1200s；每 statement 120s、lock 10s 仍保留。
  第三次同一組未改 SQL suites 完整通過；沒有修改 application/migration 來消除 timeout。
- 初版 build `epic7-f-build-368a5ede6b426252` 的 typecheck exit 2，乾淨副本缺 Next 產生的 LayoutProps。
  Tool 加入 `next typegen` 後重測全通過；沒有改 tsconfig、build script、dependency 或 lockfile。
- 早期 Epic7 run `epic7-f-local-0380a7ff0b9b807a61343872e8f60b07` 是六個關鍵表 count observer。
  最終 Epic7 run 擴成全部 94 個 public/auth 表 count + digest，並補 runtime denials。
  Legacy run 使用當時六表 observer，不宣稱它也跑了後來的 94-table observer。
- result.json tools 欄位是結果彙整時 hashes；legacy run 期間獨立加入了 observer/metadata，不能把該欄位
  當作它使用後來 observer 的證明。Legacy SQL suites/migrations 與 candidate bytes 相同；最終 Epic7 run
  才是最終 adapter/observer 的執行證據。case manifest 後續只補 evidence/status，未改 ID/SQL，另重跑 offline/safety。

## 隔離、rollback 與不可變證據

固定 image：`sha256:b3bfedb107413abb3b8cb0d0874b0414a1dceb3d55bc0c778de6ad22d1f7dc86`
（Supabase PG 17.6.1.166）。每 run 隨機 ID 與唯一 container ID/name/label；network none、無 mount/published port；
固定本機 Docker named pipe，不接受 localhost URL/tunnel。新 PG `/tmp/epic7-f-data` 讀回本輪 run marker。
`epic7_race_20260906` 是**新容器內**名稱，不是原開發 container 的同名 DB。

只從核對 ID 的原本機 container 讀 auth schema-only metadata，沒有讀正式 backup 或任何資料列；原 DB 未 reset。
positive progress 沿用已核准 local fixture contract，authority stub 只存在新 synthetic container/rollback transaction；
以 authenticated Student RPC 測試，沒有 superuser 直接寫 activity 冒充成功。race finally 恢復 false，security review 再確認。
既有 local corruption regression 的 trigger 操作是測試 guard，不是為 cleanup 繞過不可變保護。

- Rollback-only suites 前後，獨立 psql session 比對 **94 表 count/digest 一致**。
- Source catalog sequence 為 auth.refresh_tokens_id_seq；沒有 Auth/Storage API。
  直接 trigger bodies 未命中 net/http/dblink/pg_notify tokens，這不是窮舉 call graph 證明；network none 是實際隔離。
- 明確新建 synthetic sequence probe，nextval 後 ROLLBACK 仍為 last_value=1/is_called=true：**增號不回滾**。
  未 setval/reset 掩蓋，probe 隨 owned container disposal 處置。WAL/log/獨立 commit 也不由 ROLLBACK 保證消失。
- 六種 races 後沒有其他此 DB sessions，transaction locks 隨 session 結束釋放。
- Committed synthetic manifest：Auth users 6、profiles 6、roles 9、Course/Map 各 1、publications 2、audit 10、
  mutation receipts 7、activity 2、activity requests 3；並保存全部 content/version/link counts/digests。
  specialties 9/legacy stages 5 是 baseline seeds，不算 race 新殘留。
- 記錄後只銷毀精確 attested owned container；沒有 DELETE immutable rows、改 history、停 RLS/triggers、
  session_replication_role 或 reset sequence 來清理。所有本輪容器（含失敗 run）disposal PASS。
  Production committed fixtures 必須另外核准保留/處置，不沿用此 synthetic disposal 授權。

## 工具版本及兩種 build

一般 sandbox shell：Node 24.19.0 / PATH pnpm 11.19.0。
Windows Docker host：Node **22.23.2**，`C:/nvm4w/nodejs/node.exe`。
先前 LOCAL CLOSURE 文件沒有 exact Node/pnpm capture，不能由稽核時版本倒推；本輪新 artifacts 記錄实际版本。

依 packageManager 從官方 npm registry 取得 **pnpm 10.34.5** 至 ignored isolated directory，驗證 SHA-512 integrity。
無 global/corepack 設定變更、dependency install、package/lock 修改。Next package/lock/installed 都 **16.3.3**。
source copy 排除所有 .env；僅 synthetic.invalid URL 與明確假的 keys。Google Fonts 可能存取公開端點，build 不宣稱零網路；
沒有正式 DB endpoint/有效憑證。只有 ValidateOnly 要求且證明完全離線。

| Command（Node 22.23.2 / pnpm 10.34.5） | 最終 exit |
| --- | ---: |
| pnpm run test | 0 |
| pnpm run lint | 0 |
| pnpm exec next typegen | 0 |
| pnpm run typecheck | 0 |
| pnpm exec next build | 0 |
| pnpm exec next build --webpack | 0 |

舊 Turbopack OS error 5 仍保留為歷史 log；新隔離副本沒有重現，不宣稱已定位舊錯誤唯一根因。
沒有因此宣告正式 Vercel build command/Node/compatibility PASS。

## 恢復包與分項 gate

[恢復授權包](EPIC7_RECOVERY_AUTHORIZATION_PACKAGE.md) 已列 source、三檔 hash、scope/排除、Auth/history 缺口、
加密/operator/RPO 未知、isolated destination、順序與 STOP 條件。舊 set 已超過 24h，本輪未 export/restore。

| 動作 | 尚缺／授權 |
| --- | --- |
| 本機準備 | 完成；未提交工具與 evidence 可供 review |
| Git push | 未授權；App 安裝與 All repositories 已有使用者證據，實際 hosting linkage/main push 行為未查明 |
| 正式 export / 真實 restore | 未授權；operator、加密位置、RPO/一致性、managed Auth/history restore procedure |
| Remote migration | 未授權；當次 BR/rollout/operator gate |
| Application deployment | 未授權；hosting project/repo/branch/build/install/Node |
| Remote smoke / cleanup | 未授權；case/retention/authority coverage 契約及 production executor review |

P04/P05/P06/R04 LOCAL PASS 不取代正式 authority 缺席的 REMOTE BLOCKED。建議 acceptance review 明確記錄
shipped deny-only scope 與正向 coverage 的處理；沒有已核准 defer contract，不降低驗收、不要求先做完整 Epic8。
Epic7 A–E LOCAL CLOSED，Epic5/6 REMOTE CLOSED，payment webhook NOT COMPLETE；沒有新增未來 scope blocker。
本輪不 stage/commit/push、不改 34 migrations/product schema/application/RLS/grants source、無正式操作。
