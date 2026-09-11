# The One 2.0 Platform Experience Map

盤點日期：2026-09-11。盤點基線：`preview-test`，HEAD `0af06802dbeb2fcd614d33db3e64c441fe711be4`，包含前一輪尚未提交的原生 UX Prototype。這是實際程式碼盤點，不是 Canonical 狀態更新，也不將介面完成計作 Epic 完成。

**現況：PARTIAL。** Epic1～6 的正式路由已接既有服務，Epic7 有本機 domain／RPC 基礎；使用者喜歡的新版 Public／Student／Teacher／Admin 外觀則在獨立 `/ux-prototype` 記憶體資料樹。兩者尚未形成從註冊、購買到持續學習的完整服務接線。下方第 2～13 節保留實作前盤點；**第 14 節記錄本輪已補入的 Account、Membership、Billing／Cancel、Public 及支援 UI，不再把它們列為「沒有畫面」；backend／政策缺口仍然存在。**

## 1. 證據、狀態與安全邊界

依序讀取 [CURRENT_WORK](CURRENT_WORK.md)、[PROJECT_STATUS](PROJECT_STATUS.md)、[CANONICAL_ROADMAP](CANONICAL_ROADMAP.md)、[PRODUCT_DECISIONS](PRODUCT_DECISIONS.md)，再核對 `src/app` 全部 `page.tsx`／`route.ts`、角色 layouts、Prototype 分流及相關資料／action 實作。盤點基線共有 **36 個檔案入口：30 個既有頁面、5 個既有 Route Handlers、1 個 Prototype catch-all**。Catch-all 的實際分支另外逐項列於下方，不能把任意可回應 URL 算作已完成頁面。

| 標記 | 本文件的精確含義 |
|---|---|
| REAL | 此路由原始碼已呼叫既有正式 server service／DAL／Action／RPC；不代表本輪執行過資料庫、不代表當前遠端可用或 production ready。 |
| HYBRID | 真實能力只覆蓋部分，例如真實 Auth 保護加上功能入口殼，或支付 provider 介面存在但處理未完成。 |
| MOCK | 靜態佔位，或僅本機 fixture／memory command。互動成功不等於既有 Epic 接線完成。 |
| 缺頁／Gap | 尚無對應實際路由／分支，不虛構 URL，也不以未來規劃當成已存在。 |

本輪只以讀原始碼確認既有正式 route 的接線，**沒有開啟會初始化正式 session 的既有路由，沒有 Supabase／SQL／migration／支付／通知呼叫**。需要安全 local／preview adapter 的地方均列於「後續接線」，不是本輪已完成。若後續 adapter 只重用正式 schema／DTO、資料仍為 fixture，必須標 **HYBRID：正式驗證規則 + 模擬資料；RPC 未執行**，不可標完全 REAL。

Canonical 現況：Epic0～4 CLOSED；Epic5、6 REMOTE CLOSED 的證據屬歷史已核准操作；Epic7 A–E LOCAL CLOSED、F local tooling complete，production F 未授權。Epic8～13 的介面／規劃不等於這些 Epic backend 已開始或已關閉。Finance、Community、AI Personalization、Cloud Classroom 等仍屬 future／post-launch。

可追溯程式碼入口：

- [Auth server authorization](../src/modules/auth/server-authorization.ts)、[角色與帳號狀態](../src/modules/auth/route-access.ts)、[Auth actions](../src/modules/auth/actions.ts)。
- [公開老師投影](../src/modules/teachers/public-discovery.ts)、[老師 Actions](../src/modules/teachers/actions.ts)、[Admin 老師 Actions](../src/modules/teachers/admin-actions.ts)。
- [Trial data](../src/modules/trials/data.ts)、[Trial actions](../src/modules/trials/actions.ts)。
- [Commerce data](../src/modules/commerce/data.ts)、[Commerce actions](../src/modules/commerce/actions.ts)。
- [Entitlement data](../src/modules/entitlements/data.ts)、[Entitlement actions](../src/modules/entitlements/actions.ts)。
- [Scheduling data](../src/modules/scheduling/data.ts)、[Scheduling actions](../src/modules/scheduling/actions.ts)。
- [Learning Map data](../src/modules/learning-map/data.ts)、[範圍限制](../src/modules/learning-map/README.md)。
- [Prototype route 分流](../src/components/ux-prototype/page.tsx)、[memory store](../src/modules/ux-prototype/store.tsx)、[開發環境隔離](../src/app/ux-prototype/layout.tsx)、[proxy](../src/proxy.ts)。

文件落差：`src/modules/auth/README.md` 還寫 placeholder，但實際 Auth action／session／roles 已存在，判定以程式碼及 Canonical 為準。此次 `rg --files` 沒找到 `THE_ONE_PRODUCT_UX_DIRECTION` 或 Cloudflare Preview 專用文件；不能由貼文推論它們已在 repo。前輪 UX 證據見 [UX_PROTOTYPE_ACCEPTANCE](UX_PROTOTYPE_ACCEPTANCE.md)。

## 2. 既有 Public 與 Auth 路由

每個路由對應的實體檔案為 `src/app/<路徑>/page.tsx`；表內「證據」指出實際讀取或執行函式。這些正式路由仍是舊有 foundation UI。

| Actual route | 角色／用途 | Epic | 現況及接線證據 | 缺失 | 後續 adapter／整合 |
|---|---|---|---|---|---|
| `/` | Public：平台入口 | 0；待2/4/8 | MOCK：只顯示 Platform Foundation／Build 正常 | 沒有完整品牌導覽、學什麼及下一步 | 將核准公開版原生元件接公開 catalog／teacher DTO；保持正式入口與本機模式邊界 |
| `/teachers` | Public：老師探索 | 2 | REAL：`listPublicTeachers` 讀 `teacher_public_profiles` 安全投影 | 舊卡片外觀；資料錯誤可能被轉成空列表 | 保留公開投影、狀態化錯誤；將資料映射至核准卡片 |
| `/teachers/[slug]` | Public：老師介紹、教學形式／價格 | 2/3 | REAL：`getPublicTeacherBySlug`，動態 metadata，找不到 `notFound()` | 未接新版 system／standalone／private 分類與正式商品映射 | 保留 publicSlug 作外部識別；安全串老師對應商品、體驗課 |
| `/teachers/[slug]/trial` | Student：體驗課申請 | 1/2/3 | REAL：identity、`getTrialTeacherContext`、`requestTrialCheckout` | 工程式表單；非一般商品 checkout；未串新學生後續 onboarding | 沿用 Trial RPC；保留獨立 trial order，不雙寫 generic Commerce |
| `/products` | Public：商品列表 | 4 | REAL：`listPublicProducts` 讀 `product_public_catalog` | 商品類型名稱直接露出；不是 System Course／Membership Catalog | 以原商品 DTO 做清楚分類；內容目錄與商品目錄保持分開 |
| `/products/[slug]` | Public／Student：商品詳情與建立訂單 | 1/4 | REAL：`getPublicProduct`、`createCheckoutOrder`；未可購商品有 coming-soon | 只有商品／數量／建立訂單；不是三種完整 checkout；缺條款與成功去向 | 沿用 checkout Action、server price 與 idempotency；依產品結果導向帳戶／已購產品／堂數 |
| `/auth/sign-in` | 訪客：登入 | 1 | REAL：`signIn`、safe redirect；有註冊／忘記密碼連結 | 尚無新版共同品牌殼；登入後預設學生入口仍 foundation | 重用同一 Auth；保留安全 next path；成功後導向相應 workspace |
| `/auth/sign-up` | 訪客：註冊 | 1 | REAL：`signUp`（名稱、Email、密碼），導向 Email 驗證 | 無首次登入學習 onboarding；無已核准法律同意文案 | 保留 Epic1；驗證成功後加明確歡迎／目標／推薦流程，不自動 enrollment |
| `/auth/forgot-password` | 訪客：重設信入口 | 1 | REAL：`requestPasswordReset`，一致回應防帳號探測 | 缺統一支援及寄信問題入口 | 保留現有安全回應與驗證；UX 加重試說明，不另造 Auth |
| `/auth/reset-password` | 復原身份：變更密碼 | 1 | REAL：`resetPassword`、`getUser`、`updateUser` | 不等於完整 Account Security 中心 | 沿用現有 session 驗證；Account 安全頁只接既有能力 |
| `/auth/verify-email` | 註冊後：收信／驗證提示 | 1 | HYBRID：真實 Auth 流程的靜態提示頁 | 沒有重寄、改 Email、首次登入引導 | 後續重用 Auth 能力；不存在的重寄 action 必須明確新增 service 接口後才算可用 |
| `/auth/access-denied` | 登入／受限者：權限拒絕 | 1 | HYBRID：實際授權導向的拒絕頁 | 回復工作區／聯絡支援不足 | 依真實 identity 提供可進入工作區，不允許前端授權自己 |

