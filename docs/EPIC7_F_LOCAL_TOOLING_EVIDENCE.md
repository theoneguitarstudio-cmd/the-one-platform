# Epic7-F Local Readiness Tooling Evidence

## 2026-09-07 本次增量：離線compiler/controller（非舊測試重跑）

基線49b7d23，Node24.19.0；新增 tools/epic7-local-engineering 七檔。
70 targeted offline tests PASS / 0 FAIL，ESLint PASS；原73tests／policy7tests／ValidateOnly／SQL/build未重跑。
新測試包含37個plan編譯檢查，並非37案實際資料庫執行。實際PG domain驗證NOT RUN。
最終logs、verification、37plans、tool hashes：`artifacts/remote-smoke/epic7-local-engineering/compiled-0ad3ffdf-9db8-4383-820f-5782f724863e`。
控制流程結果/獨立observer：`artifacts/remote-smoke/epic7-local-engineering/a63b66d2-c7be-4151-acd5-1d76b706d6e9`。
失敗修正：race編譯作用域、include regex；另修正共享payload與driver模式字串可被冒用的入口，已加新回歸。
本機Docker named-pipe API不存在（PIPE_NOT_FOUND）；PATH未找到psql/postgres，未啟動/下載/安裝。
因此真正driver/SQL/transaction/race與legacy新預算未完成；詳細限度見[工程審查包](EPIC7_EXECUTOR_ENGINEERING_REVIEW.md)。
正式DB connections=0、正式SQL=0、正式write=0；不push/deploy/backup/restore/cleanup/Epic8。


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

## 保存後固定內容驗證與契約收斂（2026-09-07 Asia/Taipei）

以上為原本機準備時點的證據，未重寫其「未提交」狀態或舊results。原候選d5f9843的application/migrations
與受測工具已於 `c61cdb6c757499b875fc9e9f41657f8b2c1a4ef1` 本機保存，未push；本節工作開始為main、
clean、相對本機origin/main 588811d為6/0。原入口因HEAD不是d5而拒絕是可重現限制，不能靠改candidate字串解決。
原工具沒有同時驗application完整內容與全部tool hashes的接續CLI；直接呼叫validate({head:...})只是測試注入，
不是合法版本证明。因此保留9個工具與舊manifest bytes不變，另增兩個專用檔（不是第二套DB/授權框架）：
[驗證入口](../scripts/epic7-preserved-validation.mjs) 與 [局部測試](../scripts/epic7-preserved-validation.test.mjs)。
獨立檔的必要性是不能修改舊受測runner/manifest而冒稱其舊hash仍有效；新入口只證明固定保存內容等價。

### 四個版本身份與驗證界線

1. 原application/migration candidate：`d5f98434106797afc65c59953aa3bc61ba26ecb4`。
2. 原受測工具：舊manifest的9個SHA-256，保存前最後case manifest只補evidence/status，已另跑offline/safety。
3. 保存commit：`c61cdb6c757499b875fc9e9f41657f8b2c1a4ef1`，其唯一parent固定為d5；原17檔diff無app/migration。
4. 本輪驗證器：新檔bytes由本節SHA-256與提交後ignored receipt綁定，不把它說成當時SQL/build用的工具。

新入口從固定c61 Git commit/tree/blob鏈讀取，逐object驗SHA-1/type/size，並驗固定parent/candidate object。
比較當前269個已保存非docs/非.env檔的Git內容；只對Git正常文字CRLF→LF，binary不改。
原9工具/34 migrations再按保存的舊manifest逐一比對**raw SHA-256**，不接受重算的manifest。
docs可追加新契約，但舊manifest固定、machine cases固定、原37IDs仍由舊validator驗；受保護source/scripts/tests/
public/migrations出現未列新增檔也拒絕。僅兩個本輪reviewed驗證檔是明列新增例外。
不接受candidate/HEAD override、任意ancestor或--yes。不是忽略SHA：以固定object鏈與實際完整受保護內容
替代不適用於保存commit的HEAD相等式；在相同內容的後續文件commit可驗，不代表新HEAD已做舊SQL/build。
通過全部內容檢查後才import已比對的舊runner，向其測試介面提供已證明的candidate，executionAllowed永遠false。
這是本機content verification，**不授權local rehearsal/production execution**；舊執行入口的HEAD guard維持不變。

新驗證器本身是reviewed code信任起點，不能以自行回報hash證明自身未遭改寫；執行前以此已reviewed SHA或
保存commit的Git blob核對新驗證器/測試。不把任意修改的新驗證器列入可接受組合，也不內嵌自身最終commit SHA。
目前source SHA-256：`f0394a2b0732a2de5e41aeaf57e73ca6ff4f53c6cb8d4fc28ef4732e6f82c74f`；
test SHA-256：`d03bbfb6ae07ba5a63bb0a0bc7a73abcb7563c823e8f05fc6424987bcca7ac56`。

### 可重現命令與offline object cache

工作目錄 `C:/Projects/the-one-platform`；Node 24.19.0（本輪sandbox），未安裝或升級依賴。
實際執行：`node scripts/epic7-preserved-validation.mjs --validate-only`；
`node --test scripts/epic7-preserved-validation.test.mjs`；只lint兩個新檔。
13/13 PASS：固定內容、偽candidate參數、production/yes、app/migration/tool/cases/manifest篡改、candidate object
替換、缺object；真實CLI在既有network/process/.env tripwire下PASS，0 DB/SQL/network，executionAllowed=false。
沒有重跑SQL/races/雙build；9舊工具、34SQL與app內容未變，沿用原限定範圍結果。新結果只覆蓋新驗證器。

