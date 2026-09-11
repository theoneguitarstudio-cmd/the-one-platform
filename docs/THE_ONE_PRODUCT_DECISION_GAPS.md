# The One 2.0 Product Decision Gaps

**Status: PROPOSED — 產品決策待核准；本文件不新增 Accepted 規則。**

盤點日期：2026-09-11。基準為本機 `preview-test`、HEAD `0af06802dbeb2fcd614d33db3e64c441fe711be4`，包含尚未提交的原生 UX 工作。這是本轮來源閱讀與產品缺口盤點，沒有重新宣告遠端驗證、正式接線或 Epic closure。

## 1. 結論與證據邊界

**完整平台使用者旅程目前是 PARTIAL。** 已有 Epic1–6 的身份、老師、體驗課、訂單、堂數、排課正式程式碼；Epic7 有本機驗證的 Learning Map／個人活動基礎。另有已驗收的原生 Mock 學習／老師／管理員 UX。兩者尚未組成從註冊、選購、帳務、取消，到日常學習與客服的完整接線旅程。

缺頁不等於缺 domain。帳號、訂單、課包和學生自助改期／取消應先整合既有實作；Membership lifecycle、訂閱帳務、Notification delivery 等仍屬未來 Epic。業務規則未定時可以完成標示 Proposed 的影響說明／確認／結果頁，不可用 UI 寫死商業承諾。

依序讀取的 Canonical：

1. [CURRENT_WORK.md](CURRENT_WORK.md)
2. [PROJECT_STATUS.md](PROJECT_STATUS.md)
3. [CANONICAL_ROADMAP.md](CANONICAL_ROADMAP.md)
4. [PRODUCT_DECISIONS.md](PRODUCT_DECISIONS.md)

另已核對 [MASTER_PRD](MASTER_PRD.md)、[BUSINESS_RULES](BUSINESS_RULES.md)、[ROLE_PERMISSION_MATRIX](ROLE_PERMISSION_MATRIX.md)、Epic7 scope／module、現有 routes/services/schema，以及 [UX_PROTOTYPE_ACCEPTANCE](UX_PROTOTYPE_ACCEPTANCE.md)。新貼文是本輪要求的輸入，不覆蓋 Canonical 已接受的產品邊界。

來源差異須保留：

- Canonical 仍記 Epic7 A–E LOCAL CLOSED、F local tooling complete、production 未授權，且沒有自動啟動 Epic8–13 的 backend 授權。新要求可以規劃／補齊對應 UX，不能據此把未來服務寫成 CLOSED。
- `src/modules/auth/README.md` 還寫 placeholder，但同目錄已有 Server Actions、session、authorization、validation，且 Canonical 記 Epic1 CLOSED。該 README 是過時描述，不能據此重造 Auth。
- 本次檔案搜尋未找到 `THE_ONE_PRODUCT_UX_DIRECTION` 或 Cloudflare Preview 設定／流程文件；不能由貼文提到它們就宣稱本機已有安全 Preview backend。整合者應在實際找到並核對前保留環境缺口。
- 原生 Mock 驗收不代表既有正式 routes 已採用新 UX，也不代表 Mock command layer 是 Epic1–7 的 application service。

## 2. 能力盤點：已有、整合缺口與未來 Epic

下列「已有正式碼」是檔案／契約存在的證據，不表示本輪連線成功。原生 Mock 路徑皆以 `/ux-prototype` 為前綴。未列出的新 Account／Checkout 路徑須由平台 Experience Map 分配，勿直接建立第二套領域或帳號。