公開老師正式 DTO 目前有 `publicSlug`，**沒有 teacher user UUID／teacherProfileId**。Prototype 的 `t1` 不是正式老師身份；過渡 adapter 可映射本機 fixture，但不可為了 URL 方便把私人身份欄位加到公開投影。

## 3. 既有 Student 路由

`src/app/student/layout.tsx` 透過 `requireAreaAccess("student")` 保護整個子樹；多角色不等於每個角色自動取得 Student permission。

| Actual route | 用途 | Epic | 現況及接線證據 | 缺失 | 後續 adapter／整合 |
|---|---|---|---|---|---|
| `/student` | 學生入口／登出 | 1 | HYBRID：真實 role layout、`SignOutForm`；內容只有Trial／Packages／Schedule連結 | 沒有Today、我的學習；Orders也不在此入口 | 新學習殼以Today為主；Account放頭像；可用能力來自真實角色 |
| `/student/trial` | 我的體驗課／結果／會議入口 | 3 | REAL：`listOwnTrialOrders`、`listOwnStudentTrialResults`；join Link | 與私人課／課程學習分散 | 聚合 DTO 到私人課總覽；Trial保留自己的來源及付款語義 |
| `/student/orders` | 個人訂單列表 | 4 | REAL：`listOwnOrders` | 狀態碼露出；沒有完整Billing中心 | Account Orders重用此service，轉譯狀態及下一步 |
| `/student/orders/[id]` | 訂單詳情、轉帳回報、未付取消 | 4 | REAL：`getOwnOrder`、`submitBankTransfer`、`cancelOwnOrder` | 無卡片支付／收據／發票／退款／訂閱管理；query錯誤提示較泛 | 以訂單與payment summaries建billing view model；未實作能力列Gap |
| `/student/packages` | 課包效期及總／可用／預留／已用堂數 | 5 | REAL：`listOwnLessonPackages` → `get_own_lesson_entitlement_summaries` | UI未接下一步選老師／時段，列表不等於權益完整歷史 | 同一summary映射私人課頁；保留ledger唯一權威，不由UI改balance |
| `/student/schedule` | 可用時段、預約、改期／取消、固定安排 | 5/6 | REAL：`findFlexibleSlots`、bookings/series RPC + scheduling Actions | 要手填Teacher/Relationship/Entitlement UUID與ISO時間；無完整友善meeting／feedback聚合 | 安全selector隱藏UUID；預約操作繼續走原RPC；取消規則以正式domain為準 |

## 4. 既有 Teacher 路由

`src/app/teacher/layout.tsx` 使用真實 Teacher role guard。Teacher Profile 可編輯自身展示欄位，不等於可編輯或發布正式 System Course。

| Actual route | 用途 | Epic | 現況及接線證據 | 缺失 | 後續 adapter／整合 |
|---|---|---|---|---|---|
| `/teacher` | 老師入口／登出 | 1 | HYBRID：角色保護，四個功能連結 | 不是今日教學工作台 | 用授權後的trial／booking summary組合Today；私密與學生可見DTO分開 |
| `/teacher/profile` | 自己的公開展示資料 | 2 | REAL：`getOwnEditableTeacherProfile`、`saveOwnTeacherProfile`、catalog | 新版展示送審快照並非同一正式workflow | 重用允許欄位和server權限；審核新workflow屬Epic13，不以Mock取代正式update |
| `/teacher/trials` | 體驗課、會議預設、完成／學生建議 | 3 | REAL：`listOwnTeacherTrials`、`saveTeacherMeetingDefaults`、`completeTrialLesson` | 尚未融入日常學生列表與學習地圖 | 沿用Trial完成與meeting安全邊界；legacy Stage不自動映射新Level能力 |
| `/teacher/packages` | 查授權學生的課包、延效 | 5 | REAL：`listTeacherStudentLessonPackages`、`extendLessonPackage` | 必須輸入學生UUID／ISO；缺學生選擇與可理解效期表單 | 既有relationship範圍內selector；保留RPC理由／idempotency |
| `/teacher/schedule` | 可教時段、固定系列、單次排課、改取消、完成課次 | 5/6 | REAL：availability/bookings/series RPC與Actions；完成課次含公私筆記／作業 | 工程表單多；機制已存在但尚未接新版課表、Today、Lesson Record | 使用既有scheduling authority；fixed series／occurrence與新版單次UI不混同 |

## 5. 既有 Admin 路由

`src/app/admin/layout.tsx` 要求 Admin／Super Admin area permission。Prototype 的 owner／ops／finance 切換是本機情境，不能直接替代正式 role／capability。

