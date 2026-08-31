"use server";

import "server-only";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireAreaAccess } from "@/modules/auth/server-authorization";
import {
  editableTeacherProfileSchema,
  specialtyIdsSchema,
} from "@/modules/teachers/domain";

function readString(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

export async function saveOwnTeacherProfile(formData: FormData) {
  await requireAreaAccess("teacher");
  const parsed = editableTeacherProfileSchema.safeParse({
    avatarUrl: readString(formData, "avatarUrl"),
    bio: readString(formData, "bio"),
    fixedLessonPriceTwd: readString(formData, "fixedLessonPriceTwd"),
    flexibleLessonPriceTwd: readString(formData, "flexibleLessonPriceTwd"),
    locationText: readString(formData, "locationText"),
    teachingModes: formData.getAll("teachingModes"),
    trialPriceTwd: readString(formData, "trialPriceTwd"),
    yearsExperience: readString(formData, "yearsExperience"),
  });
  const specialtyIds = specialtyIdsSchema.safeParse(
    formData.getAll("specialtyIds"),
  );

  if (!parsed.success || !specialtyIds.success) {
    redirect("/teacher/profile?error=invalid_input");
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("update_own_teacher_profile", {
    p_avatar_url: parsed.data.avatarUrl,
    p_bio: parsed.data.bio,
    p_fixed_lesson_price_twd: parsed.data.fixedLessonPriceTwd,
    p_flexible_lesson_price_twd: parsed.data.flexibleLessonPriceTwd,
    p_location_text: parsed.data.locationText,
    p_specialty_ids: specialtyIds.data,
    p_teaching_modes: parsed.data.teachingModes,
    p_trial_price_twd: parsed.data.trialPriceTwd,
    p_years_experience: parsed.data.yearsExperience,
  });

  if (error) {
    redirect("/teacher/profile?error=save_failed");
  }

  revalidatePath("/teacher/profile");
  revalidatePath("/teachers");
  redirect("/teacher/profile?status=saved");
}
