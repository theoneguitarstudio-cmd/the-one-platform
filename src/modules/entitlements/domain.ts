import { z } from "zod";

export const entitlementStatuses = [
  "pending", "active", "exhausted", "expired", "revoked", "cancelled",
] as const;
export const bookingModes = ["fixed", "flexible", "both"] as const;

export const lessonPackageSnapshotSchema = z.object({
  activation_rule: z.enum(["on_fulfillment", "on_first_booking", "scheduled", "admin_specified"]),
  booking_mode_eligibility: z.enum(bookingModes),
  lesson_count: z.number().int().positive(),
  lesson_duration_minutes: z.number().int().positive(),
  validity_unit: z.enum(["days", "weeks", "months"]),
  validity_value: z.number().int().positive(),
});

export const entitlementSummarySchema = z.object({
  booking_mode_eligibility: z.enum(bookingModes),
  credits_available: z.number().int().nonnegative(),
  credits_consumed: z.number().int().nonnegative().default(0),
  credits_reserved: z.number().int().nonnegative(),
  credits_total: z.number().int().nonnegative().default(0),
  expires_at: z.string().nullable(),
  id: z.uuid(),
  package_name: z.string(),
  starts_at: z.string().optional(),
  status: z.enum(entitlementStatuses),
});

export type EntitlementSummary = z.infer<typeof entitlementSummarySchema>;

export const extensionSchema = z.object({
  entitlementId: z.uuid(),
  idempotencyKey: z.uuid(),
  newExpiresAt: z.iso.datetime({ offset: true }),
  reason: z.string().trim().min(3).max(1000),
});
export const adjustmentSchema = z.object({
  entitlementId: z.uuid(),
  idempotencyKey: z.uuid(),
  quantityDelta: z.coerce.number().int().min(-1000).max(1000).refine((value) => value !== 0),
  reason: z.string().trim().min(3).max(1000),
});
export const fulfillmentRetrySchema = z.object({
  eventId: z.uuid(),
  idempotencyKey: z.uuid(),
  reason: z.string().trim().min(3).max(1000),
});
export const studentLookupSchema = z.uuid();

const domainErrorMessages: Record<string, string> = {
  CREDIT_ALREADY_RESERVED: "此預約已使用課程點數。",
  CREDIT_ALREADY_CONSUMED: "此堂課點數已使用。",
  CREDIT_ALREADY_RELEASED: "此點數預留已釋放。",
  CREDIT_ADJUSTMENT_PAYLOAD_MISMATCH: "調整請求與原始請求不一致。",
  CREDIT_RESERVATION_PAYLOAD_MISMATCH: "預留請求與原始請求不一致。",
  CREDIT_RESERVATION_NOT_FOUND: "找不到點數預留紀錄。",
  ENTITLEMENT_EXPIRED: "課程方案已過期。",
  ENTITLEMENT_EXTENSION_PAYLOAD_MISMATCH: "延長請求與原始請求不一致。",
  ENTITLEMENT_NOT_ACTIVE: "課程方案目前不可使用。",
  INSUFFICIENT_LESSON_CREDITS: "可用課程點數不足。",
  UNAUTHORIZED_ENTITLEMENT_EXTENSION: "沒有權限延長此方案。",
};

export function mapEntitlementDomainError(message?: string) {
  return domainErrorMessages[message ?? ""] ?? "操作未完成，請稍後再試。";
}

export function isEntitlementUsable(
  status: (typeof entitlementStatuses)[number],
  startsAt: string,
  expiresAt: string | null,
  now = new Date(),
) {
  return status === "active" && new Date(startsAt) <= now && (!expiresAt || new Date(expiresAt) > now);
}
