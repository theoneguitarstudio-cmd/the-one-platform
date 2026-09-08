"use client";
import Link from "next/link";
import { useRef, useState } from "react";
import { learningPreview } from "@/lib/preview/learning";
import { Progress, ResourceRow } from "./ui";
type Lesson = typeof learningPreview.lessons[number];
const segments = ["課程影片", "文字教材", "練習 1", "練習 2", "合奏練習"] as const;
function CourseOutline({ lesson, marked }: { lesson: Lesson; marked: boolean }) {
  return <nav aria-label="目前課程目錄" className="course-outline">
    <div className="outline-heading"><small>SYSTEM COURSE</small><h2>{learningPreview.course}</h2><Link href="/student/map">← 學習地圖 / 課程總覽</Link></div>
    <details open className="outline-stage"><summary><small>Stage 1</small><strong>節奏與第一首歌</strong></summary><p>{learningPreview.stages[0]}</p><Progress value={38} label="階段進度（示範）"/><h3>Module 1 · 聽見節奏</h3>
      {learningPreview.lessons.map((item,i) => item.state === "locked" ? <div className="outline-lesson locked" key={item.id}><span>0{i+1}</span><div>{item.title}<small>尚未解鎖</small></div><span aria-label="尚未解鎖">◇</span></div> : <Link className="outline-lesson" key={item.id} href={"/student/learn/"+item.id} aria-current={item.id===lesson.id ? "page" : undefined}><span>0{i+1}</span><div>{item.title}<small>{item.minutes} 分鐘 · {item.id===lesson.id && marked ? "本頁已練習" : item.state==="completed" ? "已練習（示範）" : item.id===lesson.id ? "目前課節" : "接下來"}</small></div><span aria-hidden="true">{item.state==="completed" || (item.id===lesson.id && marked) ? "✓" : "▷"}</span></Link>)}
    </details>
    <div className="outline-future"><small>接下來的學習方向</small>{learningPreview.stages.slice(1).map((title,i)=><Link key={title} href="/student/map"><small>Stage {i+2} · 查看成果方向</small><span>{title}</span></Link>)}</div>
    <p className="outline-disclaimer">課節與狀態為示範。觀看影片不代表能力通過。</p>
  </nav>;
}
function TextMaterial({ lesson }: { lesson: Lesson }) {
  return <section className="text-material"><p className="eyebrow">LEARNING NOTES / 示範教材</p><h2>{lesson.title}</h2><p>{lesson.objective}</p><p>先把注意力放在聲音的連續性，而不是速度。讓身體跟著穩定的脈動擺動，再把手上的動作放進同一個節奏。</p><h3>先聽，再動手</h3><ul><li>先聽一段熟悉的音樂，用手輕拍四個穩定的拍點。</li><li>保持呼吸自然；感覺緊繃時，先停下來放鬆。</li><li>不需要追趕原曲速度，從能夠穩定重複的速度開始。</li></ul><div className="rhythm-diagram" aria-label="四個均勻拍點示意">{[1,2,3,4].map(n=><div key={n}><span>↓</span><strong>{n}</strong><small>拍</small></div>)}</div><h3>把動作放回音樂</h3><p>在心裡持續數拍，試著完成四個小節。發現停頓時，記住發生的位置，再縮小練習範圍。</p><blockquote>今天只需要比上一次更穩定一點。</blockquote><h3>練習後，問問自己</h3><ul><li>能不能在不中斷節拍的情況下完成這一小段？</li><li>哪個動作最容易讓身體緊繃？</li><li>下次練習想先調整什麼？</li></ul><p className="material-note">原創 Mock 教材，不是正式 curriculum 或能力驗證。</p></section>;
}
export function LessonWorkspace({ lesson }: { lesson: Lesson }) {
  const [segment,setSegment]=useState(0);
  const [marked,setMarked]=useState(false);
  const scrollRef=useRef<HTMLDivElement>(null);
  function selectSegment(value: number) {
    setSegment(value);
    scrollRef.current?.scrollTo({ top: 0, behavior: "instant" });
    if (window.matchMedia("(max-width: 760px)").matches) scrollRef.current?.scrollIntoView({ block: "start", behavior: "instant" });
  }
  const index=learningPreview.lessons.findIndex(x=>x.id===lesson.id);
  const previous=learningPreview.lessons[index-1],next=learningPreview.lessons[index+1];
  return <main className="immersive-workspace">
    <aside className="outline-desktop"><CourseOutline lesson={lesson} marked={marked}/></aside>
    <div className="lesson-center">
      <div className="lesson-scroll" ref={scrollRef}>
        <details className="outline-mobile"><summary>課程目錄 · Stage 1</summary><CourseOutline lesson={lesson} marked={marked}/></details>
        <header className="immersive-title"><Link href="/student/map">學習地圖</Link><span> / Stage 1 / Module 1</span><h1>Lesson {index+1} · {lesson.title}</h1></header>
        <div className="lesson-segments" role="tablist" aria-label="課節內容">{segments.map((label,i)=><button key={label} role="tab" id={"segment-"+i} aria-controls="lesson-panel" aria-selected={segment===i} tabIndex={segment===i?0:-1} onClick={()=>selectSegment(i)} onKeyDown={e=>{if(["ArrowLeft","ArrowRight","Home","End"].includes(e.key)){e.preventDefault();const n=e.key==="Home"?0:e.key==="End"?segments.length-1:(i+(e.key==="ArrowRight"?1:segments.length-1))%segments.length;selectSegment(n);document.getElementById("segment-"+n)?.focus();}}}>{label}</button>)}</div>
        <div id="lesson-panel" role="tabpanel" aria-labelledby={"segment-"+segment} tabIndex={0}>
          {segment===1 ? <TextMaterial lesson={lesson}/> : <><div className="immersive-video" aria-label="影片佔位區，尚無實際影片"><span className="video-label">THE ONE / {segment===0 ? "LESSON" : "PRACTICE"}</span><span className="play-symbol" aria-hidden="true">▷</span><h2>{segment===0 ? lesson.title : segments[segment]}</h2><p>影片準備中 · Mock Preview</p><div className="video-controls"><span>00:00</span><div/><span>— : —</span></div></div>{segment===0 ? <section className="lesson-summary"><h2>這一課，我想做到</h2><p>{lesson.objective}</p><button className="text-link" onClick={()=>selectSegment(1)}>閱讀文字教材 →</button></section> : <section className="exercise-material"><h2>{segment===2 ? "讓每個拍點一樣穩定" : segment===3 ? "把和弦接進節奏裡" : "把今天的練習放回音樂"}</h2><p>{segment===2 ? "慢慢數出 1、2、3、4，讓右手持續擺動，連續練習四個小節。" : segment===3 ? "用兩個熟悉的和弦練習轉換。遇到停頓時，先把速度放慢。" : "選一小段熟悉的歌曲，穩定演奏後，再回想哪個動作可以更放鬆。"}</p><div className="rhythm-diagram" aria-label="靜態節奏示意，不播放音訊">{[1,2,3,4].map(n=><div key={n}><span>↓</span><strong>{n}</strong><small>拍</small></div>)}</div><small>靜態練習示意；無音訊、影片或正式進度寫入。</small></section>}</>}
          <section className="immersive-resources"><h2>學習資源</h2><ResourceRow kind="PDF" title="練習筆記" detail="教材位置展示"/><ResourceRow kind="♫" title="示範音檔" detail="聆聽與練習"/><ResourceRow kind="▶" title="伴奏音軌" detail="歌曲應用"/></section>
        </div>
      </div>
      <footer className="lesson-action-bar">
        {segment>0 ? <button onClick={()=>selectSegment(segment-1)}>← 上一個</button> : previous ? <Link href={"/student/learn/"+previous.id}>← 上一課</Link> : <Link href="/student/map">← 課程總覽</Link>}
        <button className="practice-mark" aria-pressed={marked} onClick={()=>setMarked(!marked)}>{marked ? "✓ 已練習（本頁）" : "標記已練習"}</button>
        {segment<segments.length-1 ? <button onClick={()=>selectSegment(segment+1)}>下一個 →</button> : next && next.state!=="locked" ? <Link href={"/student/learn/"+next.id}>下一課 →</Link> : <span className="locked-next">下一課尚未解鎖</span>}
        <p role="status">{marked ? "僅本頁暫記；重新載入清除，不代表通過能力驗證。" : "示範練習狀態，不保存正式進度。"}</p>
      </footer>
    </div>
  </main>;
}
