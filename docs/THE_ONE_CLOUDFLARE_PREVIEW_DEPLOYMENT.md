# THE_ONE_CLOUDFLARE_PREVIEW_DEPLOYMENT

2026-09-08｜**Cloudflare Compatibility Proof PASS，可以進入 Preview Deployment。**
這是「本機合成環境相容性通過」，不是已部署，也不是正式網站上線許可。
接受的 hosting 決策在 [SYSTEM_ARCHITECTURE](SYSTEM_ARCHITECTURE.md)。

## 現在完成到哪裡

既有 application 已在本機 workerd 執行，沒有重做 UI 或改寫 Supabase。
保留 Next 16.3.3 / React 19.2.8；新增 vinext 1.0.0-beta.9、
@vinext/cloudflare 1.0.0-beta.7、Vite 8.2.2、Cloudflare Vite plugin 1.54.5、
Wrangler 4.129.1、React plugin 6.1.1、RSC plugin 0.5.34、RSC 19.2.8。
Node 24.19.0、pnpm 10.34.5。新增依賴鎖定確切版本，安裝停用 lifecycle scripts；
沒有放寬 ignoredBuiltDependencies，也沒有執行 native postinstall，現有 optional binaries 已足夠。

- 官方 compatibility check：修正 package type 後 0 issues、1 partial（Google 字型）、96%。
- Cloudflare target build：30 pages、5 layouts、5 route handlers 完成；本機 Wrangler/workerd 啟動。
- 23 項環境與 Worker 入口安全測試；21 項真實 HTTP 請求檢查通過。
- 瀏覽器實際登入/登出、Student、Admin 拒絕、師資 Image、首頁與 390px 手機登入畫面通過；沒有捕捉到 browser errors。
- TypeScript 和新增/修改工具 ESLint 通過。
- 正式 DB connections / SQL / writes = 0；沒有 Docker、部署、export、restore 或 Epic8。

[可攜證據](evidence/cloudflare/local-compatibility-proof.json) 保存本次結果與工具/配置 hashes。
本機原始 log、合成請求摘要和截圖在 `artifacts/cloudflare-local/`，不提交產物或 Cookie。
mock 只記 method/path，不記 headers/body/token；它不是 Supabase RLS、真實 Auth 或資料庫測試。

## 開發與重跑方式

| 指令 | 用途 |
| --- | --- |
| `pnpm dev` / `pnpm build` / `pnpm start` | 原本 Next 入口保留；本輪沒有重跑完整 Next build |
| `pnpm check:vinext` | 官方相容性掃描，不能取代 runtime proof |
| `pnpm dev:vinext` | vinext + Cloudflare Vite 本機開發；先提供下表一致的隔離環境 |
| `pnpm build:vinext` | Cloudflare target build；缺環境或正式 target 直接停止 |
| `pnpm start:vinext` | 官方 `wrangler dev --local --config dist/server/wrangler.json`，需要相符的本機 runtime vars |
| `pnpm test:cloudflare` | 本輪新增的 23 項安全測試 |
| `pnpm proof:cloudflare` | 自動使用 loopback mock、建置、啟動 Workers、跑 21 項 HTTP proof、保存證據、停止程序 |

proof 需要本機 54329 和 8787 埠空閒；不讀取正式 .env。只繼承必要 OS 環境，
由程式注入明確標示的 synthetic public key，禁止 service credentials。
`node tools/cloudflare/local-proof.mjs --serve` 可保留測試服務供瀏覽器檢查，最多 15 分鐘。
`--skip-build` 僅適用已核對的同一份本機合成 build；環境不符會拒絕。

`next-env.d.ts` 是 vinext 自動更新：加入 vinext augmentation 並移除其未產生的 root-params 宣告。
Next/vinext 各自可能重新產生這份檔案；若切換入口出現差異，應檢查，不能用 reset 隱藏。
沒有修改 src application、Next config、歷史 migrations、Canonical 或 Product Decisions。

## 尚未證明的部分

