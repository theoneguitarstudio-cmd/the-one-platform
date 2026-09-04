"use server";

import "server-only";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireAreaAccess } from "@/modules/auth/server-authorization";
import {
  availabilityExceptionSchema,
  availabilityRuleSchema,
  cancellationSchema,
  flexibleBookingSchema,
  lessonCompletionSchema,
  makeupBookingSchema,
  occurrenceMaterializationSchema,
  recurringSeriesSchema,
  rescheduleSchema,
  schedulingSettingsSchema,
  seriesExceptionSchema,
} from "@/modules/scheduling/domain";

const read = (formData: FormData, key: string) => String(formData.get(key) ?? "");
const nullable = (value: string) => value || null;

export async function createFlexibleBooking(formData: FormData) {
  const identity = await requireAreaAccess("student");
  const parsed = flexibleBookingSchema.safeParse({
    entitlementId: read(formData, "entitlementId"),
    idempotencyKey: read(formData, "idempotencyKey"),
    relationshipId: read(formData, "relationshipId"),
    startsAt: read(formData, "startsAt"),
    studentUserId: identity.userId,
    teacherUserId: read(formData, "teacherUserId"),
    timezone: read(formData, "timezone"),
  });
  if (!parsed.success) redirect("/student/schedule?error=invalid_booking");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("create_lesson_booking", {
    p_entitlement_id: parsed.data.entitlementId,
    p_idempotency_key: parsed.data.idempotencyKey,
    p_reason: "Student flexible booking",
    p_relationship_id: parsed.data.relationshipId,
    p_starts_at: parsed.data.startsAt,
    p_student_user_id: parsed.data.studentUserId,
    p_teacher_user_id: parsed.data.teacherUserId,
    p_timezone: parsed.data.timezone,
  });
  if (error) redirect("/student/schedule?error=booking_failed");
  revalidatePath("/student/schedule");
  redirect("/student/schedule?status=booked");
}

export async function cancelOwnBooking(formData: FormData) {
  await requireAreaAccess("student");
  const parsed = cancellationSchema.safeParse({
    bookingId: read(formData, "bookingId"),
    creditOutcome: read(formData, "creditOutcome"),
    earningOutcome: "not_applicable",
    reason: read(formData, "reason"),
  });
  if (!parsed.success) redirect("/student/schedule?error=invalid_cancellation");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("cancel_lesson_booking", {
    p_booking_id: parsed.data.bookingId,
    p_credit_outcome: parsed.data.creditOutcome,
    p_earning_outcome: parsed.data.earningOutcome,
    p_reason: parsed.data.reason,
  });
  if (error) redirect("/student/schedule?error=cancellation_failed");
  revalidatePath("/student/schedule");
  redirect("/student/schedule?status=cancelled");
}

export async function rescheduleOwnBooking(formData: FormData) {
  await requireAreaAccess("student");
  const parsed = rescheduleSchema.safeParse({
    bookingId: read(formData, "bookingId"),
    newStartsAt: read(formData, "newStartsAt"),
    reason: read(formData, "reason"),
    timezone: read(formData, "timezone"),
  });
  if (!parsed.success) redirect("/student/schedule?error=invalid_reschedule");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("reschedule_lesson_booking", {
    p_booking_id: parsed.data.bookingId,
    p_new_starts_at: parsed.data.newStartsAt,
    p_reason: parsed.data.reason,
    p_timezone: parsed.data.timezone,
  });
  if (error) redirect("/student/schedule?error=reschedule_failed");
  revalidatePath("/student/schedule");
  redirect("/student/schedule?status=rescheduled");
}

export async function setTeacherSchedulingSettings(formData: FormData) {
  const identity = await requireAreaAccess("teacher");
  const parsed = schedulingSettingsSchema.safeParse({
    bookingHorizonDays: read(formData, "bookingHorizonDays"),
    minimumBookingNoticeMinutes: read(formData, "minimumBookingNoticeMinutes"),
    reason: read(formData, "reason"),
    slotIntervalMinutes: read(formData, "slotIntervalMinutes"),
    teacherUserId: identity.userId,
    timezone: read(formData, "timezone"),
  });
  if (!parsed.success) redirect("/teacher/schedule?error=invalid_settings");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("set_teacher_scheduling_settings", {
    p_booking_horizon_days: parsed.data.bookingHorizonDays,
    p_minimum_booking_notice_minutes: parsed.data.minimumBookingNoticeMinutes,
    p_reason: parsed.data.reason,
    p_slot_interval_minutes: parsed.data.slotIntervalMinutes,
    p_teacher_user_id: parsed.data.teacherUserId,
    p_timezone: parsed.data.timezone,
  });
  if (error) redirect("/teacher/schedule?error=settings_failed");
  revalidatePath("/teacher/schedule");
  redirect("/teacher/schedule?status=settings_saved");
}

