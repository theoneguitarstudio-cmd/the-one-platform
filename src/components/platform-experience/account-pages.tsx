"use client";

import { useEffect, useId, useRef, useState, useSyncExternalStore, type ReactNode } from "react";
import Link from "@/components/platform-experience/link";
import { BrandLogo } from "@/components/brand-logo";
import { usePrototype } from "@/modules/ux-prototype/store";
import { useExperienceViewState } from "@/modules/platform-experience/view-state";
import { balance, publicTeachers, type Student, type Theme } from "@/modules/ux-prototype/model";
import { getLocalIdentity, getLocalProfile, validateProfileUpdate, type LocalIdentity } from "@/modules/platform-experience/gateway";
import { Icon } from "@/components/ux-prototype/workspace/shared";
import { lessonVisuals } from "@/components/ux-prototype/student/reference";
import styles from "./account-pages.module.css";

const base = "/ux-prototype";
const account = `${base}/account`;
const accountNav = [
  ["", "home", "帳號總覽"], ["profile", "people", "個人資料"], ["security", "shield", "登入與安全"],
  ["membership", "book", "我的會員方案"], ["billing", "wallet", "帳務與付款"], ["orders", "file", "我的訂單"],
  ["notifications", "chat", "通知中心"], ["preferences", "settings", "使用偏好"], ["help", "chat", "幫助與支援"],
  ["search", "search", "搜尋"], ["logout", "arrow", "離開預覽帳號"],
] as const;
const headings: Record<string, [string, string]> = {
  "": ["你的帳號，一目了然。", "學習留在今天，帳號、方案與需要協助的事情放在這裡。"],
  profile: ["個人資料", "用你熟悉的稱呼，開始每一次學習。"], security: ["登入與安全", "管理登入方式，安心回到自己的學習空間。"],
  membership: ["我的會員方案", "了解你的平台方案，以及接下來可選擇的學習方式。"],
  billing: ["帳務與付款", "付款、訂單與方案狀態，清楚分開看。"], orders: ["我的訂單", "每次購買的內容與付款進度，都有可以回來查看的地方。"],
  notifications: ["通知中心", "課程安排與新的回饋，集中在這裡。"], preferences: ["把空間調成你的樣子。", "外觀與時間顯示，配合你的學習習慣。"],
  help: ["有問題，我們一起找答案。", "先找到問題的方向，再決定需要哪一種協助。"], search: ["找下一個想學的。", "搜尋課程、老師、課節與使用說明。"],
  delete: ["刪除帳號", "先了解資料與服務的影響，再決定下一步。"], logout: ["離開預覽帳號", "這裡沒有真實登入狀態；你可以回到公開首頁。"],
};
const subscribeSystemTheme = (listener: () => void) => {
  const media = window.matchMedia("(prefers-color-scheme: dark)");
  media.addEventListener("change", listener);
  return () => media.removeEventListener("change", listener);
};
type DialogState = { title: string; body: ReactNode; confirm?: () => void; confirmLabel?: string };
type Notice = (message: string) => void;