| 體驗範圍 | 已有 service／domain／UI | 目前 UX 缺口 | 所屬與最小安全接法 |
| --- | --- | --- | --- |
| ACCOUNT：登入、註冊、驗證、重設、登出 | Epic1 `auth/actions.ts`、`session.ts`、`server-authorization.ts`；`/auth/sign-in`、`sign-up`、`verify-email`、`forgot-password`、`reset-password`、callback／confirm、access-denied；既有登出表單 | 正式頁面存在，但不在原生 Mock 的完整購買／學習旅程中；缺共用 Account 首頁與來源頁返回 | 沿用 Epic1；目前 safe redirect 僅允許 student/teacher/admin/reset 四個目的地，購物／課程意圖續接是受控 integration 工作，不是再做 Auth |
| ACCOUNT：個資、Email、安全、刪帳、外觀、語言 | `profiles/domain.ts` 有 PrivateProfile 與可編輯欄位 schema，Email 屬 Auth；Mock settings 已有 theme/timezone | 沒有完整 profile 修改 action／route、Email 變更流程、刪帳請求、語言切換產品流程 | 個資與安全沿用 Epic1/profiles；外觀可沿用共用設定；刪帳政策見 DG-08。語言先保留入口即可，不以多語系後端為 blocker |
| MEMBERSHIP | PD-001/010/013 已定平台 Free/Plus/Pro、Catalog inclusion 與 access authority；Mock 只有方案標籤／情境資格 | 沒有 membership module、subscription service、真實方案／週期／renewal／change plan UI；保留的 entitlement enum 不等於已實作會員權限 | Epic8；先做方案與現況 DTO 的 Proposed UI，真實 access 必須來自未來 Plan + Inclusion/Access Policy + Entitlement，不由 Mock tier 判定 |
| CHECKOUT | Epic4 `commerce/actions.ts` `createCheckoutOrder`、catalog/order/payment DTO；`/products`、`/products/[slug]` 建訂單；Epic3 Trial 使用独立 checkout | 缺清楚的訂單確認、產品類型／billing model 區別、付款結果與下一步；沒有 subscription checkout 或 standalone learning fulfillment | 既有一次性訂單沿用 Epic4；lesson package fulfillment 沿用 Epic5。Membership 與數位存取等待 Epic8；付款 provider operations 屬 Epic13 |
| BILLING／ORDERS | `/student/orders`、`/student/orders/[id]`；`listOwnOrders`、`getOwnOrder`、付款安全摘要；銀行轉帳提交／管理員審核／現金確認 | 沒有整合 Billing Center、未來扣款、付款方式更新、收據／發票狀態、past due／retry subscription UI | 已有訂單／付款摘要可接 Epic4；訂閱帳務 Epic8＋Epic13；發票／退款規則未定，不將訂單頁偽裝正式收據 |
| CANCEL：訂單、預約、訂閱、刪帳 | Epic4 `cancelOwnOrder` 僅未付款訂單；Epic6 `cancelOwnBooking`、`rescheduleOwnBooking` 與 `/student/schedule` 已實作；Mock 管理員可改期／取消 | Mock 學生端只說明取消／改期，未接既有學生自助能力；沒有 subscription cancel／reactivate；沒有 account deletion | 四種操作必須分開。前二者優先沿用既有權威；訂閱 Epic8、刪帳另需政策，不以相同 `cancel` command 混用 |
| NOTIFICATION | `notifications/README.md` 是 placeholder；Auth 郵件是 Epic1 身份流程，不是平台通知中心 | 無通知收件匣、已讀／偏好／分類 UI，無一般事件 delivery／retry service | Epic13；可以 Mock 事件清單／來源頁連結／未讀視覺；不得聲稱已寄 Email/LINE，也不能從通知點擊產生付款／驗證 |
| SUPPORT／HELP | Mock 有公開 FAQ／規章及管理員受控查看／平台回覆 | 缺一般學生可找的 Help、Contact、Billing/Learning/Booking help、Report problem 與案件狀態入口；無 ticket service | 入口與幫助內容可補；工單／營運整合歸 Epic13。現有受控師生互動不是完整客服系統，不能把所有問題丟給老師 |
| SEARCH | Epic2 公開老師 projection／catalog；既有產品 catalog；Mock 學生有局部課節搜尋，Teacher/Admin 有學生查找 | 缺跨類型 Search 與公開／登入權限分流，無全站索引 service | 先做公開老師／商品／Help／可見課程的 presentation search；學習資源權限依 Epic8、Workspace Epic9；不建立新的搜尋權限 domain |
| ONBOARDING | Epic3 student profile 已有 learning_goal、preferred_mode/location、onboarding_status；Trial request 會寫入自己的流程資料。Mock 五題 diagnosis 有推薦 | 沒有首次登入 onboarding 接續；試課 onboarding complete 不能代表完成新 System Course onboarding；推薦還不是正式加入 | 沿用既有學生身份／相容欄位；診斷為未定義新 Epic 的 future interface，搭配 Epic8 access／Epic9 Workspace。建議不必 AI、不自動 enrollment；新持久欄位需另有 scope |
| 異常與未完成狀態 | AuthMessage、access-denied、產品 notFound、訂單局部 error；排課 domain error 映射；Mock 有空課程、鎖定、無堂數／時段、角色拒絕、長字／對話框等驗收 | 沒有全面一致的 loading/error/offline/maintenance/404 UX。部分正式 data functions 把 RPC error 直接回傳 `[]`，無法區分「沒有資料」和「服務失敗」 | 大多是 integration／呈現工作，可直接改善；Subscription/Review/Assessment 專用狀態使用 future DTO。error 與 empty 的區分不需要新增商業決策 |

