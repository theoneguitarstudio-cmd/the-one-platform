import { z } from "zod";

export const bookingStatuses = [
  "confirmed", "cancelled", "rescheduled", "completed", "credit_required", "failed",
] as const;
export const bookingSources = ["flexible", "fixed", "makeup"] as const;
export const creditOutcomes = ["released", "consumed", "unchanged", "manual_review_required"] as const;

export const schedulingBookingSchema = z.object({
  credit_outcome: z.enum(creditOutcomes).nullable(),
  ends_at: z.iso.datetime({ offset: true }),
  id: z.uuid(),
  lesson_id: z.uuid().nullable(),
  recurring_series_id: z.uuid().nullable(),
  source: z.enum(bookingSources),
  starts_at: z.iso.datetime({ offset: true }),
  status: z.enum(bookingStatuses),
  timezone_anchor: z.string().min(3).max(80),
});

export type SchedulingBooking = z.infer<typeof schedulingBookingSchema>;

export const flexibleBookingSchema = z.object({
  entitlementId: z.uuid(),
  idempotencyKey: z.uuid(),
  relationshipId: z.uuid(),
  startsAt: z.iso.datetime({ offset: true }),
  studentUserId: z.uuid(),
  teacherUserId: z.uuid(),
  timezone: z.string().min(3).max(80),
});

export const makeupBookingSchema = z.object({
  idempotencyKey: z.uuid(),
  makeupRightId: z.uuid(),
  relationshipId: z.uuid(),
  startsAt: z.iso.datetime({ offset: true }),
  studentUserId: z.uuid(),
  teacherUserId: z.uuid(),
  timezone: z.string().min(3).max(80),
});

export const cancellationSchema = z.object({
  bookingId: z.uuid(),
  creditOutcome: z.enum(creditOutcomes),
  earningOutcome: z.string().trim().min(1).max(100).default("not_applicable"),
  reason: z.string().trim().min(3).max(1000),
});

export const rescheduleSchema = z.object({
  bookingId: z.uuid(),
  newStartsAt: z.iso.datetime({ offset: true }),
  reason: z.string().trim().min(3).max(1000),
  timezone: z.string().min(3).max(80),
});

export const schedulingSettingsSchema = z.object({
  bookingHorizonDays: z.coerce.number().int().min(1).max(366),
  minimumBookingNoticeMinutes: z.coerce.number().int().min(0).max(43200),
  reason: z.string().trim().min(3).max(1000),
  slotIntervalMinutes: z.coerce.number().int().min(5).max(120),
  teacherUserId: z.uuid(),
  timezone: z.string().min(3).max(80),
});

export const availabilityRuleSchema = z.object({
  effectiveFrom: z.iso.date(),
  effectiveUntil: z.iso.date().or(z.literal("")),
  localEndTime: z.string().regex(/^\d{2}:\d{2}$/),
  localStartTime: z.string().regex(/^\d{2}:\d{2}$/),
  reason: z.string().trim().min(3).max(1000),
  teacherUserId: z.uuid(),
  timezone: z.string().min(3).max(80),
  weekday: z.coerce.number().int().min(0).max(6),
}).refine((value) => value.localStartTime < value.localEndTime, {
  message: "Availability must end after it starts.",
});

export const availabilityExceptionSchema = z.object({
  endsAt: z.iso.datetime({ offset: true }),
  exceptionKind: z.enum(["unavailable", "opening"]),
  reason: z.string().trim().min(3).max(1000),
  startsAt: z.iso.datetime({ offset: true }),
  teacherUserId: z.uuid(),
}).refine((value) => new Date(value.endsAt) > new Date(value.startsAt), {
  message: "Availability exception must end after it starts.",
});

