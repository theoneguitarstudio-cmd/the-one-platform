"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import { useSearchParams } from "next/navigation";
import Link, { useRouter } from "@/components/platform-experience/link";
import { BrandLogo } from "@/components/brand-logo";
import { usePrototype } from "@/modules/ux-prototype/store";
import { levelOutcomes } from "@/modules/ux-prototype/fixtures";
import { getLocalIdentity, LOCAL_PRODUCTS, validateCheckout } from "@/modules/platform-experience/gateway";
import styles from "./public-pages.module.css";

const base = "/ux-prototype";
type CheckoutKind = "subscription" | "standalone" | "private_package";
const checkoutNames: Record<CheckoutKind, string> = { subscription: "平台會員方案", standalone: "單次購買課程", private_package: "一對一課程包" };
const isCheckoutKind = (value: string | null | undefined): value is CheckoutKind => value === "subscription" || value === "standalone" || value === "private_package";
const faq = [
  ["第一次來，從哪裡開始？", "先看看系統課程，或用學習引導整理你的目標、經驗和可練習時間。建議只提供方向，你可以自己決定是否加入課程。"],
  ["會員方案和課程有什麼不同？", "Free、Plus、Pro 是 The One 平台會員方案。系統課程是一條有目標、階段與練習的學習路線；是否包含在方案內，要看該課程的說明。"],
  ["Plus 包含所有老師的課程嗎？", "不是。方案內的系統課程依會員目錄與存取規則提供；老師的獨立單品課和一對一課程包，可能另外販售。"],
  ["買了一對一課程包，就排好課了嗎？", "還沒有。課程包提供可用堂數，選擇老師與可用時間、確認預約後，才會出現下一堂課。請核對時區、堂數和適用規則。"],
  ["看完影片就算通過了嗎？", "看完、自報完成、老師驗證、評量通過與取得證書是不同的事。學習會從理解、練習、應用開始；需要人工確認的成果另有流程。"],
  ["我可以取消會員或調整上課時間嗎？", "會員管理與私人課預約是分開的入口。正式取消生效時間、退款、重新啟用及預約限制，需依平台確認的適用政策；目前新增流程中的未定政策會清楚標記。"],
  ["目前這個本機版本會真的收費嗎？", "不會。新增結帳、引導和支援頁供完整旅程檢查，沒有真實付款、訂閱、資料庫寫入或客服傳送。"],
] as const;

function Action({ href, children, secondary = false }: { href: string; children: ReactNode; secondary?: boolean }) {
  return <Link className={secondary ? styles.secondary : styles.primary} href={`${base}${href}`}>{children}<span aria-hidden="true">↗</span></Link>;
}
function Intro({ label, title, children }: { label: string; title: string; children: ReactNode }) {
  return <header className={styles.intro}><p className={styles.eyebrow}>{label}</p><h1>{title}</h1><div className={styles.lead}>{children}</div></header>;
}
function Notice({ children }: { children: ReactNode }) { return <aside className={styles.notice}>{children}</aside>; }

function PublicShell({ children }: { children: ReactNode }) {
  const [menu, setMenu] = useState(false);
  const menuButton = useRef<HTMLButtonElement>(null);
  const closeMenu = () => { setMenu(false); menuButton.current?.focus(); };
  return <div className={styles.surface} data-platform-public="true" onKeyDown={event => { if (event.key === "Escape" && menu) { event.preventDefault(); closeMenu(); } }}><a className={styles.skip} href="#platform-content">跳到內容</a><header className={styles.nav}><Link className={styles.logo} aria-label="The One 首頁" href={base}><BrandLogo /></Link><nav className={styles.desktopNav} aria-label="主要導覽"><Link href={`${base}/system-courses`}>系統課程</Link><Link href={`${base}/membership`}>會員方案</Link><Link href={`${base}/#p5-teacher`}>一對一老師</Link><Link href={`${base}/support`}>幫助與支援</Link></nav><Link className={styles.login} href={`${base}/auth/sign-in`}>登入</Link><button ref={menuButton} className={styles.menuButton} aria-expanded={menu} aria-controls="platform-mobile-menu" onClick={() => setMenu(!menu)}>{menu ? "關閉選單" : "開啟選單"}</button></header>{menu && <nav id="platform-mobile-menu" className={styles.mobileNav} aria-label="手機導覽" onKeyDown={event => { if (event.key === "Escape") closeMenu(); }}><Link onClick={() => setMenu(false)} href={`${base}/system-courses`}>系統課程</Link><Link onClick={() => setMenu(false)} href={`${base}/membership`}>會員方案</Link><Link onClick={() => setMenu(false)} href={`${base}/#p5-teacher`}>一對一老師</Link><Link onClick={() => setMenu(false)} href={`${base}/support`}>幫助與支援</Link></nav>}<main id="platform-content" className={styles.main}>{children}</main><footer className={styles.footer}><div><BrandLogo size="small"/><p>每一次練習，都離想彈的音樂近一點。</p></div><nav aria-label="頁尾導覽"><Link href={`${base}/about`}>關於我們</Link><Link href={`${base}/faq`}>常見問題</Link><Link href={`${base}/support`}>聯絡支援</Link><Link href={`${base}/legal/terms`}>服務條款</Link><Link href={`${base}/legal/privacy`}>隱私</Link><Link href={`${base}/legal/refund`}>退款與取消</Link></nav><p className={styles.localLabel}>本機旅程預覽 · 新增頁面為 Mock UI · 不進行真實交易或通知</p></footer></div>;
}