export async function createTeacherAvailabilityRule(formData: FormData) {
  const identity = await requireAreaAccess("teacher");
  const parsed = availabilityRuleSchema.safeParse({
    effectiveFrom: read(formData, "effectiveFrom"),
    effectiveUntil: read(formData, "effectiveUntil"),
    localEndTime: read(formData, "localEndTime"),
    localStartTime: read(formData, "localStartTime"),
    reason: read(formData, "reason"),
    teacherUserId: identity.userId,
    timezone: read(formData, "timezone"),
    weekday: read(formData, "weekday"),
  });
  if (!parsed.success) redirect("/teacher/schedule?error=invalid_rule");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("create_teacher_availability_rule", {
    p_effective_from: parsed.data.effectiveFrom,
    p_effective_until: nullable(parsed.data.effectiveUntil),
    p_local_end_time: parsed.data.localEndTime,
    p_local_start_time: parsed.data.localStartTime,
    p_reason: parsed.data.reason,
    p_teacher_user_id: parsed.data.teacherUserId,
    p_timezone: parsed.data.timezone,
    p_weekday: parsed.data.weekday,
  });
  if (error) redirect("/teacher/schedule?error=rule_failed");
  revalidatePath("/teacher/schedule");
  redirect("/teacher/schedule?status=rule_created");
}

export async function createTeacherAvailabilityException(formData: FormData) {
  const identity = await requireAreaAccess("teacher");
  const parsed = availabilityExceptionSchema.safeParse({
    endsAt: read(formData, "endsAt"),
    exceptionKind: read(formData, "exceptionKind"),
    reason: read(formData, "reason"),
    startsAt: read(formData, "startsAt"),
    teacherUserId: identity.userId,
  });
  if (!parsed.success) redirect("/teacher/schedule?error=invalid_exception");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("create_teacher_availability_exception", {
    p_ends_at: parsed.data.endsAt,
    p_exception_kind: parsed.data.exceptionKind,
    p_reason: parsed.data.reason,
    p_starts_at: parsed.data.startsAt,
    p_teacher_user_id: parsed.data.teacherUserId,
  });
  if (error) redirect("/teacher/schedule?error=exception_failed");
  revalidatePath("/teacher/schedule");
  redirect("/teacher/schedule?status=exception_created");
}

export async function createTeacherRecurringSeries(formData: FormData) {
  const identity = await requireAreaAccess("teacher");
  const parsed = recurringSeriesSchema.safeParse({
    durationMinutes: read(formData, "durationMinutes"),
    effectiveFrom: read(formData, "effectiveFrom"),
    effectiveUntil: read(formData, "effectiveUntil"),
    localStartTime: read(formData, "localStartTime"),
    preferredEntitlementId: read(formData, "preferredEntitlementId"),
    reason: read(formData, "reason"),
    relationshipId: read(formData, "relationshipId"),
    studentUserId: read(formData, "studentUserId"),
    teacherUserId: identity.userId,
    timezone: read(formData, "timezone"),
    weekday: read(formData, "weekday"),
  });
  if (!parsed.success) redirect("/teacher/schedule?error=invalid_series");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("create_recurring_lesson_series", {
    p_duration_minutes: parsed.data.durationMinutes,
    p_effective_from: parsed.data.effectiveFrom,
    p_effective_until: nullable(parsed.data.effectiveUntil),
    p_local_start_time: parsed.data.localStartTime,
    p_preferred_entitlement_id: nullable(parsed.data.preferredEntitlementId),
    p_reason: parsed.data.reason,
    p_relationship_id: parsed.data.relationshipId,
    p_student_user_id: parsed.data.studentUserId,
    p_teacher_user_id: parsed.data.teacherUserId,
    p_timezone: parsed.data.timezone,
    p_weekday: parsed.data.weekday,
  });
  if (error) redirect("/teacher/schedule?error=series_failed");
  revalidatePath("/teacher/schedule");
  redirect("/teacher/schedule?status=series_created");
}

export async function setTeacherSeriesStatus(formData: FormData) {
  await requireAreaAccess("teacher");
  const seriesId = read(formData, "seriesId");
  const status = read(formData, "status");
  const reason = read(formData, "reason");
  if (!zUuid(seriesId) || !["active", "paused", "ended"].includes(status) || reason.trim().length < 3) {
    redirect("/teacher/schedule?error=invalid_series_status");
  }
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("set_recurring_lesson_series_status", {
    p_reason: reason,
    p_series_id: seriesId,
    p_status: status,
  });
  if (error) redirect("/teacher/schedule?error=series_status_failed");
  revalidatePath("/teacher/schedule");
  redirect("/teacher/schedule?status=series_updated");
}