export function AccountPage({ segments }: { segments: string[] }) {
  const { state, actor, theme } = usePrototype();
  const page = segments[0] ?? "";
  const [notice, setNotice] = useState("");
  const [dialog, setDialog] = useState<DialogState | null>(null);
  const { cancelledPreviews, setCancelledPreviews, readNotificationIds, setReadNotificationIds } = useExperienceViewState();
  const systemDark = useSyncExternalStore(subscribeSystemTheme, () => window.matchMedia("(prefers-color-scheme: dark)").matches, () => true);
  const student = actor.role === "student" ? state.students.find(item => item.id === actor.id) : undefined;
  const identity = localIdentity(actor.role, actor.id);
  const name = student?.name ?? (actor.role === "teacher" ? state.teachers.find(item => item.id === actor.id)?.draft.name : "平台管理員") ?? "預覽帳號";
  const [title, description] = headings[page] ?? ["找不到這個帳號頁面", "請從帳號選單選擇要查看的內容。"];
  const navItems = accountNav.map(([path, icon, label]) => <Link key={path} href={`${account}${path ? `/${path}` : ""}`} aria-current={page === path ? "page" : undefined} onClick={event => event.currentTarget.closest("details")?.removeAttribute("open")}><Icon name={icon} />{label}</Link>);
  let content: ReactNode;
  if (page === "") content = <AccountOverview name={name} student={student} />;
  else if (page === "profile") content = <ProfileContent key={`${actor.role}/${actor.id}`} identity={identity} notify={setNotice} />;
  else if (page === "security") content = <SecurityContent />;
  else if (page === "membership") content = student ? <MembershipContent key={`${actor.id}/${segments[1] ?? ""}`} student={student} view={segments[1]} cancelled={cancelledPreviews.includes(student.id)} onCancel={() => setCancelledPreviews(ids => ids.includes(student.id) ? ids : [...ids, student.id])} onReactivate={() => setCancelledPreviews(ids => ids.filter(id => id !== student.id))} openDialog={setDialog} /> : <StudentAccountOnly />;
  else if (page === "billing" || page === "orders") content = student ? <BillingContent student={student} orders={page === "orders"} detail={segments[1]} openDialog={setDialog} /> : <StudentAccountOnly />;
  else if (page === "notifications") content = <NotificationContent student={student} readIds={readNotificationIds} onRead={id => setReadNotificationIds(ids => ids.includes(id) ? ids : [...ids, id])} onUnread={id => setReadNotificationIds(ids => ids.filter(item => item !== id))} />;
  else if (page === "preferences") content = <PreferencesContent />;
  else if (page === "help") content = <HelpContent key={segments[1] ?? "all"} topic={segments[1]} notify={setNotice} openDialog={setDialog} />;
  else if (page === "search") content = <SearchContent student={student} />;
  else if (page === "delete") content = <DeleteContent openDialog={setDialog} />;
  else if (page === "logout") content = <LogoutContent />;
  else content = <Empty icon="search" title="這個頁面目前不存在" text="你可以回到帳號總覽，再找到需要的功能。"><Link className={styles.primary} href={account}>回帳號總覽</Link></Empty>;
  return <div className={styles.root} data-theme={theme === "system" ? systemDark ? "dark" : "light" : theme} data-account-preview="true">
    <header className={styles.topbar}><Link href={base} aria-label="The One 首頁"><BrandLogo size="small" /></Link><div className={styles.topActions}><Link href={`${base}/${actor.role}`}><Icon name="book" />{actor.role === "student" ? "回到學習" : "回工作區"}</Link><div className={styles.identity}><span className={styles.avatar}>{name.slice(0, 1)}</span><span>{name}</span></div></div></header>
    <div className={styles.frame}><aside className={styles.sidebar}><p className={styles.navTitle}>YOUR ACCOUNT / 帳號中心</p><nav className={styles.nav} aria-label="帳號選單">{navItems}</nav></aside><main className={styles.content}>
      <details className={styles.mobileNav}><summary>帳號選單</summary><nav className={styles.nav} aria-label="手機帳號選單">{navItems}</nav></details>
      <header className={styles.heading}><p className={styles.eyebrow}>THE ONE / YOUR ACCOUNT</p><h1>{title}</h1><p>{description}</p></header>
      <div className={styles.previewNote}><Icon name="shield" /><p>本機整合預覽 · 個資、交易與通知尚未連接正式服務。待決策的商業規則會標示 Proposed，不會真的扣款、取消方案或刪除資料。</p></div>
      {notice && <div className={styles.status} role="status">{notice}<button className={styles.textButton} onClick={() => setNotice("")} aria-label="關閉帳號提示">　關閉</button></div>}
      {content}<footer className={styles.footer}>既有帳號、訂單與預約能力會沿用平台服務；這個畫面不建立另一套帳號或交易。<br /><Link href={`${base}/policies/students`}>使用規則</Link>　·　<Link href={`${base}/policies/privacy`}>隱私說明</Link>　·　<Link href={`${account}/help`}>取得協助</Link></footer>
    </main></div>
    {dialog && <AccountDialog title={dialog.title} close={() => setDialog(null)}>{dialog.body}<div className={styles.actions}><button className={styles.secondary} onClick={() => setDialog(null)}>{dialog.confirm ? "返回修改" : "知道了"}</button>{dialog.confirm && <button className={styles.primary} onClick={() => { dialog.confirm?.(); setDialog(null); }}>{dialog.confirmLabel ?? "確認示意操作"}</button>}</div></AccountDialog>}
  </div>;
}

function localIdentity(role: string, id: string): LocalIdentity | null {
  if (role === "student") return id === "s1" ? getLocalIdentity("student") : id === "s2" ? getLocalIdentity("student-2") : id === "s3" ? getLocalIdentity("student-3") : null;
  if (role === "teacher") return id === "t1" ? getLocalIdentity("teacher") : null;
  return role === "admin" ? getLocalIdentity("admin") : null;
}
function Tag({ children }: { children: ReactNode }) { return <span className={styles.tag}>{children}</span>; }
function Panel({ children, className = "" }: { children: ReactNode; className?: string }) { return <section className={`${styles.panel} ${className}`}>{children}</section>; }
function Empty({ icon, title, text, children }: { icon: string; title: string; text: string; children?: ReactNode }) { return <Panel><div className={styles.empty}><Icon name={icon} /><h2>{title}</h2><p>{text}</p>{children && <div className={styles.actions}>{children}</div>}</div></Panel>; }
function CardLink({ href, icon, title, text }: { href: string; icon: string; title: string; text: string }) { return <Link className={`${styles.panel} ${styles.linkCard}`} href={href}><Icon name={icon} /><div><h3>{title}</h3><p>{text}</p></div><Icon name="arrow" /></Link>; }
function StudentAccountOnly() { return <Empty icon="shield" title="這裡是學生自己的方案與帳務" text="目前工作区的角色不會取得其他學生的帳號資料。請使用有學生身分的帳號查看自己的內容。"><Link className={styles.secondary} href={account}>回帳號總覽</Link></Empty>; }
function AccountOverview({ name, student }: { name: string; student?: Student }) {
  return <><div className={styles.overview}><section className={styles.lead}><Tag>讓學習持續，讓管理簡單。</Tag><h2>{name}，<br />照自己的步伐前進。</h2><p>需要確認方案、查看帳單或找幫助時，都可以回到這裡。</p><div className={styles.actions}><Link className={styles.primary} href={`${base}/${student ? "student" : "account/profile"}`}>{student ? "回到今天的學習" : "查看個人資料"}<Icon name="arrow" /></Link></div></section><Panel><div className={styles.row}><div><p>目前平台方案</p><small>{student ? "示意方案；訂閱狀態待正式服務提供" : "目前為工作區帳號"}</small></div><Tag>{student?.membership ?? "帳號"}</Tag></div><div className={styles.row}><div><p>帳號與安全</p><small>登入、Email 與密碼管理</small></div><Link href={`${account}/security`} aria-label="查看登入與安全"><Icon name="arrow" /></Link></div><div className={styles.row}><div><p>需要幫忙？</p><small>付款、預約或學習上的問題</small></div><Link href={`${account}/help`} aria-label="前往幫助與支援"><Icon name="arrow" /></Link></div></Panel></div><section className={styles.section}><div className={styles.sectionHead}><h2>常用的帳號功能</h2></div><div className={styles.grid}><CardLink href={`${account}/membership`} icon="book" title="我的會員方案" text="比較平台方案，查看可使用的學習能力。" /><CardLink href={`${account}/billing`} icon="wallet" title="帳務與訂單" text="把購買內容、付款狀態與憑證分開確認。" /><CardLink href={`${account}/notifications`} icon="chat" title="通知與回饋" text="從這裡回到最新的課程安排與老師回饋。" /><CardLink href={`${account}/preferences`} icon="settings" title="使用偏好" text="調整外觀與上課時間的顯示方式。" /></div></section></>;
}

