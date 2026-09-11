"use client";
import { BrandLogo } from "@/components/brand-logo";

import Link from "@/components/platform-experience/link";
import { useSearchParams } from "next/navigation";
import { useRouter } from "@/components/platform-experience/link";
import { useEffect, useRef, useState } from "react";
import { Icon, lessonHref, lessonVisuals, modules, studentHref, studentNav } from "../student/reference";
import { useStudentLearning } from "../student/use-student-learning";
import "./lesson.css";

const activities = [
  { id: "learn", title: "教學", desc: "先理解這個動作", hero: null },
  { id: "practice", title: "練習一", desc: "慢速拆解", hero: ["先慢，", "再連起來。"] },
  { id: "apply", title: "練習二", desc: "節奏變化", hero: ["換一種，", "伴奏表情。"] },
  { id: "jam", title: "跟伴奏彈", desc: "放進音樂裡", hero: ["現在，", "一起彈。"] },
];

export function LessonPage({ segments }: { segments: string[] }) {
  const router = useRouter();
  const search = useSearchParams();
  const learning = useStudentLearning();
  const lessonId = segments[segments.indexOf("lessons") + 1] || "l3";
  const index = Math.max(0, lessonVisuals.findIndex(item => item.id === lessonId));
  const lesson = lessonVisuals[index];
  const activityId = search.get("activity") || "learn";
  const unlocked = learning.membership !== "free";
  const requestedActivity = activities.find(item => item.id === activityId) || activities[0];
  const blockedActivity = requestedActivity.id !== "learn" && !unlocked;
  const activity = blockedActivity ? activities[0] : requestedActivity;
  const hero = activity.hero || lesson.hero;
  const [wide, setWide] = useState(false);
  const [hidden, setHidden] = useState(false);
  const [drawer, setDrawer] = useState(false);
  const [notice, setNotice] = useState("");
  const [comment, setComment] = useState("");
  const [lockLabel, setLockLabel] = useState("");
  const main = useRef<HTMLElement>(null);
  const outline = useRef<HTMLElement>(null);
  const access = useRef<HTMLDialogElement>(null);
  const opener = useRef<HTMLElement | null>(null);

  const validLesson = lessonVisuals.some(item => item.id === lessonId) && segments[1] === "c1";
  const { visitLesson, progress } = learning;
  useEffect(() => { if (validLesson && (progress?.lessonId !== lesson.id || progress?.activity !== activity.id)) visitLesson(lesson.id, activity.id); }, [validLesson, lesson.id, activity.id, progress?.lessonId, progress?.activity, visitLesson]);
  useEffect(() => { if (!notice) return; const id = setTimeout(() => setNotice(""), 5500); return () => clearTimeout(id); }, [notice]);
  useEffect(() => { if (lockLabel) access.current?.showModal(); }, [lockLabel]);
  useEffect(() => { if (blockedActivity) access.current?.showModal(); }, [blockedActivity]);
  useEffect(() => {
    if (!drawer) {
      const target = opener.current;
      opener.current = null;
      target?.focus();
      return;
    }
    const close = () => setDrawer(false);
    outline.current?.querySelector<HTMLButtonElement>("button")?.focus();
    const key = (event: KeyboardEvent) => {
      if (event.key === "Escape") { event.preventDefault(); close(); }
      if (event.key === "Tab") {
        const items = Array.from(outline.current?.querySelectorAll<HTMLElement>("button,summary,a[href]") || []).filter(el => el.getClientRects().length);
        const first = items[0]; const last = items.at(-1);
        if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
        if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
      }
    };
    const resize = () => { if (window.innerWidth > 1000) close(); };
    document.addEventListener("keydown", key); window.addEventListener("resize", resize);
    return () => { document.removeEventListener("keydown", key); window.removeEventListener("resize", resize); };
  }, [drawer]);

  function openOutline() {
    if (window.innerWidth <= 1000) { opener.current = document.activeElement as HTMLElement; setDrawer(true); }
    else setHidden(false);
  }
  function closeOutline() { if (drawer) setDrawer(false); else setHidden(true); }
  function selectLesson(id: string) { setDrawer(false); setComment(""); router.push(lessonHref(id)); main.current?.scrollTo({ top: 0 }); }
  function selectActivity(id: string, title: string) { if (id !== "learn" && !unlocked) { setLockLabel(title); return; } router.push(lessonHref(lesson.id, id), { scroll: false }); main.current?.scrollTo({ top: 0 }); }
  function resource(label: string) { if (!unlocked) setLockLabel(label); else setNotice("此處只展示教材入口，沒有實際教材檔或音檔可開啟。"); }
  const playerNotice = () => setNotice("這是 16:9 播放器版位，尚未載入影片或播放器服務。播放控制僅為外觀示意。");
  const comments = learning.comments.filter(item => item.lessonId === lesson.id);

  if (!validLesson) return <div className="ux-lesson"><article className="lesson-reading"><h1>找不到這個課節</h1><p>請從已存在的課程與課節重新進入。</p><Link className="yellow-button" href={studentHref("courses")}>回到我的課程</Link></article></div>;
  return <div className="ux-lesson" data-testid="lesson-surface">
    <div className={`app${wide ? " rail-wide" : ""}${hidden ? " outline-hidden" : ""}${drawer ? " drawer-open" : ""}`}>
      <nav className="rail" aria-label="學生空間站" inert={drawer}>
        <Link href={studentHref()} className="brand" aria-label="The One"><BrandLogo compact={!wide} size="small" /></Link>
        <div className="rail-nav">{studentNav.map(([route, icon, title]) => <Link key={route} className={`nav-button${route === "courses" ? " current" : ""}`} href={studentHref(route)} aria-label={title}><Icon name={icon} /><span className="nav-label">{title}</span><span className="nav-tip" aria-hidden="true">{title}</span></Link>)}</div>
        <div className="rail-space" /><div className="rail-bottom"><Link className="nav-button" href={studentHref("settings")} aria-label="設定"><Icon name="settings" /><span className="nav-label">設定</span><span className="nav-tip">設定</span></Link><Link className="nav-button profile" href="/ux-prototype/account" aria-label="個人帳號"><span className="profile-dot">你</span><span className="nav-label">我的帳號</span></Link><button className="nav-button rail-collapse" onClick={() => setWide(!wide)} aria-expanded={wide} aria-label={wide ? "收合學生空間站選單" : "展開學生空間站選單"}><Icon name="expand" /><span className="nav-label">收合選單</span><span className="nav-tip">展開選單</span></button></div>
      </nav>
      <div className={`drawer-shade${drawer ? " show" : ""}`} aria-hidden="true" onClick={closeOutline} />
      <aside className="outline" ref={outline} aria-label="課程章節與單元" role={drawer ? "dialog" : undefined} aria-modal={drawer || undefined}>
        <div className="course-head"><div className="course-title-row"><div className="course-emblem" aria-hidden="true">1</div><div className="course-title-grow"><h2 className="course-title">The One<br />Guitar Roadmap 2.0</h2><div className="course-sub">吉他學習地圖 · 系統課程</div></div><button className="outline-close" onClick={closeOutline} aria-label="收合課程章節"><Icon name="collapse" /></button></div><Link className="overview-button" href={`${studentHref("map")}?stage=2&lesson=${lesson.id}`}><span>回到完整學習地圖</span><Icon name="arrowUpRight" /></Link></div>
        <div className="outline-scroll"><section className="stage-header"><div className="stage-label">STAGE 2</div><h3 className="stage-heading">讓伴奏不再只有一種</h3><p className="stage-copy">從穩定的拍子開始，練習停音、留白，<br />再把節奏放進一首歌裡。</p>{learning.enrolled ? <><div className="progress-track"><span style={{ width: `${learning.done.length / 6 * 100}%` }} /></div><div className="progress-caption">自報完成 {learning.done.length} / 6 課 · 示意</div></> : <p className="progress-caption">課程預覽 · 尚未加入，不顯示個人進度</p>}</section>
          {modules.map((name, moduleIndex) => <details className="module" key={`${name}-${lesson.module}`} open={lesson.module === moduleIndex}><summary>{name}<Icon name="down" /></summary><div className="lesson-list">{lessonVisuals.filter(item => item.module === moduleIndex).map(item => { const num = lessonVisuals.indexOf(item); const done = learning.done.includes(item.id); return <button className={`lesson-item${item.id === lesson.id ? " active" : ""}`} key={item.id} aria-current={item.id === lesson.id ? "page" : undefined} onClick={() => selectLesson(item.id)}><span className="lesson-no">{String(num + 1).padStart(2, "0")}</span><span className="lesson-name">{item.title}<span className="lesson-meta">{item.id === lesson.id ? "目前這一課" : done ? "已自報完成" : item.note}</span></span><Icon name={item.id === lesson.id ? "playOutline" : done ? "check" : "circle"} className="lesson-state" /></button>; })}</div></details>)}
          <p className="outline-note">本稿只呈現代表性課節，不是正式課綱。<br />尚未開始，不代表沒有存取權限。</p></div>
      </aside>
      <div className="mobile-top" inert={drawer}><Link className="mobile-brand" href={studentHref()}><BrandLogo size="small" /></Link><button onClick={openOutline} aria-label="開啟課程章節" aria-expanded={drawer}><Icon name="outline" />課程章節</button></div>
      <main className="lesson-main" ref={main} inert={drawer} aria-label="錄播上課內容"><div className="lesson-wrap"><div className="lesson-content-top"><header className="lesson-head"><div className="crumb-row"><div className="crumb"><button className="chapter-trigger" onClick={openOutline} aria-expanded={drawer}><Icon name="outline" />課程章節</button><span>Stage 2</span><span className="sep">/</span><span>{modules[lesson.module]}</span><span className="sep">/</span><span>第 {index + 1} 課</span></div><button className="more-btn" aria-label="更多課程操作" onClick={() => setNotice("可從學生設定切換 Mock 會員情境，教室固定保持核准深色。") }><Icon name="more" /></button></div><div className="heading-row"><h1>{String(index + 1).padStart(2, "0")}｜{lesson.title}</h1><span className="lesson-heading-note">課程內容示意</span></div></header>
        <nav className="activity-nav" aria-label="這一課的學習步驟">{activities.map(item => { const locked = item.id !== "learn" && !unlocked; return <button key={item.id} className={`activity${activity.id === item.id ? " selected" : ""}${locked ? " locked" : ""}`} onClick={() => selectActivity(item.id, item.title)} aria-current={item.id === activity.id ? "step" : undefined} aria-label={`${item.title}${locked ? "，示意尚未解鎖，查看說明" : ""}`}><span className="activity-label">{(locked || item.id === activity.id) && <Icon name={locked ? "lock" : "check"} />}{item.title}{locked && <span className="badge">Plus 示意</span>}</span><span className="activity-desc">{item.desc}</span></button>; })}</nav>
        <section className="video-demo" role="region" aria-label="16 比 9 教學影片位置示意，未載入影片"><div className="video-top"><span className="video-brand"><BrandLogo size="small" /></span><span>LEARN · PRACTICE · PLAY</span></div><div className="video-content"><div><div className="video-kicker">GUITAR ROADMAP / {activity.id === "learn" ? `LESSON ${String(index + 1).padStart(2, "0")}` : activity.desc}</div><div className="video-title">{hero[0]}<br />{hero[1]}</div><p className="video-note">影片位置示意 · 正式版放入自有教學影像</p></div><button className="play-circle" onClick={playerNotice} aria-label="查看播放區示意說明"><Icon name="play" /></button></div><div className="video-bottom"><div className="video-line"><span /></div><div className="video-controls"><button onClick={playerNotice} aria-label="播放示意"><Icon name="play" /></button><span className="small">00:00 / —</span><button onClick={playerNotice} aria-label="音量示意"><Icon name="volume" /></button><span className="controls-spacer" /><button className="small" onClick={playerNotice} aria-label="播放速度示意">1×</button><button className="optional-control" onClick={playerNotice} aria-label="字幕示意"><Icon name="captions" /></button><button onClick={playerNotice} aria-label="全螢幕示意"><Icon name="fullscreen" /></button></div></div></section><p className="video-caption">這是播放器版位，不會播放影片。上方切換的是同一課的學習內容，不是另一套課程。</p></div>
        <article className="lesson-reading"><div className="section-eyebrow">LESSON NOTES</div><h2>{activity.id === "learn" ? "這一課，讓聲音停下，節拍不停。" : activity.id === "practice" ? "先把一個動作拆開，慢慢練。" : activity.id === "apply" ? "用同一個和弦，試試不同的節奏。" : "讓剛才的練習，變成音樂的一部分。"}</h2><p>{activity.id === "learn" ? "先不用急著變換和弦。用你最熟悉的和弦，把注意力放在右手：讓聲音有停頓，但心裡的拍子仍然繼續往前。" : `這裡展示「${activity.title}」對應的文字、圖解與資源。你仍在「${lesson.title}」這一課裡，不需要重新尋找課程位置。`}</p><p>看完示範後，跟著下面的節奏慢慢試一次。這些文字、譜例與練習提示，就放在影片下方，不需要再開另一個頁面。</p><figure className="music-sheet" aria-label="四拍節奏排版示意：第一拍彈、第二拍停、第三拍彈、第四拍停"><div className="sheet-head"><strong>01 / 先練習留白</strong><span>四拍節奏 · 排版示意</span></div><div className="beats"><div className="sheet-line" />{[1, 2, 3, 4].map(n => <div key={n} className={`beat${n % 2 === 0 ? " mute" : ""}`}><strong>{n}</strong><span>{n % 2 ? "彈" : "停"}</span></div>)}</div><div className="sheet-foot">琴弦可以停下，心裡的拍子繼續往前。</div></figure><aside className="teacher-tip">練習提醒：先選一個舒服的速度，讓每一拍都有位置。慢一點沒有關係，先把動作連起來。</aside><h3>拿起吉他，照這個順序試一次</h3><ol className="practice-lines"><li>先只數拍子，讓右手保持規律的上下動作。</li><li>加入停音的位置，留意右手有沒有跟著停住。</li><li>再切換上方的練習或伴奏，把動作放進音樂。</li></ol><section className="resources" aria-label="本課教材與資源"><h3>本課教材與資源</h3>{[["file", "節奏圖解與練習提示", "教材位置示意 · 未提供實際檔案"], ["audio", "跟著節拍，練習留白", "伴奏音檔位置示意 · 未載入音檔"]].map(([icon, title, note]) => <div key={title} className="resource-row"><span className="resource-icon"><Icon name={icon} /></span><div className="resource-title">{title}<small>{note}</small></div><button onClick={() => resource(title)}>{unlocked ? <>查看示意<Icon name="arrowUpRight" /></> : <><Icon name="lock" />Plus 示意</>}</button></div>)}</section><div className="lesson-actions"><button className="secondary-button" disabled={index === 0} onClick={() => selectLesson(lessonVisuals[index - 1].id)}><Icon name="left" />上一課</button><button className={`complete-button${learning.done.includes(lesson.id) ? " completed" : ""}`} aria-pressed={learning.done.includes(lesson.id)} onClick={() => { const result = learning.toggleComplete(lesson.id); setNotice(result); }}><Icon name={learning.done.includes(lesson.id) ? "check" : "circle"} />{learning.done.includes(lesson.id) ? "已自報完成 · 可取消" : "標記自己完成"}</button><button className="next-button" onClick={() => index === 5 ? main.current?.scrollTo({ top: 0 }) : selectLesson(lessonVisuals[index + 1].id)}>{index === 5 ? "回看本課" : "下一課"}<Icon name="right" /></button></div><p className="progress-note">「下一課」只切換內容，不自動算完成。自報完成也不等於老師驗證；本機共享示意狀態，重新整理後清除。</p></article>
        <section className="discussion" aria-labelledby="lesson-discussion-title"><div className="section-eyebrow">ASK · SHARE · LEARN</div><div className="discussion-heading"><h2 id="lesson-discussion-title">這一課，一起聊聊</h2><span className="count">{comments.length + 2} 則提問 · 示意</span></div><p className="discussion-intro">卡在哪一個動作？把問題留在這裡，老師的回覆會接在你的提問下面。</p><form className="comment-form" onSubmit={event => { event.preventDefault(); if (!comment.trim()) return; const result = learning.addComment(lesson.id, comment.trim()); if (result.ok) setComment(""); setNotice(result.ok ? "已加入本機示意提問，沒有傳送通知；重新整理後清除。" : result.error || "無法新增提問。"); }}><div className="avatar" aria-hidden="true">你</div><div className="comment-compose"><label className="sr-only" htmlFor="lesson-comment">新增本機示範提問</label><textarea id="lesson-comment" maxLength={1000} value={comment} onChange={event => setComment(event.target.value)} placeholder="例如：切音之後，右手常常來不及回到下一拍…" required /><div className="composer-actions"><span>只新增本機示意，不會傳送給老師。<br />重新整理頁面後即清除。</span><button className="yellow-button" type="submit">試著提問</button></div></div></form>
          {comments.map(item => <Thread key={item.id} avatar="你" name="你 · 本機示意" text={item.text} />)}<Thread avatar="A" name="同學 A" text="切音的時候，我會不小心把右手也停住，應該先分開練嗎？" reply="可以先把動作放慢，暫時不急著換和弦。先確認停音之後，右手還能回到下一拍。這是一則回覆版位示意。" /><Thread avatar="B" name="同學 B" text="文字教材和影片放在一起，練習時比較容易找到剛才說的重點。" /><p className="discussion-footer">課內問答的可見範圍、發問資格與回覆安排尚待確認；此區不等於私人訊息、正式作業批改或能力驗證。<br />本頁所有課名、教材、進度、人物與留言均為示意。未連接會員、付款、影片或資料庫服務。</p></section>
      </div></main>
    </div>
    {notice && <div className="toast" role="status">{notice}</div>}
    <dialog ref={access} aria-labelledby="lesson-access-title" onClose={() => { setLockLabel(""); if (blockedActivity) router.replace(lessonHref(lesson.id)); }}><div className="dialog-icon"><Icon name="lock" /></div><h2 id="lesson-access-title">這個內容尚未解鎖</h2><p>「{lockLabel || requestedActivity.title}」在這個 Free 示範情境中尚未開放。你可以到學生設定的本機情境工具切換 Plus 或 Pro，比較解鎖後的外觀；這不會升級帳號或產生費用。</p><p className="dialog-note">僅示範這套課程已被納入相應方案時的外觀。正式存取仍由會員方案、課程政策與實際權限決定。</p><button className="yellow-button" onClick={() => access.current?.close()}>知道了，繼續上課</button></dialog>
  </div>;
}

function Thread({ avatar, name, text, reply }: { avatar: string; name: string; text: string; reply?: string }) {
  return <article className="thread"><div className="thread-top"><div className="avatar">{avatar}</div><div className="thread-body"><div className="byline"><strong>{name}</strong><span>示範內容</span></div><p>{text}</p></div></div>{reply && <div className="reply"><div className="avatar teacher">師</div><div className="thread-body"><div className="byline"><strong>老師回覆</strong><span>示範內容</span></div><p>{reply}</p></div></div>}</article>;
}