直接來源：

- [Auth actions](../src/modules/auth/actions.ts)、[safe redirect](../src/modules/auth/safe-redirect.ts)、[Profile schema](../src/modules/profiles/domain.ts)、[角色定義](../src/modules/auth/domain.ts)。
- [Commerce actions](../src/modules/commerce/actions.ts)、[Commerce data](../src/modules/commerce/data.ts)、[Payments provider](../src/modules/payments/provider.ts)、[未配置 webhook 的 501](../src/app/api/payments/[provider]/webhook/route.ts)。
- [Entitlement data](../src/modules/entitlements/data.ts)、[Scheduling data](../src/modules/scheduling/data.ts)、[Scheduling actions](../src/modules/scheduling/actions.ts)、[Scheduling domain](../src/modules/scheduling/domain.ts)、[既有學生排課頁](../src/app/student/schedule/page.tsx)。
- [Learning Map application service](../src/modules/learning-map/data.ts)、[Epic7 scope](EPIC7_SCOPE_DEFINITION.md)、[Notification placeholder](../src/modules/notifications/README.md)。

## 3. 不應重新提請決策的已確定邊界

- Free/Plus/Pro 是平台方案；The One Guitar Roadmap 是第一套旗艦 System Course。Membership 不屬於任何老師，Creator standalone Product 不自動納入會員。
- Content、Product、Order/Payment、Entitlement、Achievement 分離。一次性／訂閱 billing model 與產品內容類型分離。
- 一對一是獨立核心服務，Free 也能買。付款不自動預約；paid Order 不直接代表已授包。
- Epic5 已確定購買快照、fulfillment activation、append-only credit ledger。不能把既有 activation 決策重新寫成未定，也不能把「首次預約才啟用」偷偷設為預設。
- Epic6 已有學生自助預約／改期／取消、Fixed priority／系列與 Makeup 路徑。老師原因取消會走已存在的補課權轉換，不應沿用舊 Mock「任何取消都只釋放一堂」當正式規則。
- 新課程的 prerequisites 是建議。個人 Self Complete 不等於 Verified／Assessment Pass／Certificate，也不由看完影片自動產生。
- 推薦、可使用、正式加入是三件事。沒有加入的課程不能顯示個人 0% 進度。
- `student/teacher/admin/super_admin` 已支援同帳號多角色；Creator 現為 attribution/capability 概念，不能新增一個前端 Auth role。Workspace 切換只選擇既有能力，不能授予能力。
- Review quota、分潤、評估報酬不可硬編。Finance/Earnings/Payout、Community、AI Personalization、Cloud Classroom、Marketplace、Other Instruments、Native App 都不能因「成熟平台通常有」變成本輪 blocker。

## 4. 需要 OWNER 的 Product Decision Gaps

**下表每一項均為 PROPOSED／尚未核准。** 「現在可做」只是 UX 建議，不是政策預設值。Canonical 已確定的部分以第3節為準；以下只問其尚未確定的延伸。任何金額、期限、數量、SLA、商業效果都不得由示意值升格成正式設定。

