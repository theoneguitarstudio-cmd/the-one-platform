# THE_ONE_CLOUDFLARE_HOSTING_EVALUATION

> 後續決策：OWNER 已接受 Workers + vinext，取代本文當時的 Vercel 建議。
> 本文保留為歷史 audit；目前實作與本機證據請見 [Preview deployment plan](THE_ONE_CLOUDFLARE_PREVIEW_DEPLOYMENT.md)。


2026-09-08 / **ARCHITECTURE & HOSTING AUDIT ONLY** / recommendation PROPOSAL。
Source baseline：`preview-test` / `d3821e3a6fec98c0fe72ba280e705e7bf6f3bc79`，CLEAN。
實際 repo：`C:/Projects/the-one-platform-handoff-0af0680`。
本輪只讀程式與官方文件、寫評估文件；未安裝 adapter、改程式/config/lock、建立雲端資源或部署。

## 1. Executive Summary

**C. 可以，但現在搬不划算。建議目前先選 VERCEL，信心 MEDIUM。**

The One 的業務核心可留在 Supabase，沒有發現必須重寫 20～50 個 application files 的理由。
但 Cloudflare 不是把既有 Next build 原封不動放上去：最新官方預設已是 **Workers + vinext（Beta）**；OpenNext 仍可選，卻有目前 Proxy 的相容性缺口。
這個差異直接碰到登入、角色頁與表單安全，不能用換首頁截圖代替驗證。

預算估計：新增/修改 **5～7 個 hosting/tooling 檔**，**0～5 個 application 檔**可能需要兼容修正；加上 **2～3 個針對性測試檔**。
這是待實驗確認的範圍，不是完成 migration 的報價；不能保證0檔、不必測試。
沒有已證實需要 DB/domain architecture redesign 的 BLOCKER；但目前也沒有 Cloudflare build/runtime PASS。

Workers Paid 基礎約 US$5/月；Vercel Pro 一個部署席位約 US$20/月。初期約US$15/月的差距，需要與新工具鏈驗證及維護時間比較。
若未來流量大，Cloudflare 的傳輸費優勢可能顯著；本報告不是永遠排除 Cloudflare。

## 2. Current Architecture

完整圖、現有與未實作區分、檔案/行號見 [CURRENT_THE_ONE_RUNTIME_ARCHITECTURE](CURRENT_THE_ONE_RUNTIME_ARCHITECTURE.md)。先完成該 source review 才做平台比對。

- Next16.3.3、React19.2.8、App Router、30 pages/5 handlers；server components +7份 Server Action 模組。
- Proxy 負責 Supabase session refresh；server 再驗 `getUser()` / account / roles，DB 執行交易與授權。
- HTTP REST/RPC 接 Supabase；沒有 web runtime 直連 Postgres TCP pool，沒有 Node 常駐背景工人。
- 訂單、人工付款、課程包/點數與排程已存在；正式 gateway webhook 尚未完成。
- Next Image 頭像已 `unoptimized`；Geist 使用 next/font/google；Storage/Realtime delivery 未接線。
- 無 VERCEL_*、Vercel SDK、Blob/KV/Edge Config 或 Vercel Cron 綁定。現有首頁仍 Platform Foundation。

Canonical 工程狀態以 CURRENT_WORK/PROJECT_STATUS 最新段落為準：Epic7 本機與 Production Read-Only Preflight 已做到既定 gate，Backup/Recovery 尚未通過。
本輪不重跑 SQL/build/ValidateOnly、不重新查正式環境、不從舊 P2 文件倒退狀態。

## 3. Cloudflare Recommended Runtime

本次查閱的 [Cloudflare Next.js 官方指南][CF-NEXT]（頁面更新2026-08-25）推薦 **D：Workers + 目前推薦工具 vinext**。
它重新實作 Next API 並使用 Vite，不是消費 `next build` 的 adapter；仍是 Beta。保留既有路由檔不等於 runtime 行為完全相同。

| 選項 | 對目前 The One 的判斷 |
| --- | --- |
| A Pages | 不選。現有 SSR/Auth/Actions/Proxy 不能改 static export 而保有行為；不沿用舊 next-on-pages / 全改 Edge 教學。 |
| B 裸 Workers | 缺框架整合，不是直接上傳此 repo 就能執行。 |
| C Workers + OpenNext | 官方仍提供手動配置路徑，保留 next build；需處理 Node Proxy 缺口。 |
| D Workers + vinext | 最新官方預設；值得隔離實驗，但不能以 Beta 的平台宣稱當 The One 正式驗證。 |
| E Node hosting / container | 可保留 Next runtime，但沒有理由為此評估新增自託管維運工作。 |

[vinext 官方 compatibility dashboard][VIN-COMPAT] 在本次讀取時最新run是2026-09-07、Next **16.2.6**、vinext main；supported pass99.5%、overall95.8%。
這不是本案 **16.3.3 / React19.2.8 / lockfile** 的測試，也不能把排除範圍後的百分比當完全相容。

