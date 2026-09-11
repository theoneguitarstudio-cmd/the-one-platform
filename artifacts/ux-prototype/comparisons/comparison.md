# 原稿與原生截圖對照

生成時間：2026-09-11T10:40:38.785Z。工具：sharp 0.35.4。來源：`C:/Users/win/Downloads/the-one-complete-frontend-v1-6/the-one-codex-handoff-v1-6`。

## 計算方式

- 原稿的 SHA-256 逐張對照 SCENE_MANIFEST.json；原稿與原生輸入在處理前後再次雜湊，未修改任何輸入。
- 並排圖保留兩張完整原始畫面，左原稿、右原生。另提供對齊圖：只依 manifest 的 #app.y 移除來源展示列。公開頁0px，學生桌面36px／手機34px，播放器與老師／管理員38px。沒有為了降低差異而微調對齊。
- 對齊圖與差異圖使用共同可見範圍，不縮放。原生比來源多出的底部展示空間不參與逐像素比較；完整並排圖仍保留。
- 差異圖每通道為 abs(source-native)，未增亮、未設容差、未遮罩文字、工具或捲軸。黑色代表完全相同；亮色代表不同。
- 差異像素比例只要RGB任一通道不同就計入；平均差值範圍0–255。這些數值不是驗收分數，不設閾值宣稱PASS。

## 已知差異與判讀限制

- 尺寸：表中原生尺寸與格式取自輸入影像檔頭，不假定等於CSS viewport或副檔名。尺寸不同時只比較共同可見區，整張輸入仍保留在完整並排圖，沒有縮放。
- 編碼：部分瀏覽器截圖回傳JPEG位元組，即使檔名為.png仍依實際格式解碼；JPEG壓縮差異也包含在數值中，不轉換輸入或扣除差異。
- 權益狀態：來源播放器顯示Plus鎖定提示；player-desktop使用目前Pro情境原生圖，player-desktop-free另對照Free鎖定情境。權益標籤差異不是CSS位移；所有差異仍納入。
- 字型：來源截圖與目前Windows瀏覽器環境的中文字型、字重及反鋸齒可能不同。文字邊緣差異可能擴大逐像素比例，應同時看完整並排圖；此工具不消除字型差異。
- 捲軸：原生桌面瀏覽器的可見捲軸佔用部分可用寬度，例如390px手機工作台表格容器342px，而來源卡片容器常為352px。捲軸、底部Mock工具與開發環境UI都保留在差異圖。
- Mock資料：共用時鐘採2026-09-08，讓9/9課次保持未來；來源學生首頁截圖顯示9/12，與整合Demo老師課次不同。額度、姓名、狀態與共用流程字句可能與獨立原稿不同，差異未被遮除。
- 老師圖卡截圖是捲動到區段的場景；兩次截圖的捲動位置不一定完全相同。manifest保留來源卡片座標，完整頁差異會反映捲動位置；不能將此差異比例直接解讀成卡片尺寸不符。
- 播放器高度由viewport與獨立捲動區域共同決定，去除來源展示列仍會留下底部定位元素差異；這不代替實際三欄與獨立捲動操作驗證。
- 所有golden檔與核准HTML/CSS保持原狀；這些只是不具通過判定的派生驗收產物。

## 場景結果

