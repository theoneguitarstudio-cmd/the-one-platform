# Epic7 備份位置與寫入來源 — 2026-09-08 本機唯讀盤點

起點 main / bc4f882b036794f038bc3f4e504d2fa119a06b9e，CLEAN。資料時間約00:32 Asia/Taipei。
本輪 production connections=0；只讀目前家用 checkout、Windows 非秘密 metadata 及既有證據，未讀環境秘密或 dump。

## 儲存與能力

登錄 EditionID=Core、DisplayVersion=24H2、build=26100；ProductName 仍是 Windows 10 Home 字串，不能單憑舊字串判定實際 Windows 10。
Home edition 已有登錄證據。Win32_OperatingSystem、Win32_EncryptableVolume CIM 存取被拒絕；上輪 Get-BitLockerVolume/manage-bde 亦拒絕。
沒有要求管理員/UAC。替代登錄查證 UEFISecureBootEnabled=0，未取得可證明 C/D 加密的 BitLocker 狀態值。
SecureBoot 不等於磁碟加密；Device Encryption capability、C/D encryption/conversion/protection 仍 UNKNOWN，不是已證明未加密。
.NET DriveInfo 交叉取得 C total=255158738944/free=52038504448 bytes，D total=2000381014016/free=1510242758656 bytes。
容量可作候選，仍需下一次 export/restore 真正規模核對。
C:/TheOneBackups owner=DESKTOP-AFP7QM6\win，但 Users 可讀、Authenticated Users 可修改；D:/ owner=SYSTEM，亦有廣泛 Users/Authenticated Users 權限。
不能直接繼承這些 ACL 建目錄就宣告合格。C:/Users/win 本輪 ACL 讀取受限；上輪較窄 ACL 不自動變核准。
目錄 owner 不等於 The One 保管權；未取得 Docker VHD 可核定位置，先前 settings metadata 亦未證明其位置。
dump、Docker data layer、TEMP/log/swap 的落地保護仍需證明。未改加密、ACL、Docker或搬動舊備份。

**已證明 The One 控制且加密的合格位置：沒有；不是已證明 C/D 都不合格。**
OWNER 只需一次 UI 查閱：Windows「設定 → 隱私權與安全性 → 裝置加密」，看「裝置加密」為開啟、關閉或頁面不存在。
只回報文字，不點金鑰、不改設定、不跑 PowerShell。此頁不能單獨證明 D 的逐磁碟保護、路徑 ACL 或 Docker 落地。

條件式最小目錄：已驗證加密且 OWNER 核定控制的 root / TheOneBackups / epic7-UTC-run-id。本輪未建立。
custodian 提案 OWNER 本人；存取限其指定 operator 與必要 SYSTEM/Admin，須記具名批准與有效 ACL；不放 repo/同步分享位置。
manifest.json 與 SHA256SUMS.txt 放同一受限 run 目錄，manifest 指紋列入 SHA256SUMS，清單不自我 hash。
提案 backup 保留7天、drill data/log最多24h，處置另批准明列路徑/container，不自動清理。
若 C/D 最終不合格：另輪批准現有磁碟加密及受限目錄（免新增服務，但影響裝置並須保管金鑰）；
或 OWNER 已持有的已驗證加密外接磁碟（可離線保管，但易遺失且不解決 Docker 系統磁碟落地）。
沒有可用外接媒體證據；不購買、不實施。

## 寫入入口

A=已確認目前正式使用；B=程式存在但無目前正式使用證據；C=已證明指定工具/路徑不連正式；D=UNKNOWN。
A 本輪沒有可證明目前持續寫入的來源。歷史 P2 deployment/Epic5/6 smoke 是已完成寫入，不是常駐 writer。

