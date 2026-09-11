# 公開頁與管理員內容流程：本機實測記錄

測試日期：2026-09-11。執行於 `preview-test` 本機，入口 `http://127.0.0.1:3100/ux-prototype`。

## 原稿依據

已閱讀交接包的完整規範、最終公開首頁 p5/p6 HTML/CSS/互動、v1.4 工作台課程與文章編輯／審核程式，以及核准截圖。原稿 `file://` 瀏覽器載入曾被安全政策阻擋；本次採使用者已核准的「完整原始碼 + 原有截圖」替代核對方式。原始 HTML 與核准截圖未修改。

公開 v1.6 原生頁保留浮動白色導覽、主視覺手機、深色學習方式區、三項切換、路線方向、3:4 一對一老師圖卡、單張老師旁文、跨裝置示意、FAQ 與底部行動入口。老師圖卡是具有真實 href 的 Next Link。原教室及學生截圖只作為原稿指定的行銷預覽插圖，不能操作的產品頁沒有以整張圖或 iframe 代替。

1440 桌面原生首頁導覽寬 1180、高 74；主視覺手機寬 284；390 手機主視覺寬 225。原稿指定比例與垂直位置相符。Windows 的傳統捲軸占用 15px，公開頁有效寬分別為 1425／375；原截圖未占此寬度，因此水平中心約差 7.5px。字型沿用原 font stack，作業系統備援中文字型會造成字形筆畫差異；沒有下載新字型或修改核准截圖。

管理員課程列表依最新 v1.4 原生表格，編輯器保留內容與存取設定雙欄。手機改為原稿響應式單欄。交接包 `admin-course-editor-dark.png` 本身是「尚未選擇課程」狀態，不能當作已選取表單的完整黃金圖；實際表單另外依原始 HTML/CSS 逐項核對。

## 已完成的實際瀏覽器測試

