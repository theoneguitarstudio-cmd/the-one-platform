"use client";
import { BrandLogo } from "@/components/brand-logo";

import Link from "@/components/platform-experience/link";
import { useRef, useState, type KeyboardEvent } from "react";
import { Asset, DiagnosisCTA, Icon, LESSON_PREVIEW, PUBLIC_ROOT } from "./shared";

export type PublicTeacherView = { id: string; name: string; specialties: string; photo?: string; headline: string; about: string };

const featureChoices = [
  ["path", "沿著路線學", "看見整體階段，回到正在上的這一課。每次打開，都知道自己的下一步。"],
  ["practice", "把方法練起來", "先拆解一個動作，再慢慢放回音樂裡。看完影片，不用自己猜怎麼練。"],
  ["feedback", "需要時，有人陪", "符合課程與 Pro 服務資格時，提交自己的練習影片，取得老師的下一步建議。"],
] as const;
const pathData = [
  { id: "start", label: "剛開始學", title: ["把一首喜歡的歌，", "完整彈下來。"], sub: "從和弦、節拍，到第一次流暢的伴奏。", image: "guitar", explain: ["先把基本動作接起來。", "以清楚的和弦、穩定的節拍，找到第一段能流暢彈完的音樂。"] },
  { id: "rhythm", label: "伴奏更豐富", title: ["讓你的伴奏，", "開始有變化。"], sub: "不再只剩同一種刷法，練出層次和表情。", image: "wide", explain: ["讓熟悉的歌，出現不同表情。", "從右手節奏和切音，練習同一段伴奏的不同變化。"] },
  { id: "understand", label: "想彈得更自由", title: ["知道自己在彈什麼，", "才能走得更自由。"], sub: "把和弦、調性與聽到的音樂慢慢接起來。", image: "guitar", explain: ["把學過的動作，連成理解。", "認識和弦與調性的關係，慢慢建立處理陌生歌曲的方向。"] },
];
const faqs = [
  ["完全沒學過吉他，也適合嗎？", "可以先從診斷開始，選最像自己現在狀況的答案。這份建議會幫你找起點，不是入學考試，也不會直接替你分級或認證。"],
  ["我已經會彈幾首歌，還能學什麼？", "可以從節奏、伴奏變化或音樂理解找到下一步。先看你卡在哪裡，再挑課程中的對應內容；不用為了跟上別人，全部從頭重來。"],
  ["錄播課、Pro 指導和一對一，有什麼不同？", "錄播課讓你依照路線自己學。Pro 是平台會員等級，符合課程與服務條件時，可以提交影片取得非同步指導；次數與資格依正式方案說明。線上一對一則是另外購買、預約與老師即時上課的服務。"],
  ["填完診斷，就一定要買課嗎？", "不用。先看學習建議，再決定要不要了解課程。這份 Demo 不收取款項，也不會自動升級會員、加入付費課程或送出聯絡資料。"],
  ["課程只能在電腦上看嗎？", "這份前端雛形同時安排了電腦與手機版面，你可以預覽已核准的學生空間。正式跨裝置登入與進度同步，仍需後端整合；本頁不會跨裝置同步你的答案。"],
  ["現在有提供實體上課嗎？", "這一階段以線上學習為主，一對一也採線上預約；目前不提供實體教室時段。"],
];

function PhonePreview() {
  return <div className="p5-phone"><div className="p5-phone-inside"><div className="p5-phone-top"><b style={{width:84,display:"flex"}}><BrandLogo size="small" /></b><i aria-hidden="true" /><span>課程預覽</span></div><div className="p5-phone-photo"><Asset alt="吉他練習概念影像，非真實師資照片" /><div className="p5-phone-caption"><small>GUITAR ROADMAP</small>把練習，<br />慢慢變成音樂。</div></div><div className="p5-phone-info"><div className="p5-overline">吉他學習地圖 · 課節示意</div><b>把切音放進伴奏</b><Link href={LESSON_PREVIEW}><Icon name="play" /> 看看上課畫面 <Icon name="right" /></Link></div></div></div>;
}