function ProfileContent({ identity, notify }: { identity: LocalIdentity | null; notify: Notice }) {
  const result = identity ? getLocalProfile(identity) : null;
  const profile = result?.ok ? result.data : null;
  const [name, setName] = useState(profile?.displayName ?? "");
  const [phone, setPhone] = useState(profile?.phone ?? "");
  const [error, setError] = useState("");
  if (!profile || !identity) return <Empty icon="shield" title="此身分的個人資料尚未接線" text="不會改用另一個學生或老師的資料。請返回帳號總覽。" />;
  return <Panel><div className={styles.tags}><Tag>HYBRID · 既有個資輸入驗證</Tag></div><h2 className={styles.section}>基本資料</h2><p className={styles.sub}>目前使用合成帳號資料。可以檢查欄位格式，尚不會儲存到正式帳號。</p><form className={styles.form} onSubmit={event => { event.preventDefault(); const checked = validateProfileUpdate(identity, { displayName: name, phone: phone || null, avatarUrl: profile.avatarUrl, locale: profile.locale, timezone: profile.timezone }); if (!checked.ok) { setError(checked.message); return; } setError(""); notify("已通過平台既有個資格式驗證。這是本機檢查，沒有儲存或修改正式帳號。"); }}><label className={styles.field}><span>顯示名稱</span><input value={name} onChange={event => setName(event.target.value)} minLength={2} maxLength={80} required autoComplete="off" /><small>2–80 字；這個稱呼只在目前表單預覽。</small></label><label className={styles.field}><span>聯絡電話（選填）</span><input value={phone} onChange={event => setPhone(event.target.value)} type="tel" maxLength={32} autoComplete="off" placeholder="請勿在預覽輸入真實個資" /></label><label className={styles.field}><span>Email</span><input value="正式帳號 Email 尚未接線" readOnly /><small>Email 由既有登入服務管理，不是一般個資欄位。</small></label>{error && <p className={styles.error} role="alert">{error}</p>}<div className={styles.actions}><button className={styles.primary} type="submit">檢查資料格式</button><Link className={styles.textButton} href={`${account}/security`}>登入與安全<Icon name="arrow" /></Link></div></form></Panel>;
}
function SecurityContent() {
  return <><Panel><Tag>既有 Auth 流程 · 本機入口</Tag><h2 className={styles.section}>登入方式</h2><div className={styles.row}><div><p>Email 與密碼</p><small>登入、註冊、驗證與重設沿用平台既有格式與流程。</small></div></div><div className={styles.row}><div><p>忘記密碼</p><small>查看重設流程；預覽不會寄送真實郵件。</small></div><Link href={`${base}/auth/forgot-password`}>開啟<Icon name="arrow" /></Link></div><div className={styles.row}><div><p>變更 Email</p><small>變更與重新驗證方式尚待正式接線。</small></div><Tag>尚未提供</Tag></div><p className={styles.sub}>沒有讀取真實登入裝置、session 或密碼。離開預覽不是正式帳號登出。</p><div className={styles.actions}><Link className={styles.primary} href={`${base}/auth/sign-in`}>查看登入流程</Link><Link className={styles.textButton} href={`${account}/logout`}>離開預覽帳號</Link></div></Panel><Panel><h2>帳號與會員分開管理</h2><p className={styles.sub}>取消平台方案不會等於刪除帳號。若你只是想調整方案，先到會員管理；需要刪除帳號時，另行確認資料與服務影響。</p><div className={styles.actions}><Link className={styles.secondary} href={`${account}/membership`}>管理會員方案</Link><Link className={`${styles.textButton} ${styles.danger}`} href={`${account}/delete`}>了解刪除帳號</Link></div></Panel></>;
}

