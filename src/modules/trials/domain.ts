import { z } from "zod";

import { SUPPORTED_MEETING_PROVIDERS } from "@/modules/trials/meeting-url";

export const DELIVERY_MODES = ["online", "onsite"] as const;
export type DeliveryMode = (typeof DELIVERY_MODES)[number];

export const RECOMMENDATION_TYPES = [
  "recorded_course",
  "one_to_one",
  "hybrid",
] as const;
export type RecommendationType = (typeof RECOMMENDATION_TYPES)[number];

export const RECOMMENDATION_LABELS: Record<RecommendationType, string> = {
  hybrid: "錄播課搭配一對一",
  one_to_one: "一對一正式課程",
  recorded_course: "錄播課程",
};

const localDateTimeSchema = z.string().regex(
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/,
  "請選擇有效日期與時間。",
);

export const teacherSlugSchema = z
  .string()
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
  .max(80);

export const trialRequestSchema = z.object({
  idempotencyKey: z.string().min(16).max(160),
  learningGoal: z.string().trim().min(1).max(1000),
  localStartsAt: localDateTimeSchema,
  preferredLocation: z.string().trim().max(160),
  preferredMode: z.enum(DELIVERY_MODES),
  teacherSlug: teacherSlugSchema,
  timezone: z.string().min(3).max(80),
});

export const checkoutIntentKeySchema = z.uuid();

export const teacherMeetingDefaultsSchema = z.object({
  provider: z.enum(SUPPORTED_MEETING_PROVIDERS),
  url: z.url().startsWith("https://").max(2048),
});

export const trialCompletionSchema = z.object({
  assessmentSummary: z.string().trim().min(1).max(4000),
  homework: z.string().trim().max(2000),
  lessonId: z.uuid(),
  nextGoal: z.string().trim().max(2000),
  performanceSummary: z.string().trim().max(4000),
  privateTeacherNotes: z.string().trim().max(4000),
  recommendationType: z.enum(RECOMMENDATION_TYPES),
  stageNumber: z.coerce.number().int().min(1).max(5),
  studentVisibleNotes: z.string().trim().max(4000),
});

export const adminTrialIdSchema = z.object({ lessonId: z.uuid() });
export const adminTrialOrderSchema = z.object({ orderId: z.uuid() });
export const adminTrialRescheduleSchema = adminTrialIdSchema.extend({
  localStartsAt: localDateTimeSchema,
  timezone: z.string().min(3).max(80),
});

export type TrialTeacherContext = {
  displayName: string;
  locationText: string | null;
  publicSlug: string;
  teacherTimezone: string;
  teachingModes: DeliveryMode[];
  trialPriceTwd: number;
};

export type TeacherTrial = {
  deliveryMode: DeliveryMode;
  endsAt: string;
  hasMeeting: boolean;
  learningGoal: string;
  lessonId: string;
  locationText: string | null;
  preferredMode: DeliveryMode | null;
  privateTeacherNotes: string;
  startsAt: string;
  status: string;
  studentDisplayName: string;
  studentTimezone: string;
  teacherTimezone: string;
};

export type StudentTrialResult = {
  assessmentSummary: string | null;
  deliveryMode: DeliveryMode;
  endsAt: string;
  hasMeeting: boolean;
  homework: string | null;
  lessonId: string;
  locationText: string | null;
  nextGoal: string | null;
  performanceSummary: string | null;
  primaryStage: number | null;
  recommendation: RecommendationType | null;
  startsAt: string;
  status: string;
  studentVisibleNotes: string | null;
  teacherDisplayName: string;
};
