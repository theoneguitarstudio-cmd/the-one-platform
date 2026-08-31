import "server-only";

import { createPrivilegedSupabaseClient } from "@/lib/supabase/admin";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireAreaAccess } from "@/modules/auth/server-authorization";
import type {
  StudentTrialResult,
  TeacherTrial,
  TrialTeacherContext,
} from "@/modules/trials/domain";

type TeacherTrialRow = {
  delivery_mode: "online" | "onsite";
  ends_at: string;
  has_meeting: boolean;
  learning_goal: string;
  lesson_id: string;
  lesson_status: string;
  location_text: string | null;
  preferred_mode: "online" | "onsite" | null;
  private_teacher_notes: string;
  starts_at: string;
  student_display_name: string;
  student_timezone: string;
};

type StudentTrialResultRow = {
  assessment_summary: string | null;
  delivery_mode: "online" | "onsite";
  ends_at: string;
  has_meeting: boolean;
  homework: string | null;
  lesson_id: string;
  lesson_status: string;
  location_text: string | null;
  next_goal: string | null;
  performance_summary: string | null;
  primary_stage: number | null;
  recommendation: "recorded_course" | "one_to_one" | "hybrid" | null;
  starts_at: string;
  student_visible_notes: string | null;
  teacher_display_name: string;
};

export async function getTrialTeacherContext(
  slug: string,
): Promise<TrialTeacherContext | null> {
  await requireAreaAccess("student");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("get_trial_teacher_context", {
    p_teacher_slug: slug,
  });
  const row = data?.[0];
  if (error || !row || row.trial_price_twd === null) return null;
  return {
    displayName: row.display_name,
    locationText: row.location_text,
    publicSlug: row.public_slug,
    teacherTimezone: row.teacher_timezone,
    teachingModes: row.teaching_modes,
    trialPriceTwd: row.trial_price_twd,
  };
}

export async function getOwnProfileTimezone(userId: string): Promise<string> {
  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("profiles")
    .select("timezone")
    .eq("user_id", userId)
    .single();
  return data?.timezone ?? "Asia/Taipei";
}

export async function listOwnTeacherTrials(): Promise<TeacherTrial[]> {
  const identity = await requireAreaAccess("teacher");
  const supabase = await createServerSupabaseClient();
  const [{ data, error }, teacherTimezone] = await Promise.all([
    supabase.rpc("get_own_teacher_trials"),
    getOwnProfileTimezone(identity.userId),
  ]);
  if (error || !data) return [];
  return (data as TeacherTrialRow[]).map((row) => ({
    deliveryMode: row.delivery_mode,
    endsAt: row.ends_at,
    hasMeeting: row.has_meeting,
    learningGoal: row.learning_goal,
    lessonId: row.lesson_id,
    locationText: row.location_text,
    preferredMode: row.preferred_mode,
    privateTeacherNotes: row.private_teacher_notes,
    startsAt: row.starts_at,
    status: row.lesson_status,
    studentDisplayName: row.student_display_name,
    studentTimezone: row.student_timezone,
    teacherTimezone,
  }));
}

export async function listOwnStudentTrialResults(): Promise<StudentTrialResult[]> {
  await requireAreaAccess("student");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("get_own_student_trial_results");
  if (error || !data) return [];
  return (data as StudentTrialResultRow[]).map((row) => ({
    assessmentSummary: row.assessment_summary,
    deliveryMode: row.delivery_mode,
    endsAt: row.ends_at,
    hasMeeting: row.has_meeting,
    homework: row.homework,
    lessonId: row.lesson_id,
    locationText: row.location_text,
    nextGoal: row.next_goal,
    performanceSummary: row.performance_summary,
    primaryStage: row.primary_stage,
    recommendation: row.recommendation,
    startsAt: row.starts_at,
    status: row.lesson_status,
    studentVisibleNotes: row.student_visible_notes,
    teacherDisplayName: row.teacher_display_name,
  }));
}

export async function listOwnTrialOrders(): Promise<AdminTrialOrder[]> {
  await requireAreaAccess("student");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("trial_orders")
    .select("id, teacher_user_id, delivery_mode, proposed_starts_at, timezone, price_twd, payment_status, created_at")
    .order("created_at", { ascending: false });
  if (error || !data) return [];
  return data.map((row) => ({
    createdAt: row.created_at,
    deliveryMode: row.delivery_mode,
    id: row.id,
    paymentStatus: row.payment_status,
    priceTwd: row.price_twd,
    proposedStartsAt: row.proposed_starts_at,
    studentUserId: "",
    teacherUserId: row.teacher_user_id,
    timezone: row.timezone,
  }));
}

export type AdminTrialOrder = {
  createdAt: string;
  deliveryMode: string;
  id: string;
  paymentStatus: string;
  priceTwd: number;
  proposedStartsAt: string;
  studentUserId: string;
  teacherUserId: string;
  timezone: string;
};

export type AdminTrialLesson = {
  deliveryMode: string;
  id: string;
  startsAt: string;
  status: string;
  studentUserId: string;
  teacherUserId: string;
  timezone: string;
};

export type AdminTrialRelationship = {
  id: string;
  preferredMode: string;
  status: string;
  studentUserId: string;
  teacherUserId: string;
};

export async function listAdminTrialData(): Promise<{
  lessons: AdminTrialLesson[];
  orders: AdminTrialOrder[];
  relationships: AdminTrialRelationship[];
}> {
  await requireAreaAccess("admin");
  const supabase = createPrivilegedSupabaseClient();
  const [ordersResult, lessonsResult, relationshipsResult] = await Promise.all([
    supabase
      .from("trial_orders")
      .select("id, student_user_id, teacher_user_id, delivery_mode, proposed_starts_at, timezone, price_twd, payment_status, created_at")
      .order("created_at", { ascending: false }),
    supabase
      .from("lessons")
      .select("id, student_user_id, teacher_user_id, delivery_mode, starts_at, timezone_anchor, status")
      .eq("lesson_type", "trial")
      .order("starts_at", { ascending: false }),
    supabase
      .from("student_teacher_relationships")
      .select("id, student_user_id, teacher_user_id, relationship_status, preferred_mode")
      .in("relationship_status", ["trial", "awaiting_conversion"])
      .order("created_at", { ascending: false }),
  ]);
  return {
    lessons: (lessonsResult.data ?? []).map((row) => ({
      deliveryMode: row.delivery_mode,
      id: row.id,
      startsAt: row.starts_at,
      status: row.status,
      studentUserId: row.student_user_id,
      teacherUserId: row.teacher_user_id,
      timezone: row.timezone_anchor,
    })),
    orders: (ordersResult.data ?? []).map((row) => ({
      createdAt: row.created_at,
      deliveryMode: row.delivery_mode,
      id: row.id,
      paymentStatus: row.payment_status,
      priceTwd: row.price_twd,
      proposedStartsAt: row.proposed_starts_at,
      studentUserId: row.student_user_id,
      teacherUserId: row.teacher_user_id,
      timezone: row.timezone,
    })),
    relationships: (relationshipsResult.data ?? []).map((row) => ({
      id: row.id,
      preferredMode: row.preferred_mode,
      status: row.relationship_status,
      studentUserId: row.student_user_id,
      teacherUserId: row.teacher_user_id,
    })),
  };
}