| ID／狀態 | 尚待決定的精確範圍 | 既有依據／所屬 | 現在可完成的 Proposed UX；實際啟用的 gate |
| --- | --- | --- | --- |
| DG-01 PROPOSED：方案與可用能力 | Plus/Pro 售價、幣別、月／年週期、是否 trial；哪些 System Course／Node／Resource 與人力能力納入各方案 | PD-001/010/013；Epic8；PRD「Plan prices/capability detail」未定 | 可畫方案比較、目前方案、Catalog、單課「方案是否包含」；沒配置就顯示待公布，不能捏價格或宣稱 Pro 可批改所有課程 |
| DG-02 PROPOSED：變更方案與續訂 | Upgrade/Downgrade 何時生效、是否按比例補差／折抵、續訂基準日、price change、paused/trial 支援範圍 | Epic8 subscription lifecycle 尚無實作 | 可做 change-plan review 與不同生效情境頁；必須等明確規則與可靠 provider／entitlement mapping，才可建立實際變更 |
| DG-03 PROPOSED：取消與恢復 | 立即取消或期末取消、是否有 grace、在何時可 reactivate、reactivate 是撤回取消還是新訂閱；取消理由是否必填 | Epic8；PRD grace/refund 未定。BUSINESS_RULES 列 expected states 不是已接受轉換時機 | 完整「管理→影響→理由→確認→狀態」可用 Proposed 情境展示；影響以未知／待核准欄位呈現，不能保證「今天取消仍可用到某日」 |
| DG-04 PROPOSED：欠費與付款重試 | past_due／failed 的寬限與降級時點、重試次數／間隔、通知節點、付款方式更新後的續接、是否保留待處理人力服務 | Epic8＋Epic13；production provider webhook 尚未 complete | 可做 failed/past_due/retry/update-method 狀態與幫助入口；不能做假扣款、前端自動把 payment 標 paid 或默認立即停權 |
| DG-05 PROPOSED：退款、帳單與憑證 | 各產品退款資格／期限／部分退款、已用堂數或服務的處理、發票／收據類型與提供方、稅務／折扣啟用方式 | Epic4 `refunds` 僅預留；paid Order 不可走未付款取消；Epic13 payment operations | 可顯示退款／憑證「未提供、處理中、待協助」情境與訂單明細；未接服務不能產生正式憑證編號或保證退款成功。此處不代做法律／稅務結論 |
| DG-06 PROPOSED：取消／到期後的服務與歷史可見性 | 保留學習／證據／回饋／證書已是既定方向；尚待確認已提交待批改是否繼續、到期後可讀哪些歷史內容、下載權、重入方案如何恢復 | PRD durable outcomes；Epic7 scope§個人歷史；Epic8／10／11 | 可做「歷史保留」與「新服務受資格限制」分區；不得刪進度。不能自行承諾未完成服務一定批完或所有付費媒體永久可讀 |
| DG-07 PROPOSED：課包例外政策 | 已預約但課包先到期如何處理、自動選包、退款對堂數／補課權的對帳；若要新增遲取消費／固定系列變更，需另行核准 | BUSINESS_RULES Epic5 明列 pending；Epic6 已有現行 authority 與 teacher-caused Makeup | 現有取消／改期按 RPC 結果展示；缺政策的邊緣案可「需平台協助」。不要新增 24/48 小時門檻、有效期或一次課價；不要把已實作 Fixed/Makeup 規則降成未知 |
| DG-08 PROPOSED：帳號變更與刪除 | 刪帳申請／確認／撤回、資料保留或去識別範圍、訂單／課包／已約課／待回饋如何處理；Email 變更與重要安全事件的驗證要求 | Epic1 身份／profiles 邊界已在；沒有 deletion workflow；營運與資料處理待核准 | 可建立 Account Security 與獨立 Delete Account 影響確認頁；「取消會員」與「刪帳」不可同按鈕，未配置不真的刪除或宣稱資料已全部清除 |
| DG-09 PROPOSED：通知承諾 | 哪些事件只站內、哪些 Email／LINE；必要服務通知與可選提醒的差別、偏好／退訂、保存期與失敗處理 | Epic13 notifications/LINE；Auth 安全郵件不可被一般通知開關誤關 | 可建立站內 Mock inbox、分類、已讀與來源連結；送達、寄送時間與完整通知歷史都不能假承諾。視覺已讀不應改變業務狀態 |
| DG-10 PROPOSED：客服承諾與可見範圍 | 正式客服入口／營業時間／回覆期待、工單負責人與升級方式、支援人員可讀哪些資料及審計條件 | Epic13 operations；既有課程／師生私密邊界不能放寬 | 可做 Help categories、問題表單與提交確認 Mock；未接 service 時明示未送出，不造真實案件編號或「24小時回覆」承諾；不強迫學生私訊老師 |
| DG-11 PROPOSED：離開／封存課程 | 是否支援個人 archive/leave、是否影響 enrollment、重新加入後的歷史與版本、是否只是隱藏 Today | Epic7 已有 joined-course 邊界，但没有 enrollment engine；Epic8/9 | 可保留「管理我的學習」說明入口；未定前不做 destructive leave。不把 UI 隱藏課程視作撤銷商業權限 |
| DG-12 PROPOSED：首次登入資料與推薦 | 哪些目標／程度／時間資料要持久保存、哪些必填、可否略過與重做、是否沿用診斷；Trial onboarding complete 如何與學習 onboarding 區分 | Epic3 既有欄位；診斷是 future interface；Epic8/9 | 可做不強迫的 Welcome→目標→現況→可練時間→建議→明確加入 UX。任何必填與持久資料用途先標 Proposed；建議起點不授予通過／跳級，不做 AI personalization |
| DG-13 PROPOSED：人力服務與評量承諾 | Review quota／reset／rollover／修訂計費、reviewer routing/SLA、verification rubric、Assessment attempt/pass／certificate share/revocation政策 | PD-006/008/009；Epic10／11，授權 Epic8 | 可展示交作業→待處理→回饋→修訂、以及評量 unavailable／failed 情境。無規則時不設定可送次數、回覆天數、通過率或自動發證 |

