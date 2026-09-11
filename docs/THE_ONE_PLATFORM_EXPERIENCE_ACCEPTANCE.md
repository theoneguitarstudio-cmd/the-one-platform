# The One 2.0 平台體驗整合驗收

日期：2026-09-11（台北）。結論：**PARTIAL**。核准原生介面與新增帳號／購買／引導旅程可在本機操作；整个平台尚未形成正式帳戶、交易、訂阅與教學服務端到端接線。此文件不宣告 Epic CLOSED、REMOTE VERIFIED 或 PRODUCTION READY。

## 開啟與範圍

- 本機：[首頁](http://127.0.0.1:3100/)、[學生](http://127.0.0.1:3100/student)、[帳號](http://127.0.0.1:3100/account)、[老師](http://127.0.0.1:3100/teacher)、[管理員](http://127.0.0.1:3100/admin)。
- 啟動：在 repository 執行 `node scripts/ux-prototype-dev.mjs`。腳本要求 `preview-test`、development、127.0.0.1，注入無效本機服務地址和非憑證占位值。
- 正常網址在 development＋明確旗標＋loopback 的代理中對應原生 React 頁面；舊 `/ux-prototype` 入口保留。這不是正式 route/DAL 已全面換線。
- 共用 UI、共用 Mock store 與純契約 gateway 都在現有 Next.js repository；没有整頁 iframe，也沒有用截圖替代功能頁。首頁核准介面縮圖只是原設計中的說明插圖。
- Mock 工具明確切換示意身分。重新整理重設記憶體資料；外觀偏好例外。不是登入或新增角色。
- 全程未 push、部署、執行 SQL/migration、連正式 Supabase、正式 Auth、付款、通知、上傳、備份或還原；沒有新 commit。

## OWNER 的 15 項問題

| 問題 | 實際結果 |
| --- | --- |
| 1. Epic1–7 哪些接入 UX？ | Epic1 Auth/profile/角色純驗證、Epic4 checkout schema、Epic5 entitlement DTO、Epic6 取消／改期／時區契約被重用。Epic2 公開教師、Epic3 Trial、Epic5/6 真實交易服務、Epic7 learning service 沒有接入新本機 runtime；既有程式保持。Epic7 shipped authority 仍為 false。 |
| 2. 新增頁面？ | Account 總覽、個資、安全、會員比較／取消／恢復、帳務、訂單不可用狀態、通知、偏好、幫助、搜尋、刪帳與離開預覽；Membership、三種 Checkout 與結果、System Courses、Products、新生引導、FAQ/About/Support/Legal；Auth 各步驟與錯誤／不可用頁；單堂改期／取消確認。 |
| 3. 等待 Epic8–13？ | Membership lifecycle/access、學生學習持久化、作業／評量／真人回饋、Teacher workspace 與 CMS/operations/通知正式接線。所有 UI 成功提示均不等於正式交易成功。 |
| 4. 註冊到學習完整？ | 本機表單→驗證信步驟→五題引導→未加入 Today→明確加入→Map→核准 Stage2 課節可操作。没有寄信或正式帳戶；新生使用既有合成 s2 情境。Stage1 完整教材未提供，該處保留說明，沒有捏造首堂教材。不是正式完整旅程。 |
| 5. Membership / Checkout / Billing / Cancel？ | 本機比較、三種購買意圖、結果、帳務失敗狀態、四步取消及恢復有流程。無真訂閱、付款方式、訂單／發票查詢、續扣或取消生效；價格與政策不擅自決定。 |
| 6. Private Lesson？ | 核准共用 Mock 課包／堂數／預約／回饋保留；ab1、ab2 可走既有 schema 的單堂調整確認，但不執行交易。新建 Mock 預約沒有正式契約 token，會顯示未接線。Trial 原有鏈尚未映射進本機 UX。 |
| 7. Teacher？ | 今日課次、自己的學生、課前準備、課表、代約、作業回饋、紀錄、提案、展示頁、自己的報酬可操作 Mock。正式服務尚未整合；沒有發布正式課程權限。 |
| 8. Admin / Creator？ | 課程草稿／預覽／發布、提案審核、學生權益、預約、Pro 調度、文章、守則、檢視與財務有 Mock。Creator 沿用內容提案能力，不新增 Auth role。既有部分 Admin route 與真訂單／Membership 營運尚未映射，見 Experience Map §15。 |
| 9. 主動補上？ | 三購買意圖分流、帳戶安全與刪帳區分、付款不可用而非假空資料、角色讀取 gate、通知正確深連結、手機對話框焦點、空白表單提示、未知頁面與本機隔離。 |
| 10. Product Decision？ | 13 項 Proposed 見 Decision Gaps；優先是價格／週期／方案能力、升降級、取消／恢復、欠費重試、退款／憑證，再到資料保留、客服／通知、人力服務與評量。 |
| 11. Mobile？ | 已操作 390×844，另檢查 320/360/390/768/1024/1440 共 48 個主要頁面寬度組合。核心畫面與對話框見下；無完整真機、OS 縮放或所有支線全組合聲明。 |
| 12. Logo？ | 使用 OWNER 的 Logo9.png，檔案位元一致，共用 BrandLogo 套入公開、學生、教室、老師／Admin、帳戶及 Auth。窄 rail 用 CSS 裁出原圖圓標，不改圖片內容；原稿中的核准介面縮圖不改。 |
| 13. Production Supabase？ | 本輪正式服務操作為 0；沒有資料庫／Auth／payment action。讀碼、CPU 測試與本機 HTTP 隔離驗證，沒有把它寫成完整網路封包稽核。 |
| 14. commit / HEAD？ | 無新 commit；`preview-test` HEAD `0af06802dbeb2fcd614d33db3e64c441fe711be4`。所有修改留工作樹。 |
| 15. main？ | `main` 仍 `0af06802dbeb2fcd614d33db3e64c441fe711be4`，未切換／修改／push main，既有未提交變更保留。 |

## 正式 Logo 與原稿對照

原圖：`C:/Users/win/Downloads/Logo9.png`；使用檔：`public/brand/the-one-logo.png`；2667×765，SHA256 均為 `9BEDB5AB28FBA4490876957F03A5354F4EFEBBDF8A6E90F2C6133206DCCCCD43`。

公開首頁 v1.6（長方形老師圖卡）、學生 v1.2、教室 v1.1、整合 Demo 老師／Admin 保留。沿用前次逐張原稿／原生比較，詳見 [UX_PROTOTYPE_ACCEPTANCE](UX_PROTOTYPE_ACCEPTANCE.md) 及其 comparison artifacts。原稿 browser 開啟受政策限制；OWNER 已核准以完整 HTML/CSS/JS＋核准截圖替代；本機 app 仍實際操作。

原稿五份 HTML 與四份 Canonical 的雜湊核對未變。沒有修改原稿或核准截圖掩蓋差異。新 Logo 是本輪明確授權差異；新增帳戶、購買與支援頁沒有核准原稿，不宣稱逐像素一致。先前 source reviewbar 與 Windows 字型差異繼續保留在前次驗收記錄。

## 實際瀏覽器流程

| 檢查 | 結果／限制 | 證據 |
| --- | --- | --- |
| 三種 Checkout | subscription→會員／目錄；standalone→原有訂單／課程；private→原有堂數與預約。均不增權益；公開資料沒有已發布單品課，不把草稿當商品。 | [訂閱](../artifacts/platform-experience/checkout-subscription-result-mobile.jpg)、[單品](../artifacts/platform-experience/checkout-standalone-result-mobile.jpg)、[私課修正版](../artifacts/platform-experience/checkout-private-context-mobile.jpg) |
| teacherId / offerId | 首頁卡片→t1 private tab→p4→結果顯示同一老師與4堂包。t2+p4 被拒絕，沒有 fallback 到他人課程。 | [桌面老師卡](../artifacts/platform-experience/teacher-card-desktop.jpg)、[結果上下文](../artifacts/platform-experience/checkout-private-context-mobile.jpg) |
| 新生引導 | 五題可前後操作；換題焦點移回題目，結果不自動加入。明確加入後才出現個人 Map；Stage1 尚未提供完整內容，Stage2 示例可進入播放器。 | [換題](../artifacts/platform-experience/onboarding-focus-mobile.jpg)、[未加入 Today](../artifacts/platform-experience/new-student-unenrolled-mobile.jpg) |
| 三欄教室 | 桌面 1440：rail64、outline360、main1016；document scrollTop=0，內容區獨立捲動。手機影片與教材正常，章節抽屜可開關／Escape。 | [桌面](../artifacts/platform-experience/player-desktop.jpg)、[手機](../artifacts/platform-experience/player-mobile.jpg)、[章節](../artifacts/platform-experience/player-chapters-mobile.jpg) |
| 取消與恢復會員 | 原因長中文、確認勾選 gate、取消結果跨頁保留；恢復確認清示意標記。Free 不提供付費取消。修正原本切頁丟失標記與 dialog 左上角定位。 | [取消](../artifacts/platform-experience/membership-cancel-mobile.jpg)、[修正後置中](../artifacts/platform-experience/reactivate-dialog-mobile-fixed.jpg) |
| 帳務與支援 | 正式訂單未載入有明確 unavailable；failed 狀態不稱欠費。憑證／付款對話框、長中文支援 dialog 有捲動；Escape 焦點回到觸發按鈕。純空白公開支援有可見錯誤。 | [帳務桌面](../artifacts/platform-experience/account-billing-desktop.jpg)、[付款失敗](../artifacts/platform-experience/payment-failure-dialog-mobile.jpg)、[長中文](../artifacts/platform-experience/support-long-dialog-mobile.jpg)、[空白提示](../artifacts/platform-experience/support-whitespace-mobile.jpg) |
| 既有預約調整 | ab1 改期格式／時區確認成功，返回仍9/9 20:00，2可用1預留。ab2 取消确认可完成，原預約與堂數不更動。 | [ab1](../artifacts/platform-experience/booking-change-desktop.jpg)、[ab2](../artifacts/platform-experience/booking-ab2-cancel-mobile.jpg) |
| 老師→學生→通知 | r1 填寫回饋／練習→預覽→Mock送出→切學生→讀到相同文字與練習；通知也顯示同一回饋，可標已讀。Pro 通知連到 guidance，不誤連 private。 | [老師桌面](../artifacts/platform-experience/teacher-feedback-desktop.jpg)、[手機確認](../artifacts/platform-experience/teacher-feedback-confirm-mobile.jpg)、[學生](../artifacts/platform-experience/student-shared-feedback-mobile.jpg)、[通知](../artifacts/platform-experience/notification-shared-feedback-mobile.jpg) |
| 角色讀取 | 管理員→公開首頁→預覽學生空間被拒；只有明確切換 Mock 學生才顯示。測試另覆蓋 Teacher、Finance、異學生、未知學生與所有 student 分支。 | [拒絕畫面](../artifacts/platform-experience/student-role-block-desktop.jpg) |
| 課程編輯器 | 真正打開 c1 表單及發布前預覽，未以空白列表冒稱 editor 檢查；手機完整確認按鈕可見。未新增正式發布能力。 | [桌面](../artifacts/platform-experience/course-editor-desktop.jpg)、[手機](../artifacts/platform-experience/course-editor-mobile.jpg)、[確認](../artifacts/platform-experience/course-publish-dialog-mobile.jpg) |
| 財務 | 桌面總覽、手機620px表格放在342px可捲容器；鍵盤橫捲scrollLeft>0，頁寬保持390；明細dialog正常。 | [桌面](../artifacts/platform-experience/finance-desktop.jpg)、[手機表格](../artifacts/platform-experience/finance-table-mobile.jpg)、[橫捲](../artifacts/platform-experience/finance-table-scrolled-mobile.jpg)、[明細](../artifacts/platform-experience/finance-detail-mobile.jpg) |
| 六種寬度 | 首輪首頁320px有3px頁尾溢出，已用連結換行修正；48組複測無document水平溢出、無broken image。表格／卡片自身横捲是核准行為。 | [結果](../artifacts/platform-experience/responsive-widths.json)、[保留修正前](../artifacts/platform-experience/responsive-widths-before-footer-fix.json) |

## 程式與隔離檢查

- 功能測試：79 files／763 tests PASS，包含新增 pure gateway、route matcher、local mode、角色讀取掛載守衛；[test.log](../artifacts/ux-prototype/test.log)。
- 全 src/tests lint 與 TypeScript PASS；[lint.log](../artifacts/ux-prototype/lint.log)、[typecheck.log](../artifacts/ux-prototype/typecheck.log)。最後的 CSS 修正也包含在最終 build；probe script 另跑 ESLint PASS。
- 最終 Next production build PASS，31 static pages；[build.log](../artifacts/ux-prototype/build.log)。曾發生 webpack cache hash 例外，保留 [原始失敗](../artifacts/platform-experience/build-cache-failure.log)，只清除已核對絕對路徑的獨立 build cache 後重建，沒有更動受保護來源。
- 既有 Epic7 Node guard：12 PASS／1 FAIL，原因 `Protected content mismatch: next-env.d.ts`。這是 Next 產生的 type hint 與歷史封存位元不同；不重寫封存 manifest，不把此檢查列為 PASS。[legacy-guard.log](../artifacts/ux-prototype/legacy-guard.log)。
- 實際短暫啟動本機 production，4個雛形入口回404；dev200、CSP self／noindex 正確。Windows 已保留3101–3200，probe改用127.0.0.1:4101，完成後自動關閉；沒有部署。[production-isolation.json](../artifacts/ux-prototype/production-isolation.json)。
- 開發模式阻擋非loopback、非GET/HEAD、API、真正lesson join與Auth callback/confirm；matcher特別測試動態路徑帶圖片副檔名仍不得繞過。
- 瀏覽器累積log保留開發中HMR／provider組裝期間的錯誤與早期圖片LCP提醒；完成修正後的21:20起記錄沒有新增warn/error。這不是完全沒有發生過錯誤的宣稱，見本輪browser log檔。

## 仍未完成與下一次正式接線邊界

沒有真登入、信箱驗證、付款、訂單／發票、訂閱生效、退款、正式預約改期／取消、跨裝置儲存、真人批改或影片上傳。取消／恢復／客服只是可檢視的本機流程；不建立另一套會員或客服 domain。

既有正式公開 teacher slug 與 Mock teacherId 未完成對照。Trial chain、部分 Teacher/Admin 原 route 與新UX還沒有映射；帳務沒有偽造可用訂單。購買意圖穿過正式登入的續接、完整 Stage1 教材、完整評量與認證都未完成。沒有為縮短報告省略這些缺口。詳見 [Experience Map §15](THE_ONE_PLATFORM_EXPERIENCE_MAP.md) 與 [Product Decision Gaps](THE_ONE_PRODUCT_DECISION_GAPS.md)。

## OWNER 最值得親自測試的 10 條使用流程

以下是本機可操作／可核對的流程，正式服務斷點依前述明示；不是10條 production 完整旅程。

1. [首頁](http://127.0.0.1:3100/) → 線上一對一 → 老師卡 → 4堂課包 → 結帳示意 → 核對結果仍是同一老師與課包。
2. [註冊](http://127.0.0.1:3100/auth/sign-up) → 填合成姓名／email與12字英數密碼 → 驗證信步驟 → 新生引導 → Today未加入 → 明確加入 → Map → Stage2教室示例。
3. [會員方案](http://127.0.0.1:3100/membership) → 比較Plus/Pro → 訂阅結帳示意 → 結果 → 會員管理；確認沒有真加權益。
4. [帳務](http://127.0.0.1:3100/account/billing) → 憑證狀態 → 付款失敗情境 → 帳務協助 → 長中文草稿 → Escape返回。
5. [會員管理](http://127.0.0.1:3100/account/membership)（預設s1 Pro）→ 取消四步 → 返回會員查看標記 → 恢復確認；正式方案應不變。
6. [私人課](http://127.0.0.1:3100/student/private) → 查看堂數 → 調整時間 → 改期／取消確認 → 返回核對原時間與堂數未變。
7. [教室](http://127.0.0.1:3100/student/courses/c1/lessons/l3) → 教學／練習切換 → 自報完成／下一課 → 學習地圖；手機開章節抽屜。
8. [老師](http://127.0.0.1:3100/teacher) → 明確切換老師Mock → 作業與回饋 → 小宇r1 → 預覽送出 → Mock工具切學生 → 師生回饋與通知核對相同內容。
9. [管理員](http://127.0.0.1:3100/admin) → 明確切換管理員Mock → 課程管理 → c1編輯→填原因→草稿／發布前預覽；再切老師檢查只有提案能力。
10. [管理財務](http://127.0.0.1:3100/admin/finance) → 手機橫捲表格 → 看明細 → 切營運／財務能力情境；財務角色不得讀學生教學資料。

測試同一份資料時請用頁內連結和 Mock 工具切換；重新整理會重設資料。
