"use server";

import "server-only";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import { createPrivilegedSupabaseClient } from "@/lib/supabase/admin";
import { requireAreaAccess } from "@/modules/auth/server-authorization";
import {
  adminTeacherProfileSchema,
  specialtyIdsSchema,
  teacherCapabilitySchema,
} from "@/modules/teachers/domain";

function readString(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

export async function saveAdminTeacherProfile(formData: FormData) {
  await requireAreaAccess("admin");
  const parsed = adminTeacherProfileSchema.safeParse({
    isPublic: formData.get("isPublic") === "on",
    publicSlug: readString(formData, "publicSlug"),
    teachingStatus: readString(formData, "teachingStatus"),
    userId: readString(formData, "userId"),
  });

  if (!parsed.success) {
    redirect("/admin/teachers?error=invalid_input");
  }

  const supabase = createPrivilegedSupabaseClient();
  const { error: roleError } = await supabase.from("user_roles").upsert(
    {
      role: "teacher",
      user_id: parsed.data.userId,
    },
    { onConflict: "user_id,role", ignoreDuplicates: true },
  );

  if (roleError) {
    redirect("/admin/teachers?error=save_failed");
  }

  const { error } = await supabase.from("teacher_profiles").upsert(
    {
      is_public: parsed.data.isPublic,
      public_slug: parsed.data.publicSlug,
      teaching_status: parsed.data.teachingStatus,
      user_id: parsed.data.userId,
    },
    { onConflict: "user_id" },
  );

  if (error) {
    redirect("/admin/teachers?error=save_failed");
  }

  revalidatePath("/admin/teachers");
  revalidatePath("/teachers");
  redirect("/admin/teachers?status=saved");
}

export async function saveAdminTeacherCapability(formData: FormData) {
  await requireAreaAccess("admin");
  const parsed = teacherCapabilitySchema.safeParse({
    capabilityStatus: readString(formData, "capabilityStatus"),
    stageNumber: readString(formData, "stageNumber"),
    teacherProfileId: readString(formData, "teacherProfileId"),
  });

  if (!parsed.success) {
    redirect("/admin/teachers?error=invalid_input");
  }

  const supabase = createPrivilegedSupabaseClient();
  const { error } = await supabase
    .from("teacher_stage_capabilities")
    .upsert(
      {
        capability_status: parsed.data.capabilityStatus,
        stage_number: parsed.data.stageNumber,
        teacher_profile_id: parsed.data.teacherProfileId,
      },
      { onConflict: "teacher_profile_id,stage_number" },
    );

  if (error) {
    redirect("/admin/teachers?error=save_failed");
  }

  revalidatePath("/admin/teachers");
  revalidatePath("/teachers");
  redirect("/admin/teachers?status=saved");
}

export async function saveAdminTeacherSpecialties(formData: FormData) {
  await requireAreaAccess("admin");
  const teacherProfileId = z.uuid().safeParse(
    readString(formData, "teacherProfileId"),
  );
  const specialtyIds = specialtyIdsSchema.safeParse(
    formData.getAll("specialtyIds"),
  );

  if (!teacherProfileId.success || !specialtyIds.success) {
    redirect("/admin/teachers?error=invalid_input");
  }

  const supabase = createPrivilegedSupabaseClient();
  const { error: deleteError } = await supabase
    .from("teacher_specialties")
    .delete()
    .eq("teacher_profile_id", teacherProfileId.data);

  if (deleteError) {
    redirect("/admin/teachers?error=save_failed");
  }

  if (specialtyIds.data.length > 0) {
    const { error: insertError } = await supabase
      .from("teacher_specialties")
      .insert(
        specialtyIds.data.map((specialtyId) => ({
          specialty_id: specialtyId,
          teacher_profile_id: teacherProfileId.data,
        })),
      );

    if (insertError) {
      redirect("/admin/teachers?error=save_failed");
    }
  }

  revalidatePath("/admin/teachers");
  revalidatePath("/teachers");
  redirect("/admin/teachers?status=saved");
}
