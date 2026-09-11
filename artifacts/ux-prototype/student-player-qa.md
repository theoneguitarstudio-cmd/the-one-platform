# 學生 v1.2 / 錄播教室 v1.1 原生整合實測

測試日期：2026-09-11。分支 `preview-test`。入口 `http://127.0.0.1:3100/ux-prototype/student`。

## 原稿與核對方式

- 完整閱讀 `references/student-approved-v1.2.html`、`references/lesson-locked-v1.1.html` 的 HTML、CSS、JavaScript，以及最新 Demo 的 Pro 作業流程。依使用者明確同意，以來源閱讀及既有截圖替代被瀏覽器政策阻擋的 `file://` 原稿操作。未用 localhost 重新提供原稿。
- 對照原始 `student-today-dark.png`、`student-today-mobile.png`、`student-courses-dark.png`、`student-map-dark.png`、`student-private-dark.png`、`lesson-locked-desktop.png`、`lesson-locked-mobile.png`。核准原稿與截圖未修改。
- CSS 對應原稿並限定 `.ux-student` / `.ux-lesson` 範圍。原稿非產品示意控制條依整合規格移除，因此桌面內容約向上 36px、手機約向上 34px；整合工具獨立浮於左下。
- Windows 瀏覽器保留約 10px 捲軸溝槽，字型 fallback / 字型繪製與原稿截圖有差異。因此本報告主張結構與視覺核對通過，不主張逐像素一致。
- 私人課原稿日期 9/12 與整合 Demo 日期 9/9 不同。三端統一使用共用 Mock 時鐘 `2026-09-08T00:00:00Z`、預約 9/9，固定時段星期與時間由同一筆資料顯示。學生卡片讀各學生自己的 `focus`。

## 實際操作結果

| 項目 | 實際操作與觀察 | 結果 |
| --- | --- | --- |
| Today 桌面 | 1440×1000；學生導覽 220px，主區 1220px；卡片、練習清單、私人課提示、課節橫列皆目視核對。 | PASS |
| Today 手機 | 390×844；單欄順序、卡片、練習、手機選單；Escape 關閉選單並將焦點還給「開啟學生選單」。 | PASS |
| 播放器桌面 | 1440×1000 三欄實測 `64px 360px 1016px`；右欄實際捲動 1000px，outline scroll 仍 0、rail / course-head top 仍 0。 | PASS |
| 播放器中欄 | 1440×650 展開第二主題，實際捲動中欄到 267px；右欄仍 0、課名頂端與 rail 頂端仍 0。 | PASS |
| 播放器斷點 | 1024px 寬欄位為 `64px 316px 644px`；1920px 寬為 `64px 400px 1456px`。 | PASS |
| 播放器手機 | 390×844；影片、課名、四個活動、教材、資源與討論順序；章節抽屜 Escape 關閉並還原觸發按鈕焦點。 | PASS |
| Free 鎖定 | 在學生情境選 Free，原生導覽至 l3；三個 Plus 活動顯示鎖定。點練習一開說明，Escape 回同一按鈕，URL 維持 `activity=learn`。 | PASS |
| 續課及自報 | l3 點「下一課」至 l4，仍 2/6；再點自報完成，Today 與 map 同步 3/6。沒有老師驗證或證書。 | PASS |
| 私人課獨立 | s2 Free、未加入系統課程：我的課程顯示進行中 0 / 私人課 1，沒有系統課程進度，私人課可用。 | PASS |
| 學生預約 | s2 堂數對話框→9/10 20:00→影響預覽→確認：可預約 3→2、已預留 1→2、已上課保持 0。系統課程仍未加入。 | PASS |
| 明確加入 | 上述 s2 從「認識吉他學習地圖」確認加入後，才顯示進行中 1、Stage 1「尚未開始」，沒有沿用 s1 進度。 | PASS |
| 長中文作業 | 填入 1200 字中文、選示意影片及本機同意；桌面預覽 dialog client/scroll width=543/543，手機=339/339。內容可垂直捲動，確認按鈕可操作。 | PASS |
| 完整 Pro 回饋 | 同一 tab：學生建立 submission-101→管理員看到原題、填原因、預覽指派 t1→老師 reviews 同 id 填 observation / nextPractice、預覽確認→學生 guidance 顯示同題及兩段回覆、三步狀態皆亮。 | PASS |
| 私人備註 | 老師另存 `PRIVATE-QA-0911` 文字；学生 Today / guidance DOM 無該字串。學生進度仍 2/6，回覆不改學習進度。 | PASS |
| 外觀 / 時區 | 選白色主題；東京時區偏好放入共用 Provider 後跨頁保留；同一筆 9/9 預約由台北 20:00 正確顯示東京 21:00。 | PASS |
| 學生守則 | 原生點選「我已閱讀此版本」後，該版本按鈕顯示「目前版本已讀」且 disabled。 | PASS |
| 寬度測試 | 我的課程及播放器於 320 / 360 / 390 / 768 / 1024 / 1280 / 1920px 檢查，document 與主內容均無橫向溢出。原稿課節橫列與階段旅程仍保留各自水平捲動。 | PASS |
| 執行錯誤 | 瀏覽器 error logs 為空。開發中曾出現 Fast Refresh full reload 提示，依 Mock 設計會重設示意資料；不是流程資料持久化。 | PASS |