[OpenNext 官方支持表][OPEN] 宣稱所有 Next16 minor/patch，但明列 Node Middleware 尚不支援；[Cloudflare OpenNext 頁][CF-OPEN]亦如此。
[Next Proxy 官方規格][NEXT-PROXY]說明 Proxy 預設 Node 且不接受 runtime override。`src/proxy.ts` 正是這個入口。
因此 OpenNext 原樣接線不能判PASS；若另行實驗改回相容 middleware，必須保留 Cookie/授權語義，不可刪除 refresh、改無效 runtime 或降低安全政策。
這是 runtime entry compatibility 問題，**不等於 Supabase/domain 必須重做**。

目前 [Node compatibility文件][CF-NODE]亦已更新：compatibility_date >=2026-08-04預設啟用Node相容能力，較舊日期需顯式nodejs_compat；新配置不應盲抄舊flags。下表所稱「需nodejs_compat」是需該能力，不是一律要新增flag。

另有文件時差：[OpenNext首頁][OPEN]仍寫壓縮3/10MiB；較新的 [Cloudflare runtime limits][CF-LIMIT]（2026-09-05）已寫兩方案 **64MiB uncompressed、無壓縮大小限制**。
本報告採 Cloudflare 平台當前限制，記錄衝突；未來仍須核對鎖定工具是否保留舊檢查，不能停用檢查湊過。

## 4. Compatibility Matrix

PASS=本項原語可支援、幾乎不需改；WARN=設定/小改/相容性驗證需要；BLOCKER=已知需明顯架構改造；UNKNOWN=尚無實作或精確證據不足。
**主欄評估 Workers + vinext；OpenNext 特有差異另註。** 所有PASS只代表該項能力，不代表整個 application 已在 Cloudflare 測試通過。
Repo證據縮寫：A2～A7對應 [架構文件](CURRENT_THE_ONE_RUNTIME_ARCHITECTURE.md) 的章節及其中精確來源。

