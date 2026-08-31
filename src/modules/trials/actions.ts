"use server";

import "server-only";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireAreaAccess } from "@/modules/auth/server-authorization";
import {
  adminTrialIdSchema,
  adminTrialOrderSchema,
  adminTrialRescheduleSchema,
  teacherMeetingDefaultsSchema,
  trialCompletionSchema,
  trialRequestSchema,
} from "@/modules/trials/domain";
import { zonedLocalDateTimeToUtc } from "@/modules/trials/timezone";

function readString(formData: FormData, key: string): string {
  const value = formData.get(key);
  return typeof value === "string" ? value : "";
}

export async function requestTrialCheckout(formData: FormData) {
  await requireAreaAccess("student");
  const parsed = trialRequestSchema.safeParse({
    idempotencyKey: readString(formData, "idempotencyKey"),
    learningGoal: readString(formData, "learningGoal"),
    localStartsAt: readString(formData, "localStartsAt"),
    preferredLocation: readString(formData, "preferredLocation"),
    preferredMode: readString(formData, "preferredMode"),
    teacherSlug: readString(formData, "teacherSlug"),
    timezone: readString(formData, "timezone"),
  });
  if (!parsed.success) redirect(`/teachers/${readString(formData, "teacherSlug")}/trial?error=invalid_input`);

  let startsAt: string;
  try {
    startsAt = zonedLocalDateTimeToUtc(
      parsed.data.localStartsAt,
      parsed.data.timezone,
    );
  } catch {
    redirect(`/teachers/${parsed.data.teacherSlug}/trial?error=invalid_time`);
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("request_trial_checkout", {
    p_idempotency_key: parsed.data.idempotencyKey,
    p_learning_goal: parsed.data.learningGoal,
    p_preferred_location: parsed.data.preferredLocation || null,
    p_preferred_mode: parsed.data.preferredMode,
    p_proposed_starts_at: startsAt,
    p_teacher_slug: parsed.data.teacherSlug,
    p_timezone: parsed.data.timezone,
  });
  if (error) redirect(`/teachers/${parsed.data.teacherSlug}/trial?error=request_failed`);
  revalidatePath("/student/trial");
  redirect("/student/trial?status=requested");
}

export async function saveTeacherMeetingDefaults(formData: FormData) {
  await requireAreaAccess("teacher");
  const parsed = teacherMeetingDefaultsSchema.safeParse({
    provider: readString(formData, "provider"),
    url: readString(formData, "url"),
  });
  if (!parsed.success) redirect("/teacher/trials?error=invalid_meeting");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("update_own_teacher_meeting_defaults", {
    p_provider: parsed.data.provider,
    p_url: parsed.data.url,
  });
  if (error) redirect("/teacher/trials?error=save_failed");
  revalidatePath("/teacher/trials");
  redirect("/teacher/trials?status=meeting_saved");
}

export async function completeTrialLesson(formData: FormData) {
  await requireAreaAccess("teacher");
  const parsed = trialCompletionSchema.safeParse({
    assessmentSummary: readString(formData, "assessmentSummary"),
    homework: readString(formData, "homework"),
    lessonId: readString(formData, "lessonId"),
    nextGoal: readString(formData, "nextGoal"),
    performanceSummary: readString(formData, "performanceSummary"),
    privateTeacherNotes: readString(formData, "privateTeacherNotes"),
    recommendationType: readString(formData, "recommendationType"),
    stageNumber: readString(formData, "stageNumber"),
    studentVisibleNotes: readString(formData, "studentVisibleNotes"),
  });
  if (!parsed.success) redirect("/teacher/trials?error=invalid_completion");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("complete_trial_lesson", {
    p_assessment_summary: parsed.data.assessmentSummary,
    p_homework: parsed.data.homework,
    p_lesson_id: parsed.data.lessonId,
    p_next_goal: parsed.data.nextGoal,
    p_performance_summary: parsed.data.performanceSummary,
    p_private_teacher_notes: parsed.data.privateTeacherNotes,
    p_recommendation_type: parsed.data.recommendationType,
    p_stage_number: parsed.data.stageNumber,
    p_student_visible_notes: parsed.data.studentVisibleNotes,
  });
  if (error) redirect("/teacher/trials?error=completion_failed");
  revalidatePath("/teacher/trials");
  revalidatePath("/student/trial");
  redirect("/teacher/trials?status=completed");
}

export async function confirmTrialPayment(formData: FormData) {
  await requireAreaAccess("admin");
  const parsed = adminTrialOrderSchema.safeParse({
    orderId: readString(formData, "orderId"),
  });
  if (!parsed.success) redirect("/admin/trials?error=invalid_order");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("confirm_trial_payment", {
    p_order_id: parsed.data.orderId,
    p_starts_at: null,
  });
  if (error) redirect("/admin/trials?error=confirm_failed");
  revalidatePath("/admin/trials");
  revalidatePath("/student/trial");
  revalidatePath("/teacher/trials");
  redirect("/admin/trials?status=confirmed");
}

export async function rescheduleTrialLesson(formData: FormData) {
  await requireAreaAccess("admin");
  const parsed = adminTrialRescheduleSchema.safeParse({
    lessonId: readString(formData, "lessonId"),
    localStartsAt: readString(formData, "localStartsAt"),
    timezone: readString(formData, "timezone"),
  });
  if (!parsed.success) redirect("/admin/trials?error=invalid_schedule");
  let startsAt: string;
  try {
    startsAt = zonedLocalDateTimeToUtc(parsed.data.localStartsAt, parsed.data.timezone);
  } catch {
    redirect("/admin/trials?error=invalid_schedule");
  }
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("admin_reschedule_trial_lesson", {
    p_lesson_id: parsed.data.lessonId,
    p_starts_at: startsAt,
  });
  if (error) redirect("/admin/trials?error=reschedule_failed");
  revalidatePath("/admin/trials");
  revalidatePath("/student/trial");
  revalidatePath("/teacher/trials");
  redirect("/admin/trials?status=rescheduled");
}

export async function cancelTrialLesson(formData: FormData) {
  await requireAreaAccess("admin");
  const parsed = adminTrialIdSchema.safeParse({
    lessonId: readString(formData, "lessonId"),
  });
  if (!parsed.success) redirect("/admin/trials?error=invalid_lesson");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("admin_cancel_trial_lesson", {
    p_lesson_id: parsed.data.lessonId,
  });
  if (error) redirect("/admin/trials?error=cancel_failed");
  revalidatePath("/admin/trials");
  revalidatePath("/student/trial");
  revalidatePath("/teacher/trials");
  redirect("/admin/trials?status=cancelled");
}