OWNER 只需在要啟用相應業務效果時決定該列；這些缺口不應阻止 Help、Account navigation、Search empty state、手機確認頁等低風險 UX 完成。應優先確認 DG-01～05，因為它們決定 Membership→Checkout→Billing→Cancel 能否從 Proposed 旅程升級為可營運服務。

## 5. 無須新增政策即可做的 integration／UX 缺口

1. **共用 Account 入口與工作區切換。** 學習主導航保留 Today／我的學習／練習／私人課／回饋；Orders/Billing 放 Account。身份與可切 workspace 取 Epic1 identity，Mock 視角工具只留 preview。
2. **包裝既有 DTO。** 讓學生選老師、課包、日期和時段，不要求輸入 Teacher ID／Relationship ID／ISO instant。提交仍帶既有 IDs，由 service/RPC 重新授權。
3. **保留購買意圖。** 從產品登入後回到受控的 checkout context；safe redirect 白名單／intent ID 經安全檢查擴充，不能接受任意 URL。
4. **呈現付款與履約中間狀態。** 區分訂單已建立、轉帳待審、已付款、權益處理中、權益可用。重試沿用 item/outbox idempotency；前端不立即加堂數。
5. **顯示正式的取消結果。** 未付款訂單取消、學生預約取消、老師原因補課、取消訂閱各用自己的狀態與影響說明；會員到期不取消獨立私人課權益。
6. **失敗不偽裝成空清單。** `listOwnLessonPackages`、scheduling lists、部分 public catalog 在錯誤時回 `[]`；adapter 的錯誤通道應區分 unavailable/empty。這是實際來源讀到的整合缺陷，不能只補一張錯誤圖卻讓 runtime 永遠走 empty。
7. **完整導航與入口。** 未知 Public Mock 路徑目前落回首頁；可補明確 not-found。資源、方案、付款、通知、支援各有返回上一層與可理解的下一步。
8. **保持主頁與三欄教室的核准方向。** Account/Billing 用同品牌與可讀表單，不能為補頁重新設計已鎖定 Player 版面／獨立捲動。

## 6. 最小完整旅程建議（PROPOSED UX 整合順序）

這是將現有能力串成一條可走的路，不是新 Epic 排序。頁面數量以能承載流程的共用頁／對話框為限。