function FeatureView({ kind }: { kind: string }) {
  if (kind === "practice") return <><header><span>02</span><div>看懂之後，陪你練起來。<small>教學 → 拆解練習 → 跟著彈</small></div></header><div className="p5-practice-art"><Asset name="wide" alt="吉他練習的示意影像" /><div className="p5-counts" aria-label="四拍練習示意"><b>1</b><b>2</b><b>3</b><b>4</b></div></div><div className="p5-feature-path"><span><b>先聽</b>找到感覺</span><span><b>拆小</b>放慢動作</span><span><b>接起來</b>放進音樂</span></div><p className="p5-panel-caption">練習方法示意 · 不會自動計入完成或老師驗證</p></>;
  if (kind === "feedback") return <><header><span>03</span><div>練過，再知道下一步。<small>Pro · 支援指導的課程與合格服務</small></div></header><div className="p5-feedback-art"><small>學生提問 · 示意</small><div className="p5-feedback-question">「和弦單獨按得出來，但接起來就會停住。」</div><small>老師回饋 · 示意</small><div className="p5-feedback-answer">先不要急著彈完整首。<br />只留下兩個和弦，把速度放慢，<br />練習右手不要停下來。</div><span className="p5-feedback-tag">下一次，只專心做好一件事。</span></div><Link className="p5-link" href={`${PUBLIC_ROOT}/student/courses/c1/units/u1/guidance`}>了解影片指導 <Icon name="right" /></Link><p className="p5-panel-caption">指導方式示意，非真實學員評價；服務依課程、資格與可用額度提供。</p></>;
  return <><header><span>01</span><div>每一課，都知道自己在哪。<small>The One Guitar Roadmap 2.0</small></div></header><Asset name="lesson" alt="已核准的 The One 三欄錄播教室縮圖，僅為首頁預覽插圖" className="p5-feature-shot" /><div className="p5-feature-path"><span><b>Stage</b>目前階段</span><span><b>Lesson</b>正在上的課</span><span><b>Next</b>下一步</span></div><p className="p5-panel-caption">已核准教室的介面預覽；未替訪客加入課程或建立個人進度。</p></>;
}

function TeacherCard({ teacher }: { teacher: PublicTeacherView }) {
  const [imageFailed, setImageFailed] = useState(false);
  return <Link className="p6-teacher-card" href={`${PUBLIC_ROOT}/teachers/${encodeURIComponent(teacher.id)}?tab=private`} aria-label={`認識${teacher.name}，查看線上一對一課程`} data-testid="public-teacher-card" data-teacher-id={teacher.id}>
    <Asset src={teacher.photo} alt={teacher.photo ? `${teacher.name}的介紹照片` : "吉他影像示意，正式版替換為獲授權的老師照片"} onFailure={() => setImageFailed(true)} />
    <span className="p6-teacher-online"><Icon name="video" /> 線上一對一</span>{(!teacher.photo || imageFailed) && <span className="p6-teacher-photo-note">教學影像示意</span>}
    <div className="p6-teacher-info"><h3>{teacher.name}</h3><p className="p6-teacher-sub">{teacher.specialties}</p><span className="p6-teacher-action">認識老師與課程包 <i><Icon /></i></span></div>
  </Link>;
}

export function TeacherSection({ teachers }: { teachers: PublicTeacherView[] }) {
  return <section className="p6-teachers" id="p5-teacher" aria-labelledby="p6-teachers-title"><div className="p5-wrap"><div className="p6-teachers-head"><div className="p5-eyebrow">LEARN TOGETHER. ONE TO ONE.</div><h2 className="p5-title" id="p6-teachers-title">找一位懂你的老師，<br />把卡住的地方，一起練過去。</h2><p className="p5-desc">先認識教學方式，再選適合自己的一對一課程。<br />目前皆採線上上課，不用為了上課趕路。</p></div>
    {teachers.length ? <div className={`p6-teachers-layout ${teachers.length > 1 ? "many" : ""}`}><div className="p6-teacher-rail" aria-label="可認識的線上一對一老師">{teachers.map(teacher => <TeacherCard key={`${teacher.id}:${teacher.photo}`} teacher={teacher} />)}</div>{teachers.length === 1 && <div className="p6-teacher-companion"><h3>不是選最多堂。<br />是找到適合你的學法。</h3><p>每個人想練好的事情不同。<br />從你的目標出發，把每一堂都留給<br />真正需要一起解決的問題。</p><ol className="p6-teacher-steps"><li><b>01</b><span>看看老師的介紹與教學方式。</span></li><li><b>02</b><span>了解課程包，再決定學習安排。</span></li><li><b>03</b><span>確認時間，在線上和老師一起練。</span></li></ol><Link className="p5-link" href={`${PUBLIC_ROOT}/diagnosis`}>還沒方向？先做學習診斷 <Icon name="right" /></Link></div>}</div> : <div className="p6-teachers-empty">一對一師資介紹正在更新。<br />先透過診斷，整理你最想練好的問題。</div>}
    <p className="p6-teachers-footnote">目前展示已發布的老師示意資料；教學影像不是實際師資照片。只有經平台核准、公開展示且有公開一對一課程包的老師會出現在此處。未上架師資與指定學生報價不公開。</p>
  </div></section>;
}