| # | 能力 | 判定 | The One 實際證據 → 條件 / 官方來源 |
| --- | --- | --- | --- |
| 1 | Next.js版本 | UNKNOWN | A2固定16.3.3；vinext dashboard測16.2.6，精確組合未證明。[VIN-COMPAT]；OpenNext版本宣稱涵蓋16但不消除#6。 |
| 2 | App Router | PASS | A2的src/app hierarchy受支援；不必改Pages。[CF-NEXT] |
| 3 | React Server Components | WARN | 現有預設RSC；vinext改用Vite RSC pipeline，需驗React19.2.8序列化/導覽。[VIN] |
| 4 | Server Actions | WARN | 7個模組、FormData、redirect；平台支援，須測Origin/CSRF、server-only、錯誤與刷新，不能只測GET。[CF-NEXT] |
| 5 | Route Handlers | PASS | A3的GET/POST、Web Request/Response受支援。[CF-NEXT] |
| 6 | middleware / proxy | WARN | vinext宣稱支援proxy；測setAll傳遞與refresh。OpenNext Node Proxy目前不能原樣判PASS。[CF-NEXT][CF-OPEN][NEXT-PROXY] |
| 7 | cookies / session | WARN | A3雙向Cookie及每次身分驗證；需隔離兩個user測串號/過期，不可CDN共享session。[VIN-HEADERS][SB-SSR] |
| 8 | redirects / rewrites | PASS | 實用trusted origin / NextResponse.redirect；無自訂rewrite規則。[VIN] |
| 9 | dynamic routes | PASS | [slug]/[id]/[provider]與Promise params，路由形式支持。[CF-OPEN][CF-NEXT] |
| 10 | SSR | WARN | A2 cookie-sensitive資料頁；平台支援，實際CPU/memory/latency未知。[CF-NEXT][CF-LIMIT] |
| 11 | ISR | WARN | 沒有顯式ISR頁；有revalidatePath。日後啟用時須獨立cache backend/一致性驗證，不預先加DB儲存服務。[VIN-CACHE] |
| 12 | caching | WARN | revalidatePath有用；不得把Auth、訂單、個人頁快取給別人。vinext完整Cache Components仍有缺口，本案尚未開啟。[VIN-CACHE][VIN] |
| 13 | streaming | PASS | 框架SSR串流受支援；無自建串流產品。[CF-NEXT] |
| 14 | Next Image | PASS | teacher-avatar明確unoptimized，現況無需Images binding；若開最佳化則另做設定/費用評估。A6[CF-OPEN] |
| 15 | file upload | UNKNOWN | A6未實作；不能聲称現成可用。未來可授權直傳Storage，避Worker緩衝。[SB-UPLOAD] |
| 16 | multipart/form-data | WARN | 目前僅文字表單Actions；Web Request有formData，框架body limit及未來File須測。[CF-REQUEST] |
| 17 | Supabase Auth | WARN | HTTP服務可保留；需測全session、redirect allowlist、Auth郵件。[CF-SUPABASE][SB-SSR] |
| 18 | Supabase SSR | WARN | A3 cookies() client；Workers可連SDK不等於SSR integration已PASS。[VIN-HEADERS][SB-SSR] |
| 19 | Supabase Database | PASS | HTTPS Data API，不改Postgres/RLS/交易。[CF-SUPABASE] |
| 20 | Supabase Storage | UNKNOWN | 未接線；平台可使用SDK，bucket/policy/delivery尚未實測。[SB-DOWNLOAD] |
| 21 | Supabase Realtime | UNKNOWN | 無channel呼叫；未來browser直連wss，不必把Workers當socket中繼。[SB-REALTIME] |
| 22 | PostgreSQL connection strategy | PASS | 本案無TCP直連；HTTP SDK不需新pool/Hyperdrive。[CF-SUPABASE] |
| 23 | REST / RPC | PASS | A5既有.from/.rpc可用HTTP transport，SQL留Supabase。[CF-SUPABASE] |
| 24 | server-side service role | WARN | A5特權工廠server-only；runtime secret、bundle排除、Preview隔離須驗。[CF-SECRETS] |
| 25 | Webhooks | WARN | HTTP raw text/Headers能力可用；目前501拒絕必須維持。[CF-REQUEST] |
| 26 | payment callback | UNKNOWN | provider回null，正式簽章/交易接線未做；非hosting造成也不可宣告ready。A5 |
| 27 | cron / scheduled tasks | UNKNOWN | 無應用scheduler；Workers有Cron不等於既有outbox會自動跑。[CF-CRON] |
| 28 | background jobs | UNKNOWN | A4無工人；不能用無限waitUntil冒充可靠工人。[CF-LIMIT] |
| 29 | email | WARN | 已有Supabase Auth郵件入口；後端可保留，callback origin和測試寄件環境須核定。[SB-SSR] |
| 30 | LINE | UNKNOWN | 僅env範本；無client或webhook，不提前做Epic13。A6 |
| 31 | timezone | WARN | Intl可用；A4 DST掃描是CPU熱點，需workerd一致性與預算量測。[CF-WEB] |
| 32 | Node.js APIs | WARN | node:crypto UUID / process.env需nodejs_compat；相容層不等於完整Node主機。[CF-NODE][CF-ENV] |
| 33 | native Node modules | WARN | A4只見工具鏈間接native；Cloudflare不執行一般.node addon。vinext可能stub依賴，需證明未stub必要行為。[VIN] |
| 34 | environment variables | WARN | 5個實際env名稱；build/runtime兩處分開設定，process.env flags需核對。[CF-ENV][CF-BUILDS] |
| 35 | secrets | WARN | runtime encrypted secrets按env，禁止public prefix/Git/log/產物內嵌。[CF-SECRETS] |
| 36 | build-time env | WARN | public值會固定；Preview獨立build，Geist工具鏈差異須查。[NEXT-ENV][VIN] |
| 37 | Preview environments | WARN | 可做，但version URL不是隔離證明；採獨立Worker/env與Supabase。[CF-ENVS] |
| 38 | Production environments | WARN | 另指定production worker/main；不繼承Preview secret，尚未建立。[CF-ENVS] |
| 39 | custom domains | PASS | Workers支援自訂domain；本輪不綁theoneguitar.com。[CF-DOMAIN] |
| 40 | SSL | PASS | custom domain由平台提供憑證；HTTPS workers.dev可供預覽。[CF-DOMAIN][CF-PREVIEW] |
| 41 | GitHub auto deployment | WARN | Workers Builds有Git整合；需固定工具/branch/command，不能自動init改程式。[CF-BRANCH][CF-BUILDS] |
| 42 | branch previews | WARN | 支援non-production builds/alias URL；本案必須另隔離secrets。[CF-BRANCH][CF-PREVIEW] |
| 43 | logs / observability | WARN | 可啟用Workers Logs/metrics/source maps；request URL可能含Auth code，需遮罩/限權/保留期。[CF-LOGS] |
| 44 | rollback | WARN | 可回Worker版本；不會復原Supabase DB或已執行交易，依賴舊secret/binding可用。[CF-ROLLBACK] |
| 45 | CI / E2E | WARN | 目前vitest Node；須增workerd smoke/Auth/Actions E2E，現有測試不能替代。A7[CF-NEXT] |
| 46 | security headers | WARN | repo無自訂配置；_headers只處理assets，不覆蓋Worker SSR，需部署硬化。[CF-HEADERS] |
| 47 | CSP | UNKNOWN | repo無CSP；現行雲端header亦無證據。未來需對字型/Supabase/會議/媒體設policy，兩平台皆欠。A3 |
| 48 | large request / response | WARN | account Free/Pro request100MB；無response硬上限但不能全塞128MB RAM。Next Actions限制另算，不以100MB承諾上傳。[CF-LIMIT] |
| 49 | execution time | WARN | HTTP連線期間無硬wall-clock上限；disconnect後工作可取消，waitUntil最多延30秒。付款不得自動盲重試。[CF-LIMIT] |
| 50 | CPU | WARN | Free10ms/次；Paid預設30s最多5min。SSR/113次Intl迴圈未量測，不保證Free可跑。[CF-LIMIT] |
| 51 | memory | UNKNOWN | Worker128MB，升Paid不增；本案實際peak及bundle startup尚未量測。[CF-LIMIT] |

沒有以未完成功能湊PASS，也沒有證據支持直接判「整體不適合」。真正阻止立即採用的是#1/#6/#7/#45/#50/#51的驗證與隔離條件。

## 5. Supabase Compatibility

**Cloudflare 只取代 hosting layer，Supabase architecture 可保持。**
目前沒有技術理由搬DB/Auth到D1/KV/Durable Objects。以下是hosting接線與未來能力審查，不是資料搬遷提案。