- 真實 Preview Supabase 的 Auth、email redirect、RLS、RPC、Storage，需先有獨立專案及核准的空白 schema 初始化；不能複製正式學生資料。
- 此 proof 不是全部 30 頁的業務驗收，也沒有重新執行 Epic7 SQL suite 或正式 smoke。
- Google 字型由 vinext CDN 方式提供；現有 TeacherAvatar 本來就 unoptimized，圖片可直接顯示。未開 Cloudflare Images，沒有圖片最佳化服務承諾。
- 未啟用 KV/ISR adapter 或 CDN data cache；目前沒有依賴 ISR 的路由。未來需要跨 instance 持久快取時另外驗證，不能把本輪當 ISR proof。
- Node crypto、SSR、Server Actions、cookies、proxy 已涵蓋現有使用路徑；不代表所有 Node API 可用。
- vinext 是 Beta，升級需重跑本相容性 proof。沒有 Vercel account/runtime/secret 依賴；vinext 的開源 transitive @vercel/og 不代表使用 Vercel hosting。

## 本機 POST 連線問題與修正

重跑時曾重現 Miniflare ProxyWorker 的 Network connection lost：跨來源表單先被正確拒絕，
接著另一個登入 POST 偶發在抵達 application 前回 500。沒有用重試來掩蓋，也沒有放寬 CSRF。
僅消耗測試 client 回應、改 static routing 或在 403 後讀 body 都不足以解決；這些實驗性配置未保留。
最後在 Worker 入口先完整接收 form body，再只交給原 handler 一次；維持 Next 原本 1 MiB 上限，
加上 10 秒接收時間限制，過大 413、逾時 408、破損 400，不執行 application。
JSON webhook、GET、Auth/角色規則維持原樣。這是 transport 相容層，不是登入邏輯重寫。
同一原始 FormData 測試連續 20 組、每組 21 項（共 420 項檢查）通過，沒有 retry。
7 項表單邊界測試也通過。相關但不能直接等同本專案根因的
[官方 issue #15203](https://github.com/cloudflare/workers-sdk/issues/15203) 留作後續追蹤。

## OWNER 下一步：三個畫面

**先登入，不必貼任何秘密到對話。** 登入 OWNER/The One 自己控制的 Cloudflare 帳號；
另確認 OWNER 控制的獨立 Preview Supabase。這兩個帳號/專案目前沒有可核對的 evidence，不能宣稱只差 Cloudflare 登入。

1. **Supabase 的 Preview project 畫面**：建立或選定獨立測試專案，確認 ref、region、方案費用；只用合成帳號/資料。若 Free 名額不足或需要付費，停止詢問 OWNER，不能改拿正式專案。
2. **Cloudflare → Workers & Pages → Create application / Import repository**：選 OWNER 的帳號，GitHub 授權只給 `theoneguitarstudio-cmd/the-one-platform`，Worker 名稱 `the-one-preview`，root 為 repository 根目錄。先確認下表，再按任何會開始部署的按鈕。
3. **Worker → Settings → Build、Variables & Secrets、Domains & Routes**：設定 Preview 分支與兩份環境值，核對沒有正式 secrets；只開 workers.dev 預覽 URL，先設存取保護。首次部署仍是下一輪外部操作，不是本文件自動授權。

## 分支與部署設定

採兩個完全分開的 Worker，讓 Preview 不會共用正式秘密：

| 設定 | 第一個 Preview Worker | 未來 Production Worker |
| --- | --- | --- |
| Worker | the-one-preview | 未建立、未授權 |
| Git branch | preview-test | main（僅未來） |
| Backend | 獨立 Preview Supabase | 正式 Supabase，Epic7 gates 通過後另行授權 |
| Domain | workers.dev 測試網址 | theoneguitar.com，未授權 |

Cloudflare 的 UI「Production branch」是**該 Worker 的主要更新分支**，不是本專案的正式上線認定。
獨立 `the-one-preview` Worker 這個欄位選 preview-test；不要接受自動帶入的 main。
目前關閉其他分支自動 build。未來 Production Worker 才選 main；本輪不建立它。
詳見 [官方 branch control](https://developers.cloudflare.com/workers/ci-cd/builds/build-branches/)。

- Build：使用鎖定的 Node/pnpm；`pnpm install --frozen-lockfile --ignore-scripts` 後 `pnpm build:vinext`。
- 下一輪核准 Preview 部署後，deploy command 可用 `pnpm exec wrangler deploy --config dist/server/wrangler.json --keep-vars`，保留 UI 設定的 runtime vars。不是 `next build`，也不是 static export。
- 現在 wrangler 設定 `workers_dev:false`、`preview_urls:false`，沒有 routes。取得明確 Preview 操作授權後，只為此 Preview Worker 改為啟用測試 URL，重新 build。不要在部署前無聲開啟。
- Runtime 與 build 變數分開設定。Cloudflare build variables 不會自動成為 runtime variables，見 [官方 build settings](https://developers.cloudflare.com/workers/ci-cd/builds/configuration/)。
- main 不會因 Preview Worker 更新而修改或部署；不要把分支合併或加 production workflow。

## Preview 環境契約

| 名稱 | Build | Runtime | 來源/限制 |
| --- | --- | --- | --- |
| THE_ONE_ENV | preview | preview | 此入口只接受 preview 或本機 local-proof；拒絕 production |
| THE_ONE_PREVIEW_SUPABASE_REF | 必要 | 必要 | OWNER 核對的獨立 Preview ref，禁止正式 ref |
| NEXT_PUBLIC_SUPABASE_URL | 必要 | 必要且相同 | 精確匹配該 ref 的 HTTPS URL |
| NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY | 必要 | 必要且相同 | 同一 Preview 專案 public key，可出現在 client；不能放 service key |
| NEXT_PUBLIC_SITE_URL | 必要 | 必要且相同 | 固定的此 Preview workers.dev origin，不能用正式域名 |
| SUPABASE_SERVICE_ROLE_KEY | 不需要 | 只有 Preview Admin 操作需要 | Preview 專用 secret；不提供則保留既有 privileged operation 拒絕，不偷繞過 |
| MANUAL_BANK_TRANSFER_INSTRUCTIONS | 不需要 | 可選 | 清楚標為測試，不放正式收款資訊 |
| LINE / VDOCIPHER / PAYMENT_PROVIDER / OPENAI secrets | 不需要 | 目前不啟用 | 既有流程未要求，先留空；未來只用 test/sandbox credentials |

不要把 service key 放在任何 NEXT_PUBLIC 名稱。Cloudflare account token 只屬部署控制面，
不放 application env 或 Git。UI secrets 存 Secret 類型；正式 Supabase URL/key、
DB password、正式 payment/mail/video/AI credentials、學生資料全部禁止放 Preview。

安全入口會核對 ref、URL、環境與 build/runtime public 值，不符回 503，然後停止進入 application。
它不能憑 public key 字串證明後端所有權；OWNER/操作者仍須在 Preview Supabase UI 核對同一專案。
正式 guard 不是本輪要實作的功能，此入口故意拒絕 production。

Preview Supabase → Authentication → URL Configuration：Site URL 設上述固定 Preview origin；
明確允許該 origin 的 `/auth/callback` 與 `/auth/confirm`，不加正式網站，不使用跨所有域名的 wildcard。
密碼重設與 signup 使用既有 callback 流程；用安全測試 email 驗證。
每個版本 URL 若要直接測 Auth，必須同時核對 app URL/build/redirect allowlist，不能只換網址。

## 看網站、回滾與費用

首次核准部署後，在 Preview Worker 的 Overview / Deployments 打開 workers.dev 或版本 URL。
它會顯示現在既有的首頁、登入、公開師資/商品與角色基礎頁；不會突然出現完整 LMS/player。
[Preview URL 是額外存取入口](https://developers.cloudflare.com/workers/versions-and-deployments/preview-urls/)，
應限制給測試人員，不能把網址難猜當保護。

回滾只在 `the-one-preview` 的 Deployments 選上一個已驗證版本；確認 env 與那份 build 相符。
這只回滾應用程式，不會回滾 Supabase 或測試資料；不能順便 DELETE/restore。

**Free 優先，目前沒有證據需要購買 Paid。** 實際 server 目錄約 2.60 MB（連同本機輔助檔），
client 33 個檔案、約 0.72 MB，沒有 KV/R2/Images/DO 等付費依賴。
大小及資產數不構成 Free 阻擋。Free 每日動態請求/CPU 仍有上限；
本機通過不會證明雲端每次 SSR 都能符合 10ms CPU。
首次隔離 Preview 應量測登入、SSR、排課操作 CPU/錯誤；持續超限先分析優化，再向 OWNER 提案，
不得自動升級。現行限制見 [官方 Workers limits](https://developers.cloudflare.com/workers/platform/limits/)。

未來綁 theoneguitar.com 必須先完成 Epic7 Backup/Recovery、正式 migration/smoke 等 gates，
再核准獨立 Production Worker、main 部署、DNS/traffic 與 recovery plan。
本輪沒有任何正式部署、domain、DB 操作，也沒有開始 Epic8。
