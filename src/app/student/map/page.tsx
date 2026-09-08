import { notFound } from "next/navigation";
import { isMockDataMode } from "@/lib/preview/mode";
import { LearningStageExplorer } from "@/components/learning/stage-explorer";
export default function LearningMapPage() {
 if(!isMockDataMode()) notFound();
 return <main className="student-main map-main"><header className="map-heading"><div><p className="eyebrow">THE ONE GUITAR ROADMAP 2.0</p><h1>學習地圖</h1><p className="body-copy">一條清晰的路，陪你走向更完整的自己。</p></div><span className="soft-pill">學習地圖 · 6 段旅程</span></header><LearningStageExplorer/></main>;
}