export function PublicHome({ teachers, coursePublished }: { teachers: PublicTeacherView[]; coursePublished: boolean }) {
  const [feature, setFeature] = useState("path");
  const [path, setPath] = useState("start");
  const rail = useRef<HTMLDivElement>(null);
  function selectPath(id: string) {
    setPath(id);
    const card = rail.current?.querySelector<HTMLElement>(`[data-path="${id}"]`);
    if (card && rail.current && window.matchMedia("(max-width:600px)").matches) rail.current.scrollTo({ left: card.offsetLeft - rail.current.offsetLeft - (rail.current.clientWidth - card.clientWidth) / 2, behavior: window.matchMedia("(prefers-reduced-motion:reduce)").matches ? "auto" : "smooth" });
  }
  function tabKeys(event: KeyboardEvent<HTMLDivElement>, items: readonly string[], active: string, setter: (v: string) => void) {
    const index = items.indexOf(active);
    const next = event.key === "Home" ? 0 : event.key === "End" ? items.length - 1 : ["ArrowRight", "ArrowDown"].includes(event.key) ? (index + 1) % items.length : ["ArrowLeft", "ArrowUp"].includes(event.key) ? (index - 1 + items.length) % items.length : null;
    if (next === null) return;
    event.preventDefault(); setter(items[next]); event.currentTarget.querySelectorAll<HTMLButtonElement>('[role="tab"]')[next]?.focus();
  }
  const selectedPath = pathData.find(item => item.id === path)!;
  return <div className="p5-home" id="p5-home-main">
    <section className="p5-hero" aria-labelledby="p5-hero-title"><div className="p5-eyebrow">THE ONE · 樂玩吉他</div><h1 id="p5-hero-title">把喜歡的音樂，<br /><span>彈成自己的。</span></h1><p className="p5-hero-lead">清楚的學習路線、跟得上的練習，<br />需要時，再讓老師陪你突破卡點。</p><div className="p5-hero-cta"><DiagnosisCTA /></div><p className="p5-hero-promise">5 個小問題 · 不用登入 · 先找到適合你的下一步</p><div className="p5-stage"><PhonePreview /><div className="p5-float p5-float-left"><span className="p5-float-label">不用再猜下一步</span><h3>有路線，<br />就能安心往前。</h3><div className="p5-mini-steps" aria-hidden="true"><span>1</span><i /><span>2</span><i /><span>3</span></div><p>教學、練習、應用，一步一步來。</p></div><div className="p5-float p5-float-right"><div className="p5-float-icon"><Icon name="chat" /></div><h3>不是一個人，<br />卡在同一個地方。</h3><p>Pro 合格課程的影片指導，<br />幫你看見下一個練習重點。</p></div></div></section>
    <section className="p5-section p5-dark" id="p5-ways"><div className="p5-wrap"><div className="p5-centered"><h2 className="p5-title">找到方向，<br /><em>用適合你的方式學。</em></h2><p className="p5-desc">想照著路線自己練，或想和老師即時討論，<br />都從你現在的狀態開始。</p></div><div className="p5-service-grid">{coursePublished ? <Link className="p5-service" href={`${PUBLIC_ROOT}/courses/guitar-roadmap`}><Asset name="wide" alt="吉他學習概念影像" /><span className="p5-service-top">FLAGSHIP SYSTEM COURSE</span><h3>吉他學習地圖</h3><p>從基礎到伴奏與音樂理解，<br />走一條有順序的學習路線。</p><span className="p5-round"><Icon /></span></Link> : <div className="p5-service"><h3>課程正在準備</h3><p>可以先完成診斷，找到自己的學習方向。</p></div>}<a className="p5-service private" href="#p5-teacher"><span className="p5-service-top">LIVE ONLINE LESSONS</span><span className="p5-call-visual"><Asset alt="線上教學畫面示意" /></span><span className="p5-call-symbol"><Icon name="video" /></span><h3>線上一對一</h3><p>讓老師聽見你的問題，<br />把練習調整成更適合你的步伐。</p><span className="p5-round"><Icon /></span></a></div><p className="p5-service-note">吉他學習地圖是平台的旗艦系統課程；一對一課程包另外購買與預約，不包含在平台會員訂閱內。</p></div></section>
    <section className="p5-section p5-how" id="p5-how" aria-labelledby="p5-how-title"><div className="p5-wrap"><div className="p5-centered p5-center-head"><div className="p5-eyebrow">A CLEAR WAY TO LEARN</div><h2 className="p5-title" id="p5-how-title">不只是看懂，<br />更知道接著怎麼練。</h2><p className="p5-desc">把分散的影片，變成連得起來的學習。</p></div><div className="p5-how-grid"><div className="p5-feature-choices" role="tablist" aria-label="學習方式" onKeyDown={event => tabKeys(event, featureChoices.map(item => item[0]), feature, setFeature)}>{featureChoices.map(([key, title, description]) => <button className="p5-feature-choice" key={key} role="tab" id={`p5-tab-${key}`} aria-selected={feature === key} aria-controls="p5-feature-panel" tabIndex={feature === key ? 0 : -1} onClick={() => setFeature(key)}><h3>{title}</h3><p>{description}</p></button>)}</div><div className="p5-feature-panel" id="p5-feature-panel" role="tabpanel" aria-labelledby={`p5-tab-${feature}`} tabIndex={0}><FeatureView kind={feature} /></div></div></div></section>
    {coursePublished && <section className="p5-section p5-library" id="p5-roadmap"><div className="p5-wrap"><div className="p5-centered"><div className="p5-eyebrow">THE ONE GUITAR ROADMAP 2.0</div><h2 className="p5-title" style={{ marginTop: 15 }}>從你現在的程度，<br />再往前一步。</h2><p className="p5-desc">同一套吉他學習地圖，接住不同的學習起點。<br />先找到你最想練好的那件事。</p></div><div className="p5-path-tabs" role="tablist" aria-label="想探索的學習方向" onKeyDown={event => tabKeys(event, pathData.map(item => item.id), path, selectPath)}>{pathData.map(item => <button key={item.id} role="tab" id={`p5-path-tab-${item.id}`} aria-selected={path === item.id} aria-controls="p5-path-summary" tabIndex={path === item.id ? 0 : -1} onClick={() => selectPath(item.id)}>{item.label}</button>)}</div><div className="p5-paths" ref={rail}>{pathData.map(item => <button className="p5-path-card" key={item.id} data-path={item.id} onClick={() => selectPath(item.id)} aria-pressed={path === item.id} aria-label={`了解${item.label}的內容方向`}><Asset name={item.image} alt="吉他練習概念影像" /><span className="p5-path-top">吉他學習地圖 · 內容方向示意</span><h3>{item.title[0]}<br />{item.title[1]}</h3><p>{item.sub}</p><span className="p5-path-arrow">看看這個方向 <Icon /></span></button>)}</div><div className="p5-path-summary" id="p5-path-summary" role="tabpanel" aria-labelledby={`p5-path-tab-${path}`} tabIndex={0}><b>{selectedPath.explain[0]}</b> {selectedPath.explain[1]}</div><div className="p5-library-foot"><Link className="p5-link" href={`${PUBLIC_ROOT}/courses/guitar-roadmap`}>看看完整的學習路線 <Icon name="right" /></Link><p className="p5-library-note">這三張是同一套課程的內容方向，不是另外三門已上架課程，也不是正式階段分級。</p></div></div></section>}
    <TeacherSection teachers={teachers} />
    <section className="p5-device-section"><div className="p5-wrap p5-device-grid"><div className="p5-device-copy"><div className="p5-eyebrow">YOUR SPACE. YOUR PACE.</div><h2 className="p5-title">在你的節奏裡，<br />繼續學。</h2><p className="p5-desc">在電腦看教學，手機翻教材。<br />清楚的選單、看得懂的進度，<br />讓心力留給真正重要的練習。</p><Link className="p5-link" href={`${PUBLIC_ROOT}/student`}>預覽我的學習空間 <Icon /></Link><p className="p5-device-note">已核准學生介面的響應式版面預覽。正式跨裝置登入與進度同步尚需後端整合；Demo 不會跨裝置同步資料。</p></div><div className="p5-devices"><div className="p5-laptop"><Asset name="student" alt="已核准學生空間的電腦版預覽插圖" /></div><div className="p5-device-mobile"><Asset name="mobile" alt="已核准學生空間的手機版預覽插圖" /></div><Link className="p5-device-preview-btn" href={LESSON_PREVIEW}>打開已核准錄播教室 <Icon /></Link></div></div></section>
    <section className="p5-faq-section" id="p5-faq"><div className="p5-centered"><h2 className="p5-title">開始前，<br />你可能想知道。</h2></div><div className="p5-faq-list">{faqs.map(([q, a]) => <details key={q}><summary>{q}<span aria-hidden="true" /></summary><p>{a}</p></details>)}</div></section>
    <section className="p5-final"><h2 className="p5-title">你的下一步，<br />從這裡開始。</h2><p>不用急著選課。先讓我們多認識你一點。</p><DiagnosisCTA className="ink" /></section>
  </div>;
}
