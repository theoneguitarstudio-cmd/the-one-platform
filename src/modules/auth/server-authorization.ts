import "server-only";

import { redirect } from "next/navigation";

import {
  canAccessArea,
  PROTECTED_AREAS,
  type ProtectedArea,
} from "@/modules/auth/route-access";
import { getAuthenticatedIdentity } from "@/modules/auth/session";

export async function requireAreaAccess(area: ProtectedArea) {
  const identity = await getAuthenticatedIdentity();

  if (!identity) {
    const next = encodeURIComponent(PROTECTED_AREAS[area].path);
    redirect(`/auth/sign-in?next=${next}`);
  }

  const decision = canAccessArea(identity, area);
  if (!decision.allowed) {
    redirect("/auth/access-denied");
  }

  return identity;
}
