import Link from "next/link";
import { isMockDataMode } from "@/lib/preview/mode";
import { learningPreview } from "@/lib/preview/learning";
import { PrimaryCTA, Progress } from "@/components/learning/ui";
import { GuitarArt } from "@/components/learning/guitar-art";
import { SignOutForm } from "@/components/auth/sign-out-form";

export default function StudentPage() {
  if (!isMockDataMode()) return <main className="student-main"><h1>今天，想從哪裡開始？</h1><p>學習工作區尚未開放。</p><PrimaryCTA href="/student/schedule">查看私人課程</PrimaryCTA></main>;
  return <main className="student-main today-main">
    <div className="student-welcome">Hi, {learningPreview.student} <span className="avatar-link" aria-hidden="true">宇</span></div>
    <header className="today-greeting"><div><h1>早安，<br/>今天也讓自己更靠近想成為的吉他手！</h1><p className="body-copy">持續的練習，會讓未來的你感謝現在的自己。</p></div><span className="pace-note">Good Guitar Days Ahead.</span></header>
    <section className="continue-panel"><div><h2>繼續你的學習</h2><p>{learningPreview.course}</p><h3>Stage 1 · 我可以把一首歌完整彈完</h3><p className="muted">Lesson 02 · 讓你的右手，找到穩定節奏 · 12 分鐘</p><Progress value={38} label="本階段練習進度（示範）"/><div className="cta-row"><PrimaryCTA href="/student/learn/pulse">繼續學習</PrimaryCTA><Link className="text-link" href="/student/map">我的學習地圖 →</Link></div></div><Link className="lesson-thumbnail" href="/student/learn/pulse" aria-label="開啟目前課節"><GuitarArt compact/><span className="thumbnail-play" aria-hidden="true">▶</span></Link></section>
    <div className="today-overview">
      <section id="practice"><span className="overview-icon">♫</span><h2>今日練習</h2><p>5 分鐘，穩定右手節奏。</p><Link className="text-link" href="/student/learn/pulse#practice">開始練習 →</Link></section>
      <section><span className="overview-icon">▤</span><h2>我的課程</h2><p>Guitar Roadmap 2.0</p><Link className="text-link" href="/student/map">回到學習地圖 →</Link></section>
      <section><span className="overview-icon">◷</span><h2>即將到來的私課</h2><p>週六 14:00 · 小樂老師</p><Link className="text-link" href="/student/schedule">查看示範預約 →</Link></section>
      <section id="feedback"><span className="overview-icon">▢</span><h2>老師回饋</h2><p>先穩定，再加快。</p><small>示範建議：放慢速度，練習連續轉換。</small></section>
    </div>
    <section id="profile" className="profile-strip"><div><h2>我的個人檔案</h2><p>目前是學生示範身份；練習、預約與課節進度不是真實成果。</p></div><SignOutForm/></section>
  </main>;
}
