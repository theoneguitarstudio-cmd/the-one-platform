import "server-only";

import { createPrivilegedSupabaseClient } from "@/lib/supabase/admin";

export type AdminTeacherRow = {
  id: string;
  isPublic: boolean;
  publicSlug: string;
  specialtyIds: string[];
  teachingStatus: string;
  userId: string;
};

export async function listAdminTeachers(): Promise<AdminTeacherRow[]> {
  const supabase = createPrivilegedSupabaseClient();
  const { data, error } = await supabase
    .from("teacher_profiles")
    .select(
      "id, user_id, public_slug, teaching_status, is_public, teacher_specialties(specialty_id)",
    )
    .order("created_at", { ascending: false });

  if (error || !data) {
    return [];
  }

  return data.map((teacher) => ({
    id: teacher.id,
    isPublic: teacher.is_public,
    publicSlug: teacher.public_slug,
    specialtyIds: (teacher.teacher_specialties ?? []).map(
      (specialty) => specialty.specialty_id,
    ),
    teachingStatus: teacher.teaching_status,
    userId: teacher.user_id,
  }));
}