function CourseCatalog({ slug }: { slug?: string }) {
  const { state } = usePrototype();
  const course = state.courses.find(item => item.id === "c1" && item.published?.kind === "system");
  if (slug && slug !== "guitar-roadmap" && slug !== "c1") return <MissingPage title="找不到這套系統課程"/>;
  return <><Intro label="SYSTEM COURSES / 有方向的學習" title={slug ? "The One Guitar Roadmap 2.0" : "找到一條，適合你的學習路線。"}><p>{slug ? "第一套旗艦系統課程。從彈完一首歌開始，逐步累積能帶到音樂裡的能力。" : "課程不只是影片清單。看見每一段的目標，也知道今天可以先練哪一步。"}</p></Intro>{course ? <article className={styles.courseFeature}><div className={styles.courseArt}><span>THE ONE / FLAGSHIP SYSTEM COURSE</span><strong>Guitar<br/>Roadmap<br/>2.0</strong><span>理解 → 練習 → 應用</span></div><div className={styles.courseCopy}><span className={styles.pill}>首套旗艦 · 示意課程資料</span><h2>{course.published!.title}</h2><p>{course.published!.summary}</p><ul><li>看見階段目標和下一步</li><li>影片、練習與資源放在同一段學習裡</li><li>需要時，查看課程支援的人工回饋服務</li></ul><div className={styles.actions}><Action href="/courses/guitar-roadmap">認識這套課程</Action><Action secondary href="/onboarding">先找我的起點</Action></div><p className={styles.small}>加入與會員資格分開。方案是否包含、可用資源及服務，以課程存取說明為準。</p></div></article> : <Notice>這套課程目前沒有可展示的公開版本。你仍可先整理自己的學習目標。<Link href={`${base}/onboarding`}>開始學習引導</Link></Notice>}{slug && <section className={styles.section}><h2>你會逐步建立的能力</h2><p>六個 Level 的核心目標，沿用已核准產品定義。完整內容仍依正式課綱展開。</p><ol className={styles.outcomes}>{levelOutcomes.map((outcome, index) => <li key={outcome}><span>LEVEL {index + 1}</span><h3>{outcome}</h3></li>)}</ol></section>}<section className={styles.softBand}><div><h2>先選學習路線，再確認適合的方案。</h2><p>會員提供平台存取與服務資格；不是每個獨立課程都包含在內。</p></div><Action secondary href="/membership">了解平台會員</Action></section></>;
}

function MembershipPage() {
  return <><Intro label="THE ONE MEMBERSHIP / 平台會員" title="照自己的步伐，選擇需要的支持。"><p>Free 給方向，Plus 給系統，Pro 加上合適的人來陪你確認成果。<br/>三者都是 The One 平台方案，與一套特定課程分開。</p></Intro><div className={styles.plans}>{[{ name: "Free", line: "先找到方向", description: "認識學習路線，查看依政策開放的免費與預覽內容。", items: ["探索系統課程", "了解階段與學習方式", "使用公開學習資源"] }, { name: "Plus", line: "把練習變成系統", description: "依方案、會員目錄和存取規則，學習包含的系統課程。", items: ["符合資格的會員課程內容", "自主學習與數位練習能力", "明確加入自己要學的課程"] }, { name: "Pro", line: "有人一起確認下一步", description: "在符合資格的課程與服務範圍內，加入人工回饋及指導。", items: ["符合資格的 Plus 學習能力", "課程支援的回饋與指導", "依政策提供驗證與評量資格"] }].map(plan => <article className={styles.plan} key={plan.name}><p className={styles.eyebrow}>{plan.name === "Plus" ? "SYSTEM / 系統" : plan.name === "Pro" ? "SUPPORT / 人的支持" : "DIRECTION / 方向"}</p><h2>{plan.name}</h2><h3>{plan.line}</h3><p>{plan.description}</p><ul>{plan.items.map(item => <li key={item}>{item}</li>)}</ul><p className={styles.pricePending}>價格與方案細節待公布</p><Action secondary={plan.name !== "Plus"} href={plan.name === "Free" ? "/onboarding" : `/checkout/subscription?plan=${plan.name}`}>{plan.name === "Free" ? "先開始探索" : `查看 ${plan.name} 流程`}</Action></article>)}</div><Notice>會員價格、扣款週期、指導額度、取消生效、寬限與重新啟用政策尚待確認。此頁是方案概念與流程預覽，不承諾特定數量或價格；Pro 不自動等於通過驗證、取得證書或擁有私人課堂數。</Notice><section className={styles.softBand}><div><h2>已經有會員方案？</h2><p>查看目前方案和帳務入口，學習內容仍留在你的學生空間。</p></div><Action secondary href="/account/membership">管理我的會員</Action></section></>;
}

