import { notFound } from "next/navigation";
import { isMockDataMode } from "@/lib/preview/mode";
import { LearningStageExplorer } from "@/components/learning/stage-explorer";
export default function LearningMapPage() {
 if(!isMockDataMode()) notFound();
 return <main className="student-main map-main"><header className="map-heading"><div><p className="eyebrow">THE ONE GUITAR ROADMAP 2.0</p><h1>每一步，都在成為更好的自己。</h1><p className="body-copy">不用一次走完所有路。先找到現在的你，再往前一點。</p></div><span className="soft-pill">學習地圖 · 6 段旅程</span></header><LearningStageExplorer/></main>;
}
