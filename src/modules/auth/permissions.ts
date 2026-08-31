import type { AppRole } from "@/modules/auth/domain";

export const PERMISSIONS = [
  "student.dashboard.view",
  "teacher.dashboard.view",
  "admin.dashboard.view",
] as const;

export type Permission = (typeof PERMISSIONS)[number];

const ROLE_PERMISSIONS: Record<AppRole, readonly Permission[]> = {
  student: ["student.dashboard.view"],
  teacher: ["teacher.dashboard.view"],
  admin: ["admin.dashboard.view"],
  super_admin: ["admin.dashboard.view"],
};

export function hasPermission(
  roles: readonly AppRole[],
  permission: Permission,
): boolean {
  return roles.some((role) => ROLE_PERMISSIONS[role].includes(permission));
}
