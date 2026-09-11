# The One 2.0 已核准 UX 原生前端雛形驗收

日期：2026-09-11。範圍僅限 `preview-test` 本機原生 Mock 前端。本文件是本輪交付證據，不是 Canonical，也不宣告任何新 Epic、正式後端或 Finance 域完成。

**本輪原生 Mock 整合已完成，主要頁面與跨角色流程已實際操作並留桌面／手機證據。Build、TypeScript、source ESLint、696 項 Vitest 通過；歷史位元組封存 guard 仍有1項失敗。OS主題即時切換、瀏覽器縮放及完整Network trace受工具限制，未宣稱通過。**

## 1. 可開啟的入口與最少操作

- 公開首頁：<http://127.0.0.1:3100/ux-prototype>
- 學生：<http://127.0.0.1:3100/ux-prototype/student>
- 已核准錄播教室：<http://127.0.0.1:3100/ux-prototype/student/courses/c1/lessons/l3>
- 老師：<http://127.0.0.1:3100/ux-prototype/teacher>
- 管理員：<http://127.0.0.1:3100/ux-prototype/admin>

左下「Mock 預覽」可切換視角與重設示意資料。直接開啟另一個角色網址時，需按頁面上的明確 Mock 切換按鈕；網址本身不自動取得另一角色能力。管理員另有營運／財務／負責人情境。請在同一分頁走跨角色流程，重新整理會重設業務資料；外觀偏好保留本機，時區只保留在共用 Provider 記憶體。

啟動腳本為 [ux-prototype-dev.mjs](../scripts/ux-prototype-dev.mjs)。它檢查 `preview-test`、綁定 `127.0.0.1:3100`，使用本機佔位環境設定並關閉 Next 遙測，不安裝套件或部署。這些網址已由原生瀏覽器實際開啟，不是推測的 port。

2026-09-11 18:40（台北）最後確認：開發服務持續運作，原生瀏覽器可開啟首頁、HTTP回200。重新啟動命令：`node scripts/ux-prototype-dev.mjs`。另以本輪正式建置暫時啟動127.0.0.1:3101，實際請求首頁／學生／老師／管理員雛形入口均回404；測完已停止該檢查程序，沒有部署。見[production-isolation.json](../artifacts/ux-prototype/production-isolation.json)。

## 2. 工作區、來源與授權邊界

- 起點是乾淨的 `main`，HEAD `0af06802dbeb2fcd614d33db3e64c441fe711be4`；安全建立 `preview-test`，沒有 reset／stash／clean 清除既有工作。`main` 指標不變，未 fetch。基線見 [baseline.json](../artifacts/ux-prototype/baseline.json)。
- 已讀 repository 最新 [CURRENT_WORK.md](CURRENT_WORK.md)、[PROJECT_STATUS.md](PROJECT_STATUS.md)、[CANONICAL_ROADMAP.md](CANONICAL_ROADMAP.md)、[PRODUCT_DECISIONS.md](PRODUCT_DECISIONS.md)，以及 Guitar Roadmap 前置產品文件。實際狀態是 Epic7 A–E LOCAL CLOSED、F LOCAL READINESS TOOLING COMPLETE；交接 context 的 P2 文件只作歷史參考，不覆蓋當前 Canonical。
- 實際交接包在 `C:/Users/win/Downloads/the-one-complete-frontend-v1-6/the-one-codex-handoff-v1-6/`。已讀 CODEX_PROMPT、README、SOURCE_OF_TRUTH、VISUAL_CONTRACT、INTEGRATION_CONTRACT、ACCEPTANCE、OPEN_DECISIONS、PAGE_MAP、BASELINE_MANIFEST，以及 REFERENCE_STATE 與資產清單。
- 原稿 `file://` 載入被瀏覽器安全政策拒絕；使用者已明確授權以完整 HTML/CSS/JS 閱讀及原有核准截圖替代原稿瀏覽。沒有改以 localhost 或另一瀏覽器繞過原稿限制。原生 app 的實際桌面／手機操作仍正常執行並留下截圖。
- 五份原稿 HTML 的 SHA-256／位元組數吻合基線；對照腳本逐張核對 golden PNG 與 SCENE_MANIFEST 的 hash，輸入前後再校驗，不修改原稿或 golden。四份 Canonical hash 記於 baseline。
- 本輪沒有 commit、push、PR、部署、Supabase 連線、SQL／migration、正式 Auth／付款／通知／影片上傳、備份或還原；不改商業分潤公式、正式 quota 或取消扣堂規則。