- 公開首頁：桌面 1440×1000、手機 390×844 看圖，沒有整頁水平溢位；iframe 數量 0。
- 首頁教師卡：桌面 356×474.656、手機 335×446.656，保持 3:4；實際點擊導向 `/teachers/t1?tab=private`，一對一頁籤正確預選。
- 老師介紹頁：桌面、手機公開 4／12／24／48 堂卡片；實際打開課程包對話框，關閉與 Escape 後焦點回到「了解課程包」。
- 公開手機選單開啟、導覽與關閉；功能頁籤切到「把方法練起來」後內容更新。
- 五題診斷：未答時下一題 disabled；回答後可前進；返回上一題仍保留已選答案；完成五題 `new,song,10,direction,self` 得到「從穩定的第一個和弦開始」、10 分鐘的 2／5／3 分鐘建議。沒有自動購買、升級或老師驗證。網址保留答案是本機示意行為。
- 新課程：新增 `course-103` → 填名稱／課綱／原因 → 儲存後顯示「公開尚無、工作草稿 2」→ 預覽 → 二次確認 → 列表顯示新課公開 v1。
- 既有課程：c1 先儲存再預覽，確認發布後公開版本 v1→v2。
- 課程編輯器及發布對話框：桌面／手機實際看圖；1440 文件寬 1440，主區域 scrollWidth 等於 clientWidth；390 文件寬 390、主區域 380，沒有整頁水平溢位。手機確認對話框包含返回與確認按鈕。
- 文章：新增 → 標題／slug／內文／SEO 草稿 → 預覽 → Escape 焦點回「預覽文章」→ 送審 → 管理員讀快照、填原因 → 二次確認發布 → 公開列表只有已發布文章 → 正確 `/articles/qa-native-article` 內容。
- 文章貼入 `<script>這段只會顯示成文字</script>`，預覽與公開頁都顯示純文字；對應內容容器沒有 script 元素。
- 手機文章長預覽：對話框自身捲動，能操作底部二次確認按鈕；文章頁整頁 scrollWidth 375 = clientWidth 375。
- 老師提案跨角色：三份老師守則已讀 → 新提案填成果／對象／課綱／素材權利 → 明確送審確認 → 管理員看見同一快照 → 接受只匯入平台草稿（公開尚無，草稿 1）→ 平台修改標題 → 預覽與確認發布 v1。老師頁沒有正式發布按鈕。
- 老師展示：修改並保存名稱後，公開老師頁仍顯示舊名稱，草稿未流出；送審後管理員看到獨立展示快照。
- 課程包：老師將四堂單價提為 1100，管理員看到正確四堂總額 4400 的送審快照；完成核准後待審項目移除。手機審核對話框實際看圖。
- 展示／課程包核准後的最終公開更新已在穩定時段重新通過：首頁老師卡顯示「QA 已核准老師介紹」、連結仍是 `/teachers/t1?tab=private`；實際點入同一位 t1，公開四堂價格 4400、每堂 1100，其餘 12／24／48 堂價格不變。證據 `public-published-linkage-desktop.png`。
- 0 位老師：圖卡數 0，有明確師資更新空狀態；沒有公開課程包情境也不列出老師，圖卡數 0。
- 3 位老師：桌面三張卡各自具有 t1、qa-teacher-2、qa-teacher-3 的 href；實際點入後，第二、第三位分別呈現自己的介紹與專屬課程包。手機沿用原稿的橫向可捲動卡片清單，文件本身 scrollWidth 375 = clientWidth 375。
- 長中文名稱／介紹：手機卡片維持 3:4，文字依核准 CSS 截行，沒有整頁水平溢位；缺圖情境切換到概念吉他影像及「教學影像示意」標記，沒有破圖。
- 第二組診斷完整點答 `express,freedom,30,understand,private`，結果改為「把和弦與音樂理解接起來」、30 分鐘的 6／15／9 分鐘安排，另提供一對一老師入口。與第一組基礎、10 分鐘、自主練習結果不同。
- 手機 FAQ「完全沒學過吉他，也適合嗎？」實際展開；功能頁籤先點「把方法練起來」後按 ArrowRight，選取與內容同步切到「需要時，有人陪」。
- 課程列表、文章列表、平台財務、預約管理共 4 頁 × 8 寬：320／360／390／768／1024／1280／1440／1920。每次等核准側欄動畫 350ms 後再量測，32 組的 `document.scrollWidth` 都等於對應視窗寬，`main.scrollWidth` 都等於 `main.clientWidth`。窄版表格 wrapper 的 `overflow-x: auto`，內容寬 620px（768 視窗時 680px）在容器內捲動，不撑寬整頁。完整數值位於 `admin-table-eight-widths.json`。

- 預約管理：桌面／手機表格及「代學生預約」對話框實際開啟看圖。初次桌面截圖發現 560px 對話框容納雙欄，左欄與時段卡過窄、日期變成單字直排；保留 `admin-booking-dialog-before-fix-desktop.png`，將該原生對話框套用既有寬版樣式後重新驗證。修正版桌面對話框寬 780px、表單欄 371px、時段卡 181px；手機對話框 366.594px、單欄與卡寬 305.594px，日期正常換行且對話框自身垂直捲動。按 Escape 關閉後焦點回「＋ 代學生預約」，既有預約仍 2 筆，這次視覺檢查沒有提交新增。數值見 `admin-booking-dialog-geometry.json`。

## 原生實作與共用資料

公開與管理員直接使用 `usePrototype`。正式課程、提案、展示、課程包、文章沒有另建 UI 商業陣列。`src/modules/ux-prototype/model.ts` 集中角色 guard、有效性、草稿／公開分離、提案匯入、快照審核與版本衝突檢查。管理員預覽提供 `expectedRevision` 或 `expectedSnapshot`；錯誤不會關掉確認對話框冒稱成功。

新建頁面首次在開發環境曾發生新增成功但 imperative 導向未完成；課程及文章改為在新增 state commit 後以 effect 導向。修改後實際新增與導航通過。HMR 全頁重載會清除示意資料，應在穩定的同一分頁操作完整情境。

