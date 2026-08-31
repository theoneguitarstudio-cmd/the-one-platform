import type { AccountStatus, AppRole } from "@/modules/auth/domain";
import {
  hasPermission,
  type Permission,
} from "@/modules/auth/permissions";

export const PROTECTED_AREAS = {
  student: {
    path: "/student",
    permission: "student.dashboard.view",
  },
  teacher: {
    path: "/teacher",
    permission: "teacher.dashboard.view",
  },
  admin: {
    path: "/admin",
    permission: "admin.dashboard.view",
  },
} as const satisfies Record<
  string,
  { path: string; permission: Permission }
>;

export type ProtectedArea = keyof typeof PROTECTED_AREAS;

type RouteIdentity = {
  accountStatus: AccountStatus;
  roles: readonly AppRole[];
};

export type AccessDecision =
  | { allowed: true }
  | { allowed: false; reason: "account_inactive" | "missing_permission" };

export function canAccessArea(
  identity: RouteIdentity,
  area: ProtectedArea,
): AccessDecision {
  if (identity.accountStatus !== "active") {
    return { allowed: false, reason: "account_inactive" };
  }

  if (!hasPermission(identity.roles, PROTECTED_AREAS[area].permission)) {
    return { allowed: false, reason: "missing_permission" };
  }

  return { allowed: true };
}
