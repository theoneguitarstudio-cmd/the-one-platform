# 已核准 UX 原生前端整合 — 本機進度

## 最終交付更新

本輪原生Mock整合及桌面／手機操作驗收已完成。可直接開啟 http://127.0.0.1:3100/ux-prototype ，服務由本任務啟動並持續運作；重新啟動使用`node scripts/ux-prototype-dev.mjs`。請以[完整驗收報告](UX_PROTOTYPE_ACCEPTANCE.md)及各QA檔最新更新為準，下方保留最初工作紀錄。

Public v1.6、Student v1.2、Player v1.1與最新老師／管理員流程均為原生Next頁面。跨角色共用預約／堂數／回饋、提案與發布快照、師資與公開課程包、文章、規章、財務分權均已實測。最後發現的管理員代約對話框過窄已修正並重拍。

最終Build、TypeScript、source ESLint、74檔696項Vitest通過；production本機實測四個雛形入口404。歷史位元組封存guard仍12通過1失敗，保留原始結果。OS主題即時切換、瀏覽器縮放及完整Network trace受工具限制未驗證；公開頁有捲軸／取景差異，沒有宣稱逐像素一致。

仍為Mock：所有業務資料、角色、發布、權益、財務與已讀；重整重設資料，只有外觀偏好存本機。正式Auth、Supabase、SQL、金流、通知、媒體上傳與備份還原均未接。`preview-test`及main的HEAD仍為起始0af06802dbeb2fcd614d33db3e64c441fe711be4，五份原稿與四份Canonical雜湊不變，無commit/push/deploy。

## 初始工作紀錄（已由上方更新取代待完成狀態）

日期：2026-09-11。這是本機 UX 工作紀錄，不變更四份 Canonical 或 Epic 狀態。

## 工作區與來源

- 起點為乾淨的 `main`，HEAD `0af06802dbeb2fcd614d33db3e64c441fe711be4`；比本機 `origin/main` 記錄多 7 筆既有提交。沒有 fetch。
- 已安全建立 `preview-test`，`main` 指標不動。無既有未提交修改。
- 專案內沒有交接包；實際來源是使用者指定的 `C:/Users/win/Downloads/the-one-complete-frontend-v1-6/the-one-codex-handoff-v1-6/`。
- 已完整讀取 CODEX_PROMPT、README、來源／視覺／整合／驗收／未定事項、路由清單及基線。
- 五份基線 HTML 的 SHA-256 與位元組數吻合。原稿與截圖未修改。
- 實際 Canonical 是 Epic7 A–E LOCAL CLOSED、F 本機工具完成。交接包 context 的 P2 是歷史附件；PROJECT_STATUS 所列遠端 smoke SHA 是歷史基線，不是當前 HEAD。

## 原稿瀏覽方式的明確調整

瀏覽器安全政策拒絕 `file://` 原稿並禁止繞過。使用者於本任務明確核准：改為完整閱讀 HTML/CSS/JS 並對照提供的核准截圖；原生 app 的實際桌面／手機操作與截圖驗收仍須完成。不用本機 HTTP 重送原稿規避限制。

## 隔離與目前進度

- `/ux-prototype` 原生 Next.js 子樹；只在 development 可使用，production 回 404。
- 代理在此子樹不初始化 Supabase session。僅本機記憶體 Mock；無正式 Auth、付款、通知、媒體上傳或 SQL。
- Public v1.6、Student v1.2、Lesson v1.1、共用 Mock command/state 正在實作。尚未宣稱功能或視覺驗收通過。
- 管理員 editor 既有 screenshot 是空白未選課情境；驗收必須另開真正編輯表單。

## 待完成

先完成公開／學生／播放器原生 shell 並檢查，再完成老師管理員流程，接通跨角色資料；最後做全部路由、桌機手機、主題、資料邊界與真實互動驗收，更新本文件與交付報告。

禁止範圍持續有效：不 commit、push、PR、部署、Supabase 連線、SQL/migration、備份/還原、正式金流或通知。

## 2026-09-11 後續完成狀態

上方「正在實作／待完成」是起始紀錄。核准原生整合已完成前次驗收，見 [UX_PROTOTYPE_ACCEPTANCE](UX_PROTOTYPE_ACCEPTANCE.md)。後續追加官方 Logo 與平台帳號／購買／引導流程，詳細驗收、763項測試、實際手機桌面截圖、仍未接線之處及10條操作路徑，見 [THE_ONE_PLATFORM_EXPERIENCE_ACCEPTANCE](THE_ONE_PLATFORM_EXPERIENCE_ACCEPTANCE.md)。本機服務目前使用正常網址 `http://127.0.0.1:3100/`；完整正式平台結論仍是 PARTIAL，不新增 Epic closure。
