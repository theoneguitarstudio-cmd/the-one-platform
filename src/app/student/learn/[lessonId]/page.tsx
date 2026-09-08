import { notFound } from "next/navigation";
import { isMockDataMode } from "@/lib/preview/mode";
import { learningPreview } from "@/lib/preview/learning";
import { LessonWorkspace } from "@/components/learning/lesson-workspace";
export default async function LessonPage({params}:{params:Promise<{lessonId:string}>}) {
 if(!isMockDataMode()) notFound();
 const {lessonId}=await params; const lesson=learningPreview.lessons.find(x=>x.id===lessonId);
 if(!lesson||lesson.state==="locked") notFound();
 return <LessonWorkspace key={lesson.id} lesson={lesson}/>;
}
