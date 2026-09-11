"use client";

import Link from "@/components/platform-experience/link";
import { useSearchParams } from "next/navigation";
import { useRouter } from "@/components/platform-experience/link";
import { useState } from "react";
import { diagnosisRecommendation } from "@/modules/ux-prototype/model";
import { usePrototype } from "@/modules/ux-prototype/store";
import { Icon, PUBLIC_ROOT } from "./shared";
import styles from "./public.module.css";

const questions = [
  { title: "你現在，和吉他有多熟？", sub: "不用考試，也不用選得很精準。挑一個最像現在的你。", options: [["new", "我才剛開始", "甚至還不太知道怎麼練"], ["chords", "會幾個和弦，但接不順", "想把一首歌完整彈下來"], ["songs", "可以彈歌，想有更多變化", "伴奏常常只剩同一種"], ["express", "想更自由地演奏", "想理解、改編與表達自己"]] },
  { title: "最近最想做到哪件事？", sub: "先選一個，讓練習有清楚的方向。", options: [["song", "完整彈完一首喜歡的歌", "先讓音樂流動起來"], ["rhythm", "讓伴奏更好聽、更有變化", "找到節奏與表情"], ["theory", "知道自己到底在彈什麼", "把和弦與音樂理解接起來"], ["freedom", "離開譜，也能試著彈", "練習自己的音樂語言"]] },
  { title: "一次，想留多少時間給自己？", sub: "可以很短。選你現在做得到的就好，不是承諾每天一定完成。", options: [["10", "大約 10 分鐘", "先養成打開吉他的習慣"], ["20", "大約 20 分鐘", "夠拆解一個小問題"], ["30", "30 分鐘左右", "慢慢深入一個主題"]] },
  { title: "哪一件事，最容易讓你卡住？", sub: "找到卡點，不是替你貼上程度標籤。", options: [["direction", "不知道下一步練什麼", "影片看很多，路線還不清楚"], ["hands", "手跟不上腦中的聲音", "和弦、切音或指法接不起來"], ["beat", "常常跟不上節奏", "單獨練可以，合起來就亂了"], ["understand", "遇到陌生歌曲就沒方向", "想看懂和弦與調性的關係"]] },
  { title: "你喜歡怎麼被陪著練？", sub: "這只影響建議，不會替你購買或升級任何方案。", options: [["self", "給我路線，我想先自己練", "結構化內容與練習方法"], ["review", "我想知道，自己有沒有練對", "有資格時提交影片，讓老師回饋"], ["private", "我想跟老師即時討論", "線上一對一，聚焦自己的卡點"]] },
];

function quizUrl(answers: string[], step?: number) {
  const query = new URLSearchParams({ answers: answers.join(",") });
  if (step !== undefined) query.set("step", String(step));
  return `${PUBLIC_ROOT}/diagnosis${step === undefined ? "/result" : ""}?${query}`;
}