export const recurringSeriesSchema = z.object({
  durationMinutes: z.coerce.number().int().min(1).max(480),
  effectiveFrom: z.iso.date(),
  effectiveUntil: z.iso.date().or(z.literal("")),
  localStartTime: z.string().regex(/^\d{2}:\d{2}$/),
  preferredEntitlementId: z.uuid().or(z.literal("")),
  reason: z.string().trim().min(3).max(1000),
  relationshipId: z.uuid(),
  studentUserId: z.uuid(),
  teacherUserId: z.uuid(),
  timezone: z.string().min(3).max(80),
  weekday: z.coerce.number().int().min(0).max(6),
});

export const occurrenceMaterializationSchema = z.object({
  entitlementId: z.uuid(),
  idempotencyKey: z.uuid(),
  occurrenceDate: z.iso.date(),
  seriesId: z.uuid(),
});

export const seriesExceptionSchema = z.object({
  exceptionKind: z.enum(["cancel", "reschedule", "release", "teacher_unavailable", "student_leave", "skip_holiday"]),
  occurrenceDate: z.iso.date(),
  reason: z.string().trim().min(3).max(1000),
  releaseThisOccurrence: z.coerce.boolean(),
  replacementEndsAt: z.iso.datetime({ offset: true }).or(z.literal("")),
  replacementStartsAt: z.iso.datetime({ offset: true }).or(z.literal("")),
  seriesId: z.uuid(),
}).superRefine((value, context) => {
  const hasReplacement = Boolean(value.replacementStartsAt && value.replacementEndsAt);
  if ((value.exceptionKind === "reschedule") !== hasReplacement) {
    context.addIssue({ code: "custom", message: "Reschedule requires replacement instants." });
  }
  if (hasReplacement && new Date(value.replacementEndsAt) <= new Date(value.replacementStartsAt)) {
    context.addIssue({ code: "custom", message: "Replacement must end after it starts." });
  }
});

export const lessonCompletionSchema = z.object({
  bookingId: z.uuid(),
  homework: z.string().max(2000),
  nextGoal: z.string().max(2000),
  performanceSummary: z.string().max(4000),
  privateTeacherNotes: z.string().max(4000),
  studentVisibleNotes: z.string().max(4000),
});

const domainMessages: Record<string, string> = {
  AMBIGUOUS_LOCAL_TIME: "此當地時間在日光節約切換時重複，請選擇其他時間。",
  BOOKING_ALREADY_EXISTS: "此預約請求已存在。",
  BOOKING_NOT_CANCELLABLE: "此預約目前不可取消。",
  BOOKING_NOT_RESCHEDULABLE: "此預約目前不可改期。",
  ENTITLEMENT_NOT_ELIGIBLE: "此課程方案不符合本次預約資格。",
  INSUFFICIENT_LESSON_CREDITS: "可用課程點數不足。",
  MAKEUP_RIGHT_EXPIRED: "此補課權利已過期，或排定時間超過有效期限。",
  MAKEUP_RIGHT_NOT_AVAILABLE: "此補課權利目前不可用。",
  MAKEUP_RIGHT_MANAGED_BY_BOOKING: "此補課權利已由既有預約管理。",
  NONEXISTENT_LOCAL_TIME: "此當地時間因日光節約切換而不存在。",
  OCCURRENCE_ALREADY_MATERIALIZED: "此固定課次已建立。",
  RECURRING_SERIES_CONFLICT: "固定時段與既有安排衝突。",
  RECURRING_SERIES_INACTIVE: "固定安排目前未啟用。",
  SLOT_NOT_AVAILABLE: "此時段已不可預約。",
  STUDENT_SCHEDULE_CONFLICT: "學生在此時段已有課程。",
  TEACHER_SCHEDULE_CONFLICT: "老師在此時段已有課程。",
  UNAUTHORIZED_BOOKING_ACTION: "沒有權限執行此排程操作。",
};

export function mapSchedulingDomainError(message?: string) {
  return domainMessages[message ?? ""] ?? "排程操作未完成，請重新整理後再試。";
}
