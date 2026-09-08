import { GuitarArt } from "./guitar-art";
import { PrimaryCTA } from "./ui";
export function SystemCourseCard() {
 return <article className="course-feature"><GuitarArt compact /><div className="course-description"><p className="eyebrow">旗艦 SYSTEM COURSE · GUITAR</p><h3>The One<br/>Guitar Roadmap 2.0</h3><p className="body-copy">從第一首完整的歌，到彈出自己的想法。<br/>讓零散的練習，成為看得見方向的旅程。</p><div className="inline-tags"><span>成果導向</span><span>循序探索</span><span>老師陪伴</span></div><PrimaryCTA href="/courses/guitar-roadmap">探索學習路線</PrimaryCTA></div></article>;
}