export async function materializeTeacherOccurrence(formData: FormData) {
  await requireAreaAccess("teacher");
  const parsed = occurrenceMaterializationSchema.safeParse({
    entitlementId: read(formData, "entitlementId"),
    idempotencyKey: read(formData, "idempotencyKey"),
    occurrenceDate: read(formData, "occurrenceDate"),
    seriesId: read(formData, "seriesId"),
  });
  if (!parsed.success) redirect("/teacher/schedule?error=invalid_occurrence");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("materialize_recurring_lesson_occurrence", {
    p_entitlement_id: parsed.data.entitlementId,
    p_idempotency_key: parsed.data.idempotencyKey,
    p_occurrence_date: parsed.data.occurrenceDate,
    p_series_id: parsed.data.seriesId,
  });
  if (error) redirect("/teacher/schedule?error=materialization_failed");
  revalidatePath("/teacher/schedule");
  redirect("/teacher/schedule?status=occurrence_materialized");
}

export async function setTeacherSeriesException(formData: FormData) {
  await requireAreaAccess("teacher");
  const parsed = seriesExceptionSchema.safeParse({
    exceptionKind: read(formData, "exceptionKind"),
    occurrenceDate: read(formData, "occurrenceDate"),
    reason: read(formData, "reason"),
    releaseThisOccurrence: read(formData, "releaseThisOccurrence") === "true",
    replacementEndsAt: read(formData, "replacementEndsAt"),
    replacementStartsAt: read(formData, "replacementStartsAt"),
    seriesId: read(formData, "seriesId"),
  });
  if (!parsed.success) redirect("/teacher/schedule?error=invalid_series_exception");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("set_recurring_lesson_series_exception", {
    p_exception_kind: parsed.data.exceptionKind,
    p_occurrence_date: parsed.data.occurrenceDate,
    p_reason: parsed.data.reason,
    p_release_this_occurrence: parsed.data.releaseThisOccurrence,
    p_replacement_ends_at: nullable(parsed.data.replacementEndsAt),
    p_replacement_starts_at: nullable(parsed.data.replacementStartsAt),
    p_series_id: parsed.data.seriesId,
  });
  if (error) redirect("/teacher/schedule?error=series_exception_failed");
  revalidatePath("/teacher/schedule");
  redirect("/teacher/schedule?status=series_exception_created");
}

export async function cancelTeacherBooking(formData: FormData) {
  await requireAreaAccess("teacher");
  return mutateCancellation(formData, "/teacher/schedule", "unchanged", "not_applicable");
}

export async function createMakeupBooking(formData: FormData) {
  const identity = await requireAreaAccess("student");
  const parsed = makeupBookingSchema.safeParse({
    idempotencyKey: read(formData, "idempotencyKey"),
    makeupRightId: read(formData, "makeupRightId"),
    relationshipId: read(formData, "relationshipId"),
    startsAt: read(formData, "startsAt"),
    studentUserId: identity.userId,
    teacherUserId: read(formData, "teacherUserId"),
    timezone: read(formData, "timezone"),
  });
  if (!parsed.success) redirect("/student/schedule?error=invalid_makeup_booking");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("create_makeup_lesson_booking", {
    p_idempotency_key: parsed.data.idempotencyKey,
    p_makeup_right_id: parsed.data.makeupRightId,
    p_reason: "Student Makeup booking",
    p_relationship_id: parsed.data.relationshipId,
    p_starts_at: parsed.data.startsAt,
    p_student_user_id: parsed.data.studentUserId,
    p_teacher_user_id: parsed.data.teacherUserId,
    p_timezone: parsed.data.timezone,
  });
  if (error) redirect("/student/schedule?error=makeup_booking_failed");
  revalidatePath("/student/schedule");
  redirect("/student/schedule?status=makeup_booked");
}

export async function rescheduleTeacherBooking(formData: FormData) {
  await requireAreaAccess("teacher");
  return mutateReschedule(formData, "/teacher/schedule");
}