最終仍在`preview-test`，HEAD及main均為`0af06802dbeb2fcd614d33db3e64c441fe711be4`，沒有新增提交。五份HTML、四份Canonical與起始雜湊一致，见[baseline-verification.json](../artifacts/ux-prototype/baseline-verification.json)。既有受追蹤檔僅三份有差異：`src/proxy.ts`增加雛形隔離、`next.config.ts`關閉開發指示器及獨立建置目錄、Next自動更新`next-env.d.ts`的dev type路徑；共16行新增、4行移除。新增檔為原生頁面／元件、Mock module、局部資產、隔離測試、本機工具與本輪文件／QA證據。`git diff --check`通過；未動四份Canonical、既有業務頁面、資料庫或migration。

## 3. 原生架構及共用資料

`/ux-prototype/[[...segments]]` 使用現有 Next.js App Router，Public、Student、Lesson、Teacher、Admin 皆為 React 原生元件；各自 CSS namespace 隔離。沒有整頁 iframe／srcdoc／object、PNG 代替可操作頁面、eval 原稿函式或整包 HTML 注入。行銷頁原稿指定的教室插圖仍是插圖，實際教室有自己的原生路由。

共用 [model.ts](../src/modules/ux-prototype/model.ts)、[fixtures.ts](../src/modules/ux-prototype/fixtures.ts)、[store.tsx](../src/modules/ux-prototype/store.tsx) 放在 `src/modules`：

- 穩定 ID 包括老師 t1/t2、學生 s1/s2/s3、課程 c1/c2、p4/p12/p24/p48、已購包 e-yu/e-an、課次 ab1/ab2、作業 r1/r2。
- s1 是固定制私人課學生、s2 是預約制且未加入系統課、s3 是平台指派學生；多視角讀同一份記憶體資料。
- 草稿、送審快照、公開版本、已購快照獨立；變更新版價格不覆寫舊購買資料。老師只提案，管理員才編輯／發布正式課程。
- 預約 reserve 與 consume 分離；老師／學生／管理員同一筆預約共用。角色、關係、效期、時段衝突、服務資格、版本與重複請求守衛由純 command layer 處理。
- 私密備註不出現在學生回饋；財務依 ops/finance/owner 分視角；受控查看需對象與理由，角色或對象改變會重新遮蔽。
- 教學草稿可跨頁返回，正式送出回饋／教學紀錄才清除對應草稿。自報完成與練習勾選不改老師驗證或發證。
- 共用 Mock 時鐘 `2026-09-08T00:00:00Z`，使整合 Demo 的 9/9 課次保持未來。台北20:00／東京21:00由同一筆時間換算。

隔離採雙層：layout 與 proxy 在非 development 回 404；proxy 在此子樹不呼叫 Supabase session 更新，提供同來源 CSP，禁止 frame/object、外部連線與 form action。8 個 isolation 測試包括 production 拒絕及既有正式路由仍走原授權流程。這是本機 Mock 隔離證據，不能稱為正式身份或財務安全驗證。

## 4. 路由與原稿對照

下表路徑均在 `/ux-prototype` 下；動態 ID 為同一 store 的 fixture 或使用者當頁建立的 ID。PAGE_MAP 的原生路徑是建議，列表、詳情及編輯可整合在同一原生路由／對話框，不增加第二套 app。