| Actual route | 用途 | Epic | 現況及接線證據 | 缺失 | 後續 adapter／整合 |
|---|---|---|---|---|---|
| `/admin` | Admin入口／登出 | 1 | HYBRID：真實保護；頁面明示Dashboard尚未建立 | 無營運總覽；Orders不在入口列 | 以最少待辦聚合既有受權DTO，不再建立第二套admin身份 |
| `/admin/teachers` | 老師帳號／展示／能力／專長管理 | 1/2 | REAL：`listAdminTeachers`、`saveAdminTeacherProfile`、capability／specialties Actions | 舊表單；能力屬legacy Stage，非新System Course Level | 重新呈現既有流程；新course能力需明確mapping和policy |
| `/admin/trials` | 體驗課付款確認、課次改期／取消 | 3 | REAL：`listAdminTrialData`、confirm/reschedule/cancel RPC | 待辦和訂單分散；仍顯示內部ID | 保留Trial獨立來源；將操作摘要接營運總覽 |
| `/admin/orders` | 全站訂單／狀態篩選 | 4 | REAL：`listAdminOrders` | 原始狀態、缺整體支援／payment工單 | 原service映射可讀狀態，role guard不下放browser |
| `/admin/orders/[id]` | 轉帳審核、現金確認、取消未付訂單 | 4/5 | REAL：`getAdminOrder`、confirm/reject/cash/cancel Actions | production provider callback未完成；不是退款或完整財務 | 沿用payment→order.paid outbox→fulfillment；不由UI直接發課包 |
| `/admin/packages` | 權益延效、ledger調整、fulfillment人工重試 | 5 | REAL：admin summaries、extend／adjust／retry RPC | 需輸入event／entitlement ID；缺操作前影響預覽和易懂歷史 | 授權DTO＋影響預覽；保留不可變audit、理由及idempotency |
| `/admin/schedule` | 範圍課表、代建flexible、series override、改取消 | 5/6 | REAL：`listAdminSchedule`及admin scheduling Actions | UUID／ISO／creditOutcome工程欄位直接暴露；無可操作整體日程 | 原RPC做最後決策；UI以學生／課包／時段selector及確認流程承接 |

## 6. 既有 Route Handlers（不是產品頁面）

| Actual route | 角色／用途 | Epic | 狀態及實際行為 | Gap／接線要求 |
|---|---|---|---|---|
| `GET /auth/callback` | Auth callback | 1 | REAL：session code exchange、安全next導向 | 保留原callback，不為Prototype建第二套session |
| `GET /auth/confirm` | Email OTP確認 | 1 | REAL：核對OTP type／token、安全導向 | Email UX與onboarding消費既有結果，不更改驗證權威 |
| `GET /lesson/[id]/join` | 已授權課次參與者：會議轉址 | 3；可供6/12整合 | REAL：active identity、RLS lessons、scheduled／online檢查、meeting URL normalize後redirect | Meeting URL不提前放public/student DTO；目前非錄播播放器 |
| `GET /api/health` | 運作探針 | 0 | REAL（靜態HTTP探針）：非業務DB可用性檢查 | 不拿HTTP200表示backend／production ready |
| `POST /api/payments/[provider]/webhook` | 支付provider callback邊界 | 4/13 | HYBRID：未配置回501；即使verify成功仍回501「processing not enabled」；驗證失敗401 | production payment closure未完成；不得由前端success畫面自行確認付款 |

## 7. 現有原生 Prototype：Public

下表完整路徑均以 `/ux-prototype` 開頭。所有業務資料均為 **MOCK**：`PrototypeProvider → createFixtures → executeCommand`，沒有正式Epic DAL import、RPC或Auth。前輪「已實測」是本機UX證據，不提升這個接線等級。

| Actual route | 角色／用途 | 所屬Epic／現況 | 具體Gap | 下一個integration接點 |
|---|---|---|---|---|
| `/ux-prototype` | Public：v1.6首頁、FAQ、老師卡、課程入口 | 2/8/9；MOCK | 真實catalog、老師與登入導向未接 | PublicTeacher／CatalogProduct DTO adapter；用同一品牌殼 |
| `/ux-prototype/teachers/[teacherId]?tab=private` | Public：老師介紹／system／standalone／private tabs | 2/4/5；MOCK | ID為t1等fixture；價格不是Commerce authoritative quote | local fixture做slug映射；正式採PublicTeacher publicSlug、商品服務 |
| `/ux-prototype/courses/guitar-roadmap` | Public：旗艦System Course介紹／明確加入 | 7/8/9；MOCK | 尚無正式course catalog／access／joinservice | 先接安全course DTO；Epic8 eligibility與明確join分開，拒絕自動加入 |
| `/ux-prototype/courses/[courseId]` | Public：已發布示意課程內容 | 7/13；MOCK | memory published不是正式發布版本；System Course／Product仍需正式映射 | Epic7 version DTO＋Epic13發布workflow，Commerce獨立 |
| `/ux-prototype/diagnosis` | Public：五題方向問答 | 9未來UI；MOCK | 結果只在URL/local；非首次登入profile | 將答案做onboarding view model；只建議，不授權／認證 |
| `/ux-prototype/diagnosis/result` | Public：不同建議／加入或繼續入口 | 8/9；MOCK | 沒有真正 enrollment／access | 建議 →課程詳情→明確加入；不能從plan推導自動enrollment |
| `/ux-prototype/articles` | Public：已發布示意文章 | 13；MOCK | 尚無正式CMS／resource search | 公開content DTO；draft不可出公開adapter |
| `/ux-prototype/articles/[slug]` | Public：文章正文 | 13；MOCK | memory article，無正式SEO／版本／媒體 | 再用正式published content adapter；純文字內容不執行HTML |
| `/ux-prototype/policies/students` | Public：學生規範草案 | 13；MOCK | 不是正式Terms／Refund政策 | 已核准政策版本來源及明確草案狀態 |
| `/ux-prototype/policies/privacy` | Public：隱私草案說明 | 13；MOCK | 尚無已核准法務文本或account deletion流程 | 法務內容decision gap；不把占位稱生效政策 |

以上為實作前基線：當時`/ux-prototype/teachers`沒有老師列表分支，Public未知prefix會落回首頁。**本輪最後核對已新增`/teachers`的原生老師列表及未知top-level路徑的UnavailablePage，詳見第14、15節；正式publicSlug與本機teacherId的接線仍未完成。** 不能因顯示「404」文字便推定所有catch-all都回HTTP404。

## 8. 現有原生 Prototype：Student／Lesson