CUA 在個別首次跨路徑點擊後曾停留原頁，`waitForURL` 超時；對已穩定顯示的同一連結再操作才完成。多老師第二／第三卡已以實際目的 URL 與內容確認，沒有把未完成的點擊算通過。開發期間瀏覽器有 Fast Refresh full reload 警告，後續須區分 HMR 重載與尚未完成的 UI 導航，不能只憑一次 snapshot 推論成功。

## 證據與限制

圖片位於同目錄，主要檔案：

- `public-home-desktop.png`、`public-home-mobile.png`
- `public-teachers-desktop.png`、`public-teachers-mobile.png`
- `public-teacher-profile-desktop.png`、`public-teacher-profile-mobile.png`
- `public-package-dialog-desktop.png`、`public-package-dialog-mobile.png`
- `public-diagnosis-result-mobile.png`、`public-article-mobile.png`
- `admin-courses-desktop.png`
- `admin-course-editor-desktop.png`、`admin-course-editor-mobile.png`
- `admin-course-publish-dialog-desktop.png`、`admin-course-publish-dialog-mobile.png`
- `admin-articles-desktop.png`、`admin-article-editor-desktop.png`、`admin-article-editor-mobile.png`
- `admin-article-preview-mobile.png`、`admin-article-publish-dialog-mobile.png`、`admin-article-publish-dialog-mobile-actions.png`
- `admin-review-desktop.png`、`admin-proposal-review-dialog-desktop.png`、`admin-offer-review-dialog-mobile.png`
- `public-published-linkage-desktop.png`
- `public-teachers-many-desktop.png`、`public-teachers-many-mobile.png`、`public-teachers-empty-desktop.png`
- `public-teachers-long-mobile.png`、`public-teachers-fallback-mobile.png`
- `public-diagnosis-result-alternative-mobile.png`
- `admin-courses-final-desktop.png`、`admin-courses-final-mobile.png`
- `admin-articles-final-desktop.png`、`admin-articles-final-mobile.png`
- `admin-bookings-final-desktop.png`、`admin-bookings-final-mobile.png`
- `admin-booking-dialog-final-desktop.png`、`admin-booking-dialog-final-mobile.png`
- `admin-booking-dialog-before-fix-desktop.png`（保留修正前錯誤證據）

`public-final-geometry.json` 記錄部分最後證據的 DOM 量測與原始影像尺寸。此子工作 CUA 的 screenshot bytes 實際是 JPEG，沿用 `.png` 檔名的檔案仍可由 MIME／檔頭辨識，沒有重新編碼或縮放。桌面發布連動原始圖片實際 1440×1000；子工作手機截圖可能實際 375×812，即使 DOM innerWidth／innerHeight 是 390×844。量測 devicePixelRatio = 1、visualViewport.scale = 1、visualViewport.width = 375、height = 844、outerWidth = 1280、outerHeight = 820。`getScreenshot` 結果相同，完整 390×844／1440×1000 的 explicit clip 在此子工作曾被工具拒絕。根工作另以自己的瀏覽器重拍首頁與教師卡四張完整視窗圖；比較時不應把子工作的 raw 圖默認成指定 viewport 尺寸。

最後補拍的管理員課程／文章／預約列表及代約對話框共 8 張沒有上述尺寸限制：以 JPEG SOF 檔頭逐張確認，`*-final-desktop.png` 均為 1440×1000，`*-final-mobile.png` 均為 390×844，維持未縮放的工具原始 bytes。

自己的 public 與 admin-content ESLint 通過；TypeScript 檢查未回報這些檔案的錯誤。這些結果不替代全專案驗證。公開首頁最後一次重新載入後沒有新的 hydration／console error，瀏覽器 log 中保留的是修復前 09:31:34 的舊紀錄。

所有資料與發布都是記憶體 Mock，重新整理重設。教材與文章封面只記檔名，不上傳；SEO 欄位只保存示意內容。未接正式身份、金流、通知、影片、Supabase、SQL、備份或還原。

