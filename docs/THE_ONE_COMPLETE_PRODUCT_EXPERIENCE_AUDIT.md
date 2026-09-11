# The One 2.0 完整產品體驗盤點

日期：2026-09-11。工作分支：`preview-test`。本文件不是 Canonical 決策或 Epic closure。

## 盤點基準

依序閱讀 CURRENT_WORK、PROJECT_STATUS、CANONICAL_ROADMAP、PRODUCT_DECISIONS，並比對現有 src/app、src/modules、Epic 文件與 UX_PROTOTYPE_ACCEPTANCE。新增需求來自 OWNER 附件；外部 push、部署與正式服務連線仍遵守本機限制。

正式程式的 Epic 1–4 已 CLOSED、5–6 已 REMOTE CLOSED、7 為 LOCAL CLOSED。這是既有能力狀態，不能當作新 UX 已整合、遠端驗證或可正式營運的證據。Repository 中未找到 THE_ONE_PRODUCT_UX_DIRECTION 或 Cloudflare Preview 文件，不推測其內容。

## 已有、缺少與整合方式

| 旅程 | 已有 | 缺少 | 本輪可做 | 後續責任 |
| --- | --- | --- | --- | --- |
| 公開網站 | v1.6 原生首頁、老師介紹、課程介紹；Epic2 公開教師投影 | 完整目錄、FAQ、About、客服、政策缺口入口 | 共用品牌與導覽、补足入口、空白與不可用狀態 | 正式內容及政策核准 |
| 帳戶 | Epic1 註冊、登入、驗證信、忘記密碼、多角色；profile schema | 整合帳戶中心、帳單、偏好、刪帳資訊 | 沿用驗證契約；本機表單與清楚的未接線回饋 | 真 Auth 及刪帳保留政策 |
| Membership | 已核准 Free=方向、Plus=系統、Pro=成果與真人驗證 | Epic8 lifecycle、價格、續費及取消政策 | 顯示方案差異；模擬取消流程與決策缺口 | Epic8、OWNER policy |
| Checkout / Orders | Epic4 product、order、轉帳回報與管理員審核 | 新視覺整合、三種購買後導向、正式 provider | 沿用 checkout schema；本機結果展示不收款、不建立 entitlement | 安全 backend adapter、provider |
| Private Lesson | Epic5 credits、Epic6 booking、學生取消／改期、makeup/fixed SQL | 部分 TS adapter 及新 UX 接線 | 顯示既有 DTO 契約、修正舊 Prototype 文案與流程缺口 | 正式 RPC execution、競態與 DB 驗證 |
| Learning | Epic7 immutable map/activity foundation；核准 v1.1 三欄播放器 | Epic8 access authority、Epic9 workspace backend | 保留播放器外觀、既有學習 UX、未授權狀態 | 不可把 shipped authority=false 改成 true |
| Practice / Feedback | 核准原生示意、跨角色共用資料 | Epic9–11 正式 practice/submission/verification | 本機 UX 連續流程；推薦不等於加入、自報不等於驗證 | 各 Epic scope 與服務政策 |
| Teacher | Epic2 profile、3 trial、5 package、6 schedule | 新工作台接線、Epic12 workspace | 保留老師僅提案、教學回饋與日常導覽 | 正式資料及授權 |
| Admin / Creator | 既有老師、訂單、課包、排程管理 | Epic13 CMS/operations 完整接線 | 原生編輯器與營運示意、清楚能力邊界 | Creator 非新增 Auth role；課程發布不同於商品發布 |
| 跨頁體驗 | 原生共享元件、共享 Mock store | 同一網站入口、帳戶入口、三種成功導向 | 本機 development gate 內重用現有元件，正常網址與舊 UX 入口共存 | production 既有路由與 guard 保留 |

## 不能再造的能力

不另建 Auth、Roles、Teacher、Trial、Commerce、Orders、Credit、Booking 或 Learning Map domain。正式 DAL/Server Actions 多數直接連 Supabase，真正交易不變量在 RPC/DB；本輪沒有獲准可執行的 local/preview DB。因此新增 application gateway 只沿用純 DTO/schema/權限函式，以固定合成資料展示與驗證，不重造付款或 ledger 引擎、不失敗後 fallback 到正式服務。

標記定義：REAL = 實際執行既有 backend；HYBRID = 既有契約／驗證加本機 fixture response；MOCK = 尚無 backend 的本機互動。這輪 HYBRID 也不是已接通正式交易。

## 必須修正的 Prototype 假設

- Student 既有 Epic6 自助取消與改期；不能聲稱只能由 Admin 操作。
- 老師造成取消的正式流程可能轉為 makeup right，不能統一當作普通可用堂數返還。缺政策時拒絕，不猜補課期限。
- 正式 id 為 UUID，不能把 s1/t1/c1 傳正式 schema；公開老師以 publicSlug 導覽。
- 普通課時長來自 snapshot；不能將 Trial 50 分鐘規則擴為所有課。
- paid 不等於 entitlement；推薦不等於 enrollment；進度不等於正式驗證；Membership 不等於單一課程。

## 需決策、未來 Epic 與不需要

尚未 Accepted 的價格、續費、取消生效時間、退款、grace period、真人額度、review SLA、發票與刪帳保留政策，詳見 THE_ONE_PRODUCT_DECISION_GAPS。只能展示待定狀態，不預設商業承諾。

Epic8–13 backend 不因 UI 需求自動啟動。Finance 正式結算、Community、AI Personalization、Cloud Classroom、Marketplace、其他樂器與 Native App 都不是本轮完成的前置要求。無需求的排行榜、競品式 LMS 功能與自動 AI 授證不加入。

## 驗收方式

先完成上述盤點再實作。實際操作桌面與手機，檢查官方 Logo、登入入口、帳戶／會員／帳單／取消、三種 checkout 導向、onboarding、私人課、回饋、三欄播放器及管理員對話框。保留原稿與既有截圖。測試與實際限制在本輪驗收文件補錄；build 通過不等於視覺無差異。