function ProductCatalog({ slug }: { slug?: string }) {
  const product = slug ? LOCAL_PRODUCTS.find(item => item.slug === slug) : null;
  if (slug && !product) return <MissingPage title="找不到這個商品流程"/>;
  const products = product ? [product] : LOCAL_PRODUCTS;
  return <><Intro label="PRODUCTS / 選擇需要的學習方式" title={product ? product.name : "三種選擇，各自有清楚的下一步。"}><p>平台方案、獨立課程與一對一課程包，購買後得到的內容與後續安排不同。</p></Intro><Notice>這裡是既有結帳輸入契約的三種本機示例，不是正式可購商品目錄。沒有設定價格，也不代表系統課程或老師課程包已上架。</Notice><div className={styles.threeCards}>{products.map(item => { const kind: CheckoutKind = item.productType === "subscription" ? "subscription" : item.productType === "recorded_course" ? "standalone" : "private_package"; return <article className={styles.panel} key={item.slug}><span className={styles.pill}>本機商品契約示例</span><h2>{item.name}</h2><p>{item.billingLabel}</p><p>{kind === "subscription" ? "完成後查看會員與課程目錄，再決定加入哪套學習路線。" : kind === "standalone" ? "完成後查看訂單與對應的已購課程。" : "完成後先查看堂數，再選擇老師的可預約時間。"}</p><p className={styles.small}>價格尚未設定 · 不提供真實購買</p><Action href={slug ? `/checkout/${kind}` : `/products/${item.slug}`}>{slug ? "預覽這類結帳流程" : "了解這種購買方式"}</Action></article>; })}</div><section className={styles.softBand}><div><h2>還不確定自己想學什麼？</h2><p>可以先認識旗艦系統課程，找到適合自己的方向。</p></div><Action secondary href="/system-courses">探索系統課程</Action></section></>;
}

