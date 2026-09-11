# 財務／守則原生雛形驗證

2026-09-11，preview-test 本機，CUA in-app browser；1440×1000 與 390×844。所有資料與操作均為虛構 Mock，未連接銀行、正式契約或後端。

## 原稿對照與版面

- 已讀 handoff 最新 `demo.html` 財務／守則覆寫函式與三段 workspace CSS，並目視提供的桌面、手機財務及老師收入截圖。
- 桌面原生財務三個統計欄 x=258/636/1014，y=301，各寬 378；原稿統計列約 y=338，差異主要是原稿 38px 展示 reviewbar 不屬產品 UI。
- 手機390px頁寬等於viewport。財務表格容器342px、內容620px、overflow-x:auto，只有表格容器橫向捲動；沒有整頁橫向溢出。
- 手機規章編輯dialog x=14、width=362、height≈743；內容可獨立捲動。Escape關閉並恢復原「編輯規章草稿」按鈕焦點。
- 財務與守則維持原稿深色原生HTML/CSS；未嵌入整頁iframe或截图。

## 實際操作結果

1. 營運管理員進財務頁：顯示受限畫面，main沒有NT$、table數量0。
2. 財務人員準備t1結算：E-901/E-903/E-904合計3150，狀態變「待負責人覆核」，未撥款。
3. 切平台負責人，填原因、確認合約紀錄、二次確認：狀態「已覆核，尚未撥款」，待撥款仍3150。
4. 再開獨立撥款dialog，填虛構憑證DEMO-QA-SEP-001與原因、checkbox及二次確認：t1待撥款0；t2仍2400。頁面明確說明沒有真正轉帳。
5. 跨角色回老師收入：已確認4650、待撥0、已撥4650；不含合作老師B收入。
6. 分潤草稿初始金額均空白；1000基礎分配900+200顯示超額並拒絕保存。改700+200後成功保存為未核准草稿；已收27000、扣退款26000、已確認待撥2400均未被草稿重算。
7. 老師先已讀「課程提案與平台審核」v0.1。管理員保存v0.2草稿時，公開仍v0.1並提示另有草稿。預覽、理由、二次確認發布後，老師改見v0.2與未讀按鈕；再次點擊後才顯示已讀v0.2。
8. 明細、結算、規章對話框在桌面及手機實際開啟，按鈕可操作且長內容可捲動。

## 測試與瀏覽器紀錄

- model Vitest：31 tests PASS（18:03，含教學草稿保存、權限及送出清除）。
- owned module與Finance/Policies TSX ESLint PASS。
- 全專案TypeScript `--noEmit` PASS。
- 此瀏覽器session沒有console error；有一次開發期間09:54UTC Fast Refresh full reload警告，當時修改model字串，正式流程測試在root宣告stable後才開始。
- 切換管理員能力會重建本頁暫存頁籤，因此需重新點老師結算；共用結算資料仍保留，已驗證。

## 截圖

- `admin-finance-desktop-native.png`、`admin-finance-mobile-native.png`
- `admin-policies-desktop-native.png`、`admin-policies-mobile-native.png`
- `admin-policy-dialog-mobile-native.png`
- `teacher-earnings-desktop-native.png`、`teacher-earnings-mobile-native.png`
- `teacher-earning-dialog-desktop-native.png`、`teacher-earning-dialog-mobile-native.png`
- `finance-ops-masked.png`、`finance-prepare-dialog-desktop.png`
- `finance-payout-dialog-mobile.png`、`finance-invalid-allocation-mobile.png`
- `policy-publish-confirm-desktop.png`、`teacher-policy-v02-unread-mobile.png`
- `teacher-policies-light-mobile.png`（另實際切換淺色，文字與版本徽章可讀，頁寬390無溢出）

## 仍為 Mock

財務數字來自來源fixture，沒有正式分潤公式、會計認列、付款串接；規章是示意版本及已讀流程，非正式法律條款。資料只存在共用provider記憶體，重整可清除，只有外觀偏好保存本機。
