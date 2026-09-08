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
