# Approved native UX integration — 2026-09-11

本輪依 OWNER 的 SAFE UX INTEGRATION → PREVIEW DEPLOYMENT 授權，取代先前文件「僅本機、不 push/deploy」的交付限制。僅允許 origin/preview-test 與既有 Cloudflare Free workers.dev Preview。未新增產品功能或更改 Canonical 決策。

## 保存與來源

- 整合來源：origin/preview-test `7c3324fa6d250c34520ee219fd62948a0ed21920`。
- 本機 safety commit：`d60ab68332426ef99df7e63412bb805309f698bc`，分支 ux-product-safety 不推送。
- Git 外備份 311 檔、37,330,771 bytes，逐檔 SHA256 已核對；未包含環境秘密、正式資料、dump 或備份。
- manifest SHA256：`0572bc16422db6cfba1658864302e32d1b75f4206bb8d190a0bcc470cc1f0945`。
- 外部證據目錄：`C:/Users/win/.codex/visualizations/2026/09/11/01a08fba-2848-7530-995f-cfea6ad3a331/` 的 ux-product-safety、ux-preview-evidence。
- 保留完整最新四份 Canonical、Cloudflare/Git 防護與 Epic 1–7 工程來源。main 未合併、未推送。

## 原生 UX 與邊界

公開首頁 v1.6、學生 v1.2、三欄教室 v1.1、老師/管理員整合流程及帳戶/會員/帳務/結帳頁，保留既有原生 React 元件與共享 Mock store。正常 URL 經 Proxy 導向同一套原生頁面；沒有整頁 iframe 或獨立 HTML。Logo 保留原始 Logo9.png 位元組。

只在既有明確 Preview Mock 旗標生效；非 Mock 正式路由仍保留原有 Auth 與 domain service。Worker 核對 build/runtime 後，對 Mock 非 GET/HEAD 在進入 vinext 前拒絕。保留 1 MiB/10 秒請求上限，先完成受限 body buffering，避免本機 Proxy 對提早拒絕的串流回傳偶發 500。

老師提案／管理員編輯發布、預約與回饋仍共用 Mock；不存在正式登入、交易、會員變更或資料庫寫入。正式服務沒有以 Mock 身分替代安全驗證。

## 型別產物漂移

Next 會產生 routes/root-params/validator；vinext 會加入 augmentations 且產生不同 routes。依序在同一 .next/types 建置會留下不相容的 Next validator。此次已清除乾淨工作樹的舊產物，Next 驗證使用既有 THE_ONE_UX_BUILD_CHECK=1 專屬目錄，保留 Next 自動加入的 tsconfig includes；vinext 仍用自己的型別。沒有 reset、修改歷史 hash baseline 或把失敗改寫為 PASS。

## 驗證與交付

- Next production build、TypeScript、ESLint、35 個相關測試檔／341 tests 通過。
- Cloudflare vinext Mock build 通過。Vite native config 未來版 warning 原樣保留。
- 新增 ux-http-proof：26 個主要頁面、3 個寫入拒絕，另核對 callback/join 封鎖、404、原始 Logo SHA256 與版本指紋。舊 mock-http-proof 保留為原 Server Action demo 的歷史證據，不冒稱新 UX 已通過舊登入表單測試。
- 實際瀏覽器操作：老師圖卡 teacherId → 課程包、Mock 草稿儲存/發布、財務明細、取消方案四步驟、一對一 Checkout 到明確無付款結果。桌面 1440×1000、手機 390×844 截圖保留在外部證據目錄。
- 教室獨立捲動：右欄 scrollTop 0→1653，左側兩欄保持 0，文件高度保持 1000。Preview 標記不佔教室／工作空間高度。
- 初次廣泛 vitest 自動收集 Epic 7 node:test 歷史套件產生失敗；沒有執行 DB/recovery，沒有重跑不相關歷史套件或改動其證據。

部署後以公開 /__preview-meta、origin/preview-test HEAD 及瀏覽器線上 smoke 作最後證明，結果記錄在外部驗收報告；本文件本身不是部署成功聲明。實際交付不開通 Auth、付款、通知、上傳、SQL、migration、Production Supabase 或任何付費/有狀態 Cloudflare binding。