| 檢查 | 結論 / 必要條件 |
| --- | --- |
| 1 Browser → Supabase | browser工廠尚未使用；未來HTTPS SDK可保留，只有publishable key可公開，仍以RLS授權。 |
| 2 Worker → Supabase | 官方明示supabase-js支援；目前REST/RPC策略合適，不改商業交易鎖。 |
| 3 Auth cookie | same-site的app cookie由SSR管理；預覽origin要固定，Secure/SameSite/path和多cookie輸出須實測。 |
| 4 SSR session | refresh後Cookie必須同時可供當次server與下一個request使用；測過期、登出、雙使用者與角色撤銷。 |
| 5 service-role safety | 繼續server-only；只放指定worker環境secret；client bundle與log不得出現。缺值只讓必要特權功能失敗。 |
| 6 CORS | server→Supabase不受browser CORS限制；browser直連仍由Supabase端CORS回應決定。Auth redirect allowlist不是CORS，兩者分別驗。沒有理由開任意來源帶credentials。 |
| 7 region latency | 正式Supabase已知Singapore；Workers離使用者近不等於DB往返快。可評估Placement靠資料端，但只量測獨立測試後端，不能本輪probe正式。 |
| 8 connection pooling | 現在HTTP client不佔應用持有的Postgres TCP pool；不需Hyperdrive。將來若改PG driver，再獨立評估pool，不主動改。 |
| 9 Realtime / WebSocket | 未接線；未來browser可直接接Supabase wss並維持其JWT/channel授權，不必server持久socket。 |
| 10 Storage upload/download | 未接線；未來可授權後直接傳Storage，限制檔型/大小，較大檔用resumable，避免Worker memory buffer。 |
| 11 signed URL | 未做；私有資源採短效URL、先查ownership/entitlement。不是換hosting就可公開bucket；簽名URL不寫log/cache。 |
| 12 webhook callback | HTTP可承載，但目前501。未來原始body簽章、event idempotency/金額核對/交易結果不可因換平台省略。 |

以上平台依據：[Cloudflare Supabase][CF-SUPABASE]、[Supabase SSR][SB-SSR]、[Storage upload][SB-UPLOAD]、[download][SB-DOWNLOAD]、[Realtime protocol][SB-REALTIME]、[Placement][CF-PLACEMENT]。
Supabase SDK相容並不能證明The One的私有授權、付款或學習功能已remote通過。

### R2 — OPTIONAL / FUTURE

**現在不搬。** 現在甚至尚無已接線的Supabase資源delivery，不能以架空的搬遷節省當收益。
未來PDF、Audio、Backing Tracks與download assets下載量很高、已有可量測Storage帳單、而且可維持私有授權時，再比較R2。
[R2 Standard][R2]為US$0.015/GB-month、Class A US$4.50/百萬、Class B US$0.36/百萬、網際網路egress免費（仍有儲存/操作與其他服務費）。
這可能降低大量檔案外送成本；沒有流量就無法估節省多少，也不是影片DRM/Stream替代品。
維持provider-neutral resource boundary；R2不列Epic7～13 blocker，不淘汰Supabase Storage。

## 6. Preview Workflow

可以達成 **push preview-test → OWNER 手機看固定網址**，但Cloudflare的安全環境設定比Vercel多一步，不能只打開branch previews就算完成。

建議未來設兩個獨立Worker：`the-one-preview` 與 `the-one-production`（提案名稱，未建立）。
可由明確Wrangler environment分離，或兩個獨立Git build連結；核心條件是 **worker identity、secret、build variables、runtime variables、Supabase project完全分離**。

| 項目 | Preview | Production |
| --- | --- | --- |
| Git | 只接受preview-test | 只接受main；正式部署另核准 |
| Worker/env | 專用preview | 專用production |
| Supabase URL/key | 獨立測試project | 正式project，仅正式環境 |
| SITE_URL | 實際preview origin / stable alias | 核准正式origin |
| service-role | 必要才放測試project secret | 正式secret只給正式runtime |
| 帳戶/資料 | 合成帳戶與核准測試資料 | 既定正式操作治理 |
| 外部服務 | 不啟用真付款/正式LINE等 | 按後續核准開啟 |

Workers Builds的「production branch」是該Worker的build發佈分支，不等於The One商業正式環境。
因此preview專用Worker可以只追蹤preview-test而不碰正式Worker；production專用Worker追蹤main。
若改採同一Worker的non-production version URLs，必須另證明各版本不共用正式secret/bindings；本案優先獨立Worker，以免URL叫preview卻連正式DB。
[environment vars/bindings/secrets不繼承][CF-ENVS]；[build變數不自動出現在runtime][CF-BUILDS]。

[官方branch build][CF-BRANCH]與[固定alias Preview URL][CF-PREVIEW]提供所需Git/URL能力。Preview URL啟用後可公開，需先配存取保護；不依賴難猜網址。
Auth callback要從相同固定origin開始；不可從每次新hash URL登入卻回另一網域，導致PKCE cookie遺失。保留safe-redirect，不信任任意Host/X-Forwarded-Host。
vinext的CLI `--preview` 是 `--env preview`別名，**不是保證不會部署的開關**；未來先核對產物、帳戶與明確target，這輪不執行。

Vercel則原生用main Production /其他branch Preview，再限定Preview env；設定步驟已有 [The One Vercel Preview Setup](THE_ONE_VERCEL_PREVIEW_SETUP.md)。
两平台都還缺核准的獨立測試Supabase與外部建立/部署授權；單選平台不會自動產生網站。

