import { z } from "zod";

export const TEACHING_STATUSES = [
  "draft",
  "active",
  "paused",
  "inactive",
] as const;

export type TeachingStatus = (typeof TEACHING_STATUSES)[number];

export const TEACHING_MODES = ["onsite", "online"] as const;

export type TeachingMode = (typeof TEACHING_MODES)[number];

export const TEACHING_MODE_LABELS: Record<TeachingMode, string> = {
  onsite: "實體",
  online: "線上",
};

export const STAGE_CAPABILITY_STATUSES = ["allowed", "certified"] as const;

export type StageCapabilityStatus =
  (typeof STAGE_CAPABILITY_STATUSES)[number];

export type Specialty = {
  code: string;
  displayName: string;
  id: string;
};

export type LearningMapStage = {
  code: string;
  displayName: string;
  stageNumber: number;
};

export type PublicTeacher = {
  avatarUrl: string | null;
  bio: string;
  displayName: string;
  fixedLessonPriceTwd: number | null;
  flexibleLessonPriceTwd: number | null;
  locationText: string | null;
  publicSlug: string;
  specialties: Specialty[];
  stages: LearningMapStage[];
  teachingModes: TeachingMode[];
  trialPriceTwd: number | null;
  yearsExperience: number;
};

const optionalTwdSchema = z
  .union([z.literal(""), z.coerce.number().int().min(0).max(1_000_000)])
  .transform((value) => (value === "" ? null : value));

const optionalTextSchema = z
  .union([z.literal(""), z.string().trim()])
  .transform((value) => (value === "" ? null : value));

export const editableTeacherProfileSchema = z.object({
  avatarUrl: z
    .union([z.literal(""), z.url().startsWith("https://")])
    .transform((value) => (value === "" ? null : value)),
  bio: z.string().trim().max(4000),
  fixedLessonPriceTwd: optionalTwdSchema,
  flexibleLessonPriceTwd: optionalTwdSchema,
  locationText: optionalTextSchema.refine(
    (value) => value === null || value.length <= 160,
  ),
  teachingModes: z
    .array(z.enum(TEACHING_MODES))
    .max(2)
    .refine((modes) => new Set(modes).size === modes.length),
  trialPriceTwd: optionalTwdSchema,
  yearsExperience: z.coerce.number().int().min(0).max(80),
});

export const adminTeacherProfileSchema = z.object({
  isPublic: z.boolean(),
  publicSlug: z
    .string()
    .trim()
    .toLowerCase()
    .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    .min(3)
    .max(80),
  teachingStatus: z.enum(TEACHING_STATUSES),
  userId: z.uuid(),
});

export const teacherCapabilitySchema = z.object({
  capabilityStatus: z.enum(STAGE_CAPABILITY_STATUSES),
  stageNumber: z.coerce.number().int().min(1).max(5),
  teacherProfileId: z.uuid(),
});

export const specialtyIdsSchema = z
  .array(z.uuid())
  .max(20)
  .refine((ids) => new Set(ids).size === ids.length);
