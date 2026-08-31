import "server-only";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import type {
  LearningMapStage,
  PublicTeacher,
  Specialty,
  TeachingMode,
} from "@/modules/teachers/domain";

type PublicTeacherRow = {
  avatar_url: string | null;
  bio: string;
  display_name: string;
  fixed_lesson_price_twd: number | null;
  flexible_lesson_price_twd: number | null;
  location_text: string | null;
  public_slug: string;
  teacher_profile_id: string;
  teaching_modes: TeachingMode[];
  trial_price_twd: number | null;
  years_experience: number;
};

type SpecialtyRelation = {
  code: string;
  display_name: string;
  id: string;
};

type StageRelation = {
  code: string;
  display_name: string;
  stage_number: number;
};

function relationValue<T>(value: T | T[] | null): T | null {
  return Array.isArray(value) ? (value[0] ?? null) : value;
}

async function loadPublicTeacherData() {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("teacher_public_profiles")
    .select(
      "teacher_profile_id, public_slug, display_name, avatar_url, bio, years_experience, trial_price_twd, fixed_lesson_price_twd, flexible_lesson_price_twd, teaching_modes, location_text",
    )
    .order("public_slug", { ascending: true });

  if (error || !data) {
    return [];
  }

  const teachers = data as PublicTeacherRow[];
  const teacherProfileIds = teachers.map((teacher) => teacher.teacher_profile_id);

  if (teacherProfileIds.length === 0) {
    return teachers.map((teacher) => ({
      ...toPublicTeacher(teacher),
      specialties: [],
      stages: [],
    }));
  }

  const [specialtiesResult, stagesResult] = await Promise.all([
    supabase
      .from("teacher_specialties")
      .select(
        "teacher_profile_id, specialty:specialties(id, code, display_name)",
      )
      .in("teacher_profile_id", teacherProfileIds),
    supabase
      .from("teacher_stage_capabilities")
      .select(
        "teacher_profile_id, stage:learning_map_stages(stage_number, code, display_name)",
      )
      .in("teacher_profile_id", teacherProfileIds),
  ]);

  const specialtiesByTeacher = new Map<string, Specialty[]>();
  for (const row of specialtiesResult.data ?? []) {
    const specialty = relationValue(
      row.specialty as SpecialtyRelation | SpecialtyRelation[] | null,
    );
    if (!specialty) {
      continue;
    }

    const current = specialtiesByTeacher.get(row.teacher_profile_id) ?? [];
    current.push({
      code: specialty.code,
      displayName: specialty.display_name,
      id: specialty.id,
    });
    specialtiesByTeacher.set(row.teacher_profile_id, current);
  }

  const stagesByTeacher = new Map<string, LearningMapStage[]>();
  for (const row of stagesResult.data ?? []) {
    const stage = relationValue(
      row.stage as StageRelation | StageRelation[] | null,
    );
    if (!stage) {
      continue;
    }

    const current = stagesByTeacher.get(row.teacher_profile_id) ?? [];
    current.push({
      code: stage.code,
      displayName: stage.display_name,
      stageNumber: stage.stage_number,
    });
    stagesByTeacher.set(row.teacher_profile_id, current);
  }

  return teachers.map((teacher) => ({
    ...toPublicTeacher(teacher),
    specialties: specialtiesByTeacher.get(teacher.teacher_profile_id) ?? [],
    stages: (stagesByTeacher.get(teacher.teacher_profile_id) ?? []).sort(
      (a, b) => a.stageNumber - b.stageNumber,
    ),
  }));
}

function toPublicTeacher(row: PublicTeacherRow): Omit<PublicTeacher, "specialties" | "stages"> {
  return {
    avatarUrl: row.avatar_url,
    bio: row.bio,
    displayName: row.display_name,
    fixedLessonPriceTwd: row.fixed_lesson_price_twd,
    flexibleLessonPriceTwd: row.flexible_lesson_price_twd,
    locationText: row.location_text,
    publicSlug: row.public_slug,
    teachingModes: row.teaching_modes,
    trialPriceTwd: row.trial_price_twd,
    yearsExperience: row.years_experience,
  };
}

export async function listPublicTeachers(): Promise<PublicTeacher[]> {
  return loadPublicTeacherData();
}

export async function getPublicTeacherBySlug(
  slug: string,
): Promise<PublicTeacher | null> {
  const teachers = await loadPublicTeacherData();
  return teachers.find((teacher) => teacher.publicSlug === slug) ?? null;
}