function Checkout({ kind }: { kind: CheckoutKind }) {
  const { state, actor } = usePrototype();
  const query = useSearchParams();
  const router = useRouter();
  const [consent, setConsent] = useState(false);
  const [method, setMethod] = useState("preview");
  const [error, setError] = useState("");
  const plan = query.get("plan") === "Pro" ? "Pro" : "Plus";
  const product = state.courses.find(item => item.published?.kind === "standalone" && (!query.get("product") || item.id === query.get("product")));
  const requestedTeacher = query.get("teacherId") || query.get("teacher");
  const requestedOffer = query.get("offerId") || query.get("offer");
  const offer = state.offers.find(item => item.published && !item.published.targetStudentId && state.teachers.some(teacher => teacher.id === item.teacherId && teacher.published?.showPrivate) && (!requestedOffer || item.id === requestedOffer) && (!requestedTeacher || item.teacherId === requestedTeacher));
  if (kind === "private_package" && !offer) return <MissingPage title="這位老師目前沒有這個公開課程包"/>;
  const name = kind === "subscription" ? `The One ${plan}` : kind === "standalone" ? product?.published?.title || "尚未選定已上架單品課" : offer?.published?.title || "目前沒有公開課程包";
  const price = kind === "subscription" ? null : kind === "standalone" ? product?.published?.price : offer?.published?.unitPrice == null ? null : offer.published.count * offer.published.unitPrice;
  const summary = kind === "subscription" ? ["收費方式", "訂閱 · 週期待確認", "取得內容", "依會員目錄與存取政策", "下一步", "查看會員與課程目錄"] : kind === "standalone" ? ["收費方式", "單次購買", "取得內容", "該商品約定的學習內容", "下一步", "查看訂單與已購內容"] : ["收費方式", "課程包 · 單次購買", "取得內容", "課程包內的可用堂數", "下一步", "查看堂數，再自行預約"];
  function previewCheckout() {
    if (!consent) { setError("請先確認這是本機流程示意。"); return; }
    if (actor.role === "student" && !["s1", "s2", "s3"].includes(actor.id)) { setError("找不到這個本機示意學生，無法驗證購買流程。"); return; }
    const identity = getLocalIdentity(actor.role !== "student" ? actor.role : actor.id === "s2" ? "student-2" : actor.id === "s3" ? "student-3" : "student");
    const productType = kind === "subscription" ? "subscription" : kind === "standalone" ? "recorded_course" : "lesson_package";
    const localProduct = LOCAL_PRODUCTS.find(item => item.productType === productType)!;
    const result = validateCheckout(identity, { productSlug: localProduct.slug, quantity: 1, idempotencyKey: crypto.randomUUID() });
    if (!result.ok) { setError(result.message); return; }
    const nextQuery = new URLSearchParams({ type: kind });
    if (kind === "subscription") nextQuery.set("plan", plan);
    if (kind === "standalone" && product) nextQuery.set("product", product.id);
    if (kind === "private_package" && offer) {
      nextQuery.set("teacherId", offer.teacherId);
      nextQuery.set("offerId", offer.id);
    }
    router.push(`${base}/checkout/success?${nextQuery.toString()}`);
  }
  return <><Intro label="CHECKOUT / 確認你選的內容" title={checkoutNames[kind]}><p>把購買內容、付款方式與下一步確認清楚。這次只預覽流程，不會扣款。</p></Intro><div className={styles.checkoutGrid}><form className={styles.panel} data-integration-mode="HYBRID" onSubmit={event => { event.preventDefault(); previewCheckout(); }}><span className={styles.pill}>HYBRID · 既有結帳輸入驗證 ＋ Mock 流程</span><h2>{name}</h2>{kind === "standalone" && !product && <Notice>目前共用資料中沒有已發布的單品課。以下可預覽結帳步驟，不會把待上架草稿當成可購商品。</Notice>}{kind === "private_package" && <p>授課老師：{state.teachers.find(teacher => teacher.id === offer?.teacherId)?.published?.name || "待選定"}。買課程包不代表已排好課。</p>}<h3>付款方式</h3><label className={styles.radioBox}><input type="radio" name="payment" value="preview" checked={method === "preview"} onChange={event => setMethod(event.target.value)}/><span>不付款，預覽後續流程<small>正式可用的支付方式尚未接入；不需填卡號或轉帳資料。</small></span></label><h3>購買前先知道</h3><p>{kind === "subscription" ? "正式推出時，這裡會揭露扣款週期、續約、取消及退款條件；目前這些政策仍待確認。" : kind === "private_package" ? "正式購買前需確認堂數、效期、排課方式、改期與取消規則，以及老師可用時段。" : "正式購買前需確認可觀看內容、存取期間、素材使用方式與退款條件。"}</p><div className={styles.inlineLinks}><Link href={`${base}/legal/terms`}>服務條款草案狀態</Link><Link href={`${base}/legal/refund`}>退款與取消政策狀態</Link></div><label className={styles.checkbox}><input type="checkbox" checked={consent} onChange={event => { setConsent(event.target.checked); setError(""); }}/><span>我知道這是流程示意，沒有付款、訂閱、授權或預約。</span></label>{error && <p className={styles.error} role="alert">{error}</p>}<button className={styles.primary} type="submit">預覽完成後的下一步<span aria-hidden="true">↗</span></button></form><aside className={`${styles.panel} ${styles.orderSummary}`}><p className={styles.eyebrow}>YOUR SELECTION / 內容摘要</p><h2>{name}</h2><dl>{[0, 2, 4].map(index => <div key={summary[index]}><dt>{summary[index]}</dt><dd>{summary[index + 1]}</dd></div>)}</dl><div className={styles.total}><span>展示金額</span><strong>{price == null ? "待公布" : `NT$ ${price.toLocaleString("zh-TW")}`}</strong></div><p className={styles.small}>{price == null ? "政策與價格未確認前，不提供真實結帳。" : "此金額來自共用 Mock 公開版本，不是真實交易報價。"}</p><Link className={styles.textLink} href={`${base}/support?topic=billing`}>需要購買方面的協助？</Link></aside></div></>;
}