| 順序 | 最小旅程／主要下一步 | 沿用正式能力 | 尚未接線時必須展示的界線 |
| --- | --- | --- | --- |
| 1 | 首頁→老師／System Course介紹→Account sign-up/in→驗證／錯誤／返回來源 | Epic1、Epic2；System Course結構 Epic7 | local/preview 沒有安全 Auth adapter 時不可真的送信、不可把 Mock actor 叫已登入；可展示清楚的預覽身份情境 |
| 2 | 課程介紹→平台Membership→方案比較→checkout確認→結果→Catalog→onboarding→明確加入→Today | Epic4 checkout 契約；Epic7 結構／activity schema | 會員／存取 Epic8 未完成，價格／週期／成功僅 Proposed 情境。未正式加入不得產生個人課程进度 |
| 3 | Today→全局Learning Map→局部三欄Lesson→Practice→自報→返回今天的下一步 | Epic7 owner activity／version contract；現有核准 UX | Epic7 shipped learner authority目前 fail closed。不能為預览把 private helper 改 true；安全 adapter 未存在時保持 Mock，Verified 永不跟著自報變動 |
| 4 | 老師介紹→Private package→訂單→待付款／待審／paid→fulfillment pending→我的堂數→選時段→確認預約→改期／取消結果 | Epic2/4/5/6 | 一次性 package 是目前最有完整既有 domain 支撑的主路徑；預覽使用其 DTO 與既有規則，不沿用一套新的 checkout/credit/booking reducer 作正式權威 |
| 5 | Account→Billing→Orders／Payment detail；Account→Membership→Cancel→影響→理由→確認→取消狀態 | 訂單摘要 Epic4；Subscription Epic8 future | 可全程操作 Proposed UX，但不自行選立即或期末、不假退款、不自動刪帳。訂閱狀態與帳號仍分開 |
| 6 | Practice→Submission→狀態→Teacher queue→Feedback→學生修訂／下一步 | Epic7穩定內容引用；現有 Mock跨角色回饋 | Epic10 workflow、Epic11正式評量尚未接線。私密筆記保持隔離；回饋不直接授予Verified或Certificate |
| 7 | 任一失敗頁→Help category→搜尋／FAQ→Report problem→提交狀態；Notification→來源頁 | 公開老師／產品／Help資料可安全投影 | Support／Notification delivery屬Epic13；未接線不發送、不聲稱收到案件或通知；錯誤頁仍提供可行的自助路徑 |

Teacher 的 Today→Student→Roadmap context→Review／Lesson Record 與 Admin 的 Course→Draft→Review→Publish→Operations 可保留已驗收 UI；下一步是按既有 Epic2/3/5/6 權限／DTO 接線。Epic13 Creator publication backend 未有，不能把 Mock publish 宣稱正式內容上架。Teacher 仍只能提案，管理員才編輯／發布正式課程。

## 7. 異常狀態最低覆蓋

| 狀態 | 正確的使用者下一步 | 依據／不得混淆 |
| --- | --- | --- |
| 未登入、驗證連結失效、帳號 suspended/disabled、權限不足 | 登入／重新取連結／帳號協助／回有權限頁 | Epic1；不要用角色切換按鈕取得正式角色 |
| Empty、Loading、服務錯誤、Offline、Maintenance、404 | 建議探索／等待／重試／返回安全入口／查看支援 | 通用UX可直接補；無資料不同於資料載入失敗；維護頁不必引進完整監控產品 |
| 無課程／無搜尋結果 | 探索課程／清除篩選／修改查詢 | 不自動加入、不建立假0%進度、不搜尋私密資料 |
| Locked Content／Expired Membership | 說明不可用原因、看目前方案、其他可用內容 | Epic8；「尚未加入」與「沒有使用資格」是不同原因 |
| Payment failed／Past Due／付款已確認但未授權益 | 查看付款狀態、可用時重試、等待履約或聯絡支援 | Epic4/5已有outbox邊界；訂閱狀態為Epic8/13；不能前端補寫paid或加點數 |
| No Credits／Expired package／No Availability／時段被搶先預約 | 選其他有效包／查看課包／換時段或老師／刷新 | Epic5/6 authority；不讓UI假設預覽時可約就一定成功 |
| Cancelled Booking／Teacher unavailable／Makeup | 讀取消影響、依補課權可用條件重約／請平台協助 | Epic6現行teacher-caused規則；不能統一當一般退款或釋放 |
| Submission pending／Review overdue／Revision required | 看狀態／查看下一步／修訂或支援 | Epic10；overdue期限未定時只標情境，不造SLA |
| Assessment failed／Certificate unavailable | 看未達標項目／練習／重新了解資格 | Epic11；失敗不刪除歷史成果，自報不換取證书 |