function MembershipContent({ student, view, cancelled, onCancel, onReactivate, openDialog }: { student: Student; view?: string; cancelled: boolean; onCancel: () => void; onReactivate: () => void; openDialog: (dialog: DialogState) => void }) {
  const [reactivated, setReactivated] = useState(false);
  if (view === "cancel") return <CancellationFlow student={student} onCancel={onCancel} />;
  if (view === "compare") return <PlanComparison current={student.membership} />;
  if (view === "reactivate") return <Panel><Tag>Proposed · 恢復方案流程</Tag><h2 className={styles.section}>想繼續原本的學習嗎？</h2><p className={styles.sub}>能否恢復原訂閱、是否需要重新購買，以及何時恢復使用，仍待方案政策確認。這裡只預覽操作步驟。</p>{reactivated && <p className={styles.status} role="status">恢復流程已預覽，已清除本頁取消示意標記；正式訂閱與權益沒有變更。</p>}<div className={styles.noticeBox}>目前示意方案：The One {student.membership}<br />恢復日期與費用：尚未設定<br />不會建立付款或改變課程使用資格。</div><div className={styles.actions}><button className={styles.primary} onClick={() => openDialog({ title: "確認恢復流程示意", body: <p>只清除本頁的取消預覽標記。沒有實際恢復訂閱、扣款或授予課程權益。</p>, confirm: () => { onReactivate(); setReactivated(true); }, confirmLabel: "完成恢復示意" })}>預覽恢復方案</button><Link className={styles.secondary} href={`${account}/membership`}>回會員管理</Link></div></Panel>;
  if (view) return <Empty icon="search" title="找不到這個方案管理頁面" text="請回會員管理選擇可用的操作。"><Link href={`${account}/membership`} className={styles.primary}>回會員管理</Link></Empty>;
  return <><Panel><div className={styles.tags}><Tag>平台會員</Tag><Tag>{cancelled ? "已完成取消流程預覽" : "Mock · 目前情境"}</Tag></div><div className={styles.planName}>The One {student.membership}</div><p className={styles.sub}>Membership 提供平台學習能力；是否包含某套課程與服務，要再看該課程的適用範圍。</p><dl className={styles.facts}><div><dt>訂閱狀態</dt><dd>{cancelled ? "取消示意，正式方案未變更" : "待正式會員服務提供"}</dd></div><div><dt>計費週期</dt><dd>尚未設定</dd></div><div><dt>下次續訂</dt><dd>日期與金額待確認</dd></div><div><dt>正式使用資格</dt><dd>尚未接線</dd></div></dl><div className={styles.actions}><Link className={styles.primary} href={`${account}/membership/compare`}>比較平台方案<Icon name="arrow" /></Link><Link className={styles.secondary} href={`${base}/student/courses`}>看看我的課程</Link></div></Panel><section className={styles.section}><Panel><h2>你的課程與一對一</h2><p className={styles.sub}>會員方案、加入課程與一對一課程包，分開管理。升級方案不會自動加入所有課程，也不會替你預約一對一。</p><div className={styles.actions}><Link className={styles.secondary} href={`${base}/courses/guitar-roadmap`}>探索旗艦課程</Link><Link className={styles.textButton} href={`${base}/student/private`}>查看私人課程</Link></div></Panel></section><section className={styles.section}><Panel><h2>管理接下來的方案</h2><p className={styles.sub}>調整、生效日期、取消與恢復仍為 Proposed。歷史學習成果不因取消方案而被刪除；待處理服務和媒體存取的詳細範圍尚待確認。</p><div className={styles.actions}><Link className={styles.secondary} href={`${account}/membership/${cancelled ? "reactivate" : "cancel"}`}>{cancelled ? "查看恢復流程" : "查看取消流程"}</Link><Link className={styles.textButton} href={`${account}/help/billing`}>方案與帳務協助</Link></div></Panel></section></>;
}
function PlanComparison({ current }: { current: string }) {
  const plans = [
    { name: "Free", label: "先找到方向", text: "從免費與預覽內容，找到適合自己的起點。", points: ["免費或預覽的學習內容", "先探索，再決定要加入的課程", "一對一課程可獨立選購"] },
    { name: "Plus", label: "建立自己的練習系統", text: "依平台方案與課程範圍，安排有結構的自主學習。", points: ["符合方案範圍的 System Courses", "適用的數位學習與練習能力", "不自動包含所有單品課"] },
    { name: "Pro", label: "讓練習有人回應", text: "在適用課程中，加入老師的回饋與人力服務。", points: ["適用的自主學習內容", "課程支援的回饋或指導服務", "服務資格、額度與價格待確認"] },
  ];
  return <><p className={styles.previewNote}>Proposed · 這是平台方案方向，價格、週期與課程適用範圍尚未定稿。不是 Guitar Roadmap 專屬訂閱。</p><div className={styles.planGrid}>{plans.map(plan => <section className={`${styles.plan} ${current === plan.name ? styles.planSelected : ""}`} key={plan.name}><Tag>{current === plan.name ? "目前示意方案" : plan.label}</Tag><h2>The One {plan.name}</h2><p>{plan.text}</p><p><strong>價格與週期待公布</strong></p><ul>{plan.points.map(point => <li key={point}>{point}</li>)}</ul><div className={styles.actions}>{plan.name === "Free" ? <Link className={styles.secondary} href={`${base}/courses/guitar-roadmap`}>探索免費方向</Link> : <Link className={styles.primary} href={`${base}/checkout/subscription?plan=${plan.name}`}>查看 {plan.name} 選購示意</Link>}</div></section>)}</div><div className={styles.noticeBox}><strong>每套課程都會說明是否包含。</strong>加入平台會員不等於加入所有 System Courses；額外單品課與一對一課程各自提供購買說明。</div><div className={styles.actions}><Link className={styles.textButton} href={`${account}/membership`}>回會員管理</Link></div></>;
}
function CancellationFlow({ student, onCancel }: { student: Student; onCancel: () => void }) {
  const [step, setStep] = useState(0);
  const [reason, setReason] = useState("");
  const [acknowledged, setAcknowledged] = useState(false);
  if (student.membership === "Free") return <Empty icon="book" title="Free 情境目前沒有付費訂閱可取消" text="如果你只是想離開某套課程，或需要處理帳號，請分別查看對應功能。一對一課程包仍是獨立的上課權益。"><Link className={styles.primary} href={`${account}/membership`}>回會員管理</Link><Link className={styles.secondary} href={`${account}/help/billing`}>查看帳務協助</Link></Empty>;
  return <Panel><Tag>Proposed · 取消方案流程</Tag><h2 className={styles.section}>先把影響說清楚。</h2><p className={styles.sub}>目前示意方案是 The One {student.membership}。這裡不會真的取消訂閱或刪除帳號。</p><ol className={`${styles.steps} ${styles.section}`}>{["了解影響", "你的原因", "確認內容", "取消狀態"].map((label, index) => <li key={label} aria-current={step === index ? "step" : undefined}><b>{index + 1}</b>{label}</li>)}</ol>{step === 0 ? <><h3>取消會員，與刪除帳號是兩件事。</h3><ul className={styles.capability}><li>帳號與已留下的學習成果不因取消方案而被刪除。</li><li>獨立購買的一對一課程包不等於平台會員訂閱。</li><li>停止新服務或內容使用的時間，須依正式政策決定。</li></ul><div className={styles.noticeBox}><strong>以下仍待確認</strong>立即或期末生效、是否退款、寬限期、待處理服務與恢復方案方式。這份預覽不承諾任何生效日期或退款金額。</div><div className={styles.actions}><button className={styles.primary} onClick={() => setStep(1)}>繼續查看取消流程</button><Link className={styles.secondary} href={`${account}/membership`}>保留目前方案</Link></div></> : step === 1 ? <><label className={styles.field}><span>願意分享原因嗎？（本頁選填）</span><textarea value={reason} onChange={event => setReason(event.target.value)} maxLength={1200} placeholder="例如：最近練習時間較少。請勿輸入個人敏感資料。" /><small>原因是否必填仍待政策確認，這裡只示範願意分享時的操作。</small></label><div className={styles.actions}><button className={styles.primary} onClick={() => setStep(2)}>檢查取消內容</button><button className={styles.secondary} onClick={() => setStep(0)}>上一步</button></div></> : step === 2 ? <><dl className={styles.facts}><div><dt>方案</dt><dd>The One {student.membership}</dd></div><div><dt>生效時間</dt><dd>尚待政策核准</dd></div><div><dt>退款</dt><dd>尚待政策與服務確認</dd></div><div><dt>帳號</dt><dd>不執行刪除</dd></div></dl>{reason && <div className={styles.noticeBox}><strong>你填寫的原因</strong>{reason}</div>}<label className={styles.checkbox}><input type="checkbox" checked={acknowledged} onChange={event => setAcknowledged(event.target.checked)} /><span>我了解這是 Proposed 流程預覽，不會改變實際訂閱、課程資格或付款。</span></label><div className={styles.actions}><button className={styles.primary} disabled={!acknowledged} onClick={() => { onCancel(); setStep(3); }}>完成取消流程示意</button><button className={styles.secondary} onClick={() => setStep(1)}>返回修改</button></div></> : <><div className={styles.successIcon}>✓</div><h3>取消流程已預覽完成。</h3><p className={styles.sub}>目前没有發生正式取消。你的示意方案與學習權益維持原狀；生效時間、退款與後續服務需要正式政策與接線後才能確認。</p><div className={styles.actions}><Link className={styles.primary} href={`${account}/membership`}>查看會員管理</Link><Link className={styles.secondary} href={`${account}/membership/reactivate`}>查看恢復流程</Link></div></>}</Panel>;
}