function CheckoutSuccess() {
  const { state } = usePrototype();
  const query = useSearchParams();
  const kind = isCheckoutKind(query.get("type")) ? query.get("type") as CheckoutKind : null;
  if (!kind) return <MissingPage title="請先選擇要預覽的結帳流程"/>;
  const content = kind === "subscription" ? { title: "接著，看看你的會員與學習路線。", copy: "正式開通後，你可以查看方案狀態，再選擇想加入的系統課程。會員不會自動把所有課程加入你的學習空間。", href: "/account/membership", action: "查看目前會員", second: "/system-courses", secondText: "探索系統課程" } : kind === "standalone" ? { title: "接著，找到訂單與課程的入口。", copy: "正式購買成功後，訂單會保留購買內容與狀態，並提供進入對應課程的入口。這次示意不產生新訂單或授予存取。", href: "/account/orders", action: "查看訂單入口", second: "/student/courses", secondText: "查看原有的課程" } : { title: "接著，了解堂數與預約的下一步。", copy: "正式購買成功後，先確認課程包堂數與效期，再選老師的可用時段。付款完成和預約成立是兩個不同步驟。", href: "/student/private", action: "查看原有堂數與預約", second: "/account/orders", secondText: "查看訂單入口" };
  let selection: ReactNode;
  if (kind === "subscription") {
    const selectedPlan = query.get("plan");
    selection = <><h2>{selectedPlan === "Plus" || selectedPlan === "Pro" ? `The One ${selectedPlan}` : "未指定平台會員方案"}</h2><p>本次只預覽方案流程，沒有變更目前會員。</p><Action secondary href="/membership">返回平台會員說明</Action></>;
  } else if (kind === "standalone") {
    const selectedProduct = state.courses.find(item => item.id === query.get("product") && item.published?.kind === "standalone");
    selection = selectedProduct?.published ? <><h2>{selectedProduct.published.title}</h2><p>{selectedProduct.published.summary}</p><p className={styles.small}>目前公開版本 v{selectedProduct.revision} · 只呈現共用 Mock 課程，沒有建立購買紀錄。</p><Action secondary href={`/courses/${encodeURIComponent(selectedProduct.id)}`}>返回本次選定課程</Action></> : <><h2>沒有可顯示的已發布單品課</h2><p>{query.get("product") ? "本次指定的課程目前不存在或尚未公開；不會換成另一門課，也不會展示草稿。" : "本次只有結帳流程預覽，沒有選定已上架單品課。"}</p><Action secondary href="/products">返回商品流程列表</Action></>;
  } else {
    const selectedTeacher = state.teachers.find(item => item.id === query.get("teacherId") && item.published?.showPrivate);
    const selectedOffer = selectedTeacher ? state.offers.find(item => item.id === query.get("offerId") && item.teacherId === selectedTeacher.id && item.published && !item.published.targetStudentId) : undefined;
    selection = selectedOffer?.published && selectedTeacher?.published ? <><h2>{selectedTeacher.published.name} · {selectedOffer.published.title}</h2><p>{selectedOffer.published.count} 堂，每堂 {selectedOffer.published.duration} 分鐘。{selectedOffer.published.note}</p><p className={styles.small}>目前公開版本 v{selectedOffer.version} · 這是本次選擇，不是新取得的課程包或已成立預約。</p><Action secondary href={`/teachers/${encodeURIComponent(selectedTeacher.id)}?tab=private`}>返回這位老師的課程包</Action></> : <><h2>本次課程包目前無法顯示</h2><p>請從老師介紹頁重新選擇公開課程包。缺少、已不公開或不屬於該老師的課程包，不會換成另一個商品。</p><Action secondary href="/teachers">返回一對一老師</Action></>;
  }
  return <section className={styles.success}><span className={styles.successMark} aria-hidden="true">✓</span><p className={styles.eyebrow}>FLOW PREVIEW / 完成畫面示意</p><h1>{content.title}</h1><p>{content.copy}</p><Notice>沒有真實付款，也沒有改變目前會員、課程權限、堂數或預約。下方帳號、課程與私人課入口顯示原有資料，不是本次流程的新購買結果。</Notice><section className={styles.panel} aria-label="本次流程所選（Mock）"><span className={styles.pill}>本次流程所選（Mock）</span>{selection}</section><div className={styles.actions}><Action href={content.href}>{content.action}</Action><Action secondary href={content.second}>{content.secondText}</Action></div>{kind === "subscription" && <Link className={styles.textLink} href={`${base}/onboarding`}>第一次學習？先整理自己的目標</Link>}</section>;
}

