"use client";
import type { ReactNode } from "react";
import { usePathname } from "next/navigation";
import { StudentNavigation } from "./student-navigation";

export function StudentShell({ children }: { children: ReactNode }) {
  const path = usePathname();
  const lesson = path.startsWith("/student/learn/");
  const core = lesson || path === "/student" || path === "/student/map";
  return <div className={core ? `student-shell learning-shell${lesson ? " in-lesson" : ""}` : "student-shell"}>
    <StudentNavigation /><div className="student-content">{children}</div>
  </div>;
}