| Actual route | 用途 | 所屬Epic／現況 | 具體Gap | 下一個integration接點 |
|---|---|---|---|---|
| `/ux-prototype/student`（亦識別`/student/today`） | 今日學習／目前課節／練習／下一堂 | 7/9/12；MOCK | 今日推薦、joined／currentLesson、課次皆fixture | 聚合正式owner activity＋course membership＋scheduling summaries；authority未開不能偽造可用 |
| `/ux-prototype/student/courses` | 已加入／已完成／私人課 | 8/9；MOCK | 只展示c1；沒有正式join／archive、已購standalone完整呈現 | Eligibility與Enrollment分開的adapter；archive列decision gap |
| `/ux-prototype/student/map?stage=2` | 全局Stage旅程與Module／Lesson | 7/9；MOCK | 3個代表性Stage與6課是核准示意，非正式完整六Level課綱 | 從Epic7版本階層映射；legacyStage與courseLevel不得ID等同 |
| `/ux-prototype/student/courses/[courseId]/lessons/[lessonId]?activity=learn` | 三欄錄播／文字／練習／教材／下一步 | 7/8/9；MOCK | 實際僅c1的l1～l6；播放器／素材placeholder；未讀正式content／policy | Provider-neutral resource adapter，server access gate後才供媒體；觀看不自動完成 |
| `/ux-prototype/student/practice` | 當日練習、自報勾選 | 9；MOCK | 無正式practice計畫／歷史／notes／音檔 | Epic9服務未來接線；自報不等於verified |
| `/ux-prototype/student/private?package=[id]` | 課包、下一堂、練習、紀錄與回饋 | 5/6/12；MOCK | 模擬選slot預約；學生改期／取消是規則說明，由admin做示意操作；meeting入口不開真會議 | 既有credit summaries＋scheduling Actions；補友善改取消及authorized join |
| `/ux-prototype/student/feedback` | 私人課回饋／平台協助 | 10/12；MOCK | 未接正式lessonrecord／submission；不同來源仍需DTO隔離 | 先接Epic6學生可見教學資料；Epic10正式review另保留Future |
| `/ux-prototype/student/guidance` | Pro提交與指派／回覆狀態 | 8/10；MOCK | 指導資格／指派／回饋只memory；沒有quota帳或正式驗證 | Epic8資格adapter＋Epic10 submission/review；不寫死quota、不把AI當verifier |
| `/ux-prototype/student/courses/c1/units/u1/guidance` | 單元示意提交、預覽、明確送出 | 8/10；MOCK | 只u1；媒體placeholder，不上传／通知 | 正式evidence provider及consent須另實作；不得接已禁止上傳 |
| `/ux-prototype/student/settings` | 外觀／時區／情境／守則入口 | 9/13；MOCK | 外觀localStorage、時區memory；不是Account Center | 共用偏好adapter；profile／security／billing是分開account功能 |
| `/ux-prototype/student/policies` | 學生守則版本已讀 | 13；MOCK | memory acknowledge，不是正式簽署 | Policy version+ack服務待Epic13，正式條款需產品確認 |

Lesson內 `activity` 分頁及課節搜尋是局部互動，不是全站Search或新的獨立route。`/ux-prototype/student/courses/[id]` 並沒有正式單一System Course workspace分支；不能僅因catch-all回應就當新增詳情頁。

## 9. 現有原生 Prototype：Teacher

所有列均為教師示意角色；只在memory命令層檢查關係／能力，不是真實server授權。

| Actual route | 用途 | 所屬Epic／現況 | Gap | 下一個integration接點 |
|---|---|---|---|---|
| `/ux-prototype/teacher` | Today、下一堂、待回饋 | 6/10/12；MOCK | 聚合來源是fixture | 真實bookings／trials＋未來review queue分層接線 |
| `/ux-prototype/teacher/schedule` | 老師課表 | 6/12；MOCK | 固定／彈性示意不等同正式recurrence引擎 | 沿用Epic6availability／series／occurrences／bookings |
| `/ux-prototype/teacher/book-for-student` | 關係內代學生選時段 | 6/12；MOCK | 正式role/RPC支援範圍要逐一對照 | 只接正式允許的Action；不把Mock教師權限帶進Admin RPC |
| `/ux-prototype/teacher/students` | 授課學生搜尋與列表 | 5/6/12；MOCK | teacherStudents為fixture關係 | 授權student relationship DTO；不要查全站profiles |
| `/ux-prototype/teacher/students/[id]` | 學生學習脈絡／課包／回饋 | 7/10/12；MOCK | 路線與progress沒有正式owner授權DTO | scoped學生summary；新Level能力需policy |
| `/ux-prototype/teacher/lessons/[id]` | 課後公私筆記、練習、完成課次 | 6/12；MOCK | memory完成與consume，非正式credit ledger | Epic6 completeTeacherBooking；public/private notes各自DTO |
| `/ux-prototype/teacher/reviews` | 作業與回饋列表 | 10/12；MOCK | 無正式rubric／assignment／due-policy | Epic10queue adapter，權限依assignment與capability |
| `/ux-prototype/teacher/reviews/[id]` | 檢視示意提交及回覆 | 10；MOCK | 無真媒體、resubmit／正式verified未完備 | 明確保留未來Epic；人工正式verifier不可由fixture替代 |
| `/ux-prototype/teacher/records` | 教學紀錄 | 6/12；MOCK | memory資料，沒有正式歷史載入 | 從既有lesson完成資料建立teacher-private／student-visible views |
| `/ux-prototype/teacher/courses` | 課程與提案／私人課包tabs | 4/7/12/13；MOCK | 無正式proposal及offer審核service | Teacher只提案；正式內容由Admin編輯發布；商品與內容分開 |
| `/ux-prototype/teacher/proposals/[id]` | 提案草稿、權利說明、送審 | 13；MOCK | snapshot只在記憶體，非正式CMS | Epic13受控draft/review adapter，不直接寫course published |
| `/ux-prototype/teacher/profile` | 展示頁草稿／送審 | 2/13；MOCK | 與正式Epic2更新workflow尚未映射 | 先重用Epic2允許欄位；新增審核生命週期需正式service |
| `/ux-prototype/teacher/earnings` | 教師收入示意 | Future Finance；MOCK | 沒有正式收入／歸屬／settlement權威 | 不列本輪backend blocker；不固定分潤公式 |
| `/ux-prototype/teacher/policies` | 合作守則版本已讀 | 13；MOCK | 不是正式合約簽署 | 經核准版本＋ack服務；商業條款未決先標Proposed |
| `/ux-prototype/teacher/settings` | 共用外觀／時區 | 12/13；MOCK | 不含真實profile／security | 進共同Account Center，不另建一套帳號 |

## 10. 現有原生 Prototype：Admin／Creator

沒有獨立Creator正式role或`/creator` route；課程與文章編輯目前在Admin memory workflow。正式Auth只列student／teacher／admin／super_admin，不能自行把Creator當已授權角色。

