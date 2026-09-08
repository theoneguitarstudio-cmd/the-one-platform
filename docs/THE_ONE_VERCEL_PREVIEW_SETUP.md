# THE_ONE_VERCEL_PREVIEW_SETUP

> 此 Vercel 方案已由 OWNER 接受的 Cloudflare Workers + vinext 決策取代。
> 現行入口為 [Cloudflare Preview plan](THE_ONE_CLOUDFLARE_PREVIEW_DEPLOYMENT.md)；本文僅留作歷史準備紀錄。


2026-09-08；起點 preview-test / e4a646fb6744945deafa93f4f97388d9dc5592dc，CLEAN。
**設定與建立程序已可審閱；Project未建立、Preview未部署、尚無可開啟URL。**
本輪是readiness，不是部署批准；main、正式Supabase、theoneguitar.com皆不動。

## 先說會看到什麼

不是空repository，但還不是旗艦課程網站。
目前30個page檔、5個Route Handler：首頁1、Auth6、公開老師3、商品2、Student6、Teacher5、Admin7。
首頁實際顯示「The One 樂玩吉他 2.0 / Platform Foundation / Environment / Build 正常。」
它是白底、黃標籤、有框卡片的基礎頁，不是本轮提議的漸層、少框線完整品牌首頁。
有登入/註冊/忘記與重設密碼、師資與商品列表/詳情、體驗課、訂單、課程方案、排程與管理表單。
Student/Teacher/Admin入口主要是角色入口與連結；Admin明寫正式Dashboard尚未建立。
30不是完成百分比、不是30套完整功能，也不是30頁都能在匿名/空資料環境正常使用。
尚無Guitar Roadmap課程工作區、Membership購買接課程、完整練習/提交/認證UI。
Epic7已有資料基礎，不等於Epic8/9已完成。payment webhook仍拒絕未實作供應商，不可試真付款。

**不能用「建立Project就一定看得到首頁」承諾。**
src/proxy.ts涵蓋首頁、Auth和/api/health，會先驗證Supabase URL/key並執行session流程。
未填public變數會拋錯；health handler自身不連DB，也不能推論整個HTTP請求完全不連Auth。
有獨立測試Supabase之後，可先看基礎首頁/Auth表單；列表可能是空狀態，受保護頁須對應合成帳戶、角色及schema。
不假造enrollment、grant或student progress；不改Proxy略過驗證。
本輪未啟動server、未截取實際渲染畫面、未跑cloud build；以上來自目前程式與合成設定測試。

## 1. 建立Project要填什麼

| 設定 | 本專案值／條件 |
| --- | --- |
| Team / account | OWNER確認由The One控制、允許本商業用途的Team；不能因連線看得到就用together-stories的Team替代 |
| Project name | 建議the-one-platform，真正名稱/ID由核准建立結果確認；不沿用together-stories |
| Git repository | theoneguitarstudio-cmd/the-one-platform |
| Framework | Next.js，現有版本16.3.3，不升級 |
| Root Directory | repository root（Dashboard保持根目錄，API為null）；不是src或src/app |
| Node.js | 24.x；本機24.19.0是已使用版本，package未强制此minor；Vercel僅可選major，須記錄實際build版本 |
| Package manager | packageManager固定pnpm@10.34.5，保留pnpm-lock.yaml與workspace政策 |
| Build Command | corepack pnpm run build（實際package build=next build） |
| Output Directory | Next.js預設，不自訂out或改成static export |
| Development Command | 沿用Next.js預設；不在雲端跑next dev |
| Install Command | 下方固定版本、frozen-lockfile、ignore-scripts的命令 |
| Production Branch | main，建立後實查Environments → Production → Branch Tracking，不依賴預設猜測 |
| Preview Branch | preview-test；不是Production Branch，不需建立付費custom environment來表示此分支 |
| Protection | 先限制OWNER/核准測試者，使用Team實際具備的Deployment Protection；不為方便關閉保護 |
| Domains | 只使用Vercel生成的Preview URL，不新增Production domain，不綁theoneguitar.com |
| Integrations / jobs | 不自動連Production Supabase、付款、LINE、AI、VdoCipher、cron或其他正式服務 |

