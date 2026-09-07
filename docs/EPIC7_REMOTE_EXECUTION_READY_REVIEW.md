# EPIC7_REMOTE_EXECUTION_READY_REVIEW

狀態：**BLOCKER / NOT READY**。2026-09-07，本輪起點為 `6f54f9727fe76e7ae701537573372072c0e72c33`。
實際專案：`C:/Projects/the-one-platform-handoff-0af0680`；起點 working tree CLEAN。
先前回報的 49b7d23 是較早版本，不倒退、不重新交接。
application / migration candidate 仍為 d5f98434106797afc65c59953aa3bc61ba26ecb4；preserved c61 證據沿用。
本文件不是核准、不是執行證據，也不把本機 handoff 分支視為 GitHub 最新狀態。

## 結論與本輪完成範圍

**尚不能進入 Epic7 Remote Preflight 的實際執行。可以審閱 preflight 所需資料清單。**
仍有真實 PostgreSQL 接線與驗證工作，不能說成「只缺操作者簽名」。
本輪新增三檔離線工程工具，28 項針對性測試 PASS、ESLint PASS。正式 connections / SQL / writes = 0。
未啟動 Docker、未下載 image、未執行任何 SQL、未 push / deployment / backup / restore / cleanup / Epic8。
原 73 safety tests、70 離線 controller tests、preserved ValidateOnly、完整 SQL/build 未重跑。

- `observer-program.mjs`：編譯獨立讀取計畫及嚴格結果解碼，不包含開連線 API。
  public/auth 表清單、28 表本次資料、全部表摘要、不屬於本次的資料摘要、sequence 狀態、結構/權限摘要。
  遇到未覆蓋 private 資料表、foreign table、materialized view、非法名稱、清單漂移、缺結果即 STOP，
  不默默排除。固定單次唯讀 repeatable-read 計畫、10 秒 statement / 2 秒 lock 上限，
  以另一連線的 pid、固定合成本機 DB 名稱與 run marker 作離線解碼約束。
- 完整結果必須提供 count 字串與 SHA-256；缺欄位、多欄位、錯 target/run、與 writer 相同 pid、
  不唯讀、弱隔離、sequence 不可讀／越界、原始資料欄位或 raw error 均拒絕。
  不輸出 row body、函式內容、角色細節或秘密，只保留合成鍵與摘要。
- `budget-review.mjs`：逐案檢查28表的鍵、checkpoint順序、最終數量、各表峰值、既有 ceiling、
  rollback 後數量及隔離保留提案。L01–L04 一律 UNKNOWN/null，不能將空鍵誤報零影響。
  readiness 由實际未執行狀態產生，caller approval / SHA / 文件標記不能升成 READY。
- `readiness.test.mjs`：測試上述新增契約與拒絕分支。初跑抓到 count 被 JavaScript
  自動轉字串接受的漏洞，已要求實際 string 並補上序號上界、inventory drift 測試。
  最終 28 PASS / 0 FAIL；沒有降低原安全規則。

**限制：這些測試使用合成輸入，不會執行 observer SQL。**
解碼的 pid、run marker 和 hash 仍是未受信任的觀察輸入，不是正式 target attestation。
catalog 摘要包含內部 metadata，隔離環境若有背景 maintenance 也可能造成 FAIL；
不能為消除此 FAIL 自動忽略差異。新 collector 的可見性、欄位型別與 SQL 相容性必須用真 PG 驗證。
目前範圍不是任意其他 schema 或整站備份證明。

## 1. 還缺的工程工作（Codex 負責，不交給 owner 除錯）

| 項目 | 已有 | 尚需工程完成／可接受證據 |
| --- | --- | --- |
| 目標及版本 | 原 preserved validation、受保護內容hash、34 migration source hashes；封閉本機模型 | 將受信任內容證據接至真正 transport；精確 Supabase name/ref/region/candidate/application/tool/migration attestation，禁止信任 caller SHA；漂移STOP |
| Serial 25案 | S/H/C/G/V/P01–03 參數化逐案 SQL 計畫與鍵數量；已測 controller | 真PG parameter/result/SQLSTATE 映射、每案完整 AC 核對及 trigger 實際副作用；計畫不代表AC全部通過 |
| R01–R03 | 兩 session 鎖定順序、winner/retry/loser 預算、獨立保留核對邏輯 | 實作／驗證真雙連線 driver、held-lock barrier、server cancel、未知 commit 結果 STOP與獨立讀取；不能用串行替代 |
| L01–L04 | 固定舊 suite 與 include hashes | 抽出本次專用 fixture/作用範圍、精確預算、接線及實際 trigger 核算；不直接把完整歷史 suite 當本次37案已跑 |
| P04–P06 / R04 | authority shipped false，拒絕與本機成功證據分開，沒有正向替代SQL | 真 authority 上線後另補成功／併發／隔離分支；本輪不實作 Epic8。coverage/有限結案提案仍未 accepted |
| 連線／transaction | 封閉替身已驗 timeout、late-connect close、cancel / rollback / close 失敗 STOP | 真 socket/psql 生命周期、server deadline、transaction state、斷線與未知 commit 結果處理，禁止自動 repair |
| Sentinel / residue | before/inside/after 契約、獨立 exact-key/count 核對、本輪完整讀取程式 | 真 PG 寫入與 rollback 證明、另一 reader 實際查得結果；開始前碰撞、殘留、外部表或編號變化均FAIL |
| Evidence | 既有exclusive artifact、plan/result/observer/hashes，本輪預算／讀取程式／工具hash | 真 driver 產生且綁定 exact target/candidate/case/run/manifest/time/result/STOP 的證據；失敗與中斷不能落成PASS |