| Actual route | 用途 | 所屬Epic／現況 | Gap | 下一個integration接點 |
|---|---|---|---|---|
| `/ux-prototype/admin` | 營運總覽 | 13；MOCK | fixture指標與待辦 | 聚合既有正式orders／trial／bookings，而非平行營運資料 |
| `/ux-prototype/admin/courses` | 正式課程草稿列表 | 7/13；MOCK | 沒有正式System Course CRUD／CMS | Epic7標準版本資料，Epic13draft/review/publish服務 |
| `/ux-prototype/admin/courses/[id]` | 內容／存取草稿、預覽／發布 | 7/8/13；MOCK | memory公開版及policy不是正式access authority | 內容版本與membership inclusion分開；不可由checkbox直授權 |
| `/ux-prototype/admin/review` | 提案／profile／offer／article審核 | 2/4/13；MOCK | memory快照guard非正式server交易 | 保留提案先匯入draft；正式expected-version／audit服務 |
| `/ux-prototype/admin/articles` | 文章列表／草稿 | 13；MOCK | 沒有正式文章CMS | published content adapter；適當內容權限 |
| `/ux-prototype/admin/articles/[id]` | 文案／SEO／檔名、预览／送審 | 13；MOCK | 不上传封面；SEO只存memory | 正式CMS與asset adapter分开；保持純文字安全呈現 |
| `/ux-prototype/admin/students` | 學生搜尋、課包權益／補發示意 | 1/5/13；MOCK | memory grant不等於Epic5 fulfillment或正式贈課權限 | 先接admin entitlement summaries；每種write對照原RPC，有缺口則停留Mock |
| `/ux-prototype/admin/bookings` | 代約／改期／取消、權益影響預覽 | 5/6/13；MOCK | 受測memory規則不替代正式policy | 沿用admin scheduling RPC＋理由／idempotency／audit |
| `/ux-prototype/admin/guidance` | Pro指導資格與老師指派 | 8/10/13；MOCK | 沒有正式review routing／quota ledger | Epic8eligibility＋Epic10assignment；不是Finance或一對一credits |
| `/ux-prototype/admin/oversight` | 理由化受控師生互動檢視／平台回覆 | 13；MOCK | frontend遮蔽不是正式privacy security | server最小資料、受控揭露和audit後才接；不能讀全部私人notes |
| `/ux-prototype/admin/audit` | 示意操作軌跡 | 13；MOCK | memory陣列會重整消失；非不可變server audit | 聚合正式audit read DTO，不能以此取代原RPC稽核 |
| `/ux-prototype/admin/policies` | 守則版本預覽／發布 | 13；MOCK | 未正式法律／版本儲存服務 | 經核准政策來源＋版本影響檢查 |
| `/ux-prototype/admin/finance` | 收入／預留／退款等表格示意 | Future Finance；MOCK | 並非帳務結算domain，也未接真付款 | 只提供明確preview；詳細settlement仍future，不列現在blocker |
| `/ux-prototype/admin/settings` | 外觀／時區 | 13；MOCK | 不是管理帳號／安全中心 | 共用Account偏好adapter；真正權限由backend |

## 11. 尚不存在的完整體驗與最小補齊方向

此表列缺口，不宣稱以下建議名詞已有對應URL。新頁應採同一App Shell／role-aware navigation；不複製四套網站。

| 使用者旅程／需求 | 實際已存在 | 尚缺的體驗 | 分類／後續 |
|---|---|---|---|
| 公開資訊架構 | 老師、商品正式頁；新版首頁/FAQ/文章Mock | System Course catalog、Membership、公眾About／Contact／Help與完整法律入口 | 安全UI可補；政策未決明示Gap |
| 首次註冊→開始學習 | Epic1驗證流程；Prototype五題診斷與明確加入 | 真實驗證後Welcome／目標／時間／推薦→Today，未串joined workspace | 重用Auth；onboarding UI可先Mock；access/join待Epic8/9 |
| Account Center | 真Auth sign-out／password recovery；散落訂單；Prototype外觀 | Profile／個資／Email／安全／Membership／付款／通知／支援／刪除入口 | 不存在`/account`子樹；profile capabilities先盤點，缺service不寫成可保存 |
| Membership管理 | Free/Plus/Pro只有Mock情境 | Current plan／週期／續約／包含課程／升降級／取消／再啟用 | Epic8；immediate/end-of-period/grace/refund/reactivate未決→Product Decision Gaps |
| 三類Checkout | Epic4商品→order；Trial獨立checkout | Membership subscription、standalone、私人課包的差異、付款方式、條款、成功下一步 | 重用Commerce；subscription不可冒稱已接；payment success不能自授權 |
| Billing／Cancel | Own orders／payment summaries／轉帳回報 | Payment method／下次扣款／收據／發票／退款／past-due／retry／取消訂閱 | 既有order部分可接；subscription lifecycle需Epic8，發票／退款政策未決 |
| 取消會員 vs 刪除帳號 | 都沒有完整正式流程 | 兩個獨立入口、影響、原因、確認、結果狀態 | 刪除保留／法務／financial retention需decision；不能共用「取消」動作 |
| 私人課購買→堂數→預約 | Epic4/5/6真服務各自存在；Prototype已有共享UX | 購買成功後明確導到堂數／選時段；真實友善改取消／join／紀錄 | 優先整合原service；買credits不自動booking |
| System Course學習 | Epic7hierarchy/version/activity；Prototypemap/player | 正式Catalog／加入／policy／resources／owner position接線 | Epic7不開假authority；Epic8政策先行，Epic9workspace |
| Practice | Prototype當日勾選和課節activity | 正式計畫／歷史／notes／PDF/audio/backing-track provider | Epic9，媒體服務未接時標Mock |
| Submission／Coaching | 跨角色Mock提交→指派→回覆 | 真實evidence／rubric version／revision/resubmit／due／verified | Epic10，不自動verified，不讓AI作formal verifier |
| Assessment／Achievement | 明確不將self-complete冒充證書 | Eligibility／attempt／result／feedback／achievement／certificate／驗真分享 | Epic11 Future UI，沒有正式route或backend接線 |
| Teacher日常 | Epic3/5/6正式分散頁；PrototypeToday/student/record/review | 正式role-scoped聚合、學生roadmap授權、完整review能力 | Epic12整合原service；review本身Epic10 |
| Admin／Creator內容 | Epic2/3/4/5/6操作；Prototype編輯發布 | 真Users／Products／Memberships／Support／Reports／CMS版本流程 | Epic13整合；Creator身份與發佈權限需正式policy |
| Notification Center | notifications module僅README | 閱讀通知／篩選／已讀／連到事件對象 | Epic13 Mock UI先行；Email／LINE backend未完成不可發送 |
| Help／Support | FAQ＋部分說明對話框 | Help Center／帳務、預約、學習求助／問題回報／處理狀態 | 先安全入口UX；客服後端Gap，不全轉給老師 |
| 全站Search | Prototype課節局部搜尋、學生列表搜尋 | Course／Resource／Teacher／Help跨類型搜尋及無結果 | UI可Mock，search backend不是当前blocker |
| 角色切換 | 真實roles array／三area guard；Prototype手動情境 | 基於同一真實帳號能力的workspace switcher及回到學生學習 | 不以路由／前端按鈕授權；復用Epic1 |
| 404／錯誤／Loading／Offline／Maintenance | Next預設notFound；Auth拒絕；各別empty／toast | `src/app`無自訂`not-found/error/loading/global-error`；Public未知prototype route落首頁 | 共享恢復入口與狀態頁可補；不可把fetch失敗都展示「沒有資料」 |

## 12. 必須保留的狀態與語義

目前有部分empty、no-public-offer、no-credit、no-slot、permission-gate、未加入、待指派、已回覆及版本衝突Mock；正式頁多為empty和泛用query error，**不代表完整異常旅程已覆蓋**。後續應逐頁列出 loading、error/retry、inactive role、locked content、expired/past-due membership、teacher unavailable、cancelled booking、review overdue、assessment failed、certificate unavailable，沒有正式backend的狀態明確標Mock／Proposed。

Domain接線時維持：

- Membership是平台方案；System Course是課程，不因會員資格就自動加入全部課程。
- Content、Product、Commerce、Payment、Entitlement、Achievement分開；作者不決定存取或收入歸屬。
- Credit、Booking、Recurring Series／Occurrence、Lesson分開；前端不能計算最終時段或直接改ledger。
- Recommendation不是Enrollment；Eligibility不是Enrollment；Self Complete不是Verified、Assessment Pass或Certificate。
- 老師可提案，不可藉新UI取得正式System Course的編輯／發布權。
- 既有正式domain若與Prototype規則不同，調整Prototype；不可為保留Mock方便而修改已核准domain。
- Future Finance不作當前阻礙；不得為補畫面硬編分潤／quota／退款／取消商業規則。