const onboardingQuestions = [
  { key: "goal", title: "你最想把吉他帶到哪裡？", hint: "先選現在最想做到的一件事。", options: [["song", "完整彈完喜歡的歌"], ["rhythm", "伴奏更穩、更有變化"], ["understand", "理解和弦與音樂"]] },
  { key: "level", title: "現在的你，最接近哪一種？", hint: "這不是考試，也不會決定你能不能學。", options: [["new", "剛開始，還在認識吉他"], ["chords", "會一些和弦，轉換還會卡"], ["song", "能彈歌，想更靈活"]] },
  { key: "preference", title: "怎麼樣的學習方式，讓你安心？", hint: "之後可以依自己的需要調整。", options: [["self", "有清楚路線，自己慢慢練"], ["feedback", "先自己練，需要時得到回饋"], ["private", "希望老師一對一帶著我"]] },
  { key: "time", title: "一天願意留多少時間給練習？", hint: "選一個比較容易持續的長度。", options: [["10", "大約 10 分鐘"], ["20", "大約 20 分鐘"], ["30", "大約 30 分鐘"]] },
  { key: "interest", title: "哪種音樂，最讓你想拿起吉他？", hint: "用你喜歡的音樂，讓練習有一個理由。", options: [["sing", "自彈自唱與流行歌曲"], ["rhythm", "節奏、律動與伴奏"], ["melody", "旋律、編曲與獨奏"]] },
] as const;

function Onboarding() {
  const [step, setStep] = useState(0);
  const [answers, setAnswers] = useState<string[]>(["", "", "", "", ""]);
  const [finished, setFinished] = useState(false);
  const questionRef = useRef<HTMLLegendElement>(null); const resultRef = useRef<HTMLDivElement>(null); const initial = useRef(true); useEffect(() => { if(initial.current){initial.current=false;return;} (finished ? resultRef.current : questionRef.current)?.focus(); }, [step, finished]);
  const question = onboardingQuestions[step];
  const selected = answers[step];
  const recommendation = answers[1] === "new" ? "從第一個和弦與穩定拍子開始。" : answers[0] === "understand" ? "從歌曲裡，慢慢聽懂和弦的選擇。" : answers[0] === "rhythm" ? "讓右手穩定，再給伴奏一點變化。" : "先把一小段連起來，再彈完整首歌。";
  return <><Intro label="WELCOME / 你的學習起點" title={finished ? "這是一個起點，你可以自己選擇。" : "先認識你，再一起找方向。"}><p>{finished ? "這份建議不會自動加入課程、升級會員或替你安排老師。" : "五個簡單選擇，幫你把目標與練習時間整理清楚。無需提供真實個資。"}</p></Intro>{finished ? <div className={styles.resultGrid} ref={resultRef} tabIndex={-1}><section className={styles.panel}><span className={styles.pill}>學習方向建議 · 非程度認證</span><h2>{recommendation}</h2><p>可以先認識 The One Guitar Roadmap 2.0。每天用約 {answers[3]} 分鐘，理解一小段、慢慢練，再放回歌曲裡。</p><p>{answers[2] === "private" ? "你偏好有人陪練，也可以先認識一對一老師，了解授課方式。" : answers[2] === "feedback" ? "你可以先自主練習，再查看適用課程的回饋服務與資格。" : "清楚的課程路線能幫你自主前進；遇到卡關時也可以回頭複習。"}</p><div className={styles.actions}><Action href="/courses/guitar-roadmap">認識建議課程</Action><Action secondary href={answers[2] === "private" ? "/#p5-teacher" : "/student"}>{answers[2] === "private" ? "認識一對一老師" : "前往今日學習"}</Action></div><button className={styles.textButton} onClick={() => setFinished(false)}>修改我的選擇</button></section><aside className={styles.panel}><h2>你剛才的選擇</h2><dl className={styles.answerSummary}>{onboardingQuestions.map((item, index) => <div key={item.key}><dt>{["目標", "經驗", "偏好", "時間", "興趣"][index]}</dt><dd>{item.options.find(option => option[0] === answers[index])?.[1]}</dd></div>)}</dl><p className={styles.small}>只保留在這個頁面的本機狀態，離開後不建立個人學習紀錄。</p></aside></div> : <section className={`${styles.panel} ${styles.question}`}><div className={styles.stepRow}><span>第 {step + 1} 題，共 5 題</span><span>{Math.round((step + 1) / 5 * 100)}%</span></div><div className={styles.progress}><span style={{ width: `${(step + 1) * 20}%` }}/></div><form onSubmit={event => { event.preventDefault(); if (!selected) return; if (step === 4) setFinished(true); else setStep(step + 1); }}><fieldset><legend ref={questionRef} tabIndex={-1}>{question.title}</legend><p>{question.hint}</p><div className={styles.choices}>{question.options.map(([value, label]) => <label className={`${styles.choice} ${selected === value ? styles.selected : ""}`} key={`${question.key}-${value}`}><input type="radio" name={question.key} value={value} checked={selected === value} required onChange={() => setAnswers(answers.map((answer, index) => index === step ? value : answer))}/><span>{label}</span><span aria-hidden="true">{selected === value ? "✓" : ""}</span></label>)}</div></fieldset><div className={styles.stepRow}><button type="button" className={styles.secondary} disabled={step === 0} onClick={() => setStep(step - 1)}>上一步</button><button type="submit" className={styles.primary} disabled={!selected}>{step === 4 ? "看看我的學習方向" : "下一步"}<span aria-hidden="true">→</span></button></div></form></section>}</>;
}

