import "server-only";

import { z } from "zod";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireAreaAccess } from "@/modules/auth/server-authorization";
import {
  activityCommandSchema, activityTargetSchema, ownActivitySchema, versionInspectionSchema,
} from "@/modules/learning-map/domain";

// Internal foundation only. No route, public workspace or privileged client.
// Each RPC independently rechecks the active database identity and authority.
export async function setOwnLearningActivity(input: unknown): Promise<number> {
  await requireAreaAccess("student");
  const command = activityCommandSchema.parse(input);
  const client = await createServerSupabaseClient();
  const { data, error } = await client.rpc("learning_set_activity", {
    p_version: command.versionId, p_node: command.nodeId,
    p_expected: command.expectedRevision, p_key: command.requestId, p_patch: command.patch,
  });
  if (error) throw new Error("Learning activity could not be saved.");
  return z.number().int().positive().parse(data);
}

export async function getOwnLearningActivity(input: unknown) {
  await requireAreaAccess("student");
  const target = activityTargetSchema.parse(input);
  const client = await createServerSupabaseClient();
  const { data, error } = await client.rpc("learning_get_own_activity", {
    p_version: target.versionId, p_node: target.nodeId,
  });
  if (error) throw new Error("Learning activity is unavailable.");
  return ownActivitySchema.nullable().parse(data);
}

export async function inspectLearningVersion(input: unknown) {
  await requireAreaAccess("admin");
  const version = z.uuid().parse(input);
  const client = await createServerSupabaseClient();
  const { data, error } = await client.rpc("learning_inspect_version", { p_version: version });
  if (error) throw new Error("Curriculum inspection is unavailable.");
  return versionInspectionSchema.nullable().parse(data);
}
