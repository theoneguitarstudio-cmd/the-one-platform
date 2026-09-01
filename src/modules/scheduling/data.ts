import "server-only";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireAreaAccess } from "@/modules/auth/server-authorization";
import type { SchedulingBooking } from "@/modules/scheduling/domain";

export type FlexibleSlot = {
  booking_mode_eligibility: "fixed" | "flexible" | "both";
  ends_at: string;
  lesson_duration_minutes: number;
  starts_at: string;
  teacher_timezone: string;
};

export type RecurringSeriesSummary = {
  duration_minutes: number;
  effective_from: string;
  effective_until: string | null;
  id: string;
  local_start_time: string;
  preferred_entitlement_id?: string | null;
  status: "active" | "paused" | "ended";
  student_user_id?: string;
  teacher_user_id?: string;
  timezone: string;
  weekday: number;
};

export type AvailabilityConfiguration = {
  booking_horizon_days: number;
  effective_from: string | null;
  effective_until: string | null;
  is_active: boolean | null;
  local_end_time: string | null;
  local_start_time: string | null;
  minimum_booking_notice_minutes: number;
  rule_id: string | null;
  setting_timezone: string;
  slot_interval_minutes: number;
  weekday: number | null;
};

export type AdminScheduleItem = {
  booking_id: string;
  credit_reservation_id: string | null;
  ends_at: string;
  lesson_id: string | null;
  recurring_series_id: string | null;
  source: "fixed" | "flexible";
  starts_at: string;
  status: string;
  student_user_id: string;
  teacher_user_id: string;
};

export async function listOwnSchedulingBookings(): Promise<SchedulingBooking[]> {
  await requireAreaAccess("student");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("get_own_scheduling_bookings");
  if (error) return [];
  return (data ?? []) as SchedulingBooking[];
}

export async function listTeacherSchedulingBookings() {
  await requireAreaAccess("teacher");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("get_teacher_scheduling_bookings");
  if (error) return [];
  return (data ?? []) as Array<SchedulingBooking & { student_user_id: string }>;
}

export async function listOwnRecurringSeries(): Promise<RecurringSeriesSummary[]> {
  await requireAreaAccess("student");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("get_own_recurring_lesson_series");
  if (error) return [];
  return (data ?? []) as RecurringSeriesSummary[];
}

export async function listTeacherRecurringSeries(): Promise<RecurringSeriesSummary[]> {
  await requireAreaAccess("teacher");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("get_teacher_recurring_lesson_series");
  if (error) return [];
  return (data ?? []) as RecurringSeriesSummary[];
}

export async function getTeacherAvailabilityConfiguration(): Promise<AvailabilityConfiguration[]> {
  await requireAreaAccess("teacher");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("get_teacher_availability_configuration");
  if (error) return [];
  return (data ?? []) as AvailabilityConfiguration[];
}

export async function findFlexibleSlots(input: {
  entitlementId: string;
  from: string;
  teacherUserId: string;
  to: string;
}): Promise<FlexibleSlot[]> {
  await requireAreaAccess("student");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("get_available_flexible_slots", {
    p_entitlement_id: input.entitlementId,
    p_from: input.from,
    p_teacher_user_id: input.teacherUserId,
    p_to: input.to,
  });
  if (error) return [];
  return (data ?? []) as FlexibleSlot[];
}

export async function listAdminSchedule(from: string, to: string): Promise<AdminScheduleItem[]> {
  await requireAreaAccess("admin");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("get_admin_schedule_overview", {
    p_from: from,
    p_to: to,
  });
  if (error) return [];
  return (data ?? []) as AdminScheduleItem[];
}