這些是後續實作的驗收清單，不是本文件已執行的瀏覽器測試。實際測試與截圖應另記於本輪 Experience Audit，避免挪用舊 Mock 驗收當新頁 PASS。

## 8. 實作標記與安全接線準則

- **REAL**：確實執行既有正式 service/domain，對已核准且隔離的 local／preview backend adapter 操作；標明使用哪個 adapter 與實際驗證範圍。只有 import schema 或把 fixture 命名成正式 DTO，仍不足以稱 REAL。
- **HYBRID**：明確列出哪些資料／操作經既有權威，哪些只是 future view model；不要把同頁一個 REAL 欄位推廣為整頁 backend complete。
- **MOCK / PROPOSED**：純示意資料與未核准政策狀態。沿用既有 contract 投影，不新增平行 Auth、Order、Entitlement、Credit 或 Booking domain。
- 尚未提供 safe preview adapter 的 server-only data/actions 直接建立 Supabase client；不能從 UI 直接 import 執行，或用 production credentials 讓畫面看起來真實。
- Epic7 權限 fail closed 是刻意 gate。缺 Epic8 policy 不是把測試 synthetic authority 搬入 runtime 的理由。
- Preview checkout／cancel／support 等應清楚區分「檢視示意流程」與真正提交；不能用靜默 side effect 製造付款、Email、LINE、發證或正式發布。
- `UX COMPLETE`、`BACKEND COMPLETE`、`INTEGRATED`、`REMOTE VERIFIED`、`PRODUCTION READY` 分開記錄。保留 Canonical 原狀；本文件沒有授權 SQL／migration／remote 或新增 Epic。

## 9. 本文件驗證紀錄

盤點階段已完成本機 read-only 的 route/module/source 搜尋、四份 Canonical 與相關來源核對。SQL 僅讀取現有 migration 以辨認契約，未執行 SQL、service action 或資料庫連線。價格／取消期限／SLA／退款／quota 等全數保持 Proposed，未代 OWNER 決策；Canonical、原稿／截圖與遷移檔沒有改動。

### 本輪後續 UX 補齊記錄

整合者後續另授權補上 [AccountPage](../src/components/platform-experience/account-pages.tsx) 與 [CSS module](../src/components/platform-experience/account-pages.module.css)。第2節是新增頁面前的能力基線；下列更新不會使任何政策自動 Accepted：

- 已新增 Account overview、Profile、Security、Membership／比較／取消／恢復、Billing／Orders unavailable、Notifications、Preferences、Help／問題預覽、Search／empty、Delete／Logout 說明的原生呈現。
- Profile 已使用新本機 gateway 對映自身 s1/s2/s3 合成身份並重用既有 `editableProfileSchema`；成功只代表格式驗證，receipt 明確 `persisted=false`、`transactionExecuted=false`，不能說個資已存入正式帳號。
- Theme/timezone 讀寫既有共用偏好；通知只投影自己可見的預約、回饋與平台訊息，read/unread 是 component-local 呈現。沒有新 Notification domain 或發送服務。
- 訂單未有 own-order adapter，因此顯示「尚未載入」，不宣稱無消費；沒有把平台 `cashEvents` 當個人訂單。課包權益只作明確標示的參考。
- 取消／恢復只變更本頁流程預覽標記，不改共享會員資格／付款／課程存取。Free 情境沒有付費訂閱可取消。刪帳和客服表單不會送出真實申請。
- 此新增 UI 的 TypeScript 與檔案 ESLint 已通過。桌面／手機、長字對話框、跨頁／角色與焦點的實際瀏覽器驗收由整合者接續執行；此處未宣稱視覺或 E2E PASS。

新增畫面只補齊可操作的 UX；Membership lifecycle、自己的訂單接線、Auth session、通知發送、客服案件、正式付款與資料刪除仍維持本文件揭露的 backend／政策缺口。