## 13. 建議接線次序與完成標準

1. **先做安全adapter邊界**：複用既有DTO／schemas／timezone／permissions；目前DAL直接初始化Supabase，不是現成memory repository，不能在Preview盲呼叫。明確固定local/preview target，未配置時fail closed，不fallback production。
2. **Public／Account入口**：核准Public元件接安全公開老師／商品DTO；Account Orders重用Commerce；Auth只復用Epic1。新增Help／錯誤／未支援入口可先做純UX。
3. **Private Lesson接線**：同一既有Entitlement summary、Scheduling read model及mutation；不由Prototype command代替正式授權。前端selection和confirmation只收集意圖。
4. **Learning安全預備**：先映射Epic7版本階層，保留已交付deny authority；membership、join、resources、review待各Epic批准接口，不新建第二套Learning Map domain。
5. **Teacher／Admin聚合**：優先把已存在的orders/trials/credits/bookings嵌入新版工作殼；內容CMS、Pro、通知等目前缺service的部分保持清楚Future/Mock。

每個後續交付另報 `UX COMPLETE`、`BACKEND COMPLETE`、`INTEGRATED`、`REMOTE VERIFIED`、`PRODUCTION READY`。本文件只是基線盤點；沒有因列出integration建議就取得production執行授權，也沒有修改四份Canonical或宣告Epic8～13完成。

## 14. 本輪新增接線與畫面（實作後增補）

本節根據新檔案與實際dispatcher更新，不覆蓋上方基線證據。新增畫面仍由同一個catch-all承接，沒有新增第二套Auth／Commerce／Entitlement／Booking domain。既有正式`src/app`檔案仍存在。

本機模式條件為 **三者同時成立**：`NODE_ENV=development`、明確旗標`THE_ONE_LOCAL_EXPERIENCE=1`、hostname為localhost／127.0.0.1／[::1]，由 [local-mode](../src/modules/platform-experience/local-mode.ts) 判定。滿足時 [proxy](../src/proxy.ts) 把正常網址rewrite至`/ux-prototype`的相同原生React分支，並跳過正式session更新；`PlatformRoutes`只轉換內部連結。這是 **local native presentation**，不是iframe，也不是已接正式DAL。**因此表內`/membership`等是受條件限制的本機入口，不是已部署的正式服務路由。** Production不啟用這個切換，既有production路由的原Auth／role／server guard仍保留；Prototype仍限development。此模式阻擋mutation、API、Auth callback／confirm及真實meeting join，不提供production fallback；明確開啟本機旗標卻使用非loopback host時拒絕服務。