| 本機路徑 | 已實作頁面／流程 | 原稿依據與限制 |
|---|---|---|
| `/`、`/#p5-teacher` | 置中首頁、feature 切換、FAQ、3:4 老師卡、0/1/多師資情境 | demo.html public-home v1.6；公開維持 light |
| `/teachers/t1?tab=private` | 老師介紹、system／standalone／private、公開課程包及說明框 | demo.html public-teacher；依 teacherId 與已發布資料 |
| `/courses/guitar-roadmap`、`/courses/[id]` | 課程介紹、明確加入入口 | demo.html public-roadmap；推薦不等於加入／購買 |
| `/diagnosis`、`/diagnosis/result` | 五題前後切換、必答檢查、不同答案建議 | demo.html public-diagnosis/public-result；不是評級 |
| `/articles`、`/articles/[slug]` | 已發布文章列表與正文 | demo.html public-articles/public-article |
| `/policies/students`、`/policies/privacy` | 公開守則／隱私草案說明 | demo.html 規章流程；未宣稱法律條款生效 |
| `/student`、`/student/courses` | Today、我的課程、未加入／私人課獨立情境 | student-approved-v1.2.html |
| `/student/map?stage=2` | Stage／Module／Lesson 定位與自報狀態 | student v1.2；只提供核准代表性課節，非捏造完整課綱 |
| `/student/private?package=[id]` | 下一堂、課前練習、紀錄／回饋、課包選擇、預約 | student v1.2＋整合 Demo；學生改期／取消入口為規則說明，由管理員操作 |
| `/student/practice`、`/student/feedback` | 練習、自報、私人課回饋與平台協助訊息 | student v1.2；非驗證／證書 |
| `/student/guidance`、`/student/courses/c1/units/u1/guidance` | Pro 提交、資格提示、被指派老師回覆 | demo.html unit-guidance/guidance-inbox；額度資格是 Mock，不扣正式 quota |
| `/student/settings`、`/student/policies` | 黑／白／系統、時區、版本已讀 | student v1.2＋整合守則 |
| `/student/courses/c1/lessons/l1` 至 `l6` | 三欄教室、四活動、教材、討論、下一課／回地圖、手機抽屜 | lesson-locked-v1.1.html；保持 dark與獨立捲動 |
| `/teacher`、`/teacher/schedule` | 今日教學、課表、公開可用時段 | demo.html 最新 teacher today/schedule；僅線上 |
| `/teacher/students`、`/teacher/students/[id]` | 私人學生及平台指派分流、私人備註 | demo.html students/student；不把平台指派當永久師生關係 |
| `/teacher/reviews`、`/teacher/reviews/[id]` | 分類 tabs、兩欄／手機單欄作業卡、回饋草稿／預覽送出 | demo.html reviews/review；只回覆自己關係或指派 |
| `/teacher/lessons/[bookingId]`、`/teacher/records` | 本堂記錄、草稿與教學紀錄 | demo.html lesson/records；保存筆記不完成課次或扣堂 |
| `/teacher/courses`、`/teacher/proposals/[id]` | 正式課程唯讀、提案／改版、素材聲明、4/12/24/48／自訂與指定報價 | demo.html latest teacherCoursesV14/proposalEditor；舊正式編輯入口不提供編輯權 |
| `/teacher/profile`、`/teacher/policies`、`/teacher/earnings`、`/teacher/settings` | 展示草稿、合作守則、自己報酬、偏好 | demo.html 最新展示／規章／收入；不露其他老師收入 |
| `/teacher/book-for-student` | 自己有效預約制學生的代約、同意、原因、確認 | demo.html teacher-booking；只 reserve |
| `/admin`、`/admin/students` | 營運總覽、學生／權益、詳情及人工授包對話框 | demo.html admin-home/admin-students/admin-student |
| `/admin/bookings` | 代約、改期、取消與影響確認 | demo.html admin-bookings；同一筆課次與 reserve ledger |
| `/admin/courses`、`/admin/courses/[id]/edit`、`/admin/review` | 新增／編輯、提案匯入草稿、快照審核、預覽／本地發布 | demo.html adminCourses/editor/catalogV14；editor golden是未選課空態，真表單依CSS／函式另驗 |
| `/admin/articles`、`/admin/articles/[id]/edit` | 文章編輯／SEO、預覽、送審、發布 | demo.html articleEditor；只記檔名、不上傳 |
| `/admin/guidance`、`/admin/oversight`、`/admin/audit` | Pro 指派、指定對象受控查看、平台身分回覆、操作紀錄 | demo.html admin-guidance/conversations/audit |
| `/admin/finance`、`/admin/policies`、`/admin/settings` | ops遮罩、收支／結算／分潤草稿、守則版本、偏好 | demo.html latest finance/rules；正式財務與契約仍未接 |