Git有packed objects；初版只讀loose object失敗（7/13），補offline已驗hash object cache後發現既有Git文字CRLF
差異（12/13），改為上述Git文字比對加原raw hashes後13/13。這些是本輪驗證器修正，不是候選產品缺陷；
沒有修改舊logs或用新hash掩蓋未測工具。CLI不啟動git、不fetch或unpack；缺object/cache則拒絕。
cache只含固定Git中已提交的object bytes，不是正式DB資料；不提交Git。可在**本機已有兩個commit時**
用以下唯讀Git命令建立；GIT_NO_LAZY_FETCH=1，未授權fetch，缺物件即失敗。它只準備cache，不是ValidateOnly：

```powershell
@'
const fs=require('fs'),cp=require('child_process'),z=require('zlib'),crypto=require('crypto');
const git=(...a)=>cp.execFileSync('git',['--no-replace-objects',...a],{env:{...process.env,GIT_NO_LAZY_FETCH:'1'},maxBuffer:16*1024*1024});
const ids=new Map();
for(const c of ['c61cdb6c757499b875fc9e9f41657f8b2c1a4ef1','d5f98434106797afc65c59953aa3bc61ba26ecb4']){
 ids.set(c,'commit');ids.set(git('rev-parse',c+'^{tree}').toString().trim(),'tree');
}
for(const row of git('ls-tree','-r','-t','c61cdb6c757499b875fc9e9f41657f8b2c1a4ef1').toString().trim().split('\n')){
 const[,type,id]=row.split(/\s+/);ids.set(id,type);
}
const bundle={};
for(const[id,type]of ids){
 const b=git('cat-file',type,id),raw=Buffer.concat([Buffer.from(type+' '+b.length+'\0'),b]);
 if(crypto.createHash('sha1').update(raw).digest('hex')!==id)throw Error('hash');
 bundle[id]=z.deflateSync(raw).toString('base64');
}
fs.mkdirSync('artifacts/remote-smoke/epic7-preserved-validation',{recursive:true});
fs.writeFileSync('artifacts/remote-smoke/epic7-preserved-validation/objects.json',JSON.stringify(bundle));
'@ | node
```

本機cache已建立381個verified objects；保存cache不是信任其內容，讀取時仍按固定Git物件鏈驗hash。
本輪最終commit身份、Node、兩個新工具hash與ValidateOnly結果放同目錄post-commit.json，提交後產生，
不將最終SHA回寫本文件、不amend。此receipt只是此次執行紀錄，不是production approval。

### Canonical交接差異與待審內容

CURRENT_WORK原「uncommitted」是保存前描述，已追加c61保存註記；PROJECT_STATUS保留A–E歷史Turbopack失敗，
F後續兩種build PASS見本文件，不回寫成A–E當時通過。Local Execution的push-ready YES也是舊機械準備判斷，
不可覆蓋後續hosting未查明與PUSH NOT AUTHORIZED。P2的早期next Epic7文字是歷史，不倒退目前A–E/F進度。
新[coverage條款](EPIC7_F_CASE_COVERAGE.md)與[兩條復原路徑](EPIC7_RECOVERY_AUTHORIZATION_PACKAGE.md)
均NOT APPROVED；保留Epic5/6 REMOTE CLOSED、Epic7 REMOTE CLOSED NO及payment webhook NOT COMPLETE。

## 公司本機executor安全核心驗證（2026-09-07；非正式executor結案）

本輪起點 `0af06802dbeb2fcd614d33db3e64c441fe711be4`，工作目錄為新獨立handoff專案。
新增[工程審查包](EPIC7_EXECUTOR_ENGINEERING_REVIEW.md)、四份tools/epic7-executor工具及
[review manifest](EPIC7_EXECUTOR_REVIEW_MANIFEST.json)。原驗證器、九歷史工具、candidate application與34 migrations未改。
本輪在Node **24.19.0**、既有offline tripwire下只測新增安全功能：**73 tests / 73 PASS / 0 FAIL**；
四份新檔ESLint exit0；新增CLI `--simulate` exit0，executionAllowed=false、正式connections/SQL/writes全部0。
首次shell解析到Node22，因不支援test-isolation選項在測試啟動前拒絕；改明確Node24路徑，沒有降低檢查或改依賴。

實際CLI合成run：`519417aa-96c3-47ed-89c7-58405223453c`。
其ignored artifacts目錄為 `artifacts/remote-smoke/epic7-executor-preparation/<run>/`：
result/fixture/observer/hashes及verification/summary.json、三份本機logs；summary包含UTC、版本及各log SHA-256。
失敗控制案例保持FAIL證據；測試成功指「成功拒絕不安全狀態」，不把注入失敗改報成正式smoke PASS。
新verify整合只為證明新增executor必經原preserved內容比對；沒有重跑換機ValidateOnly CLI、舊完整SQL、race或雙build。

模型核對實際記憶體transaction/durable狀態，不是PostgreSQL連線、實際RPC或正式權限證據。
formal live collector、逐案SQL/actor/PK compiler、PG timeout/cancel/rollback及獨立observer、真正網站復原
仍是明列的工程缺項；沒有宣稱只等operator。coverage/retention提案未接受，正式REMOTE NOT RUN、Epic7 REMOTE CLOSED=NO。
使用者只需集中回答[五題白話決策單](EPIC7_OWNER_DECISIONS.md)，本輪不要求其代寫工程步驟。
