import { StudentNavigation } from "@/components/learning/student-navigation";
import type { ReactNode } from "react";

import { requireAreaAccess } from "@/modules/auth/server-authorization";

export default async function StudentLayout({
  children,
}: {
  children: ReactNode;
}) {
  await requireAreaAccess("student");
  return <div className="student-shell"><StudentNavigation /><div className="student-content">{children}</div></div>;
}
