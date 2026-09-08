# The One Product UX Direction

Status: OWNER APPROVED visual direction — White-led Warm Tech Learning.
此輪明確授權取代 UI 僅限黃黑白的舊視覺約束；不修改 Canonical curriculum、角色權限或商業決策。

白色主體、淡紫/淡藍/杏色氛圍、深海軍藍文字、少量accent。集中tokens於 src/app/globals.css。
Gradient限hero、學習焦點、journey與section；不做霓虹、彩虹或每個按鈕漸層。
中文主視覺，英文僅eyebrow辅助；Typography/留白/色面建立階層，卡片限真正物件。
原創SVG吉他與CSS山景不使用第三方素材。品牌The One是平台，Guitar Roadmap 2.0是旗艦System Course，不是平台唯一課程。

## 本次五頁
- /：方向、System Courses、學習方式、老師陪伴、Free/Plus/Pro角色。
- /courses/guitar-roadmap：旗艦成果、適合對象、六個既有Level成果、資源/老師/會員能力。
- /student：Today learning focus、繼續學習、練習、課程、示範私人課與回饋。
- /student/map：stage journey、目前階段、node狀態與可切換成果預覽。
- /student/learn/[lessonId]：桌面三欄，手機依影片→標題→目標→資源→下一步→收合課節導覽。

共用元件在 src/components/learning；server頁面負責組合，只有選單active、stage與player暫存互動為client。
Student layout保留requireAreaAccess；無Admin/Orders主導覽。舊後台路由不刪、不重設計。
新map/player在非mock時notFound；既有Today非mock顯示未開放資訊，不呈現假學生。
learningPreview為集中合成UX資料；不是curriculum/enrollment/progress authority。
課節資源明示準備中；沒有假下載或假影片播放。練習標記不保存，重新載入清除，不代表verified。
Free/Plus/Pro只介紹角色，不新增價格、quota、access policy或Payment/Email/LINE。
保留六個既有Level成果，非附件五段示例取代Canonical。每個frozen Node必要objective/resource規則不變。

## 驗證與界線
本機Cloudflare Mock build、lint/typecheck、既有23 Cloudflare及20 Mock guard tests通過。
既有38 HTTP proof通過；五頁桌面1440與手機390無overflow、互動/locked404通過。
瀏覽器原始結果在ignored artifacts/white-learning-ui：有被阻擋的Kaspersky注入外連，非application來源；不關閉防毒或放行其請求。
本次不連Production Supabase、不SQL/write、不migration/recovery，不宣告Epic8/9 CLOSED。
workers.dev Preview為唯一部署目標，無DNS/custom domain/付費binding。OWNER視覺驗收仍待回饋。
新增4項learning route boundary測試PASS：非Mock拒絕、locked/unknown課節404；僅已知示範課節開放。瀏覽器嚴格全網路判定因防毒注入而非零exit，不將它改寫為零外連attempt。

## Visual Golden Reference v1

2026-09-08 OWNER 圖片「ChatGPT Image 2026年9月8日 下午07_34_28.png」為純視覺優先依據；圖片沒有納入 Git，也未當作資料模型或新產品決策。

| 頁面 | 與參考圖對照後採用的構圖／層次 | 保留差異 |
| --- | --- | --- |
| Homepage | 45:55 左文右圖、白色淡暖漸層、大 navy 標題、下方 icon + 短文橫列 | 無品牌人物照片，以原創吉他插畫保留圖片空間 |
| Guitar Roadmap | breadcrumb、System Course、成果標題、右側大吉他、簡短資訊列 | 6 個 canonical 成果，不採圖中 5 階或 50+ 課程數 |
| Today | 窄側欄、淡粉紫藍頂部、單一學習重點、小課節圖、下方四項輕量資訊 | 合成 Stage 1 / 38%，不是圖片 Stage 2 / 60% |
| Map | 六階垂直路徑、暖色目前階段、淡灰未來、淡藍山形、右側白色詳細內容 | CSS 抽象山景；沒有假造已完成階段 |
| Player | 20:52:28、左側無逐課卡片、淡藍 selected、右側目標/資源/練習、清楚 prev/next | 無正式影片，明示播放器位置；無假下載 |

已逐頁檢視桌面／手機截圖的 composition、spacing、background、gradient、typography、card density、hierarchy、balance。
視覺上 Today / Map / Player 的資訊結構最接近；首頁及 Landing 仍需要 OWNER 正式品牌攝影才能接近照片質感。
手機保留垂直地圖；Player 影片→課名→目標→資源→下一課，課節目錄可收合。底部學生導覽指向原有 routes。
本次依 React review 檢查：無新增 fetch/effect/storage，只有原有 client 暫存狀態；server requireAreaAccess 與 non-Mock route guard 保留。
47 單元測試、lint/typecheck、Cloudflare Mock build、38 HTTP proof 通過。五頁 1440/390 無 overflow，9 項既有互動通過。
嚴格瀏覽器命令 exit 1 原因為防毒注入外連；UI failures=[]、page errors=[]，不把原始 network WARN 改寫成 PASS。
[可攜本機瀏覽器證據](evidence/cloudflare/golden-reference-local.json)。原始截圖在 ignored artifacts/white-learning-ui，未上傳私人檔案或任何 secrets。
