import "server-only";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import type {
  LearningMapStage,
  Specialty,
} from "@/modules/teachers/domain";

export async function getTeacherCatalog(): Promise<{
  specialties: Specialty[];
  stages: LearningMapStage[];
}> {
  const supabase = await createServerSupabaseClient();
  const [specialtiesResult, stagesResult] = await Promise.all([
    supabase.from("specialties").select("id, code, display_name").order("code"),
    supabase
      .from("learning_map_stages")
      .select("stage_number, code, display_name")
      .order("stage_number"),
  ]);

  return {
    specialties: (specialtiesResult.data ?? []).map((specialty) => ({
      code: specialty.code,
      displayName: specialty.display_name,
      id: specialty.id,
    })),
    stages: (stagesResult.data ?? []).map((stage) => ({
      code: stage.code,
      displayName: stage.display_name,
      stageNumber: stage.stage_number,
    })),
  };
}