## 5. 實際操作與守衛證據

詳細原始結果以各工作區 QA 記錄為準，不能把 source HTML 的 QA 當成原生 app 通過：

- [公開與管理員內容 QA](../artifacts/ux-prototype/public-admin-qa.md)：真 Link 的 teacherId 與 private tab、五題診斷、管理員新課／既有課程草稿→預覽→發布、老師提案→匯入草稿→管理員發布、文章草稿→送審→公開，長內容及 `<script>` 純文字處理。
- [學生／播放器 QA](../artifacts/ux-prototype/student-player-qa.md)：1440三欄64/360/1016，1024為64/316/644，1920為64/400/1456；右欄與中欄分別實際捲動而不推動其他欄；手機抽屜 Escape 焦點恢復；Free鎖定、續課、自報跨頁、私人課獨立、時區、長中文作業、完整Pro跨角色回覆與私密備註遮蔽。
- [財務／守則 QA](../artifacts/ux-prototype/finance-policy-qa.md)：ops沒有財務數字或表格；finance準備3150→owner覆核仍未撥→獨立DEMO憑證與二次確認才記已撥；老師收入同步4650/0/4650且無t2；超額分配1000<900+200拒絕、改700+200後只存草稿；守則v0.1已讀→v0.2草稿不公開→確認發布→舊ack失效→重讀新版。
- [營運追加 QA](../artifacts/ux-prototype/operations-qa.md)：以檔案最前面的「最終實測更新」為準。人工授包、改期、取消、受控查看與重新遮蔽、平台回覆、兩種教學草稿、共用時區皆已由整合者實際補測；下方仍保留子代理瀏覽器回收時的歷史待補紀錄。
- 31個純 model 測試涵蓋快照／版本競爭、角色與受益人、不同老師、重複預約、過期／衝突、僅reserve不consume、私密資料、Pro多門檻、unknown金額、獨立結算、政策版本、教學草稿保存及精準清除。完整命令結果另列第8節。

### 整合者營運補測

人工贈課空原因被拒；具體原因、版本及二次確認後，雙擊只新增一份4堂包。學生課包 selector 可選同一新包，顯示4可用／0預留／0消耗。ab2改期維持同一id與預留數；取消空原因被拒，確認後雙擊只取消一次，舊包回到4可用／0預留／0消耗，新gift包不受影響。平台回覆以「平台協助」呈現在正確學生端；換受控對象或切finance再切ops均重新遮蔽。作業與本堂記錄草稿離頁重進仍保留，正式送出只產生一份回饋且不自動扣堂或增加完成進度。

老師代約另實際建立booking-101，管理員看到同一時段，學生小安原包可用3→2、預留1→2、消耗0不變。新建預約、人工授包、作業回饋及取消均有重複操作守衛；實際雙擊授包／回饋／取消各只形成一次影響，預約重複請求另有model測試。

目前可引用的補測圖包括 [三端預約學生](../artifacts/ux-prototype/booking-crossrole-student-mobile.png)、[三端預約管理員](../artifacts/ux-prototype/booking-crossrole-admin-mobile.png)、[授包確認](../artifacts/ux-prototype/admin-grant-confirm-mobile.png)、[改期確認](../artifacts/ux-prototype/admin-reschedule-confirm-mobile.png)、[取消確認](../artifacts/ux-prototype/admin-cancel-confirm-mobile.png)、[受控查看](../artifacts/ux-prototype/admin-oversight-mobile.png)、[平台回覆學生](../artifacts/ux-prototype/platform-feedback-student-mobile.png)、[私人回饋學生](../artifacts/ux-prototype/feedback-private-crossrole-mobile.png)。

## 6. 原稿／原生視覺證據

