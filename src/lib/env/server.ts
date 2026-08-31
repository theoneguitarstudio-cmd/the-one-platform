import "server-only";

import { z } from "zod";

import { getPublicSupabaseEnv } from "@/lib/env/public";

const serviceRoleEnvSchema = z.object({
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(20),
});

export function getServerSupabaseEnv() {
  return getPublicSupabaseEnv();
}

export function getServiceRoleEnv() {
  const result = serviceRoleEnvSchema.safeParse({
    SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
  });

  if (!result.success) {
    throw new Error("Supabase privileged environment is not configured.");
  }

  return {
    ...getServerSupabaseEnv(),
    ...result.data,
  };
}

export function getSiteUrl(): string {
  const configuredUrl = process.env.NEXT_PUBLIC_SITE_URL;

  if (!configuredUrl && process.env.NODE_ENV === "development") {
    return "http://localhost:3000";
  }

  const result = z.url().safeParse(configuredUrl);

  if (!result.success) {
    throw new Error("NEXT_PUBLIC_SITE_URL is not configured.");
  }

  const url = new URL(result.data);
  if (!["http:", "https:"].includes(url.protocol) || url.username || url.password) {
    throw new Error("NEXT_PUBLIC_SITE_URL is invalid.");
  }

  return url.origin;
}
