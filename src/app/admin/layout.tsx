import type { ReactNode } from "react";

import { requireAreaAccess } from "@/modules/auth/server-authorization";

export default async function AdminLayout({
  children,
}: {
  children: ReactNode;
}) {
  await requireAreaAccess("admin");
  return children;
}
