"use client";

import Link from "@/components/platform-experience/link";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { publicOffers, type Course, type PackageOffer, type PrototypeState } from "@/modules/ux-prototype/model";
import { Asset, DiagnosisCTA, Icon, LESSON_PREVIEW, PUBLIC_ROOT } from "./shared";
import styles from "./public.module.css";

export function PublicDialog({ title, children, onClose, returnFocus }: { title: string; children: ReactNode; onClose: () => void; returnFocus?: HTMLElement | null }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const previousFocus = useRef<HTMLElement | null>(null);
  useEffect(() => {
    if (!previousFocus.current) previousFocus.current = returnFocus ?? (document.activeElement instanceof HTMLElement ? document.activeElement : null);
    const element = dialog.current;
    const overflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    element?.showModal();
    return () => { element?.close(); document.body.style.overflow = overflow; previousFocus.current?.focus(); };
  }, [returnFocus]);
  return <dialog className={styles.dialog} ref={dialog} aria-labelledby="public-dialog-title" onCancel={event => { event.preventDefault(); onClose(); }}><button className={styles.dialogClose} aria-label="關閉對話框" onClick={onClose}>×</button><h2 id="public-dialog-title">{title}</h2>{children}<div className="x-actions"><button className="btn secondary" onClick={onClose}>關閉</button></div></dialog>;
}

const money = (value: number | null) => value === null ? "價格未設定" : `NT$ ${value.toLocaleString("en-US")}`;

function OfferCard({ offer, onSelect }: { offer: PackageOffer; onSelect: (offer: PackageOffer, opener: HTMLButtonElement) => void }) {
  const content = offer.published!;
  return <article className="x-price-card"><span className="mini-chip">一對一課程包</span><h3>{content.count}<small>堂課</small></h3><span style={{ fontSize: 12 }}>{content.title}</span><p>{content.mode === "both" ? "固定制／預約制" : content.mode === "fixed" ? "固定制" : "預約制"} · 每堂 {content.duration} 分鐘</p><div className="x-price">{money(content.unitPrice === null ? null : content.count * content.unitPrice)}<small>每堂 {money(content.unitPrice)} · 示意售價</small></div><p>{content.expiryLabel}</p><button className="btn primary" onClick={event => onSelect(offer, event.currentTarget)}>了解課程包</button></article>;
}

export function CourseCard({ course }: { course: Course }) {
  const content = course.published!;
  return <article className={styles.courseCard}><span className="mini-chip">{content.kind === "system" ? "系統課程" : "單品課程"} · 公開版本 {course.revision}</span><h3>{content.title}</h3><p>{content.summary}</p><div className="x-actions"><Link className="btn primary" href={`${PUBLIC_ROOT}/courses/${course.id === "c1" ? "guitar-roadmap" : course.id}`}>認識這套課程 <Icon name="right" /></Link></div></article>;
}