## 7. Cost Comparison

價格於2026-09-08查官方頁；USD/月、不含稅、匯率、Supabase、郵件、付款、影片、檔案媒體、域名與人力。
這是hosting/compute/HTML-JS-CSS傳輸的情境試算，不是user數量定價，不是整套平台月費。

### 價格與限制

- [Workers][CF-PRICE]：Free 100,000 dynamic requests/日、10ms CPU/次；Paid US$5基礎，含10M requests與30M CPU-ms/月，超額分別US$0.30/M、US$0.02/M CPU-ms。一般static assets requests免費，未啟用另計費Workers Caching；沒有Workers egress bandwidth費。
- [Vercel Pro][V-PRO]：US$20平台費含一部署席位及US$20使用額；含1TB傳輸/10M Edge requests。不是再加一份US$20使用額。
- 以Singapore假設示範：[地域單價][V-SIN] FDT US$0.16/GB超額、Edge US$2.60/M超額、Fast Origin Transfer US$0.27/GB；[Fluid][V-FLUID] CPU US$0.160/h、memory US$0.0133/GB-h、invocations US$0.60/M。實際CDN訪客地域可能不同，不能當全球固定費率。

### 明確情境假設

user指每月活躍使用者；30天，日尖峰=平均3倍；RSC導航/表單/API/Proxy的工作量包含在動態request假設內。
靜態請求每dynamic request四次；動態HTML/RPC不shared-cache，靜態資源由CDN處理。Free運算上限必須看每次實測，不可只看平均。

| 每位每月 | LOW | NORMAL | HIGH |
| --- | --- | --- | --- |
| Dynamic requests | 50 | 300 | 1,500 |
| Static requests | 200 | 1,200 | 6,000 |
| 平均CPU/動態請求 | 8ms | 20ms | 50ms |
| 平均wall time/動態請求 | 0.1s | 0.3s | 1s |
| 動態origin收送合計/請求 | 0.02MB | 0.05MB | 0.1MB |
| hosting傳給browser總量/人 | 0.02GB | 0.15GB | 0.8GB |

Vercel採2GB provisioned memory，保守假設無concurrency攤提，CPU包含refresh/render；額外獨立middleware invocation若平台另計需增加，未假裝已測實際切分。
Workers CPU使用同一假設方便比較，不表示Node與workerd真的等速。cold start、bots、error retries、cache實作與訪客地域都會改變數字。
計入origin傳輸，避免錯把全部動態流量都包含在1TB免費外送裡。

### 12組粗估（四捨五入至約US$1；小額Paid顯示一位小數）

| MAU | 情境 | Dynamic/月 | Hosting GB/月 | CF Free | Workers Paid | Vercel Pro |
| --- | --- | --- | --- | --- | --- | --- |
| 100 | LOW | 5,000 | 2 | $0有條件* | 約$5 | 約$20 |
| 100 | NORMAL | 30,000 | 15 | 不合假設CPU | 約$5 | 約$20 |
| 100 | HIGH | 150,000 | 80 | 不合假設CPU | 約$5 | 約$20 |
| 500 | LOW | 25,000 | 10 | $0有條件* | 約$5 | 約$20 |
| 500 | NORMAL | 150,000 | 75 | 不合假設CPU | 約$5 | 約$20 |
| 500 | HIGH | 750,000 | 400 | 不合假設CPU | 約$5.2 | 約$28 |
| 1,000 | LOW | 50,000 | 20 | $0有條件* | 約$5 | 約$20 |
| 1,000 | NORMAL | 300,000 | 150 | 不合假設CPU | 約$5 | 約$20 |
| 1,000 | HIGH | 1,500,000 | 800 | CPU/尖峰日量超限 | 約$5.9 | 約$56 |
| 5,000 | LOW | 250,000 | 100 | $0有條件* | 約$5 | 約$20 |
| 5,000 | NORMAL | 1,500,000 | 750 | CPU/尖峰日量超限 | 約$5 | 約$26 |
| 5,000 | HIGH | 7,500,000 | 4,000 | CPU/尖峰日量超限 | 約$11.9 | 約$831 |

*LOW的8ms只是平均假設，必須所有必要操作能可靠滿足限制、memory/startup/bundle符合，才可用Free。The One尚無該證據；不能承諾100人即可免費。
HIGH高費用是刻意放大hosting流量的敏感度情境，不是The One預測；PDF/audio/影片不在4TB內。
若大檔直接走Supabase/R2，其費用由該服務計，不應再算一次Vercel hosting。

可重算公式（R=dynamic count、E=5R、c=CPU毫秒、t=wall秒、F=origin GB、B=browser GB；max即取較大者）：

```text
Workers = 5 + 0.30*max(R-10,000,000,0)/1,000,000
            + 0.02*max(R*c-30,000,000,0)/1,000,000
Vercel usage = 0.160*R*c/3,600,000 + 0.0133*2*R*t/3,600
             + 0.60*R/1,000,000 + 0.27*F
             + 0.16*max(B-1,000,0) + 2.60*max(E-10,000,000,0)/1,000,000
Vercel total = 20 + max(Vercel usage-20,0)
```

