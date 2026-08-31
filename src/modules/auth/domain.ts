export const APP_ROLES = [
  "student",
  "teacher",
  "admin",
  "super_admin",
] as const;

export type AppRole = (typeof APP_ROLES)[number];

export const ACCOUNT_STATUSES = ["active", "suspended", "disabled"] as const;

export type AccountStatus = (typeof ACCOUNT_STATUSES)[number];

export function isAppRole(value: string): value is AppRole {
  return APP_ROLES.includes(value as AppRole);
}

export function isAccountStatus(value: string): value is AccountStatus {
  return ACCOUNT_STATUSES.includes(value as AccountStatus);
}