| 入口 | 分類 | 本機依據與寫入 |
| --- | --- | --- |
| Auth actions/callback/confirm | B | [actions](../src/modules/auth/actions.ts)、[callback](../src/app/auth/callback/route.ts)、[confirm](../src/app/auth/confirm/route.ts)：註冊、登入/登出、重設/更新密碼、OTP/token；Auth/session 可能變更 |
| Session middleware | B | [proxy](../src/lib/supabase/proxy.ts) SSR/getClaims/session refresh；GET 不一定沒有 Auth 寫入 |
| Teacher/admin | B | [admin-actions](../src/modules/teachers/admin-actions.ts) user_roles、teacher_profiles、teacher_stage_capabilities upsert，teacher_specialties delete/insert；[actions](../src/modules/teachers/actions.ts) update_own_teacher_profile |
| Trial | B | [actions](../src/modules/trials/actions.ts)：request_trial_checkout、update_own_teacher_meeting_defaults、complete_trial_lesson、confirm_trial_payment、admin_reschedule_trial_lesson、admin_cancel_trial_lesson |
| Commerce/payment admin | B | [actions](../src/modules/commerce/actions.ts)：create_checkout_order、submit_bank_transfer、cancel_own_order、admin_confirm_payment、admin_reject_payment_submission、admin_confirm_cash_payment、admin_cancel_order |
| Entitlement/retry | B | [actions](../src/modules/entitlements/actions.ts)：extend_lesson_package_entitlement、admin_adjust_lesson_credits、admin_retry_order_fulfillment_event |
| Scheduling | B | [actions](../src/modules/scheduling/actions.ts)：create/cancel/reschedule/complete booking、teacher settings/availability、recurring series status/exceptions/materialize、makeup booking |
| Epic7 foundation | B | [data](../src/modules/learning-map/data.ts) learning_set_activity，無公開 workspace/route；上輪已證明正式 Epic7 functions 未部署，非當前可用正式入口 |
| Provider webhook | C，僅此程式處理路徑 | [provider](../src/modules/payments/provider.ts) 永遠 null；[route](../src/app/api/payments/%5Bprovider%5D/webhook/route.ts) 回501，無DB寫入。不涵蓋未知部署版本/其他外部webhook |
| Health / lesson join | C，health；B，join環境連線 | [health](../src/app/api/health/route.ts) 無DB；[join](../src/app/lesson/%5Bid%5D/join/route.ts) SELECT/redirect，無業務寫入，仍須考慮Auth session |
| DB triggers/exposed RPC | B | supabase/migrations：Auth建立profile、public projection、updated_at、產品catalog、fulfillment/audit等連帶寫入。舊29已部署；trigger非獨立排程，直接REST/RPC可能繞過網頁 |
| Remote smoke / migration / 手動SQL | B | scripts/remote-smoke-test-epic3/4.mjs 使用環境client；epic5/6.mjs有linked/ref正式分支；CLI/migration可寫schema/history。歷史完成不代表目前在執行 |
| 本機隔離 Epic7 PG 工具 | C，限attested target | [pg-local](../tools/epic7-local-engineering/pg-local.mjs)、[實測](EPIC7_LOCAL_PG_EXECUTION_EVIDENCE.md)：新synthetic、network none、Unix socket、identity/schema guards。不推廣為所有scripts皆安全 |
| 舊concurrency scripts | B，現行執行未知 | scripts/validate-*-concurrency.ps1以Docker exec操作指定本機container；未本輪attest既有target，不能憑local名稱保證資料來源 |
| Cron/background/Edge | D，正式 | repo無.github/workflows、vercel.json、supabase/functions；migration未見cron.schedule/pg_cron/pg_net/http_post；package僅dev/build/start/lint/typecheck/test。SYSTEM_ARCHITECTURE記Epic5無queue/cron，不排除Dashboard/外部jobs |
| Production/preview/home dev app | D，部署/運行；B，程式 | client由環境URL/key決定target，未讀值；不同環境可能共用正式target，無本次runtime/流量對應證據 |
| 外部整合/Dashboard/other clients | D | 其他服務帳戶、SQL editor、Auth/Storage/Edge jobs/webhooks、外部scheduler未觀測 |

本次已盤點可見checkout的client/RPC、現有routes/actions、package、migration trigger/cron字樣、工具與hosting；不是全帳戶/全網路發現。
**沒有證據證明真學生或 The One 2.0 app 正在持續寫入，答案 UNKNOWN。**
[上輪快照](EPIC7_PRODUCTION_READONLY_PREFLIGHT.md) users/orders等=0、Stage=5只是當時計數，沒有active connections/排程/連續活動證據。

## Hosting 與一致性

本 checkout .vercel/project.json、vercel.json、.github/workflows 不存在；next.config.ts空設定，tracked Vercel名稱僅public/vercel.svg。
[既有證據](EPIC7_REMOTE_READINESS_EVIDENCE.md)：Vercel App安裝及All repositories已證明；可見連線只有together-stories。
The One account/team/project、repo/release、production branch、preview target、build/autodeploy/traffic仍UNKNOWN；沒找到不等於不存在。
不再查同一GitHub授權頁，未操作GitHub/Vercel。

停寫必要性 **UNKNOWN**。原15分鐘估計撤回；先找實際入口、控制/恢復方法、export規模，再定上限及取消門檻。
A：若證明全窗口無writer、無在途交易、無排程/手動schema/role/Auth變更且能維持，可不額外停網站，直接採受控靜止窗口。
一瞬間零writer、前後counts相同均不足；三次dump不是共享snapshot。
B：有writer時控制實際使用的Auth/session、上述actions、admin/RPC/direct clients、preview/dev、job/webhook/worker及operator DDL，排空在途後匯出與取同窗口metadata/digests，核對後按批准程序恢復。只停首頁不足。
C：先核准[最小活動查證](PRODUCTION_WRITE_ACTIVITY_READONLY_REQUEST.md)，另需hosting/runtime target與具名入口控制證據；DB統計不能獨自辨識每個網站。
本輪不停止網站、revoke、改RLS/API/app/DB。

1h **CONDITIONAL，目前未通過**：加密/ACL/Docker落地與全窗口writer控制未證明。
條件補齊：identity → 靜止Tquiet → dump及metadata → manifest/hashes → 結束窗口 → 隔離restore/verify → BR evidence → STOP。
未來另核准migration須再驗「開始UTC - 一致T <= 3600秒」；等待/drill超時需另核准新backup，不能用mtime替代。
單次backup不保證持續1h事故保障。BR-1/3 UNKNOWN、BR-2未通過；DB-only不等於全事故恢復。
[整套申請](EPIC7_BACKUP_RECOVERY_EXECUTION_REQUEST.md)可無缺件一次批准執行=NO，仍PENDING OWNER APPROVAL。
Epic5/6 REMOTE CLOSED；payment webhook NOT COMPLETE；Epic7 REMOTE CLOSED=NO；無Epic8。