Build另列：假設每月100次×5分鐘=500分鐘；[Workers Builds][CF-BUILD-PRICE] Free含3000、Paid6000分鐘，故此情境無超額。
Vercel若用不開on-demand/Elastic的Standard build，按[官方條件][V-PRICE]不另收該build費；若選Basic paid machine，500×US$0.007=US$3.50計入使用額，超額时再增加帳單。
此表不開Images optimization、額外cache storage/queue、付費log drain或觀測附加包；若adapter實驗證明必要須加回，不能稱表為all-in。

### 免費是否適合商業 / 何時升級

依本次讀到的官方方案與Self-Serve條款，未見一般商業用途禁令；這是條款與方案比對的判讀，**一般商業Preview/初期站點可作條件式選項**，並非所有付款流程都可免費。
但[Self-Serve條款的使用限制(h)][CF-TERMS]禁止在接受Free Services的web property處理/收集信用卡資訊，不能籠統保證正式收卡流程免費可用。
目前程式是人工匯款/現金、沒有信用卡欄位；未來provider hosted checkout也須重新核對整體流程及適用條款，不能把「只買Workers Paid」視為所有Free Services條件都消失。

[Hobby][V-HOBBY]限personal/non-commercial，不能把The One商業Preview預設放免費Hobby。
Workers Paid可能在第一個真SSR/Auth測試就需要，因10ms限制，而非等1000學生才升；但Paid仍128MB，不能靠付費解memory問題。
最便宜合理hosting起點為Workers Paid約US$5/月（**前提相容性測過**）；目前最省工程風險方案是Vercel Pro約US$20/月。

### 工程成本

估計單一Cloudflare路徑的隔離驗證/設定 **12～24工程小時**；若採vinext並要對既有安全流程做較完整差異驗證，預留 **24～48小時**，不是保證交期。
若按假設每小時US$30～60估算，一次成本約US$360～2,880；沒有actual bill，不是Codex向OWNER報價。
初期節省US$15/月，單次US$360即需24個月才能回收，還沒算維護與延後課程上線的機會成本。
因此對「這週先看到網站」的目標，不建議先進行toolchain轉換。若流量接近HIGH或工程實驗非常順利，應重算，不能永遠沿用此結論。

## 8. Vercel vs Cloudflare

此表是針對目前The One的工程推論，不是平台全面排名；能力依上述官方來源與既有Preview方案。

| 面向 | 判斷 | 原因 |
| --- | --- | --- |
| Next.js support | Vercel better | 原生Next build；CF需vinext重新實作或OpenNext適配，精確組合未驗。 |
| deployment difficulty | Vercel better | 已有設定草案且無adapter；CF需配置/測試新工具鏈。 |
| Preview | Vercel better | branch/env整合直接；CF能達同一手機體驗但隔離設計較多。 |
| build logs | Equal | 兩者有build logs；不能因此替代runtime安全證據。 |
| environment variables | Vercel better | 本案Preview/Production scope較直覺；CF要分build/runtime/worker/env。 |
| rollback | Depends | 兩者可回code版本，皆不能回DB；CF bindings與cache一致性需審。[V-ROLLBACK][CF-ROLLBACK] |
| debugging | Vercel better | 目前Node/Next心智模型不變；CF新增API相容層與workerd差異。 |
| local development | Vercel better | 公司Windows現有Next工具已可用；OpenNext官方不保證Windows完整支援，vinext另需驗證。 |
| Git integration | Equal | 兩者能GitHub push→build→URL；都需正確branch/credential scope。 |
| observability | Depends | CF細CPU/Workers logs；Vercel Next請求/部署整合好，進階觀測皆可能加價。 |
| production reliability | Depends | 未有The One跨平台load/SLO數據；本案初期偏Vercel以少一個adapter風險，不能捏造uptime比較。 |
| global performance | Depends | static全球分發都可；動態多次Supabase往返取決於placement/region。 |
| Supabase integration | Equal | HTTPS SDK兩者可用；Auth callback/env都需正確設定。 |
| AI / Codex maintenance | Vercel better | 少一套runtime兼容規則；Codex仍能維護CF，但不能靠AI消除驗證成本。 |
| hosting流量單價 | Cloudflare better | Workers無egress費，在高流量假設差距大；不等於Supabase/媒體免費。 |

[Vercel Next integration][V-NEXT]、[Cloudflare官方流程][CF-NEXT]、[OpenNext Windows限制][OPEN]、[Workers logs][CF-LOGS]支持上述能力差異；比較結論為本案判斷。

## 9. Required Code Changes

**這輪沒有改下列檔案。** 估算是選定一條CF路徑後的聯集，不把vinext與OpenNext全部安裝。
Application file指src下既有網站檔；hosting config、lock與測試另計。沒有證據需要20/50個application檔，更沒有理由重寫歷史migration。

### A. Hosting-only / tooling：5～7檔

