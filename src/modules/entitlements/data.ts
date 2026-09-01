import "server-only";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireAreaAccess } from "@/modules/auth/server-authorization";
import type { EntitlementSummary } from "@/modules/entitlements/domain";

export async function listOwnLessonPackages(): Promise<EntitlementSummary[]> {
  await requireAreaAccess("student");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("get_own_lesson_entitlement_summaries");
  if (error) return [];
  return (data ?? []) as EntitlementSummary[];
}

export async function listTeacherStudentLessonPackages(studentUserId: string) {
  await requireAreaAccess("teacher");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("get_teacher_student_lesson_entitlement_summaries", {
    p_student_user_id: studentUserId,
  });
  if (error) return [];
  return (data ?? []) as Array<Pick<EntitlementSummary,
    "id" | "package_name" | "credits_available" | "credits_reserved" |
    "expires_at" | "status" | "booking_mode_eligibility">>;
}

export async function listAdminLessonPackages() {
  await requireAreaAccess("admin");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("get_admin_lesson_entitlement_summaries");
  if (error) return [];
  return (data ?? []) as Array<EntitlementSummary & {
    beneficiary_name: string;
    beneficiary_user_id: string;
  }>;
}