| 新增本機入口（亦有`/ux-prototype`前綴版本） | 角色／用途 | Epic | 實作狀態／證據 | 仍待接線 |
|---|---|---|---|---|
| `/system-courses` | Public：單一旗艦課程目錄 | 7/8/9 | MOCK：[public-pages](../src/components/platform-experience/public-pages.tsx)，只取共用c1已發布資料 | 正式catalog／eligibility／join |
| `/teachers` | Public：本機老師探索列表 | 2 | MOCK：[PublicPage](../src/components/ux-prototype/public/index.tsx)已有空ID分支，使用同一`TeacherSection`與共用已公開老師fixture | 尚未接`listPublicTeachers`或正式publicSlug，不能視為既有正式老師探索DAL已遷移 |
| `/system-courses/guitar-roadmap`、`/system-courses/c1` | Public：旗艦六Level成果介紹 | 7/9 | MOCK：沿用`levelOutcomes`核准定義，未知slug有找不到提示 | 正式課綱／版本DTO；不是填完所有課程內容 |
| `/products` | Public：三類購買方式的契約示例列表 | 4/8 | MOCK：唯一來源`gateway.LOCAL_PRODUCTS`，明示本機契約fixture、價格未定；不冒充正式商品目錄 | 正式`listPublicProducts`尚未在新頁執行；內容發布和老師公開課包資料不由此fixture替代 |
| `/products/local-platform-membership`、`/products/local-standalone-course`、`/products/local-private-package` | Public：三類示例詳情及各自checkout入口 | 4/8 | MOCK：只接受三個已定義local slug，未知slug為Missing；不自創可出售商品 | 依序到subscription／standalone／private_package的HYBRID輸入驗證流程，沒有商品購買或backend寫入 |
| `/membership` | Public：Free／Plus／Pro平台概念 | 8 | MOCK：價格與商業細節明示待公布 | 正式plan、catalog access與訂閱lifecycle |
| `/checkout/subscription?plan=Plus`（或Pro） | Student：會員結帳預覽 | 1/4/8 | HYBRID：`gateway.validateCheckout`重用`checkoutSchema`＋`canAccessArea`；quantity1、合成商品slug、idempotency UUID | 正式授權／商品查價／訂單與支付均未執行；schema接受不代表subscription可售 |
| `/checkout/standalone?product=[id]` | Student：單品課結帳預覽 | 1/4 | HYBRID：同一既有輸入契約；只有published單品可展示，無商品清楚說明 | 無正式訂單、無內容授權；沒有把c2草稿當已上架 |
| `/checkout/private_package?teacherId=[id]&offerId=[id]` | Student：一對一課程包結帳預覽 | 1/4/5 | HYBRID：共用公開offer，核對同一老師與課包；錯配不fallback其他商品；同一checkout validation | 仍無購買／fulfillment／credits異動 |
| `/checkout/success?type=subscription\|standalone\|private_package` | Student：各產品完成後下一步 | 4/8/12 | MOCK：訂閱帶plan；單品帶product；課包帶teacherId／offerId。結果顯示「本次流程所選（Mock）」並連回該已發布課程或該老師課程包；錯配／不公開不fallback其他商品 | 明示只是完成畫面示意，不當付款證據；通用帳號／學習／私人課入口顯示原有資料，沒有本次新訂單或權益 |
| `/onboarding` | Student／訪客：五題目標／經驗／偏好／時間／興趣 | 9 | MOCK：必答、可返回、摘要與不同建議；不呼叫join／upgrade | 沒有保存真實profile、未替代formal enrollment |
| `/faq`、`/about` | Public：FAQ及平台學習原則 | 9/13 | MOCK／靜態：原生內容與可展開FAQ | 不承諾未核准服務數量或政策 |
| `/support`、`/help` | Public：學習／帳務／預約／帳號問題入口 | 13 | MOCK：問題草稿可預覽、返回；明示尚未送出 | 未建立客服案件、未寄信／LINE或通知老師 |
| `/legal`、`/legal/terms`、`/legal/privacy`、`/legal/refund` | Public：政策待定項目 | 13 | MOCK／Proposed：非生效法律條款 | 正式文本、取消／退款／retention決策 |
| `/auth/sign-in`、`/auth/sign-up`、`/auth/forgot-password`、`/auth/reset-password` | 訪客：安全本機Auth流程預覽 | 1 | HYBRID：[LocalAuthPage](../src/components/platform-experience/auth-page.tsx)重用既有signIn／signUp／email／password schema | 不建立帳戶／session、不寄信、不改密碼；本機rewrite下不是原server Action |
| `/auth/verify-email`、`/auth/access-denied` | 訪客：驗證步驟／權限提示 | 1 | MOCK流程頁：不宣稱Email已驗證 | 真實Auth結果仍沿用Epic1，待安全adapter |
| `/account` | 各角色：帳號總覽、回自己的工作區 | 1/13 | MOCK：[AccountPage](../src/components/platform-experience/account-pages.tsx)，共用actor資料 | 真實身份與server account read DTO |
| `/account/profile` | 各角色：個資格式檢查 | 1 | HYBRID：`getLocalProfile`＋`validateProfileUpdate`重用`editableProfileSchema` | 合成DTO，沒有更新正式profile；驗證成功不是儲存成功 |
| `/account/security` | 各角色：Email／密碼入口 | 1 | MOCK入口連到本機Auth validation頁 | 真Auth／session管理，仍未實際執行 |
| `/account/membership`、`/account/membership/compare` | Student：會員現況與方案比較 | 8 | MOCK：共用student.membership；真計費週期／renewal顯示未提供 | 正式subscription／access policy |
| `/account/membership/cancel` | Student：影響→原因→確認→取消狀態 | 8 | MOCK／Proposed：僅共用view-state取消預覽標記，不改會員資格 | 生效時間／退款／grace等需要Product Decision |
| `/account/membership/reactivate` | Student：恢復流程預覽 | 8 | MOCK／Proposed：清除取消預覽標記，不恢復真正subscription | 正式政策及backend |
| `/account/billing` | Student：帳務／付款方法／失敗與past-due提示 | 4/8/13 | MOCK：清楚「尚未載入」，不把未接線顯示成無購買；不使用平台總收入冒充個人帳單 | `listOwnOrders`／`getOwnOrder`／payment summaries；provider及subscription部分仍缺 |
| `/account/orders`、`/account/orders/[id]` | Student：自己的訂單入口 | 4 | MOCK／unavailable：詳情明示未接自己的訂單服務 | 必須接正式own-order DTO；既有課包不能替代order |
| `/account/notifications`、`/notifications` | Student：課次／回饋事件及已讀 | 13 | MOCK：從共用bookings／feedback衍生；已讀為view-state | 正式notification service／delivery未接 |
| `/account/preferences` | 各角色：外觀／時間／語言保留 | 9/13 | MOCK：共用偏好，不另建帳號 | 真實profile preference adapter |
| `/account/help`、`/account/help/[topic]` | 各角色：分類支援與問題说明 | 13 | MOCK入口／草稿 | 不把客服未接線冒充已送出 |
| `/account/search`、`/search` | Student：課程／老師／課節／說明搜尋 | 9/13 | MOCK：以共用公開內容與課節示例搜尋，含無結果 | 正式search backend未接，不列當前blocker |
| `/account/delete` | 各角色：刪除帳號的獨立影響入口 | 1/13 | MOCK／Proposed；不實際刪除資料，與cancel分開 | retention、法務及身份確認service |
| `/account/logout` | 各角色：離開預覽入口 | 1 | MOCK：回公開頁，明示無真實登入狀態 | 不宣稱執行正式Auth signOut |
| `/student/bookings/[bookingId]/change` | Student：改期／取消本機補口 | 5/6/12 | HYBRID：既有scheduling schemas／時區驗證＋共用Mock booking；見[booking-change](../src/components/platform-experience/booking-change.tsx) | 只接受既有`LOCAL_REFERENCE_MAP`中可對應的預約，ab1／ab2均已有合成契約token；新建示意預約無mapping時拒絕。token不代表正式資料對應；確認不改預約／堂數，最終authorization／transaction未接原RPC |
| `/student/orders[/id]`、`/student/packages`、`/student/schedule` | Student：本機舊入口銜接 | 4/5/6 | MOCK aliases：orders→Account；packages/schedule→私人課 | 本機alias不代表既有正式服務已被接入 |
| `/unavailable`、`/error`、未知top-level路徑 | 各角色：找回入口／重試說明 | 0/13 | MOCK恢復UX：[UnavailablePage](../src/components/platform-experience/auth-page.tsx)；未知路徑不再落首頁。另有`src/app/ux-prototype/not-found.tsx` | 有本機not-found介面不等於全站error／loading／offline boundary；catch-all直接render不會自動設定HTTP404 |

原公開`PublicCourse`已加平台Membership入口；`PublicTeacher`課包對話框加帶正確teacherId／offerId的結帳入口，保留查看私人課secondary。核准首頁、3:4老師圖卡、三欄播放器外觀未因新增頁而重新設計。正式Logo使用共同[BrandLogo](../src/components/brand-logo.tsx)，來源資產與處理證據由本輪完整Audit記錄。

**接線結論仍是PARTIAL：** 特定新增示意路徑可以在本機串接；這不等於全部既有URL都已映射，也不等於真實使用者旅程完整。既有輸入契約已在部分UI使用，但正式DAL／RPC尚未透過此本機表示層執行。特別是Orders不可標REAL、結帳不可標已付款、Membership取消不可標正式取消。瀏覽器桌面／手機實際結果由本輪完整Audit及驗收證據另記，本文不拿TypeScript或檔案存在當視覺／E2E通過。

## 15. 最後原始碼核對：橋接範圍與未映射入口

本節只讀取目前`src/proxy.ts`、`local-mode.ts`、`PrototypePage`及各Public／Student／Workspace／Account dispatcher、原角色layouts；本次文件修訂沒有開瀏覽器、執行服務或修改程式。上方「REAL」描述的是**既有實體路由的程式接線**，下表描述的是**開啟本機橋接後同一URL的實際表示層分支**，兩者不可混讀。

### 15.1 同一網址在不同模式的含義

| 模式 | 正常URL的處理 | `/ux-prototype`的處理 | 能否視為正式整合 |
|---|---|---|---|
| development + `THE_ONE_LOCAL_EXPERIENCE=1` + loopback | GET／HEAD由proxy rewrite到同路徑的PrototypePage；只有dispatcher支援的分支才有對應頁。非GET／HEAD、`/api/*`、正式Auth callback／confirm及Lesson join回503 | 原生PrototypeProvider＋ExperienceViewProvider；連結可呈現去前綴的正常URL | 否：只是一個local native presentation bridge；正式session、DAL／RPC沒有執行 |
| development + 旗標非`1` | 走原App Router與原Supabase session／area guards；沒有實體路由的新正常URL不因本機元件存在而成立 | development內仍可用前綴Prototype，且不初始化正式Auth | 否：本輪沒有在此模式驗證正式backend；不能為避開本機限制而偷偷回原正式服務 |
| development + 旗標`1` + 非loopback | matched request拒絕，503 | 不允許此host使用本機橋接 | 否：不是Cloudflare Preview backend方案 |
| production（即使旗標`1`） | 不進本機橋接；保留原正式route、Auth session刷新與各角色`requireAreaAccess` | proxy／layout禁止Prototype，回not-found | 否：新的Account／Membership等只存在於本機分支，不能宣稱已成正式可用頁 |