export async function completeTeacherBooking(formData: FormData) {
  await requireAreaAccess("teacher");
  const parsed = lessonCompletionSchema.safeParse({
    bookingId: read(formData, "bookingId"),
    homework: read(formData, "homework"),
    nextGoal: read(formData, "nextGoal"),
    performanceSummary: read(formData, "performanceSummary"),
    privateTeacherNotes: read(formData, "privateTeacherNotes"),
    studentVisibleNotes: read(formData, "studentVisibleNotes"),
  });
  if (!parsed.success) redirect("/teacher/schedule?error=invalid_completion");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("complete_lesson_booking", {
    p_booking_id: parsed.data.bookingId,
    p_homework: parsed.data.homework,
    p_next_goal: parsed.data.nextGoal,
    p_performance_summary: parsed.data.performanceSummary,
    p_private_teacher_notes: parsed.data.privateTeacherNotes,
    p_student_visible_notes: parsed.data.studentVisibleNotes,
  });
  if (error) redirect("/teacher/schedule?error=completion_failed");
  revalidatePath("/teacher/schedule");
  redirect("/teacher/schedule?status=completed");
}

export async function adminCreateFlexibleBooking(formData: FormData) {
  await requireAreaAccess("admin");
  const parsed = flexibleBookingSchema.safeParse({
    entitlementId: read(formData, "entitlementId"),
    idempotencyKey: read(formData, "idempotencyKey"),
    relationshipId: read(formData, "relationshipId"),
    startsAt: read(formData, "startsAt"),
    studentUserId: read(formData, "studentUserId"),
    teacherUserId: read(formData, "teacherUserId"),
    timezone: read(formData, "timezone"),
  });
  if (!parsed.success) redirect("/admin/schedule?error=invalid_booking");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("create_lesson_booking", {
    p_entitlement_id: parsed.data.entitlementId,
    p_idempotency_key: parsed.data.idempotencyKey,
    p_reason: read(formData, "reason"),
    p_relationship_id: parsed.data.relationshipId,
    p_starts_at: parsed.data.startsAt,
    p_student_user_id: parsed.data.studentUserId,
    p_teacher_user_id: parsed.data.teacherUserId,
    p_timezone: parsed.data.timezone,
  });
  if (error) redirect("/admin/schedule?error=booking_failed");
  revalidatePath("/admin/schedule");
  redirect("/admin/schedule?status=booked");
}

export async function adminCancelBooking(formData: FormData) {
  await requireAreaAccess("admin");
  return mutateCancellation(
    formData,
    "/admin/schedule",
    read(formData, "creditOutcome"),
    read(formData, "earningOutcome"),
  );
}

export async function adminRescheduleBooking(formData: FormData) {
  await requireAreaAccess("admin");
  return mutateReschedule(formData, "/admin/schedule");
}

export async function adminSetSeriesStatus(formData: FormData) {
  await requireAreaAccess("admin");
  const seriesId = read(formData, "seriesId");
  const status = read(formData, "status");
  const reason = read(formData, "reason");
  if (!zUuid(seriesId) || !["active", "paused", "ended"].includes(status) || reason.trim().length < 3) {
    redirect("/admin/schedule?error=invalid_series_status");
  }
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("set_recurring_lesson_series_status", {
    p_reason: reason,
    p_series_id: seriesId,
    p_status: status,
  });
  if (error) redirect("/admin/schedule?error=series_status_failed");
  revalidatePath("/admin/schedule");
  redirect("/admin/schedule?status=series_updated");
}

async function mutateCancellation(
  formData: FormData,
  returnPath: string,
  creditOutcome: string,
  earningOutcome: string,
) {
  const parsed = cancellationSchema.safeParse({
    bookingId: read(formData, "bookingId"),
    creditOutcome,
    earningOutcome,
    reason: read(formData, "reason"),
  });
  if (!parsed.success) redirect(`${returnPath}?error=invalid_cancellation`);
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("cancel_lesson_booking", {
    p_booking_id: parsed.data.bookingId,
    p_credit_outcome: parsed.data.creditOutcome,
    p_earning_outcome: parsed.data.earningOutcome,
    p_reason: parsed.data.reason,
  });
  if (error) redirect(`${returnPath}?error=cancellation_failed`);
  revalidatePath(returnPath);
  redirect(`${returnPath}?status=cancelled`);
}

async function mutateReschedule(formData: FormData, returnPath: string) {
  const parsed = rescheduleSchema.safeParse({
    bookingId: read(formData, "bookingId"),
    newStartsAt: read(formData, "newStartsAt"),
    reason: read(formData, "reason"),
    timezone: read(formData, "timezone"),
  });
  if (!parsed.success) redirect(`${returnPath}?error=invalid_reschedule`);
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("reschedule_lesson_booking", {
    p_booking_id: parsed.data.bookingId,
    p_new_starts_at: parsed.data.newStartsAt,
    p_reason: parsed.data.reason,
    p_timezone: parsed.data.timezone,
  });
  if (error) redirect(`${returnPath}?error=reschedule_failed`);
  revalidatePath(returnPath);
  redirect(`${returnPath}?status=rescheduled`);
}

function zUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}