完整場景、原尺寸、SHA-256、裁切矩形、未遮罩RGB差值見 [comparison.md](../artifacts/ux-prototype/comparisons/comparison.md) 與 [comparison.json](../artifacts/ux-prototype/comparisons/comparison.json)。生成腳本 [ux-prototype-compare.mjs](../scripts/ux-prototype-compare.mjs) 只讀原稿與原生PNG，另寫派生圖，不會替換任何輸入。

| 重點 | 原生桌面／手機 | 與原稿並排／像素差異 |
|---|---|---|
| 公開首頁 | [桌面](../artifacts/ux-prototype/public-home-desktop.png)／[手機](../artifacts/ux-prototype/public-home-mobile.png) | [並排](../artifacts/ux-prototype/comparisons/home-desktop-side-by-side.png)／[手機差異](../artifacts/ux-prototype/comparisons/home-mobile-diff.png) |
| 長方形老師卡 | [桌面](../artifacts/ux-prototype/public-teachers-desktop.png)／[手機](../artifacts/ux-prototype/public-teachers-mobile.png) | [並排](../artifacts/ux-prototype/comparisons/teacher-cards-mobile-side-by-side.png)／[差異](../artifacts/ux-prototype/comparisons/teacher-cards-mobile-diff.png) |
| 學生Today | [桌面](../artifacts/ux-prototype/student-today-desktop.png)／[手機](../artifacts/ux-prototype/student-today-mobile.png) | [去展示列並排](../artifacts/ux-prototype/comparisons/student-today-desktop-aligned.png)／[差異](../artifacts/ux-prototype/comparisons/student-today-desktop-diff.png) |
| 三欄播放器 | [桌面](../artifacts/ux-prototype/lesson-desktop.png)／[手機](../artifacts/ux-prototype/lesson-mobile.png) | [去展示列並排](../artifacts/ux-prototype/comparisons/player-desktop-aligned.png)／[Free鎖定情境](../artifacts/ux-prototype/comparisons/player-desktop-free-aligned.png)／[差異](../artifacts/ux-prototype/comparisons/player-desktop-diff.png) |
| 老師作業列表 | [桌面](../artifacts/ux-prototype/teacher-reviews-desktop.png)／[手機](../artifacts/ux-prototype/teacher-reviews-mobile.png) | [去展示列並排](../artifacts/ux-prototype/comparisons/teacher-reviews-mobile-aligned.png)／[差異](../artifacts/ux-prototype/comparisons/teacher-reviews-mobile-diff.png) |
| 課程編輯器 | [桌面](../artifacts/ux-prototype/admin-course-editor-desktop.png)／[手機](../artifacts/ux-prototype/admin-course-editor-mobile.png) | source editor golden是未選課情境，沒有假稱表單逐像素一致 |
| 財務與對話框 | [財務桌面](../artifacts/ux-prototype/admin-finance-desktop-native.png)／[財務手機](../artifacts/ux-prototype/admin-finance-mobile-native.png)／[手機撥款框](../artifacts/ux-prototype/finance-payout-dialog-mobile.png) | [去展示列並排](../artifacts/ux-prototype/comparisons/finance-desktop-aligned.png)／[差異](../artifacts/ux-prototype/comparisons/finance-mobile-diff.png) |

灰色評圖列不是產品：依 SCENE_MANIFEST 的 `#app.y`，來源public無評圖列，student桌面36px／手機34px，player／teacher／admin38px。比較時只移除該來源列、取共同可見區，不微調位置、不縮放、不遮字／捲軸、不設定容差或以差異比例判PASS。完整原尺寸並排仍保留兩邊全部畫面。

可見的環境／內容差異包含 Windows 字型 fallback 與反鋸齒、10–15px傳統捲軸溝槽、固定在左下的Mock工具、共用9/9課次取代學生原稿9/12、Pro／Free權益標籤不同。老師圖卡的捲動位置必須對照最後DOM測量；比例保持3:4，但手機可用寬度可能因捲軸不同而有實際像素差。這些均未被抹掉。

