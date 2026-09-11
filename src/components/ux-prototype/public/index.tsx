"use client";

import { useSearchParams } from "next/navigation";
import { useRouter } from "@/components/platform-experience/link";
import { publicTeachers } from "@/modules/ux-prototype/model";
import { usePrototype } from "@/modules/ux-prototype/store";
import { PublicHome, TeacherSection } from "./home";
import { PublicArticles, PublicCourse, PublicPolicies, PublicTeacher } from "./details";
import { Diagnosis } from "./diagnosis";
import { PUBLIC_ROOT, PublicFooter, PublicNav } from "./shared";
import styles from "./public.module.css";
import reference from "./reference.module.css";

export function PublicPage({ segments }: { segments: string[] }) {
  const { state } = usePrototype();
  const router = useRouter();
  const query = useSearchParams();
  const tab = ["private", "system", "standalone"].includes(query.get("tab") ?? "") ? query.get("tab")! : "system";
  const teachers = publicTeachers(state).map(teacher => ({ id: teacher.id, ...teacher.published! }));
  let content;
  if (segments[0] === "teachers" && !segments[1]) content = <main className="p5-home"><TeacherSection teachers={teachers}/></main>;
  else if (segments[0] === "teachers") content = <PublicTeacher key={segments[1]} state={state} teacherId={segments[1]} tab={tab} onTab={next => router.replace(`${PUBLIC_ROOT}/teachers/${encodeURIComponent(segments[1])}?tab=${next}`, { scroll: false })} />;
  else if (segments[0] === "courses") content = <PublicCourse state={state} courseId={segments[1]} />;
  else if (segments[0] === "articles") content = <PublicArticles state={state} slug={segments[1]} />;
  else if (segments[0] === "policies") content = <PublicPolicies state={state} privacy={segments[1] === "privacy"} />;
  else if (segments[0] === "diagnosis") content = <Diagnosis result={segments[1] === "result"} />;
  else content = <PublicHome teachers={teachers} coursePublished={Boolean(state.courses.find(course => course.id === "c1")?.published)} />;
  return <div className={`${styles.surface} ${reference.surface}`} data-public-prototype="true"><PublicNav />{content}<PublicFooter /></div>;
}