| 場景 | 原稿／原生尺寸 | 原稿展示列px | 逐像素範圍 | 不同像素 | 平均RGB差 | 產物 |
|---|---|---:|---|---:|---:|---|
| home-desktop | 1440×1000 / 1425×1000 (jpeg) | 0 | 1425×1000 | 27.23% | 4.070 | [並排](home-desktop-side-by-side.png) · [去展示列](home-desktop-aligned.png) · [差異](home-desktop-diff.png) |
| home-mobile | 390×844 / 375×844 (jpeg) | 0 | 375×844 | 61.35% | 8.472 | [並排](home-mobile-side-by-side.png) · [去展示列](home-mobile-aligned.png) · [差異](home-mobile-diff.png) |
| teacher-cards-desktop | 1440×1000 / 1425×1000 (jpeg) | 0 | 1425×1000 | 26.19% | 5.220 | [並排](teacher-cards-desktop-side-by-side.png) · [去展示列](teacher-cards-desktop-aligned.png) · [差異](teacher-cards-desktop-diff.png) |
| teacher-cards-mobile | 390×844 / 375×844 (jpeg) | 0 | 375×844 | 79.26% | 35.079 | [並排](teacher-cards-mobile-side-by-side.png) · [去展示列](teacher-cards-mobile-aligned.png) · [差異](teacher-cards-mobile-diff.png) |
| student-today-desktop | 1440×1000 / 1440×1000 (jpeg) | 36 | 1440×964 | 43.15% | 6.105 | [並排](student-today-desktop-side-by-side.png) · [去展示列](student-today-desktop-aligned.png) · [差異](student-today-desktop-diff.png) |
| student-today-mobile | 390×844 / 390×844 (jpeg) | 34 | 390×810 | 46.31% | 8.952 | [並排](student-today-mobile-side-by-side.png) · [去展示列](student-today-mobile-aligned.png) · [差異](student-today-mobile-diff.png) |
| player-desktop | 1440×1000 / 1440×1000 (jpeg) | 38 | 1440×962 | 49.17% | 6.469 | [並排](player-desktop-side-by-side.png) · [去展示列](player-desktop-aligned.png) · [差異](player-desktop-diff.png) |
| player-desktop-free | 1440×1000 / 1440×1000 (jpeg) | 38 | 1440×962 | 50.16% | 6.571 | [並排](player-desktop-free-side-by-side.png) · [去展示列](player-desktop-free-aligned.png) · [差異](player-desktop-free-diff.png) |
| player-mobile | 390×844 / 390×844 (jpeg) | 38 | 390×806 | 67.30% | 14.697 | [並排](player-mobile-side-by-side.png) · [去展示列](player-mobile-aligned.png) · [差異](player-mobile-diff.png) |
| teacher-reviews-desktop | 1440×1000 / 1440×1000 (jpeg) | 38 | 1440×962 | 21.66% | 3.015 | [並排](teacher-reviews-desktop-side-by-side.png) · [去展示列](teacher-reviews-desktop-aligned.png) · [差異](teacher-reviews-desktop-diff.png) |
| teacher-reviews-mobile | 390×844 / 390×844 (jpeg) | 38 | 390×806 | 54.52% | 6.397 | [並排](teacher-reviews-mobile-side-by-side.png) · [去展示列](teacher-reviews-mobile-aligned.png) · [差異](teacher-reviews-mobile-diff.png) |
| finance-desktop | 1440×1000 / 1440×1000 (jpeg) | 38 | 1440×962 | 44.74% | 6.164 | [並排](finance-desktop-side-by-side.png) · [去展示列](finance-desktop-aligned.png) · [差異](finance-desktop-diff.png) |
| finance-mobile | 390×844 / 390×844 (jpeg) | 38 | 390×806 | 37.32% | 14.765 | [並排](finance-mobile-side-by-side.png) · [去展示列](finance-mobile-aligned.png) · [差異](finance-mobile-diff.png) |

所有配置的場景均有截圖。

詳細矩形、hash、RMSE與來源geometry保存在[comparison.json](comparison.json)。

公開頁最後一次實際DOM測量另見 [public-final-geometry.json](../public-final-geometry.json)，也原樣附在 comparison.json 的 nativePublicGeometry。此資料不拿來移動、縮放或遮罩像素差異圖。

根工作公開場景的要求viewport、實際client寬、scrollY及卡片DOM矩形見 [root-public-geometry.json](../root-public-geometry.json)，也原樣附在 rootPublicGeometry。DOM可能在同場景不同時點量測，與截圖像素分別保留，不假設最後捲動位置完全一致。公開截圖工具回傳內容clip寬1425／375，而要求viewport為1440／390；圖像不補畫捲軸、不擴展或縮放成要求尺寸。

主要場景的實際目視判讀另見 [visual-review.md](visual-review.md)，不以像素差異數值取代人工檢查。