function BillingContent({ student, orders, detail, openDialog }: { student: Student; orders: boolean; detail?: string; openDialog: (dialog: DialogState) => void }) {
  const { state } = usePrototype();
  const [scenario, setScenario] = useState("unavailable");
  const packs = state.packages.filter(item => item.studentId === student.id);
  if (orders && detail) return <Empty icon="file" title="尚無可讀取的訂單詳情" text="這個入口尚未接自己的訂單服務。課程包與平台總收款都不能代替這筆訂單。"><Link href={`${account}/orders`} className={styles.primary}>回我的訂單</Link></Empty>;
  const receipt = () => openDialog({ title: "收據與發票狀態", body: <><p>目前尚未接入自己的付款與憑證資料，無法確認是否已開立或可下載。</p><div className={styles.noticeBox}>訂單明細不是正式收據。這裡不會產生憑證編號、稅額或假下載檔案。</div><div className={styles.actions}><Link className={styles.textButton} href={`${account}/help/billing`}>查看帳務協助</Link></div></> });
  return <>{!orders && <Panel><Tag>目前示意方案</Tag><h2 className={styles.section}>The One {student.membership}</h2><dl className={styles.facts}><div><dt>付款方式</dt><dd>正式付款資料尚未接線</dd></div><div><dt>下次扣款</dt><dd>日期與金額待確認</dd></div><div><dt>會員計費週期</dt><dd>尚未設定</dd></div><div><dt>收據／發票</dt><dd>目前無法查詢</dd></div></dl><div className={styles.actions}><Link href={`${account}/membership`} className={styles.primary}>管理會員方案</Link><Link href={`${account}/orders`} className={styles.secondary}>查看我的訂單</Link></div></Panel>}
    <section className={!orders ? styles.section : ""}><Panel><div className={styles.sectionHead}><h2>{orders ? "訂單與購買紀錄" : "最近的付款紀錄"}</h2><Tag>待接既有訂單服務</Tag></div><div className={styles.empty}><Icon name="file" /><h2>正式訂單尚未載入。</h2><p>平台已有自己的訂單與付款摘要服務。這個預覽目前未接線，所以不能把空白畫面當作「沒有購買過」。</p><div className={styles.actions}><button className={styles.secondary} onClick={receipt}>查看憑證狀態說明</button><Link className={styles.textButton} href={`${account}/help/billing`}>查不到訂單？</Link></div></div></Panel></section>
    {!orders && <section className={styles.section}><Panel><Tag>Proposed · 付款异常情境</Tag><div className={styles.tabs} aria-label="付款狀態預覽">{[["unavailable", "尚未接線"], ["failed", "付款失敗"], ["past-due", "待完成付款"]].map(([key, label]) => <button key={key} aria-pressed={scenario === key} onClick={() => setScenario(key)}>{label}</button>)}</div><h3>{scenario === "failed" ? "這次付款還沒有完成。" : scenario === "past-due" ? "方案有一筆待處理付款。" : "付款狀態等待正式服務提供。"}</h3><p className={styles.sub}>{scenario === "unavailable" ? "目前不保存信用卡，也沒有已設定的自動扣款。" : "這是狀態示意，不代表你真的欠費。金額、寬限期、重試次數與使用影響都需要正式規則。"}</p><div className={styles.actions}>{scenario !== "unavailable" && <button className={styles.primary} onClick={() => openDialog({ title: "重新付款／更新方式", body: <p>正式付款方式與重試服務尚未接線。沒有扣款，也不會將付款或會員狀態改成成功。需要協助時可前往帳務說明。</p> })}>查看付款處理方式</button>}<Link className={styles.secondary} href={`${account}/help/billing`}>帳務協助</Link></div></Panel></section>}
    <section className={styles.section}><Panel><h2>你的課程包權益</h2><p className={styles.sub}>以下讀取同一份學生示意資料，提供上課權益參考；它不是訂單或付款證明。</p>{packs.length ? packs.map(pack => { const credits = balance(state, pack.id); return <div className={styles.row} key={pack.id}><div><p>{pack.snapshot.title}</p><small>可用 {credits.available} 堂 · 預留 {credits.reserved} 堂 · 已上課 {credits.consumed} 堂</small><small>來源：{pack.source}</small></div><Link href={`${base}/student/private?package=${pack.id}`}>查看<Icon name="arrow" /></Link></div>; }) : <p className={styles.sub}>目前示意資料沒有私人課程包。</p>}</Panel></section></>;
}