export function Diagnosis({ result = false }: { result?: boolean }) {
  const query = useSearchParams();
  const router = useRouter();
  const { state, studentId, setActor, dispatch } = usePrototype();
  const [message, setMessage] = useState("");
  const rawAnswers = query.get("answers")?.split(",") ?? [];
  const answers = questions.map((question, index) => question.options.some(option => option[0] === rawAnswers[index]) ? rawAnswers[index] : "");
  const requestedStep = Number(query.get("step") ?? 0);
  const firstMissing = answers.findIndex(answer => !answer);
  const step = Math.min(Number.isInteger(requestedStep) ? Math.max(0, Math.min(4, requestedStep)) : 0, firstMissing < 0 ? 4 : firstMissing);
  const question = questions[step];
  function answer(value: string) {
    const next = [...answers]; next[step] = value;
    router.replace(quizUrl(next, step), { scroll: false });
  }
  function join() {
    setActor({ role: "student", id: studentId });
    const student = state.students.find(item => item.id === studentId);
    if (!student?.joinedCourseIds.includes("c1")) {
      const outcome = dispatch({ type: "joinCourse", studentId, courseId: "c1" });
      if (!outcome.ok) { setMessage(outcome.error ?? "目前無法加入，請稍後再試。"); return; }
    }
    router.push(`${PUBLIC_ROOT}/student/courses`);
  }
  if (result && firstMissing >= 0) return <div className="v4-quiz-shell"><h1>先讓我們多認識你一點。</h1><p className={styles.note}>完成五個小問題後，才會出現這份方向建議。</p><Link className="v4-public-btn" href={quizUrl(answers, firstMissing)}>繼續診斷 <Icon /></Link></div>;
  if (result) {
    const recommendation = diagnosisRecommendation(answers);
    const joined = state.students.find(item => item.id === studentId)?.joinedCourseIds.includes("c1");
    return <div className="v4-quiz-shell"><span className="v4-public-eyebrow">A SMALL NEXT STEP, JUST FOR YOU.</span><h1 className="v4-quiz-title">{recommendation.focus}。</h1><p className="v4-quiz-sub">根據你剛才的選擇，我們建議先從「{recommendation.entry}」找一個小課節開始。<br />這是自我描述形成的學習建議，不是實力驗證或正式 Stage 分級。</p><div className="v4-answer-recap">{answers.map((value, index) => <span key={index}>{questions[index].options.find(option => option[0] === value)?.[1]}</span>)}</div><div className="v4-result"><section className="v4-result-plan"><span className="v4-public-eyebrow">TODAY / ABOUT {recommendation.mins} MINUTES</span><h2>今天，先這樣練。</h2><p>這份練習是診斷結果示意，正式內容應對應已發布的教材。</p><div className="v4-result-practice">{recommendation.practice.map((text, index) => <div key={text}><b>{recommendation.parts[index]}′</b><span>{text}</span></div>)}</div></section><section className="v4-result-choice"><span className="v4-public-eyebrow" style={{ color: "#aaa48b" }}>目前推薦的旗艦系統課程</span><h3>The One<br />Guitar Roadmap 2.0</h3><p>建議入口：{recommendation.entry}<br />{recommendation.support === "review" ? "你偏好有人回饋。可再了解合格課程的 Pro 影片指導，不會自動升級。" : recommendation.support === "private" ? "你偏好即時討論。可另外了解線上一對一，不與平台會員綁在一起。" : "你偏好自己練。先看課程路線與教學內容，再選擇適合的學習方式。"}</p><Link className="v4-public-btn yellow" href={`${PUBLIC_ROOT}/courses/guitar-roadmap`}>看看這套學習路線 <Icon /></Link></section></div><div className="v4-quiz-bottom"><Link className="v4-public-link" href={quizUrl(answers, 0)}>重新調整答案</Link><button className="v4-public-btn" onClick={join}>{joined ? "查看已加入的示意狀態" : "加入我的學習空間（示意）"}<Icon /></button></div>{recommendation.support === "private" && <Link className="v4-public-link" href={`${PUBLIC_ROOT}#p5-teacher`} style={{ marginTop: 18 }}>另外認識線上一對一老師 <Icon name="right" /></Link>}{message && <p role="alert" className={styles.note}>{message}</p>}<p className={styles.note}>推薦 ≠ 已加入；加入 ≠ 已付款或升級。診斷不會替你解鎖課程，也不會產生老師驗證或正式證書。答案僅保存在此本機網址中。</p></div>;
  }
  return <div className="v4-quiz-shell"><div className="v4-quiz-head"><Link className="v4-public-link" href={PUBLIC_ROOT}><Icon name="left" /> 回首頁</Link><span className="v4-public-eyebrow">你的學習方向 / {step + 1} OF 5</span></div><div className="v4-quiz-progress" role="progressbar" aria-label="診斷進度" aria-valuemin={0} aria-valuemax={5} aria-valuenow={step + 1}><span style={{ width: `${(step + 1) * 20}%` }} /></div><span className="v4-public-eyebrow">LET’S START WITH YOU.</span><h1 className="v4-quiz-title">{question.title}</h1><p className="v4-quiz-sub">{question.sub}</p><div className="v4-quiz-options">{question.options.map(([value, text, description]) => <button className="v4-answer" key={value} aria-pressed={answers[step] === value} onClick={() => answer(value)}><span className="radio" aria-hidden="true" /><span>{text}<small>{description}</small></span></button>)}</div><div className="v4-quiz-bottom"><button className="v4-public-link" disabled={step === 0} onClick={() => router.replace(quizUrl(answers, step - 1))}><Icon name="left" /> 上一題</button><button className="v4-public-btn" disabled={!answers[step]} onClick={() => { if (answers[step]) router.push(quizUrl(answers, step === 4 ? undefined : step + 1)); }}>{step === 4 ? "看看我的學習建議" : "下一題"} <Icon /></button></div><p className={styles.note}>不用登入。答案只用於此本機網址的示意建議；不會上傳或用來評級。</p></div>;
}