export function PublicTeacher({ state, teacherId, tab, onTab }: { state: PrototypeState; teacherId: string; tab: string; onTab: (tab: string) => void }) {
  const teacher = state.teachers.find(item => item.id === teacherId);
  const profile = teacher?.published;
  const [selectedOffer, setSelectedOffer] = useState<PackageOffer | null>(null);
  const [offerOpener, setOfferOpener] = useState<HTMLButtonElement | null>(null);
  const offers = publicOffers(state, teacherId);
  const courses = state.courses.filter(course => course.teacherId === teacherId && course.published && course.published.kind === (tab === "system" ? "system" : "standalone"));
  if (!profile) return <div className={styles.content}><Link className="p6-return-link" href={`${PUBLIC_ROOT}#p5-teacher`}><Icon />返回一對一老師</Link><div className={styles.empty}>這位老師目前沒有已發布的公開介紹。<br />未核准的草稿不會出現在公開頁。</div></div>;
  const showCourses = tab === "system" ? profile.showSystem : profile.showStandalone;
  return <div className={styles.content}><Link className="p6-return-link" href={`${PUBLIC_ROOT}#p5-teacher`}><Icon /> 返回一對一老師</Link><div className="x-public-hero"><div className="x-photo-box">{profile.photo ? <Asset src={profile.photo} alt={`${profile.name}的介紹照片`} /> : <div className="x-avatar-xl" aria-label="老師照片尚未提供的示意頭像">師</div>}</div><div><div className="eyebrow">THE ONE / 教學師資</div><h1>{profile.name}</h1><p className="x-headline">{profile.headline}</p><p className="x-copy">{profile.specialties}</p><div className="x-actions"><button className="btn primary" onClick={() => onTab("private")}>看看一對一課程</button><button className="btn secondary" onClick={() => onTab("system")}>探索系統課程</button></div></div></div><section className="x-public-section"><h2>關於這位老師</h2><p className="x-copy" style={{ maxWidth: 750 }}>{profile.about}</p></section><section className="x-public-section"><h2>跟著這位老師學習</h2><div className="x-public-tabs" role="tablist" aria-label="老師課程分類">{[["system", "系統課程"], ["standalone", "單品課"], ["private", "一對一課程包"]].map(([id, label]) => <button key={id} className={`tab ${tab === id ? "active" : ""}`} role="tab" aria-selected={tab === id} onClick={() => onTab(id)}>{label}</button>)}</div><div role="tabpanel" aria-label={tab === "private" ? "一對一課程包" : tab === "system" ? "系統課程" : "單品課"}>{tab === "private" ? profile.showPrivate && offers.length ? <div className="x-grid four">{offers.map(offer => <OfferCard key={offer.id} offer={offer} onSelect={(offer, opener) => { setOfferOpener(opener); setSelectedOffer(offer); }} />)}</div> : <div className={styles.empty}>目前沒有公開的一對一課程包。<br />指定學生的客製報價不會公開。</div> : showCourses && courses.length ? <div className="x-grid">{courses.map(course => <CourseCard key={course.id} course={course} />)}</div> : <div className={styles.empty}>{showCourses ? "單品課還在準備中。" : "這個分類目前不公開。"}<br />只呈現老師選擇公開且通過平台審核的內容。</div>}</div></section><p className={styles.note}>平台 Plus／Pro 的存取資格依課程政策決定；不是這位老師個人的訂閱。單品課與一對一是另外的商品或服務。</p>
    {selectedOffer?.published && <PublicDialog returnFocus={offerOpener} title={`${profile.name} · ${selectedOffer.published.title}`} onClose={() => setSelectedOffer(null)}><span className="mini-chip">公開版本 {selectedOffer.version} · 線上一對一</span><p>{selectedOffer.published.count} 堂，每堂 {selectedOffer.published.duration} 分鐘。<br />示意總價：{money(selectedOffer.published.unitPrice === null ? null : selectedOffer.published.unitPrice * selectedOffer.published.count)}<br />{selectedOffer.published.expiryLabel}</p><p>{selectedOffer.published.note}</p><p>這裡提供公開課程包說明。購包、預約與上課是不同步驟；本地雛形不收款、不自動授予課程包。</p><div className="x-actions"><Link className="btn primary" href={`${PUBLIC_ROOT}/checkout/private_package?teacherId=${encodeURIComponent(teacherId)}&offerId=${encodeURIComponent(selectedOffer.id)}`} onClick={() => setSelectedOffer(null)}>查看課程包結帳示意 <Icon name="right" /></Link><Link className="btn secondary" href={`${PUBLIC_ROOT}/student/private`} onClick={() => setSelectedOffer(null)}>查看我的示意私人課 <Icon name="right" /></Link></div></PublicDialog>}
  </div>;
}