公開展示及四堂課包在核准後已實測同步：首頁與t1介紹顯示核准名稱，四堂總額4400／每堂1100，其餘12／24／48堂不變。0老師、無公開包、3老師各自連結／課包、長名稱與缺圖fallback也已操作；見公開QA最終紀錄及[DOM量測](../artifacts/ux-prototype/public-final-geometry.json)。部分子代理截圖位元組為JPEG、實際尺寸小於所要求viewport；比較腳本讀檔頭而非副檔名，不縮放偽裝一致。

根工作已重拍首頁／師資區四張並完成13組比較。要求viewport為1440×1000／390×844，公開頁因Windows傳統捲軸，可視內容截圖是1425×1000／375×844；使用原始document座標截取，未縮放補邊。工作台與播放器截圖則保留完整要求尺寸。手機師資圖與golden仍有約15–30px取景差，不能宣稱逐像素一致。[最終取景紀錄](../artifacts/ux-prototype/root-public-geometry.json)與[逐圖人工判讀](../artifacts/ux-prototype/comparisons/visual-review.md)保留差異。曾誤用clip座標截到頁頂的老師卡圖已重拍，最終實際檔案亦以圖片工具重新檢視。

## 7. 響應式、主題與無障礙實測範圍

- 已有主要Public、Student、Player、Teacher Reviews/Income、Admin Editor/Finance/Policies的1440×1000與390×844實際看圖／操作。頁面沒有以截圖壓縮成手機介面；實際影像位元組尺寸另依第6節揭露。
- Student Courses與Player已查320/360/390/768/1024/1280/1920，document／主區沒有橫向溢出，必要橫列仍局部捲動；finance390px的表格容器342px／內容620px、overflow-x:auto，整頁寬390px。
- 對話框有高度上限和獨立捲動；規章手機框x14／width362、height約743，scroll內容約806；Escape關閉回原觸發按鈕。學生／播放器抽屜、公開課包、文章預覽也有實測焦點恢復。
- 黑／白切換與跨頁偏好、東京時區已操作；public固定light，player固定dark。跟隨系統時實測matchMedia dark=false，workspace data-theme=light。**環境沒有操作OS偏好的介面，因此未驗證作業系統即時切換；Control++未改變viewport／DPR／visualViewport，因此未驗證瀏覽器縮放。**不以監聽程式碼或viewport大小替代這兩項。

追加穩定斷點量測：Public首頁及9個Teacher頁面共80組（每頁320/360/390/768/1024/1280/1440/1920），見[root-responsive-final.json](../artifacts/ux-prototype/root-responsive-final.json)；Admin課程／文章／財務／預約四頁共32組，見[admin-table-eight-widths.json](../artifacts/ux-prototype/admin-table-eight-widths.json)。均未出現document或主內容水平溢位，表格保留容器內捲動。老師提案、課程包、學生詳情及教學紀錄另有實際桌面／手機截圖和表單操作；提案及課前準備額外即時斷點紀錄見[root-workspace-responsive.json](../artifacts/ux-prototype/root-workspace-responsive.json)。

最後視覺檢查確實抓到並修正一個缺陷：admin代約對話框原寬560px，兩欄使時段日期擠成直排；改採原稿已有`x-wide-dialog`後桌面dialog780px、左欄371px、時段卡181px，手機dialog366.594px／內容305.594px單欄，日期正常。修正前圖仍保留，修正後[桌面](../artifacts/ux-prototype/admin-booking-dialog-final-desktop.png)／[手機](../artifacts/ux-prototype/admin-booking-dialog-final-mobile.png)與[量測證據](../artifacts/ux-prototype/admin-booking-dialog-geometry.json)已實際重驗，Escape回到原按鈕。沒有改原稿掩蓋差異。

## 8. 命令與真實結果

本機腳本 [ux-prototype-check.mjs](../scripts/ux-prototype-check.mjs) 使用現有已安裝工具，沒有升級框架或下載新套件。命令中的 `node` 由Codex bundled Node執行，Git亦使用已存在runtime。