Vercel支援[Node24.x及major選擇](https://vercel.com/docs/functions/runtimes/node-js/node-js-versions)。
[套件管理文件](https://vercel.com/docs/package-managers)說明Corepack可依packageManager固定版本；
需於Preview的建置環境設定ENABLE_EXPERIMENTAL_COREPACK=1。
不要只填未限定版本的pnpm install；它可能落到別的預裝pnpm版本。

建議Install Command（Linux建置容器；本輪未執行安裝）：

```sh
test "$(corepack pnpm --version)" = "10.34.5" && corepack pnpm install --frozen-lockfile --ignore-scripts
```

保留workspace中的ignoredBuiltDependencies: sharp / unrs-resolver。
若指定版本取不到、校驗失敗、lock不合或native套件失敗，STOP並由工程分析，
不改latest、不重建lock、不一次批准所有scripts。不在install/build加migration、seed或Supabase linked命令。
src/app/layout.tsx使用next/font/google的Geist/Geist Mono，雲端build需正常官方字型存取；本輪沒改字型或做離線假頁。

## 2. 安全的第一次建立／Preview流程

**首次部署特別小心：** Vercel[首次CLI部署指南](https://vercel.com/docs/projects/deploy-from-cli)明確寫，
新Project第一次裸vercel deploy可能成為Production，即使沒有--prod。
因此「沒有綁正式網域」不等於「不是Production」。不要讓OWNER直接點Import頁最後的Deploy來碰運氣。

下一輪在OWNER核准Team與建立範圍後，工程採兩段：

1. 僅建立Project與設定：使用官方create-project API或vercel link的建立能力，
   不同時送deployment。先記錄確切Team/Project ID，設定Next.js/root/build/install/Node/保護。
   Git連結前後核對repo與main Production Branch；若任何UI只有建立並部署選項，停在該按鈕之前，
   改用已核准的create-only程序，不先部署一次Production當跳板。
2. 獨立Preview後端/變數就緒並另獲該次Preview部署授權後，
   使用明確的 `vercel deploy --target=preview`（需先核對受控CLI版本與指定Project/Team），
   或官方deployments API的Preview請求。不能使用裸deploy作首次預設。
   CLI的[--target明確支援preview](https://vercel.com/docs/cli/deploy#target)；
   [API](https://vercel.com/docs/rest-api/deployments/create-a-new-deployment)以省略target表示preview，回應target=null，
   不把API的staging別名當本案preview捷徑。
   若CLI行為/實際API參數不能確保Preview，停止，不自動改Production。
3. 若選CLI上傳，必須用乾淨受審checkout及上傳排除規則，確保ignored artifacts/cache、.env、本機工具與資料不被送出；
   不能把公司整個目錄當deploy payload。優先以核對的Git commit作GitSource。
4. 部署後驗證project/repo/commit、environment=Preview、Production指標/網域未動、build版本及非秘密錯誤。
   首次URL出來後才能核定NEXT_PUBLIC_SITE_URL和測試Supabase redirect allowlist，
   必要時重新Preview build；不能從Production抄站點URL。驗證手機首頁、Auth顯示與無正式請求後才交URL。

以上是可執行設計，**未建立、未連結、未部署，也未安裝Vercel CLI**。
API/CLI登入若缺授權，OWNER只需在官方登入畫面授權，不把token貼聊天。

## 3. preview-test與main各自怎麼工作

[官方Git整合規則](https://vercel.com/docs/git#production-branch)：
Production Branch=main時，preview-test是非Production分支，Git整合可為其push/PR產生Preview。
目前GitHub preview-test已存在；不需要merge到main才看Preview。
Project尚未連結時push只是GitHub同步；連結後push preview-test可能立即觸發Preview build，須將後端隔離及變數先準備好。
以project實際設定為準，不以分支名稱自行認定部署環境。
main保留Production Branch與穩定基線；任何main push/merge、--prod或promote仍需獨立正式授權。
這不是要求本輪修改main、GitHub default branch或新建Production domain。

## 4. Preview專用變數

只配置Vercel的Preview scope，能限定preview-test時再限定；不要勾Production。
不要改NODE_ENV為development：Next.js的Preview build仍是production-mode編譯。
變數管理與[環境隔離](https://vercel.com/docs/environment-variables)遵照Vercel，值不進Git、聊天或evidence。

| 名稱 | Preview用途與最小要求 |
| --- | --- |
| ENABLE_EXPERIMENTAL_COREPACK | 1，非秘密的建置開關 |
| NEXT_PUBLIC_SUPABASE_URL | OWNER核准的獨立測試project URL；不得是ygxeihtcolpiulupieeq正式target |
| NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY | 同一獨立測試project的publishable key；可公開不代表可拿正式project來測 |
| NEXT_PUBLIC_SITE_URL | 實際核對過的https Preview站點origin；程式不自動由VERCEL_URL推導，不填theoneguitar.com或localhost |
| SUPABASE_SERVICE_ROLE_KEY | 只有測試既有privileged Admin流程才需要；限同一獨立測試project、server-only、Preview scope。先看首頁/Auth不必提供；缺值保持該功能不可用 |
| MANUAL_BANK_TRANSFER_INSTRUCTIONS | 若測試表單，需要明寫「測試，請勿轉帳」，不得填真正收款指示 |
| LINE_CHANNEL_SECRET / LINE_CHANNEL_ACCESS_TOKEN | 此Preview階段不啟用，不填正式值 |
| VDOCIPHER_API_SECRET / PAYMENT_PROVIDER_SECRET / OPENAI_API_KEY | 範本有名稱不代表目前需要；保持未設定，不借正式值、不啟動真付款/發信/付費外部呼叫 |

現有來源有5個實際application env讀取名稱（含可選轉帳說明），另使用NODE_ENV決定本機site fallback。
.env.example中的其他整合名稱目前是預留；不可「把所有正式env複製進來」。
網站本身不需要DATABASE_URL、Supabase DB密碼、Supabase管理access token或Vercel操作token。
正式service-role/secret key、正式URL與publishable key組合、DB connection string、JWT signing秘密、
SMTP/付款/LINE等正式憑證、備份與學生資料皆不能放Preview。
Vercel Team shared env或Marketplace自動注入也須核對scope，不能自動繼承正式值。

**目前獨立Preview Supabase的project/ref/schema/Auth redirect/合成帳戶全部未核定。**
公司Docker不是Vercel可連後端，不把本機production備份匯進Preview。
要看登入後/資料表單，下一輪需另批准獨立測試環境與合成資料初始化；
沿既有schema及角色邊界，不偷做Epic8，不把isolated初始化當正式migration批准。

## 5. OWNER真正需要的畫面（最多三組）

1. Vercel登入後的Team選擇與Team Settings → Billing：確認哪個是The One控制且適合商業用途的Team，
   不重查GitHub App All repositories，不要求立即付款。
   本輪連線只看見together-stories Project，方案Hobby；
   [Hobby限個人非商業](https://vercel.com/docs/plans/hobby#hobby-billing-cycle)，不能把商業預覽預設放此方案。
   其他合格Team是否已存在UNKNOWN，先選已有合格Team，不擅自升級。
2. 若UI用Add New → Project → Import，選theoneguitarstudio-cmd/the-one-platform，核對上表。
   **停在最後Deploy之前**；OWNER批准create-only＋明確Preview範圍後，由工程接手安全建立與設定。
   不必OWNER自己除錯命令或先建Production。
3. Project建立後的Settings → Environments（main tracking）、Build and Deployment、
   Environment Variables及Deployment Protection：核對工程填好的值/scope。
   獨立測試Supabase需由OWNER指定或另批准建立；必要金鑰只在官方設定介面輸入，不貼對話。
   最後查看Deployments的Preview標記和網址，不點Promote to Production。

若OWNER只想現在選Team、批准建立，後續設定可由已授權工具完成，不要求OWNER逐欄操作。
本輪實際停止在「Team/商用方案、獨立Preview後端與create/deploy批准」外部界線；
不是尚欠一套假網站，也不是逼OWNER處理SQL。

## 6. 本輪驗證與下一步

來源：30 page/5 handler盤點、所有src env讀取/Proxy/client及核心actions，
package/lock/workspace、空next.config、無vercel.json/.vercel/project.json/.github workflows。
6組合成設定檢查PASS：缺public env、無效env、獨立合成配置、缺site/service key、
顯式Preview origin、Proxy涵蓋範圍。無網路/DB/server，沒有認證繞過。
本輪是文件與readiness驗證，沒有聲稱Linux/Vercel build或畫面E2E已PASS；
application/歷史migration/package/lockfile未改，不重跑完整SQL/build或舊Epic7測試。

本輪視覺方向僅記錄：現代、乾淨、輕科技、可漸層、色彩不限定黃黑白、
少框線/少Card、以色彩背景留白字級分層、mobile first，避免WordPress LMS/企業後台感。
未重做第二套網站；下一個視覺改動應直接改正式application，須保持原產品界線，
不以Preview理由實作Epic8/9。

**可開始建立Project的設定審查：YES。可現在直接部署並保證可看：NO。**
OWNER確認The One Team與獨立測試後端、核准create-only/Preview步驟後，
工程可建立、設定、執行受影響build/runtime驗證並提供Preview URL；不需先通過正式DB migration。
Epic7正式Backup/Recovery gate是另一條線，不以Preview可看冒充它已通過。
