# 管理員營運與老師教學追加驗收

## 最終實測更新（取代下方早期「待補」狀態）

2026-09-11，root 使用 IAB 瀏覽本機原生 app，主要操作 viewport 390×844；老師工作台另有1440×1000。

| 流程 | 實際結果 |
| --- | --- |
| 人工贈課 | 空原因被拒；選小安、已發布4堂v1、預約制、gift、2027-01-01，填原因並預覽；雙擊確認只新增一包。原包3可用／1預留不變，新包4／0／0。學生私人課selector出現同包，堂數對話框顯示v1、總數4、可用4、預留0、上課0。 |
| 改期 | ab2原9/9 21:00，改至9/10 20:00；學生及原包disabled，需具體同意、原因、守則確認。二次確認明列預留不變；表格仍為ab2。 |
| 取消 | 空原因拒絕；具體原因及二次確認後雙擊，只取消ab2一次。原包變成可用4／預留0／上課0；新增gift包仍4／0／0；學生顯示「有堂數，尚未排課」。依核准流程採原因與確認，沒有增加新商業規則。 |
| 受控互動 | 小宇空理由被拒；填理由才展開提交與公開回饋。以「平台協助」回覆後，學生feedback收到相同文字與平台署名。切小晴立刻遮蔽且不顯示小宇回覆。 |
| 能力切換 | 小晴重新填理由開啟後改finance，頁面拒絕營運功能；切回ops仍遮蔽，沒有沿用access，main無NT$財務數字。 |
| 作業草稿 | r1寫兩欄、保存、離開再進入，文字仍在且待回覆；預覽後雙擊確認只產生一份學生可見回饋，學生首頁仍2/6自報完成。 |
| 教學紀錄草稿 | ab1寫本堂重點與課後練習、存草稿、離開到學生詳情再返回，兩欄保留；保存示意紀錄後提示不扣堂。學生詳情仍2可用／1預留／1已上課。 |
| 共用時區 | 老師設定切東京，回今日教學同一ab1顯示9/9 21:00–21:50 UTC+9；切回台北20:00–20:50。 |
| 系統外觀 | 選跟隨系統，matchMedia dark=false，workspace data-theme=light；手動黑色可恢復。OS系統偏好即時切換無可用控制介面，未宣稱驗證。 |

手機价格編輯器x14、寬362、高742.72、scrollHeight1112，保持本地垂直捲動。回饋確認框完整可見。Escape關閉並返回原操作；改期／取消巢狀對話框可操作。390px營運表格僅資料區水平捲動，document寬390。

證據檔：`admin-grant-form-mobile.png`、`admin-grant-confirm-mobile.png`、`grant-student-crossrole-mobile.png`、`admin-reschedule-confirm-mobile.png`、`admin-cancel-confirm-mobile.png`、`admin-oversight-mobile.png`、`platform-feedback-student-mobile.png`、`teacher-feedback-confirm-mobile.png`、`feedback-private-crossrole-mobile.png`、`teacher-lesson-mobile.png`、`teacher-lesson-form-mobile.png`、`teacher-lesson-desktop.png`、`teacher-student-detail-mobile.png`、`teacher-packages-desktop.png`、`teacher-packages-mobile.png`、`teacher-package-editor-mobile.png`、`teacher-proposal-mobile.png`。

瀏覽器有數次首次click僅將低處連結捲入視野，waitForURL未抵達；第二次點擊及目標heading確認後才記結果，未把前一頁作目標頁證據。Control++未改innerWidth／DPR／visualViewport，未把viewport調整冒稱瀏覽器縮放。

以下保留早期子代理瀏覽器不可用及靜態核對紀錄；實際狀態以上方root補驗結果為準。財務不受授包／預約變更的command不變量另有model tests，財務瀏覽器實測見finance-policy-qa.md。

日期：2026-09-11。本文件區分實際瀏覽器操作及靜態程式核對，不將後者當成視覺驗收。

## 本次環境狀態

學生／播放器子任務完成後，原本的獨立瀏覽器工作階段已回收。再次啟動追加驗收時，`cua.getState()` 回傳 `browsers: []`；原 browser 1、`getBrowser({url})`、建立 IAB／Chrome 分頁均回覆瀏覽器不可用。CLI `agent-browser` 亦未安裝。未安裝新套件、未繞過原稿 `file://` 安全政策。

已把人工授包→學生課包 selector 的實際操作交由仍持有瀏覽器的 public_ui 子代理協助；以下未填實際證據的項目不得宣稱瀏覽器 PASS。

## 靜態核對

| 流程 | 程式核對 | 狀態 |
| --- | --- | --- |
| 人工授包 | `GrantPackage` 要求已發布 offer 與至少三字原因；先顯示二次確認，再送 `grantPackage`。確認內容明列新增堂數、排課方式、有效期、來源與原因，並說明不建立付款／預約／報酬。 | 靜態通過，瀏覽器待補 |
| 選擇新課包 | 學生 `student/private` 有超過一包時顯示 selector，透過 `?package=` 選擇；預約與 balance 都讀該包 id。 | 靜態通過，瀏覽器待補 |
| 改期 | 修改既有預約時學生與課程包欄 disabled；時段由 `availableSlots(..., booking.id)` 排除目前本筆；要求原因、具體學生同意依據及 checkbox；確認內容明列已預留不變、不消耗。 | 靜態通過，瀏覽器待補 |
| 取消 | `CancelBooking` 目前要求原因、二次預覽，送 `cancelBooking` 並釋放預留；沒有額外獨立「學生同意」欄位。已向 root 回報，未自行新增取消商業規則。 | 原因＋確認已實作，同意欄待 root 判定 |
| 受控查看 | 先選學生、填理由並送 `openOversight`；無對應 access 時內容遮蔽。換學生先送 `closeOversight`、清理由與回覆。 | 靜態通過，瀏覽器待補 |
| 平台回覆 | 僅在本次 access 下送 `platformReply`，作者標籤使用「平台協助」，學生 feedback 只列自己 studentId 的回覆。 | 靜態通過，瀏覽器待補 |
| 能力切換隱私 | Provider `setActor` 在 actor／capability 變更時清空 oversightAccess；財務能力在 Workspace 受營運權限 gate 阻擋，不能直接展開營運內容。 | 靜態通過，瀏覽器待補 |

## 待補實際證據

- admin/students 人工授包二次確認與新包在 student/private 的相同資料。
- ab2 改期／取消前後預留、可用、消耗計數，及手機對話框。
- oversight 小宇開啟、平台回覆、換小晴重新遮蔽，ops／finance 切換後重新遮蔽。
- 老師學生詳情與教學紀錄手機畫面，不發生整頁水平溢位。

前一輪已完成的學生／播放器與完整 Pro 指派回覆證據見 [student-player-qa.md](./student-player-qa.md)。
