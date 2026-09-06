import { z } from "zod";

export const activityTargetSchema = z.object({
  versionId: z.uuid(),
  nodeId: z.uuid(),
}).strict();

export const activityPatchSchema = z.object({
  opened: z.literal(true).optional(),
  resume_resource_id: z.uuid().nullable().optional(),
  needs_revisit: z.boolean().optional(),
  self_completed: z.boolean().optional(),
}).strict().refine((patch) => Object.values(patch).some((value) => value !== undefined), {
  message: "An explicit personal activity change is required.",
});

export const activityCommandSchema = activityTargetSchema.extend({
  expectedRevision: z.number().int().min(0).max(2147483646),
  requestId: z.uuid(),
  patch: activityPatchSchema,
});

export const ownActivitySchema = z.object({
  revision: z.number().int().positive(),
  opened_at: z.string().nullable(),
  last_opened_at: z.string().nullable(),
  resume_resource_id: z.uuid().nullable(),
  needs_revisit: z.boolean(),
  self_completed: z.boolean(),
  self_completed_at: z.string().nullable(),
}).strict();

// A self-report is never a formal outcome, even when every Node is marked.
export type OwnLearningActivity = z.infer<typeof ownActivitySchema>;
export type ActivityCommand = z.infer<typeof activityCommandSchema>;

const idTitle = { id: z.uuid(), title: z.string() };
export const versionInspectionSchema = z.object({
  ...idTitle, course_id: z.uuid(), map_id: z.uuid(), version_number: z.number().int(),
  state: z.enum(["draft", "frozen"]), revision: z.number().int(),
  levels: z.array(z.object({ ...idTitle, position: z.number().int() }).strict()),
  modules: z.array(z.object({ ...idTitle, level_id: z.uuid(), position: z.number().int() }).strict()),
  nodes: z.array(z.object({
    ...idTitle, module_id: z.uuid(), guidance: z.string(), position: z.number().int(),
    resources: z.array(z.object({ ...idTitle, revision_id: z.uuid(), kind: z.string(), purpose: z.string(), position: z.number().int() }).strict()),
    objectives: z.array(z.object({ id: z.uuid(), objective: z.string() }).strict()),
    capabilities: z.array(z.object({ id: z.uuid(), code: z.string(), description: z.string() }).strict()),
  }).strict()),
  credits: z.array(z.object({ display_credit: z.string(), contribution: z.string(), resource_revision_id: z.uuid().nullable() }).strict()),
}).strict();
