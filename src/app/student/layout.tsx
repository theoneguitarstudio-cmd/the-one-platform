import { StudentShell } from "@/components/learning/student-shell";
import type { ReactNode } from "react";

import { requireAreaAccess } from "@/modules/auth/server-authorization";

export default async function StudentLayout({
  children,
}: {
  children: ReactNode;
}) {
  await requireAreaAccess("student");
  return <StudentShell>{children}</StudentShell>;
}