function FaqPage() { return <><Intro label="QUESTIONS / 在開始之前" title="你想知道的，我們先說清楚。"><p>從選課、方案到私人課，先找到讓你安心的答案。</p></Intro><div className={styles.faq}>{faq.map(([title, answer]) => <details key={title}><summary>{title}<span aria-hidden="true">＋</span></summary><p>{answer}</p></details>)}</div><section className={styles.softBand}><div><h2>還沒找到答案？</h2><p>整理問題，從帳務、學習或預約分類開始。</p></div><Action href="/support">前往幫助與支援</Action></section></>; }

function AboutPage() { return <><Intro label="ABOUT THE ONE / 樂玩吉他" title="讓音樂，慢慢成為你的日常。"><p>The One 希望讓學習不只停在「我看過」，而是走向「我做得到」。</p></Intro><div className={styles.threeCards}>{[["方向", "知道下一步", "用清楚的學習路線與階段目標，減少不知道該練什麼的時刻。"], ["練習", "把理解帶進音樂", "不急著追完所有影片。練一小段、試著應用，再慢慢連成一首歌。"], ["支持", "遇到卡關，也有入口", "自主學習、合適的老師回饋與私人課，可以依不同需要選擇。"]].map(([tag, title, copy]) => <article className={styles.panel} key={tag}><p className={styles.eyebrow}>{tag}</p><h2>{title}</h2><p>{copy}</p></article>)}</div><section className={styles.softBand}><div><h2>第一套旗艦學習路線</h2><p>The One Guitar Roadmap 2.0，從吉他開始，陪你累積真正能使用的能力。</p></div><Action href="/system-courses">探索系統課程</Action></section></>; }

function SupportPage() {
  const query = useSearchParams();
  const [topic, setTopic] = useState(["billing", "booking", "learning", "account"].includes(query.get("topic") || "") ? query.get("topic")! : "learning");
  const [subject, setSubject] = useState("");
  const [body, setBody] = useState("");
  const [preview, setPreview] = useState(false);
  const [error, setError] = useState("");
  const topics: Record<string, string> = { learning: "學習與課程", booking: "私人課與預約", billing: "購買與帳務", account: "帳號與使用問題" };
  return <><Intro label="HELP & SUPPORT / 讓問題有個入口" title="卡住的時候，先一起釐清。"><p>選擇問題類型，看看常見說明；需要更多協助時，先把情況整理好。</p></Intro><div className={styles.supportGrid}><section className={styles.panel}>{preview ? <><span className={styles.pill}>問題草稿 · 尚未傳送</span><h2>{subject}</h2><p>{topics[topic]}</p><p className={styles.prewrap}>{body}</p><Notice>客服系統還沒有接入。本次只整理本機草稿，沒有寄信、通知老師或建立客服案件。</Notice><button className={styles.secondary} onClick={() => setPreview(false)}>返回修改</button></> : <form onSubmit={event => { event.preventDefault(); if (!subject.trim() || !body.trim()) { setError("請填寫一句話說明與問題內容，不能只輸入空白。"); return; } setError(""); setPreview(true); }}><h2>整理你的問題</h2><label className={styles.field}>問題類型<select value={topic} onChange={event => setTopic(event.target.value)}>{Object.entries(topics).map(([id, label]) => <option key={id} value={id}>{label}</option>)}</select></label><label className={styles.field}>一句話說明<input value={subject} onChange={event => { setSubject(event.target.value); setError(""); }} aria-invalid={Boolean(error) && !subject.trim()} aria-describedby={error ? "support-validation" : undefined} required maxLength={100} placeholder="例如：不知道下一堂課的時間"/></label><label className={styles.field}>發生了什麼？<textarea value={body} onChange={event => { setBody(event.target.value); setError(""); }} aria-invalid={Boolean(error) && !body.trim()} aria-describedby={error ? "support-validation" : undefined} required maxLength={2000} rows={5} placeholder="請使用示意內容，不要填密碼、卡號或真實聯絡資料。"/></label><p className={styles.small}>此處不收真實個資或附件，內容只保留在目前頁面。</p>{error && <p id="support-validation" className={styles.error} role="alert">{error}</p>}<button type="submit" className={styles.primary}>預覽問題草稿<span aria-hidden="true">→</span></button></form>}</section><aside className={styles.panel}><h2>也許這裡有答案</h2><Link className={styles.helpLink} href={`${base}/faq`}>常見問題<span>選課、方案與預約</span></Link><Link className={styles.helpLink} href={`${base}/account/orders`}>查看訂單<span>購買內容與付款狀態</span></Link><Link className={styles.helpLink} href={`${base}/student/private`}>查看私人課<span>堂數、時間與老師回饋</span></Link><Link className={styles.helpLink} href={`${base}/student`}>回到今日學習<span>找到目前這一步</span></Link></aside></div></>;
}

