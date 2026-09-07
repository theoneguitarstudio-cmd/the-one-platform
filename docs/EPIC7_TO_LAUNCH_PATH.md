# EPIC7_TO_LAUNCH_PATH

**PROPOSAL / 未接受 / 不實作**，2026-09-07。
依 [Canonical Roadmap](CANONICAL_ROADMAP.md)、[Product Decisions](PRODUCT_DECISIONS.md)、
[guitar-roadmap](guitar-roadmap/README.md)、[學生困難](guitar-roadmap/student-pain-points.md)、
[Membership](guitar-roadmap/membership-model.md) 整理。沒有修改 accepted roadmap 或 Epic 編號。

## 一條進度線

現在（Epic7-F本機PG接線／驗證未完）
→ Epic7 Remote Closure
→ Epic8
→ Epic9
→ Epic10
→ Epic11
→ Epic12
→ Epic13
→ Production Launch

這是 canonical 主線，不代表每一站已完成。Epic7 remote closure仍NO。
本輪工程細節見 [Remote execution ready review](EPIC7_REMOTE_EXECUTION_READY_REVIEW.md)。

## 逐段要完成什麼

| Epic | 保留的正式名稱 | 對學生／營運的成果與離站條件 |
| --- | --- | --- |
| Epic7 | Learning Map Core | 可承載多套System Course的課程地圖、內容版本和界線；先完成本機真PG工程，再經核准取得remote/recovery/security/migration證據與明確coverage結案決定 |
| Epic8 | Membership & Content Access | Free/Plus/Pro、Membership Catalog、課程納入與存取政策、訂閱/權益生命週期；購買或加入能授予正確權限，失效/撤銷確實收回，其他學生不能越權 |
| Epic9 | Learning Workspace & Practice | 學生登入後知道今天做什麼，可看課程地圖與資源、練習、記錄自己的狀態；手機可用，可回訪/忘記/重啟；觀看不等於能力通過 |
| Epic10 | Submission / Coaching / Verification | 作業證據、提交、回饋、修訂/重交、人工確認、rubric版本與可配置額度；AI不可做正式VERIFIED決定 |
| Epic11 | Assessment / Achievement / Certificate | 評量版本、attempt、評量者、通過條件、階段完成、成就與證書；付款或自己勾完成不等於取得認證 |
| Epic12 | Private Lesson / Teacher Workspace | 學生看/加入/改期私課、作業與課後紀錄；老師的排程、學生地圖、回饋與review queue；維持學生、Teacher、Admin權限邊界 |
| Epic13 | Admin / Creator / Operations / Production Launch | Admin/Creator、Draft→Review→Publish、教師能力、通知/LINE、付款營運、監控/E2E、安全加固與上線驗收；真內容、真營運與恢復可用後才launch |

沒有將 Epic10–13 刪除、改名、重編號或移到 Future。商業優先範圍若要改變發行切點，須接受新的發行提案；
不能因較早開放第一批人就宣稱所有Epic已完成。

## 最快讓第一批學生可以加入、付款並學習：建議先做有限範圍的 Plus 自學課程

建議首批發行以 The One Plus 的明確課程範圍為主，提供一段能實際學會、練習並回顧的完整路徑。
The One Guitar Roadmap 2.0 是第一套旗艦 System Course。
不把它臨時改成 Teacher 個人 Plus 或獨立 Creator 付費商品來繞過 Epic8。
首發範圍必須清楚標示；未完成的課程、人工服務、認證不能先當已交付賣點。

以下是發行範圍 **PROPOSAL**，不是重排或接受新的 roadmap：

| 首批 Launch MVP 必要 | 為什麼不能省略 |
| --- | --- |
| Epic7的安全基礎及正式結案／明確接受的coverage邊界 | 未完成的正式安全檢查不能靠「先賣」略過 |
| Epic8真Membership、課程納入、Entitlement與server/DB授權 | 付費後能進正確課程，未付費/失效的人不能看；Membership不是課程本身 |
| 至少一條誠實可交付的加入／收款／核對／啟用／撤銷流程 | 現行文件的payment webhook仍NOT COMPLETE，不能宣稱自動收款已完成；必須驗證重送、失敗、退款/撤銷如何對齊權益 |
| Epic9的登入、課程入口、今日練習、資源、自己的學習記錄與返回路徑 | 學生能持續學習，不只買到影片清單；自己的記錄與他人隔離 |
| 已審核且有權使用的真教材與一段完整學習路徑 | 測試假資料不能當課程交付；範圍、資源能否存取、內容版本、作者與使用權都要核實，目前實際備課完成度UNKNOWN |
| 與首發承諾相符的驗證方法 | Learn→Practice→Apply→Verify保留；自我練習檢核可作自學引導，不能冒充老師確認或證書；有人工承諾就必須先完成相應Epic10/11切片 |
| Epic13必要營運與上線切片 | 安全的內容發布、客服/人工核對責任、失敗/撤權處理、監控、端到端驗收、備份與整站恢復、正式hosting/環境界線；不能等賣出後再補安全 |
| 對外說明與功能一致 | 價格、可用課程範圍、開通方式及延遲、是否有人工回饋/私課/證書均清楚；商業設定未定就明列未定，不hard-code |

如要用人工核對收款加快首發，只能另提「受控營運流程」：
先查並驗證既有訂單/付款/權益流程，責任人可稽核核對與撤銷，不能直接寫progress或塞假授權。
本文件沒有選付款供應商、收費數字、付費方案或承諾現有流程已可上線。

## 哪些可提議在首批開放後逐步擴充

- Epic9：更豐富的練習安排、資源體驗與個人工作區；首批基本可學、可回訪不能延期。
- Epic10：完整教師回饋工作流、重交、可配置額度、AI預審；
  如果首發賣Pro人工成果或保證老師批改，相關能力就是首發必要，不能延期。
- Epic11：完整正式評量、Achievement/Certificate；未完成前不販售／宣稱正式認證。
- Epic12：更完整Teacher Workspace、私課與地圖連結；若首發方案包含私課，對應學生及教師必要流程要先可用。
- Epic13：更完整Creator營運、通知/LINE、自動化操作；權限、內容審核、收款權益核對、E2E、監控和恢復不能延期。
- Finance creator結算、Community等保留Canonical Future，不能無理由拉來阻擋首發；亦不自行決定收入分潤公式。

這不是將上述Epic整體標成post-launch。它只提出經owner審查的**首批有限開放範圍**，
完整canonical Production Launch仍以各Epic與必要驗收條件為準。
目前沒有可根據證據承諾的上線日期；應先解除Epic7本機驗證阻礙，再估下一段工期。

## 架構及產品界線

- Membership != System Course。
- The One 2.0 != The One Guitar Roadmap 2.0。
- Content != Product != Commerce != Payment != Entitlement != Achievement。
- 存取來源為 Membership Plan + Membership Inclusion / Access Policy + Entitlement，
  不是 Teacher/Creator身分或內容作者。
- 第一套吉他課不能讓資料模型、URL/權限或商業設定hard-code成只支援吉他；
  後續其他System Course共用架構，維持內容作者、收入歸屬與權限來源分離。
- Free＝方向、Plus＝系統、Pro＝成果與人類驗證；六個Level既定成果不改；
  要照顧卡關、忘記、重來、練習時間有限，不把觀看量當能力。
- 本文件不接受coverage缺口、不授權正式操作、不實作Epic8，也不改商業收入／quota等未定政策。

下一個工程動作仍是 Epic7-F 的本機真PG接線與受影響測試。
不是重新交接或再做一套存檔文件，也不是直接開做Epic8。
