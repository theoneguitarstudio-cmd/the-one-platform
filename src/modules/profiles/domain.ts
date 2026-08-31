import { z } from "zod";

import type { AccountStatus } from "@/modules/auth/domain";

export type PrivateProfile = {
  accountStatus: AccountStatus;
  avatarUrl: string | null;
  createdAt: string;
  displayName: string;
  id: string;
  legacyWordpressUserId: number | null;
  locale: string;
  phone: string | null;
  timezone: string;
  updatedAt: string;
  userId: string;
};

export type PublicProfile = {
  avatarUrl: string | null;
  displayName: string;
  id: string;
  userId: string;
};

const ianaTimezoneSchema = z
  .string()
  .refine(
    (value) =>
      value === "UTC" || /^[A-Za-z_]+\/[A-Za-z0-9._+-]+(?:\/[A-Za-z0-9._+-]+)*$/.test(value),
    "Use an IANA timezone such as Asia/Taipei.",
  );

export const editableProfileSchema = z.object({
  avatarUrl: z.union([z.url().startsWith("https://"), z.literal(""), z.null()]),
  displayName: z.string().trim().min(2).max(80),
  locale: z.string().regex(/^[a-z]{2,3}(-[A-Z]{2})?$/),
  phone: z.union([z.string().trim().min(7).max(32), z.literal(""), z.null()]),
  timezone: ianaTimezoneSchema,
});