function LegalPage({ topic }: { topic?: string }) {
  const titles: Record<string, string> = { terms: "服務條款", privacy: "隱私與資料使用", refund: "退款與取消" };
  const title = topic ? titles[topic] : "使用前，先了解適用的說明。";
  if (topic && !title) return <MissingPage title="找不到這份政策說明"/>;
  const items = topic === "privacy" ? ["個人資料的收集目的與必要範圍", "教學素材、影片與回饋的存取和保存期限", "查詢、更正、匯出、刪除及聯絡窗口"] : topic === "refund" ? ["會員取消的生效時間與再次啟用條件", "單品課／私人課包各自的退款適用條件", "改期、未出席、已使用堂數與退款如何處理"] : ["平台服務範圍及帳號使用", "會員、課程、商品與私人課適用的不同規則", "素材授權、申訴與爭議處理"];
  return <><Intro label="POLICIES / 清楚的承諾" title={title}><p>政策確認後，會在購買、預約及相關操作前提供適用版本。</p></Intro><section className={`${styles.panel} ${styles.legal}`}><span className={styles.pill}>待確認 · 非生效條款</span><h2>這裡先保留應說清楚的內容。</h2><p>以下是需要完整揭露的項目，不是已成立的法律或商業條件。這份本機預覽不要求你同意尚未定稿的條款。</p><ul>{items.map(item => <li key={item}>{item}</li>)}</ul><Notice>會員取消與帳號刪除是兩種不同操作。正式生效時間、退款、寬限期、資料保留與再次啟用，需要平台確認政策後才能接入服務。</Notice><div className={styles.inlineLinks}>{Object.entries(titles).filter(([id]) => id !== topic).map(([id, label]) => <Link key={id} href={`${base}/legal/${id}`}>{label}</Link>)}</div><Action secondary href="/support">需要進一步說明</Action></section></>;
}
function MissingPage({ title }: { title: string }) { return <section className={styles.success}><p className={styles.eyebrow}>LET’S FIND YOUR WAY / 重新找到方向</p><h1>{title}</h1><p>從課程目錄繼續探索，或回到你正在學習的位置。</p><div className={styles.actions}><Action href="/system-courses">探索系統課程</Action><Action secondary href="/student">回到今日學習</Action></div></section>; }

export function PlatformPublicPage({ segments }: { segments: string[] }) {
  const [page, id] = segments;
  let content: ReactNode;
  if (page === "system-courses") content = <CourseCatalog slug={id}/>;
  else if (page === "products") content = <ProductCatalog slug={id}/>;
  else if (page === "membership") content = <MembershipPage/>;
  else if (page === "checkout") content = id === "success" ? <CheckoutSuccess/> : isCheckoutKind(id) ? <Checkout kind={id} key={id}/> : <MissingPage title="請選擇要預覽的購買方式"/>;
  else if (page === "onboarding") content = <Onboarding/>;
  else if (page === "faq") content = <FaqPage/>;
  else if (page === "about") content = <AboutPage/>;
  else if (page === "support" || page === "help") content = <SupportPage/>;
  else if (page === "legal") content = <LegalPage topic={id}/>;
  else content = <MissingPage title="找不到這個頁面"/>;
  return <PublicShell>{content}</PublicShell>;
}