| 檢查 | 已取得的原始結果 | 證據 |
|---|---|---|
| `node scripts/ux-prototype-check.mjs test` | 74個Vitest檔／696 tests PASS；Node內建runner檔另行執行 | [test.log](../artifacts/ux-prototype/test.log) |
| `node scripts/ux-prototype-check.mjs legacy-guard` | **12 PASS、1 FAIL**；封存保護檢查報 `Protected content mismatch: next-env.d.ts`。未刪測試、未改保護基線；不把它算入Vitest通過 | [legacy-guard.log](../artifacts/ux-prototype/legacy-guard.log) |
| `node scripts/ux-prototype-check.mjs lint` | PASS（source/tests/local scripts/config範圍） | [lint.log](../artifacts/ux-prototype/lint.log) |
| `node scripts/ux-prototype-check.mjs typecheck` | 最後變更後全專案TypeScript PASS | [typecheck.log](../artifacts/ux-prototype/typecheck.log) |
| `node scripts/ux-prototype-check.mjs build` | 最後對話框修正後Webpack build EXIT_CODE=0 | [build.log](../artifacts/ux-prototype/build.log) |
| `node scripts/ux-prototype-production-check.mjs` | 暫時啟動本機production，4個雛形入口實際404；dev200與CSP/noindex正確 | [production-isolation.json](../artifacts/ux-prototype/production-isolation.json) |
| `node scripts/ux-prototype-compare.mjs` | 讀來源hash、另寫並排與diff；無PASS閾值 | [comparison.md](../artifacts/ux-prototype/comparisons/comparison.md) |

初次失敗保留：直接對全工作區lint掃到歷史 `artifacts/remote-smoke/.../.next`生成碼，原結果見 [lint-initial-generated-artifacts.log](../artifacts/ux-prototype/lint-initial-generated-artifacts.log)；初次Vitest混跑Node原生測試runner，報 `No test suite found`，見 [test-initial-mixed-runners.log](../artifacts/ux-prototype/test-initial-mixed-runners.log)。後續分開正確runner與生成物範圍，沒有刪除失敗用例；legacy guard本身仍明確失敗。

第二次建置曾在Webpack既有快取的WasmHash崩潰，原始結果保留於[build-webpack-cache-failure.log](../artifacts/ux-prototype/build-webpack-cache-failure.log)。只清除此輪建立的`.next/ux-prototype-build/cache`後重新建置成功，未變更依賴、測試或門檻。

最終瀏覽器warning/error為0，DOM沒有iframe/object/embed，觀察到的script、樣式及圖像均為本機路徑，见[browser-final-observation.json](../artifacts/ux-prototype/browser-final-observation.json)。開發期間HMR曾清除Mock，已在程式穩定後重走相關流程；未將中斷步驟算通過。瀏覽器介面沒有完整Network trace功能，故**不宣稱已取得全程外部請求0次的網路封包證明**；此處證據為實際同來源CSP、DOM資源與console觀察、隔離HTTP及command測試。

## 9. Mock、未接與尚待驗證

所有角色、授權、課程、價格、課包、預約、回饋、文章、規章、收入、audit都為共用Mock。發布只改記憶體，不能送正式網站；影片播放器為明確placeholder，檔案選擇只記檔名，沒有真實播放／上傳／Storage。分潤仍是待核准假設，規章已讀不是簽約，Pro服務資格不是正式quota。

Stage 1/3為核准原稿中的旅程示意，Stage2提供6個代表性課節；未捏造完整旗艦課綱。六個Canonical Level成果定義未改。學生取消／改期頁目前是規則說明，實際Mock修改由管理員流程進行，不捏造商業取消期限。

剩餘限制：OS主題即時切換、瀏覽器縮放與完整Network trace未驗證；公開頁的原始內容截圖不含15px傳統捲軸且手机師資取景有差異；歷史位元組封存guard仍1項失敗。頁面及授權範圍內Mock流程已完成，沒有把這些限制自動改寫成「全站全部PASS」。

禁止範圍持續有效：main不改、沒有push或部署、沒有資料庫／金流／通知／備份或還原。以整合者最後git與原稿hash核對結果完成交付。
