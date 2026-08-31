import "server-only";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import type {
  Specialty,
  TeachingMode,
} from "@/modules/teachers/domain";

export type EditableTeacherProfile = {
  avatarUrl: string | null;
  bio: string;
  fixedLessonPriceTwd: number | null;
  flexibleLessonPriceTwd: number | null;
  locationText: string | null;
  specialties: Specialty[];
  teachingModes: TeachingMode[];
  trialPriceTwd: number | null;
  yearsExperience: number;
};

export async function getOwnEditableTeacherProfile(
  userId: string,
): Promise<EditableTeacherProfile | null> {
  const supabase = await createServerSupabaseClient();
  const { data: teacher, error } = await supabase
    .from("teacher_profiles")
    .select(
      "id, bio, avatar_url, years_experience, trial_price_twd, fixed_lesson_price_twd, flexible_lesson_price_twd, teaching_modes, location_text",
    )
    .eq("user_id", userId)
    .maybeSingle();

  if (error || !teacher) {
    return null;
  }

  const { data: specialtyRows } = await supabase
    .from("teacher_specialties")
    .select("specialty:specialties(id, code, display_name)")
    .eq("teacher_profile_id", teacher.id);

  const specialties = (specialtyRows ?? []).flatMap((row) => {
    const specialty = relationValue(
      row.specialty as
        | { code: string; display_name: string; id: string }
        | { code: string; display_name: string; id: string }[]
        | null,
    );

    return specialty
      ? [
          {
            code: specialty.code,
            displayName: specialty.display_name,
            id: specialty.id,
          },
        ]
      : [];
  });

  return {
    avatarUrl: teacher.avatar_url,
    bio: teacher.bio,
    fixedLessonPriceTwd: teacher.fixed_lesson_price_twd,
    flexibleLessonPriceTwd: teacher.flexible_lesson_price_twd,
    locationText: teacher.location_text,
    specialties,
    teachingModes: teacher.teaching_modes,
    trialPriceTwd: teacher.trial_price_twd,
    yearsExperience: teacher.years_experience,
  };
}

function relationValue<T>(value: T | T[] | null): T | null {
  return Array.isArray(value) ? (value[0] ?? null) : value;
}