`PlatformRoutes`與`localHref`只負責Link／router的路徑轉換，不建立Auth身份、授權、Enrollment或商品。正式原`/student`、`/teacher`、`/admin` layouts仍分別呼叫`requireAreaAccess`；production未改用Mock actor。`/`與Auth layout加入正式Logo，仍不改變正式首頁是foundation、正式Auth使用原服務的事實。

### 15.2 既有URL尚未等價映射到新表示層

以下是目前程式碼可直接判定的缺口；均未因新增同名或相似介面而完成。錯誤／找不到訊息的實際HTTP狀態未在本次文件修訂測試。

| 既有正式路由／handler | 開啟本機bridge後的實際情況 | 缺口與後續 |
|---|---|---|
| `/teachers/[slug]` | `PublicTeacher`仍以`state.teachers[].id`查本機t1等ID，沒有正式`publicSlug`轉換 | 正式老師slug不能推定可用；需安全公開DTO及穩定slug映射，勿暴露私人UUID |
| `/teachers/[slug]/trial` | Public dispatcher只讀teachers與第二段ID，沒有trial分支；若第二段恰為t1，會呈現老師介紹而不是體驗課；其他slug可能找不到老師 | Epic3體驗申請未接入新版旅程，不能把這個URL回應算Trial UI完成 |
| `/student/trial` | Student dispatcher無trial case，顯示「找不到這個學生頁面」 | 原體驗課訂單／結果／join尚未映射；保留Epic3service另接 |
| `/teacher/trials` | Workspace無trials分支，顯示找不到工作台頁面（先依Mock角色入口檢查） | 老師體驗課、會議預設、完成Trial尚未整合到新版Today |
| `/teacher/packages` | Workspace無packages分支 | 新版學生詳情／我的課程並不等同既有授權學生課包查詢與延效 |
| `/admin/teachers` | Admin Workspace無teachers分支 | 新版review中的展示審核不等於正式老師帳號／專長／能力管理 |
| `/admin/trials` | Admin Workspace無trials分支 | 正式Trial付款確認、改期／取消未映射 |
| `/admin/packages` | Admin Workspace無packages分支 | 新版students示意權益不等於既有ledger調整／fulfillment retry／延效 |
| `/admin/schedule` | Admin Workspace期待`bookings`，沒有schedule alias | 新版`/admin/bookings`可操作Mock單次預約，不等於既有Admin schedule／series override入口 |
| `/admin/orders`、`/admin/orders/[id]` | Admin Workspace無orders分支 | 正式轉帳審核／現金確認／訂單取消未接到新營運殼；Finance表格不能代替Commerce |
| `/products/[slug]` | 新Public商品分支只承認三個`local-*`契約示例slug | 正式已發布商品slug未載入，未知slug顯示Missing；不是`getPublicProduct`接線 |
| `/student/orders`、`/student/orders/[id]` | 明確alias到Account Orders，但內容顯示正式訂單尚未載入，詳情不可讀取 | 是有入口的unavailable狀態，不是已完成訂單查詢／付款回報 |
| `/student/packages`、`/student/schedule` | 都alias到同一Mock私人課頁 | 沒有執行原summary／slot／recurring-series RPC，不保證保留原查詢參數及全部排課能力 |
| `GET /lesson/[id]/join` | 本機橋接明確503，不進原meeting轉址 | 真實會議參與者授權與join沒有在本機完成；不是錄播播放器的替代實作 |
| `GET /auth/callback`、`GET /auth/confirm` | 本機橋接明確503 | 本機Email驗證畫面不代表真實Email驗證或session建立 |
| `GET /api/health`、`POST /api/payments/[provider]/webhook` | `/api/*`與mutation在本機橋接阻擋503 | 舊health與支付callback不是這個本機模式的可操作功能；不能用本機UI宣稱payment callback完成 |

其他同名但非等價的頁面也必須留意：`/teacher/profile`現在可呈現Mock送審，不是呼叫Epic2的原update；`/teacher/schedule`呈現Mock課表，未取代正式availability／固定series；`/admin`呈現Mock總覽，未接真實營運資料。新介面的route guard是本機情境檢查，不是production授權證據。

### 15.3 真實旅程仍中斷的位置

| 旅程 | 已有本機介面 | 真實接線仍缺什麼 |
|---|---|---|
| 註冊→Email驗證→Onboarding→加入→Today | Auth schema驗證、驗證步驟、五題建議、課程入口、Today | 未建立真帳戶／session／Email驗證；Onboarding僅頁面state；未接正式join、access policy與owner progress |
| 會員→結帳→內容存取 | 方案概念、checkout schema驗證、依類型的完成示意與目錄連結 | 沒有權威報價、正式order／payment／subscription／fulfillment；完成URL可直接開作示意，不能作付款或資格證明 |
| 單品課→購買→直接學習 | 三類契約商品、只取published單品展示、完成後導Orders／我的課程 | 原始c2預設未發布；無商品時只有流程預覽。Orders不可讀，沒有已購產品到可存取內容的正式映射 |
| 一對一購包→堂數→預約→上課 | 正確本機teacherId／offerId連結、同師檢查、結果保留所選內容、既有fixture堂數及Mock預約 | 結帳不新增課包；fixture餘額不是新購買結果；正式booking／ledger／meeting join未接。改期／取消頁只做契約確認；ab1／ab2已有合成token，其他新建預約仍未映射 |
| 帳戶→Billing→Cancel／Reactivate | 帳務入口、未接線狀態、Proposed取消四步、恢復示意 | 無實際付款歷史、receipt／invoice／refund、period／grace／retry政策與subscription mutation；view-state只是顯示標記 |
| Today→Map→Lesson→Practice→Feedback | 核准代表課節、練習、提交／指派／回覆Mock | 不是完整已發布課綱；Epic7正式learner authority仍deny；媒體、實際practice history、正式evidence／review／assessment／certificate未接 |
| Teacher／Admin日常與營運 | 本機Today、學生、課次、回饋、草稿／發布、營運及財務示意 | 未整合上表Trial／Orders／Teacher管理等舊route；CMS發布只memory；沒有正式Creator workspace／能力、不可變audit與營運資料聚合 |
| 求助／通知／搜尋／錯誤恢復 | 原生分類入口、問題草稿、由Mock事件衍生通知、局部搜尋、Unavailable頁 | 不送出客服、不發通知；無全站正式search、offline恢復或全域server error/loading處理。未知nested尾段也未全面嚴格匹配 |

**最終判定：完整專業平台旅程仍為PARTIAL。** 本輪已有可審查的原生旅程表示層，部分使用既有純schema／時區／permission函式；尚不足以宣稱所有正式路由被整合、所有正常與異常狀態已覆蓋，或500名真實學生可據此正式營運。下一步應針對具體舊route與既有service逐一接安全adapter，而不是把本機URL、視覺完成或合成資料當作正式backend完成。
