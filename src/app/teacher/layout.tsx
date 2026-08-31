import type { ReactNode } from "react";

import { requireAreaAccess } from "@/modules/auth/server-authorization";

export default async function TeacherLayout({
  children,
}: {
  children: ReactNode;
}) {
  await requireAreaAccess("teacher");
  return children;
}