function NotificationContent({ student, readIds, onRead, onUnread }: { student?: Student; readIds: string[]; onRead: (id: string) => void; onUnread: (id: string) => void }) {
  const { state, timeZone } = usePrototype();
  const [filter, setFilter] = useState("all");
  const events = student ? [
    ...state.bookings.filter(item => item.studentId === student.id).map(item => ({ id: `booking-${item.id}-${item.status}`, kind: "lesson", title: item.status === "cancelled" ? "課次已取消（示意）" : "查看你的課程安排", text: new Intl.DateTimeFormat("zh-TW", { timeZone, month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date(item.start)), href: `${base}/student/private?package=${item.packageId}` })),
    ...state.feedback.filter(item => item.studentId === student.id).map(item => ({ id: `feedback-${item.id}`, kind: "feedback", title: "老師留下了新的回饋", text: item.observation, href: `${base}/student/${state.submissions.find(submission => submission.id === item.submissionId)?.kind === "pro" ? "guidance" : "feedback"}` })),
    ...state.platformReplies.filter(item => item.studentId === student.id).map(item => ({ id: `support-${item.id}`, kind: "feedback", title: "平台協助回覆", text: item.body, href: `${base}/student/feedback` })),
  ] : [];
  const shown = events.filter(item => filter === "unread" ? !readIds.includes(item.id) : filter === "all" || item.kind === filter);
  return <Panel><Tag>Mock · 從目前自己的課程與回饋投影</Tag><p className={styles.sub}>標為已讀只影響本頁顯示。未接 Email／LINE 發送，也沒有真實送達紀錄。</p><div className={styles.tabs} aria-label="通知篩選">{[["all", "全部"], ["unread", "未讀"], ["lesson", "課程安排"], ["feedback", "回饋與協助"]].map(([value, label]) => <button key={value} aria-pressed={filter === value} onClick={() => setFilter(value)}>{label}{value === "unread" ? ` ${events.filter(item => !readIds.includes(item.id)).length}` : ""}</button>)}</div>{shown.length ? <ul className={styles.inbox}>{shown.map(item => { const read = readIds.includes(item.id); return <li key={item.id} className={styles.notification} data-unread={!read}><Icon name={item.kind === "lesson" ? "calendar" : "chat"} /><div><h3>{item.title}</h3><p>{item.text}</p><div className={styles.actions}><Link className={styles.textButton} href={item.href} onClick={() => onRead(item.id)}>查看內容<Icon name="arrow" /></Link><button className={styles.textButton} onClick={() => read ? onUnread(item.id) : onRead(item.id)}>{read ? "標為未讀" : "標為已讀"}</button></div></div></li>; })}</ul> : <div className={styles.empty}><Icon name="chat" /><h2>{filter === "unread" ? "目前沒有未讀通知。" : "這裡目前沒有示意通知。"}</h2><p>有可見的課程安排或老師回饋時，會在這裡提供返回來源頁的入口。</p></div>}<div className={styles.noticeBox}>付款、續訂、評量結果與新教材通知的正式事件還在後續整合範圍。此處沒有捏造這些通知或自動改變業務狀態。</div></Panel>;
}
function PreferencesContent() {
  const { theme, setTheme, timeZone, setTimeZone } = usePrototype();
  return <><Panel><h2>外觀</h2><p className={styles.sub}>偏好同步到學生、老師與管理員工作區。已核准教室保持專注的深色。</p><div className={styles.themeChoices}>{(["light", "dark", "system"] as Theme[]).map(item => <button key={item} className={styles.themeChoice} aria-pressed={theme === item} onClick={() => setTheme(item)}><div className={styles.swatch} data-appearance={item} aria-hidden="true" />{item === "light" ? "明亮" : item === "dark" ? "深色" : "跟隨系統"}</button>)}</div></Panel><Panel><h2>時間與語言</h2><label className={styles.field}><span>上課時間顯示</span><select value={timeZone} onChange={event => setTimeZone(event.target.value)}><option value="Asia/Taipei">台北（UTC+8）</option><option value="Asia/Tokyo">東京（UTC+9）</option><option value="America/Los_Angeles">洛杉磯（依日期換算）</option></select><small>同一筆預約換算顯示，跨頁保留於本機預覽；不會改動預約時間。</small></label><div className={styles.row}><div><p>語言</p><small>繁體中文；其他語言尚未提供。</small></div><Tag>目前版本</Tag></div></Panel><Panel><h2>通知偏好</h2><p className={styles.sub}>站內、Email／LINE 與必要服務通知的選項仍待確認。正式接線前不顯示會讓你誤以為已生效的訂閱開關。</p><div className={styles.actions}><Link className={styles.secondary} href={`${account}/notifications`}>查看通知中心</Link></div></Panel></>;
}

const helpQuestions = [
  { category: "billing", question: "會員方案和一對一課程包有什麼不同？", answer: "Free／Plus／Pro 是平台會員方案；一對一課程包是獨立的上課權益。加入會員不會自動替你預約私人課，也不一定包含所有单品課程。" },
  { category: "billing", question: "付款後還沒有看到課程包，怎麼辦？", answer: "先查看訂單與付款狀態。付款確認和權益處理是兩個步驟；本預覽尚未接正式訂單資料。請勿因為權益尚未顯示就重複付款。" },
  { category: "billing", question: "取消方案會刪掉我的帳號嗎？", answer: "取消會員與刪除帳號是不同操作。取消生效時間、退款與恢復條件尚待正式政策確認；預覽不會真的取消或刪除。" },
  { category: "booking", question: "為什麼有堂數卻找不到可預約時段？", answer: "請確認課程包對應老師、有效期間與排課方式。時段也須符合老師可用安排和双方既有課次。換一個日期，或先請平台協助確認。" },
  { category: "booking", question: "已預留和已上課是一樣的嗎？", answer: "不同。確認預約會預留堂數；完成上課與消耗堂數由對應流程處理。改期和取消的影響應以該次預約的處理結果為準。" },
  { category: "learning", question: "看完課程就代表通過了嗎？", answer: "觀看、練習、自報完成與老師驗證不同。你可以記錄自己的練習進度；正式驗證、評量與證書需要各自的資格與流程。" },
  { category: "learning", question: "推薦課程會自動加入我的學習嗎？", answer: "不會。推薦只提供方向；你仍須確認課程與方案是否適合，並明確選擇加入。尚未加入的課程不會有個人進度。" },
] as const;
function HelpContent({ topic, notify, openDialog }: { topic?: string; notify: Notice; openDialog: (dialog: DialogState) => void }) {
  const [category, setCategory] = useState(topic && ["billing", "learning", "booking"].includes(topic) ? topic : "all");
  const [query, setQuery] = useState("");
  const [subject, setSubject] = useState(topic && ["billing", "learning", "booking"].includes(topic) ? topic : "learning");
  const [message, setMessage] = useState("");
  const [prepared, setPrepared] = useState(false);
  const questions = helpQuestions.filter(item => (category === "all" || item.category === category) && `${item.question}${item.answer}`.includes(query.trim()));
  return <><div className={styles.helpGrid}>{[["learning", "book", "學習與練習"], ["booking", "calendar", "私人課與預約"], ["billing", "wallet", "方案與帳務"]].map(([value, icon, label]) => <button key={value} className={`${styles.panel} ${styles.textButton}`} onClick={() => setCategory(value)} aria-pressed={category === value}><Icon name={icon} /><h3>{label}</h3></button>)}</div><section className={styles.section}><Panel><h2>先看看常見問題</h2><label className={styles.field}><span>搜尋使用說明</span><input value={query} onChange={event => setQuery(event.target.value)} placeholder="輸入會員、付款、預約或練習…" /></label><div className={styles.tabs}><button aria-pressed={category === "all"} onClick={() => setCategory("all")}>全部問題</button></div>{questions.length ? questions.map(item => <details className={styles.faq} key={item.question}><summary>{item.question}</summary><p>{item.answer}</p></details>) : <div className={styles.empty}><h3>沒有找到相符的問題。</h3><p>可以換個關鍵字，或在下方整理需要協助的內容。</p></div>}</Panel></section><section className={styles.section}><Panel><Tag>Mock · 客服入口尚未接線</Tag><h2 className={styles.section}>把問題整理好。</h2><p className={styles.sub}>目前表單不會送到客服。先說明你想完成的事情、在哪裡遇到問題；不要輸入密碼、完整付款資料或敏感個資。</p>{prepared && <div className={styles.status} role="status">問題內容已在本頁預覽，尚未送出，也沒有建立正式客服案件。</div>}<form onSubmit={event => { event.preventDefault(); if (!message.trim()) return notify("請先描述需要協助的事情。"); openDialog({ title: "確認要協助的內容", body: <><p>類別：{subject === "billing" ? "方案與帳務" : subject === "booking" ? "私人課與預約" : "學習與使用"}</p><blockquote>{message}</blockquote><p>這個動作只完成本頁預覽，不送信、不建立案件，也不承諾回覆時間。</p></>, confirmLabel: "完成問題預覽", confirm: () => setPrepared(true) }); }}><label className={styles.field}><span>問題方向</span><select value={subject} onChange={event => setSubject(event.target.value)}><option value="learning">學習與使用</option><option value="booking">私人課與預約</option><option value="billing">方案與帳務</option></select></label><label className={styles.field}><span>需要協助的事情</span><textarea value={message} onChange={event => { setMessage(event.target.value); setPrepared(false); }} maxLength={2000} required placeholder="我想要…，在…頁面遇到…" /><small>{message.length} / 2000</small></label><div className={styles.actions}><button className={styles.primary} type="submit">預覽問題內容</button><Link className={styles.textButton} href={`${account}/search`}>搜尋其他內容</Link></div></form></Panel></section></>;
}
function SearchContent({ student }: { student?: Student }) {
  const { state } = usePrototype();
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("all");
  const entries = [
    ...state.courses.filter(item => item.published).map(item => ({ id: `course-${item.id}`, kind: "course", label: "課程", title: item.published!.title, text: item.published!.summary, href: `${base}/courses/${item.id}` })),
    ...publicTeachers(state).map(item => ({ id: `teacher-${item.id}`, kind: "teacher", label: "老師", title: item.published!.name, text: item.published!.headline, href: `${base}/teachers/${item.id}` })),
    ...helpQuestions.map((item, index) => ({ id: `help-${index}`, kind: "help", label: "使用說明", title: item.question, text: item.answer, href: `${account}/help/${item.category}` })),
    ...(student?.joinedCourseIds.includes("c1") && state.courses.some(item => item.id === "c1" && item.published) ? lessonVisuals.map(item => ({ id: `lesson-${item.id}`, kind: "lesson", label: "已加入課程的課節", title: item.title, text: "The One Guitar Roadmap 2.0 · 使用資格仍依課程頁說明", href: `${base}/student/courses/c1/lessons/${item.id}` })) : []),
  ];
  const keyword = query.trim().toLocaleLowerCase();
  const results = entries.filter(item => (category === "all" || item.kind === category) && (!keyword || `${item.title}${item.text}`.toLocaleLowerCase().includes(keyword)));
  return <Panel><form className={styles.searchForm} onSubmit={event => event.preventDefault()} role="search"><input className={styles.searchInput} aria-label="搜尋課程、老師與說明" value={query} onChange={event => setQuery(event.target.value)} maxLength={150} placeholder="想學的主題，或需要幫助的事情…" /><button className={styles.primary} type="submit"><Icon name="search" />搜尋</button></form><div className={styles.tabs} aria-label="搜尋種類">{[["all", "全部"], ["course", "課程"], ["teacher", "老師"], ["lesson", "我的課節"], ["help", "說明"]].map(([value, label]) => <button key={value} aria-pressed={category === value} onClick={() => setCategory(value)}>{label}</button>)}</div><p className={styles.sub}>本機搜尋公開資料與自己已加入課程的課節名稱。沒有搜尋私密回饋、付款資料或未公開資源。</p>{results.length ? <ul className={styles.searchResults}>{results.map(item => <li key={item.id}><Link href={item.href}><Tag>{item.label}</Tag><h3>{item.title}</h3><p>{item.text}</p></Link></li>)}</ul> : <div className={styles.empty}><Icon name="search" /><h2>目前沒有相符的結果。</h2><p>試試「節奏」、「會員」或「預約」，也可以清除篩選重新看看。</p><div className={styles.actions}><button className={styles.secondary} onClick={() => { setQuery(""); setCategory("all"); }}>清除搜尋與篩選</button><Link className={styles.textButton} href={`${account}/help`}>取得協助</Link></div></div>}</Panel>;
}
function DeleteContent({ openDialog }: { openDialog: (dialog: DialogState) => void }) {
  const [acknowledged, setAcknowledged] = useState(false);
  return <Panel><Tag>Proposed · 帳號刪除尚未接線</Tag><h2 className={styles.section}>先確認，你是想取消方案，還是刪除帳號？</h2><p className={styles.sub}>如果只想停止訂閱，請到會員管理。刪除帳號還涉及學習記錄、已購權益、既有預約與需要保留的交易資料，處理方式尚待確認。</p><ul className={styles.capability}><li>取消方案不會自動刪除帳號。</li><li>此頁不會刪除學習紀錄、付款、預約或真實個資。</li><li>正式資料處理、身分確認與撤回方式尚未定稿。</li></ul><label className={styles.checkbox}><input type="checkbox" checked={acknowledged} onChange={event => setAcknowledged(event.target.checked)} /><span>我了解目前只能查看流程說明，沒有提交正式刪除申請。</span></label><div className={styles.actions}><button className={styles.secondary} disabled={!acknowledged} onClick={() => openDialog({ title: "帳號刪除流程尚未提供", body: <><p>沒有刪除任何資料，也沒有建立正式刪帳申請。後續需確認身份驗證、保留資料、未結束服務與撤回規則。</p><p className={styles.sub}>需要協助時可先查看帳號支援說明。</p></> })}>查看申請前的確認事項</button><Link className={styles.primary} href={`${account}/membership`}>我只是想管理方案</Link></div></Panel>;
}
function LogoutContent() {
  return <Panel><h2>準備先休息一下？</h2><p className={styles.sub}>這個本機環境沒有建立真實 Auth session。回到首頁不會冒稱已從所有裝置登出，也不會刪除正式資料。</p><div className={styles.actions}><Link className={styles.primary} href={base}>離開預覽，回首頁</Link><Link className={styles.secondary} href={account}>繼續查看帳號</Link></div></Panel>;
}
function AccountDialog({ title, children, close }: { title: string; children: ReactNode; close: () => void }) {
  const ref = useRef<HTMLDialogElement>(null);
  const id = useId();
  useEffect(() => { const previous = document.activeElement as HTMLElement | null; const dialog = ref.current; dialog?.showModal(); return () => { dialog?.close(); previous?.focus(); }; }, []);
  return <dialog ref={ref} className={styles.dialog} aria-labelledby={id} onClick={event => { if (event.target instanceof Element && event.target.closest("a")) close(); }} onCancel={event => { event.preventDefault(); close(); }}><div className={styles.dialogHead}><h2 id={id}>{title}</h2><button className={styles.iconButton} onClick={close} aria-label="關閉對話框"><Icon name="close" /></button></div>{children}</dialog>;
}
