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
  const identity = await requireAreaAccess("teacher");
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
  const { data: teacher, error: teacherError } = await supabase
    .from("teacher_profiles")
    .select("id")
    .eq("user_id", identity.userId)
    .maybeSingle();

  if (teacherError || !teacher) {
    redirect("/auth/access-denied");
  }

  const { error: profileError } = await supabase
    .from("teacher_profiles")
    .update({
      avatar_url: parsed.data.avatarUrl,
      bio: parsed.data.bio,
      fixed_lesson_price_twd: parsed.data.fixedLessonPriceTwd,
      flexible_lesson_price_twd: parsed.data.flexibleLessonPriceTwd,
      location_text: parsed.data.locationText,
      teaching_modes: parsed.data.teachingModes,
      trial_price_twd: parsed.data.trialPriceTwd,
      years_experience: parsed.data.yearsExperience,
    })
    .eq("id", teacher.id);

  if (profileError) {
    redirect("/teacher/profile?error=save_failed");
  }

  const { error: deleteError } = await supabase
    .from("teacher_specialties")
    .delete()
    .eq("teacher_profile_id", teacher.id);

  if (deleteError) {
    redirect("/teacher/profile?error=save_failed");
  }

  if (specialtyIds.data.length > 0) {
    const { error: insertError } = await supabase
      .from("teacher_specialties")
      .insert(
        specialtyIds.data.map((specialtyId) => ({
          specialty_id: specialtyId,
          teacher_profile_id: teacher.id,
        })),
      );

    if (insertError) {
      redirect("/teacher/profile?error=save_failed");
    }
  }

  revalidatePath("/teacher/profile");
  revalidatePath("/teachers");
  redirect("/teacher/profile?status=saved");
}