export function PublicCourse({ state, courseId }: { state: PrototypeState; courseId: string }) {
  const course = state.courses.find(item => item.id === (courseId === "guitar-roadmap" ? "c1" : courseId));
  const content = course?.published;
  if (!course || !content) return <div className={styles.content}><h1>課程正在準備</h1><p className={styles.note}>目前尚未公開；草稿保存不會自動更新公開版本。</p><DiagnosisCTA /></div>;
  return <div className="v4-site-content"><section className="v4-public-roadmap"><span className="v4-public-eyebrow">THE ONE / {content.kind === "system" ? "FLAGSHIP SYSTEM COURSE" : "STANDALONE COURSE"}</span><h1>{content.title}</h1><p className="v4-hero-lead">{content.summary}</p><div className="v4-hero-actions"><Link className="v4-public-btn" href={`${PUBLIC_ROOT}/diagnosis`}>先找到適合我的起點 <Icon /></Link><Link className="v4-public-link" href={LESSON_PREVIEW}>預覽已核准教室・示意 <Icon name="right" /></Link></div><div className="v4-path-strip"><div><b>01</b><div><h3>清楚的學習路線</h3><p>知道現在在哪，也知道下一步。</p></div></div><div><b>02</b><div><h3>看完，更知道怎麼練</h3><p>影片、文字、練習有共同的方向。</p></div></div><div><b>03</b><div><h3>需要時，找到指導</h3><p>依課程與服務資格提供。</p></div></div></div><section className="v4-section"><span className="v4-public-eyebrow">PUBLISHED CONTENT PREVIEW</span><h2 className="v4-section-title">先看一段，怎麼從懂走到會。</h2><p className="v4-hero-lead">{content.outline}</p></section><div className="v4-teacher-section"><div><h2>課程與會員，是兩件事。</h2><p>這是 The One 2.0 平台的一套{content.kind === "system" ? "系統" : "單品"}課程。Free／Plus／Pro 是平台方案，不是這位老師的個人方案。<br />單品課與線上一對一另外呈現，服務價格與權益以正式商品說明為準。</p></div><div className="v4-hero-actions"><Link className="v4-public-btn" href={`${PUBLIC_ROOT}/membership`}>了解平台會員 <Icon /></Link><Link className="v4-public-btn outline" href={`${PUBLIC_ROOT}/teachers/${encodeURIComponent(course.teacherId)}?tab=system`}>認識老師 <Icon /></Link></div></div><p className={styles.note}>課綱與內容均為雛形示意；目前公開版本 v{course.revision}，只有管理員的「本頁發布」會更新此處。</p></section></div>;
}

export function PublicArticles({ state, slug }: { state: PrototypeState; slug?: string }) {
  const articles = state.articles.filter(article => article.published);
  const article = articles.find(item => item.published?.slug === slug || item.id === slug);
  if (slug) return <div className={styles.content}><Link className="p6-return-link" href={`${PUBLIC_ROOT}/articles`}><Icon /> 返回學習文章</Link>{article?.published ? <article className={styles.article}><span className="mini-chip">{article.published.category}</span><h1>{article.published.title}</h1><div className={styles.articleMeta}>The One · 公開版本 {article.revision} · 文章示意</div><p>{article.published.summary}</p><p>{article.published.body}</p></article> : <div className={styles.empty}>這篇文章尚未發布或已不存在。公開頁不會顯示文章草稿。</div>}</div>;
  return <div className={styles.content}><div className="eyebrow">READ. PRACTICE. PLAY.</div><h1>讓練習，離音樂更近一點。</h1><p className={styles.note}>學習文章 · 只顯示目前已發布的版本。</p>{articles.length ? <div className="x-grid">{articles.map(item => <article key={item.id} className={styles.courseCard}><span className="mini-chip">{item.published!.category}</span><h3>{item.published!.title}</h3><p>{item.published!.summary}</p><Link className="p5-link" href={`${PUBLIC_ROOT}/articles/${encodeURIComponent(item.published!.slug)}`}>閱讀文章 <Icon name="right" /></Link></article>)}</div> : <div className={styles.empty}>學習文章正在準備；未發布草稿不會出現。</div>}</div>;
}

export function PublicPolicies({ state, privacy }: { state: PrototypeState; privacy: boolean }) {
  if (privacy) return <div className={styles.content}><h1>隱私與資料使用</h1><div className={styles.policy}><h2>本機雛形的資料說明</h2><p>這是隔離的本機 Mock 體驗。全部學生、老師、訂單與回饋都是示意資料，重新整理會回復初始資料。<br />不接正式登入、付款、資料庫、通知或真實影片上傳。診斷答案只用於目前網址的本機示意建議，不上傳服務。<br />正式隱私條款與個資政策仍待確認，本說明不代表正式法律文件。</p></div></div>;
  return <div className={styles.content}><div className="eyebrow">LEARN TOGETHER / 線上學習</div><h1>學生學習守則</h1><p className={styles.note}>規章內容為本地草案；閱讀標記不代表法律簽署。新版會重新要求確認。</p>{state.policies.filter(policy => policy.audience === "student").map(policy => <section className={styles.policy} key={policy.id}><span className="mini-chip">版本 {policy.version} · 示意草案</span><h2 style={{ marginTop: 16 }}>{policy.title}</h2><p>{policy.body}</p></section>)}<div className="x-actions"><Link className="btn primary" href={`${PUBLIC_ROOT}/student/policies`}>到學生空間閱讀並確認 <Icon name="right" /></Link></div></div>;
}