37 ID 目前分類：25 個 serial 計畫、3 個 race schedule、4 個 authority blocked、
4 個 legacy source bundle、1 個 observer-only L05。**37 個正式案例全部 REMOTE NOT RUN。**
工程必須先在核准的純合成本機 PG 完成上述接線及受影響案例測試，修正程式，再更新本審查。
不能以多寫 mock 或文件替代真正 PostgreSQL 行為。尚未完成的工程項目不得標成 operator-only。

## 精確預算的讀法

本輪 artifact 的 `readiness.json` 保存37案逐表鍵、最終數量、各表峰值與上限。
峰值合計是各表最大值之和，**不保證同一瞬間同時達峰**；不是資料庫量測。
8 個合成身份 trigger 產生8 profiles與8 student roles；額外4角色使 user_roles 峰值12，最終8。
例如 H05 最終79列／各表峰值合計83；V02為114／118；
R01隔離保留提案82列，R02/R03各81列。這是每案獨立run，不是共同fixture去重後總量。
R01/R02/R03 的82/81/81包含身份、內容、receipts、audit，不只是課程數。
rollback案預期0殘留；正式 committed 預設0。L01–L04仍 UNKNOWN。
P04–P06/R04的0表示不建立fixture、不執行被擋正向案例，不能填成功證據。

## 2. 還缺的外部唯讀資訊（本輪未查）

- Supabase exact project/ref/region、實際 deployed candidate、migration history/catalog/authority。
  source34份與歷史remote29份不是今天的實際部署清單。
- 可實際還原的最新一致時間點、備份／PITR能力，以及是否能證明資料損失不超過已接受1小時。
- The One自控加密空間的實際位置、存取者、保管者、保留時間及可還原證據。任職公司空間不是預設。
- Auth、Storage、application、domains/traffic、environment/secrets、connection strings、
  extensions、migration history、重新開放寫入順序；Realtime/Edge Functions 是否使用仍 UNKNOWN。
  DB logical restore drill 不等於整站事故恢復。不得讀取對話中的秘密或正式學生資料。
- Vercel 的 The One account/team、project、repo link、production branch、main push 是否部署、
  Root Directory / build / install / output 設定。
  GitHub App All repositories 已有證據，不再重查。
  若現有連線看不到 The One，未來才由 owner 一次查看 project 的 Git 與 Build and Deployment 設定畫面；
  不 push 試探，不建立 project，不把 together-stories 當 The One。

## 3. 真正需要逐次批准的正式操作

已接受 D1–D5 原則不重問，但不是任何一次執行批准。
正式唯讀 preflight 也需要本輪以後明確授權 exact target / scope / 時間與非秘密 evidence。
backup export、真實資料 restore、migration、deployment、remote smoke 分別提出可審閱操作單；
cleanup 不自動發生，committed / immutable fixture 預設僅核准隔離環境。
任一錯誤、未知結果、hash/row差異、timeout、rollback失敗都 STOP，不修補資料湊PASS。
coverage 缺口是否接受為有限結案，仍須明確決定，不能從fixture隔離原則推導。

## 4. 現在的真正停止點

本機 Docker 的 docker_engine 與 dockerDesktopLinuxEngine pipe 均不可用。
本輪嘗試「隱藏啟動既有 Docker Desktop」在執行前被**自動核准審查拒絕**：
先前使用者明確禁止啟動 Docker 演練，本次本機工程要求不足以撤銷該限制，且啟動可能帶起服務或網路活動。
未啟動、未改用其他 runtime 繞過、未安裝、未抓 image。
這阻止真 PG 接線及行為驗證；不是缺正式帳密，也不是正式 preflight 已到位。
需要的例外授權限於啟動本機引擎及使用已存在映像的合成隔離環境；
沒有既有核對通過映像就另報缺環境，不改用 latest、不下載繞過。
取得此範圍前保持阻擋；取得後工程繼續做表列項目，不要求 owner 逐條除錯。
本輪不申請正式 DB / migration / deployment / smoke 授權。

## 證據

`artifacts/remote-smoke/epic7-local-engineering/review-71762026-e4b5-4227-88b5-a94fd20632f9/`

- readiness.json：37案預算與未完成工程；observer-program.json / observer-plan.json：合成讀取計畫綁定。
- test.log / eslint.log / verification.json：28 項新測試、Node24.19.0、ESLint exit0。
- tool-hashes.json / hashes.json：本輪工具與artifact內容hash，非批准簽章。
- 本輪只測新增三檔；原 application、migration、package、lockfile、workspace、accepted roadmap/policy 不變。
