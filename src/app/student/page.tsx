import Link from "next/link";
import { isMockDataMode } from "@/lib/preview/mode";
import { learningPreview } from "@/lib/preview/learning";
import { PrimaryCTA, Progress, SectionHeader } from "@/components/learning/ui";
import { GuitarArt } from "@/components/learning/guitar-art";
import { SignOutForm } from "@/components/auth/sign-out-form";
export default function StudentPage() {
 if (!isMockDataMode()) return <main className="student-main"><h1>今天，想從哪裡開始？</h1><p>學習工作區尚未開放。</p><PrimaryCTA href="/student/schedule">查看私人課程</PrimaryCTA></main>;
 return <main className="student-main"><header className="today-greeting"><div><p className="eyebrow">TODAY IS A GOOD DAY TO LEARN</p><h1>歡迎回來，{learningPreview.student}。<br/><span>今天，留一點時間給音樂。</span></h1></div><span className="pace-note">♫ 按自己的節奏，就很好。</span></header>
 <section className="continue-panel"><div><p className="eyebrow">繼續你的學習 / LEVEL 01</p><h2>讓你的右手，<br/>找到穩定節奏。</h2><p>{learningPreview.course}</p><p className="muted">我可以把一首歌完整彈完 · 本次約 12 分鐘</p><Progress value={38} label="本階段練習進度（示範）"/><div className="cta-row"><PrimaryCTA href="/student/learn/pulse">繼續學習</PrimaryCTA><Link className="text-link" href="/student/map">看看我的路線 →</Link></div></div><GuitarArt compact/></section>
 <div className="today-lower"><section id="practice"><SectionHeader eyebrow="A SMALL STEP TODAY" title="今日練習"/><div className="practice-line"><span className="round-icon">♫</span><div><h3>先慢下來，再穩下來。</h3><p>用 5 分鐘空弦練習，讓右手和節拍一起呼吸。</p></div><Link href="/student/learn/pulse#practice" aria-label="開始今日節奏練習">↗</Link></div><SectionHeader eyebrow="MY SYSTEM COURSES" title="我的學習旅程"/><Link href="/student/map" className="my-course"><span className="course-monogram">G</span><div><small>SYSTEM COURSE</small><h3>Guitar Roadmap 2.0</h3><p>Level 01 · 持續向前</p></div><span>↗</span></Link></section><aside><section className="upcoming-lesson"><p className="eyebrow">UPCOMING PRIVATE LESSON</p><h3>有人陪你，聽見進步。</h3><p>小樂老師 · 示範私人課程</p><div className="lesson-time"><strong>週六</strong><span>14:00 – 14:30<br/>線上 · 節奏與和弦轉換</span></div><Link href="/student/schedule" className="text-link">查看私人課程 →</Link><small>合成預約展示，沒有真實會議連結。</small></section><section id="feedback" className="feedback"><p className="eyebrow">A NOTE FROM YOUR TEACHER</p><h3>「先穩定，再加快。」</h3><p>今天試著把速度放慢一點。每一次穩定的轉換，都會成為下一次進步的基礎。</p><small>小樂老師 · 示範回饋</small></section></aside></div>
 <section id="profile" className="profile-strip"><div><h2>我的個人檔案</h2><p>目前是學生示範身份；練習與課節切換不會保存為真實成果。</p></div><SignOutForm/></section></main>;
}