## 截圖清單

本資料夾中的以下檔案皆為實際本機頁面的原始瀏覽器截圖，未改圖掩蓋差異。

- `student-today-desktop.png`、`student-today-mobile.png`、`student-menu-mobile.png`
- `student-courses-desktop.png`、`student-courses-mobile.png`
- `student-map-desktop.png`、`student-map-mobile.png`
- `student-private-desktop.png`、`student-private-mobile.png`、`student-private-light-tokyo.png`
- `student-private-only-mobile.png`、`student-booking-dialog-mobile.png`、`student-joined-from-zero-mobile.png`
- `lesson-desktop.png`、`lesson-mobile.png`、`lesson-free-desktop.png`、`lesson-access-dialog-desktop.png`
- `lesson-outline-independent-scroll.png`、`lesson-1024.png`、`lesson-1920.png`
- `student-guidance-desktop.png`、`student-guidance-mobile.png`
- `student-guidance-long-dialog-desktop.png`、`student-guidance-long-dialog-mobile.png`、`student-guidance-record-mobile.png`
- `cross-role-pro-assignment-desktop.png`、`cross-role-teacher-reply-desktop.png`
- `cross-role-student-feedback-desktop.png`、`cross-role-student-feedback-mobile.png`

## 已修正的實測問題

- 手機章節抽屜關閉後在 inert 移除後還原焦點。
- 學生時區改為共用 Provider 偏好，避免換頁遺失。
- 多課包預約只取選中 package；私人課練習提示不混用 Pro 回饋。
- 預約制有剩餘堂數時，堂數對話框提供新增預約入口。
- 學生各情境的預約卡 / 上課資訊 / 已上課紀錄讀各自練習主題。
- 非當前 l3 不再錯標「目前這一課」；續課後首頁主題同步。
- 對話框內容切換時移動焦點；scenario select 提供短且明確的 aria-label。
- 對話框與回饋文字允許長文字折行，手機 Stage 標籤不分行。

## 技術檢查及限制

- `node node_modules/typescript/bin/tsc --noEmit --pretty false` PASS。
- `node node_modules/eslint/bin/eslint.js src/components/ux-prototype/student src/components/ux-prototype/lesson` PASS。
- JSX / CSS 原生頁面，沒有整頁 iframe、整張截图替代頁面或 HTML 注入。
- 本輪所有課程、媒體、預約、作業、回饋、身份、守則已讀都仍為 Mock。沒有實際影片播放 / 檔案上傳 / 通知 / DB / 金流 / 認證；刷新會重設業務資料。外觀偏好可以保留，時區為本機記憶體偏好。
- 學生取消及改期入口保留規則說明，由管理員原生流程操作同一筆示意預約；未捏造取消期限或扣堂規則。
- 桌面 / 手機視覺檢查已完成，但沒有宣稱所有內容與所有瀏覽器都逐像素一致。