| file（候選） | 原因 | 風險 / 複雜度 |
| --- | --- | --- |
| package.json | 鎖定vinext/Vite/RSC或OpenNext/Wrangler、新scripts；vinext init可能加type=module | 中；須審既有scripts語義，禁止本輪執行 |
| pnpm-lock.yaml | 新套件精確依賴；保留pnpm10.34.5及既有政策 | 中；正式實驗另核准，不能用latest漂移 |
| wrangler.jsonc（新） | identity、environment、assets、compatibility_date/flags、CPU與隔離 | 中；最怕指到正式後端 |
| vite.config.ts（vinext，新）**或**open-next.config.ts（OpenNext，新） | 選一路runtime integration | 中；不是兩個都要 |
| .gitignore | 排除.dev.vars、.wrangler、所選產物目錄等 | 低；秘密不得入Git |
| next.config.ts（OpenNext條件） | 本機bindings integration等官方配置；vinext不預設需改 | 低～中；不做static export、不移除安全入口 |
| .github/workflows/the-one-preview.yml（条件新） | 若不採Workers Builds，固定preview-test→專用preview Worker | 中；只一種CI方案，不給preview job正式secret |

tsconfig目前有@/*、next生成type引用；vinext工具聲稱不需改，但若type生成檢查失敗可能另加1檔，須重估而非硬承諾上限。
postcss.config.mjs已ESM，不先改；workspace忽略scripts政策不得自動取消。

### B. Minor compatibility：0～3個既有application檔（候選）

| file | 可能原因 | 風險 / 複雜度 |
| --- | --- | --- |
| src/proxy.ts | OpenNext路徑可能需轉相容middleware入口；vinext先原樣測 | 高安全重要性、中改動量；不能省略refresh |
| src/lib/supabase/proxy.ts | request/response多cookie adapter差異，只在測試證明必要時改 | 高安全重要性、中；不得吞掉必須寫入的cookie |
| src/lib/env/server.ts | 若runtime/env取值行為不等需最小接線；官方process.env可用故預期可能0改 | 中；不從任意Host推trusted origin |

### C. Application behavior：0～2個既有application檔（條件）

| file | 可能原因 | 風險 / 複雜度 |
| --- | --- | --- |
| src/app/layout.tsx | vinext Google Fonts改CDN載入；若要保留Next自託管字型行為需調整font策略/資產 | 中；影響視覺、外部請求與CSP，不能默默接受 |
| src/modules/scheduling/timezone.ts | 若workerd CPU量測不合預算，先評Paid；僅確需優化時改，不改DST拒絕語義 | 中；需既有邊界測試，不為Free降低安全 |

其餘Auth callback/confirm、server client、授權、Actions原則上**驗證而非預先改寫**。
若修正範圍超過此估計，停止migration路徑、更新決策；不能批次改業務來迎合結論。

### D. Architecture redesign：目前0個

不改src/modules domain、DB/RLS/RPC/transaction、角色/權益模型；不搬Supabase，不引入D1/KV/DO替代商業資料。
安全測試候選2～3檔：`tests/hosting/auth-session.spec.ts`、`tests/hosting/actions-isolation.spec.ts`、`tests/hosting/runtime-budget.test.ts`（名稱提案，未建立）。
這些驗Cookie/Auth/角色拒絕、Actions/redirect/no-cross-user-cache、時間轉換/資源預算；不用換機理由重跑全部SQL。

## 10. Migration Risk

最高三件：**登入/授權語義、工具鏈版本與資源限制、Preview與正式環境隔離**。

- vinext dashboard尚非本案版本；官方自己列Beta、cache/font/native細節缺口。adapter安全與Next安全更新需一起追，不可只更新Next就當全部修補。
- OpenNext保留Next build較成熟，但Node Proxy gap是現存問題；不能把「支援Next16」遮住它。
- Runtime既有Node本機測試不等於workerd驗證；memory/startup、Cookie、表單CSRF、redirect、revalidatePath必須有合成測試。
- `server-only`阻擋、服務金鑰不得進client、個人回應不可shared-cache是不可退讓條件。
- Workers Free規格可能比實際SSR/Auth需求小；Paid只放寬部分限制。不得把longwalltime當交易可無限持續的保證。
- rollback只換程式；不可自動repair/delete重試交易。Epic7 Backup/Recovery gate与1h owner要求原封保留。
- 本案還缺CSP/完整hosting硬化、正式payment gateway與後續Epics；這些是既有工程路徑，不是CF獨有blocker。

## 11. Recommendation

**VERCEL / MEDIUM**，以盡快在手機看真application、保持Next工具鏈及安全為優先；這是建議，未改accepted hosting或roadmap。
更高hosting單價買到的實際價值是：少一套API重實作/adapter兼容層、較直接的branch Preview與環境隔離、沿用Next診斷工具。
不是付款即可免測試或自動讓Epic7結案，也不是宣稱Vercel每種流量都較省。

Cloudflare適合留作成本/性能候選：本案沒有深Vercel鎖定，未來可回來實驗。
若owner把月費壓到US$5優先於本週Preview，先做受控CF試驗，再以實測決定；不現在宣告B「只需小改」而隱去未驗證行為。

Roadmap保持：Epic7 Learning Map Core → Epic8 Membership & Content Access → Epic9 Learning Workspace & Practice → Epic10 Submission / Coaching / Verification → Epic11 Assessment / Achievement / Certificate → Epic12 Private Lesson / Teacher Workspace → Epic13 Admin / Creator / Operations / Production Launch。
The One 2.0 != The One Guitar Roadmap 2.0；Membership != System Course；Content != Product != Commerce != Payment != Entitlement != Achievement。
R2、Workers AI、D1都不新增為gate，不實作Epic8。

## 12. Suggested Next Step

若採建議Vercel：沿既有Preview setup確認The One控制的合格Team/方案、獨立測試Supabase；下一輪核准create-only與明確Preview部署後再執行，不改main或正式DB。
本輪不需要OWNER登入Cloudflare或提供secret，沒有為稽核創造外部操作。

若選Cloudflare，最小實驗提案（**本輪未授權/未執行**）：

1. 新的隔離實驗範圍內，固定vinext/Wrangler/Vite/RSC精確版本，審package scripts後才安装；先跑官方compatibility check，保留Next16.3.3與原業務。不可執行帶隱含deploy的初始化路徑。
2. 只本機workerd + mock/合成後端，測首頁/老師頁、session refresh、兩user隔離、未授權Actions、callback origin、raw webhook501、revalidatePath及DST轉換。記錄CPU/128MB/64MiB/startup與字型外連差異；無正式連線。
3. 只有本機證據足夠，再單獨核准建立**preview專用Worker**與獨立測試Supabase、受保護URL部署，驗手機完整登入/表單路徑。不是production或正式DB授權。
4. 結果不合就保留評估並回原Next/Vercel路徑，不改正式資料或降低權限政策；以實測修正工時與費用。

Audit驗證：51項矩陣/12組成本公式、repo位置/版本與文件links核對；只新增兩份hosting audit文件。
未跑新adapter check/build/E2E，不聲稱Cloudflare runtime已PASS。未安裝、部署、建立Project、動Supabase/Vercel或修改main。

### 官方來源索引（本次查閱2026-09-08）

[CF-NEXT]: https://developers.cloudflare.com/workers/framework-guides/web-apps/nextjs/
[CF-OPEN]: https://developers.cloudflare.com/workers/framework-guides/web-apps/opennext/
[VIN]: https://github.com/cloudflare/vinext
[VIN-COMPAT]: https://vinext.dev/compatibility
[VIN-HEADERS]: https://github.com/cloudflare/vinext/blob/main/packages/vinext/src/shims/headers.ts
[VIN-CACHE]: https://github.com/cloudflare/vinext/blob/main/packages/vinext/src/shims/cache.ts
[OPEN]: https://opennext.js.org/cloudflare
[NEXT-PROXY]: https://nextjs.org/docs/app/api-reference/file-conventions/proxy
[NEXT-ENV]: https://nextjs.org/docs/app/guides/environment-variables
[CF-LIMIT]: https://developers.cloudflare.com/workers/platform/limits/
[CF-NODE]: https://developers.cloudflare.com/workers/runtime-apis/nodejs/
[CF-WEB]: https://developers.cloudflare.com/workers/runtime-apis/web-standards/
[CF-REQUEST]: https://developers.cloudflare.com/workers/runtime-apis/request/
[CF-ENV]: https://developers.cloudflare.com/workers/configuration/environment-variables/
[CF-SECRETS]: https://developers.cloudflare.com/workers/configuration/secrets/
[CF-ENVS]: https://developers.cloudflare.com/workers/wrangler/environments/
[CF-BUILDS]: https://developers.cloudflare.com/workers/ci-cd/builds/configuration/
[CF-BRANCH]: https://developers.cloudflare.com/workers/ci-cd/builds/build-branches/
[CF-PREVIEW]: https://developers.cloudflare.com/workers/versions-and-deployments/preview-urls/
[CF-DOMAIN]: https://developers.cloudflare.com/workers/configuration/routing/custom-domains/
[CF-LOGS]: https://developers.cloudflare.com/workers/observability/logs/workers-logs/
[CF-ROLLBACK]: https://developers.cloudflare.com/workers/versions-and-deployments/rollbacks/
[CF-HEADERS]: https://developers.cloudflare.com/workers/static-assets/headers/
[CF-CRON]: https://developers.cloudflare.com/workers/configuration/cron-triggers/
[CF-SUPABASE]: https://developers.cloudflare.com/workers/databases/third-party-integrations/supabase/
[CF-PLACEMENT]: https://developers.cloudflare.com/workers/configuration/placement/
[SB-SSR]: https://supabase.com/docs/guides/auth/server-side/creating-a-client?queryGroups=framework&framework=nextjs
[SB-UPLOAD]: https://supabase.com/docs/guides/storage/uploads/standard-uploads
[SB-DOWNLOAD]: https://supabase.com/docs/guides/storage/serving/downloads
[SB-REALTIME]: https://supabase.com/docs/guides/realtime/protocol
[R2]: https://developers.cloudflare.com/r2/pricing/
[CF-PRICE]: https://developers.cloudflare.com/workers/platform/pricing/
[CF-BUILD-PRICE]: https://developers.cloudflare.com/workers/ci-cd/builds/limits-and-pricing/
[CF-TERMS]: https://www.cloudflare.com/terms/
[V-PRO]: https://vercel.com/docs/plans/pro-plan
[V-HOBBY]: https://vercel.com/docs/plans/hobby
[V-SIN]: https://vercel.com/docs/pricing/regional-pricing/sin1
[V-FLUID]: https://vercel.com/docs/functions/usage-and-pricing
[V-PRICE]: https://vercel.com/docs/pricing
[V-NEXT]: https://vercel.com/docs/frameworks/full-stack/nextjs
[V-ROLLBACK]: https://vercel.com/docs/instant-rollback
