export function isMockDataMode(env: Record<string, string | undefined> = {
  THE_ONE_ENV: process.env.THE_ONE_ENV,
  NEXT_PUBLIC_DATA_MODE: process.env.NEXT_PUBLIC_DATA_MODE,
  NEXT_PUBLIC_APP_ENV: process.env.NEXT_PUBLIC_APP_ENV,
  NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
}): boolean {
  const mode = env.NEXT_PUBLIC_DATA_MODE;
  if (mode === undefined || mode === "" || mode === "supabase") return false;
  if (mode !== "mock" || env.NEXT_PUBLIC_APP_ENV !== "preview" || (env.THE_ONE_ENV && env.THE_ONE_ENV !== "preview")) throw new Error("Unknown or unsafe data environment");
  if (env.NEXT_PUBLIC_SUPABASE_URL || env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY) throw new Error("Mock must not contain Supabase connection settings");
  return true;
}
export const mockSupabaseEnvironment = {
  NEXT_PUBLIC_SUPABASE_URL: "https://preview.invalid",
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "synthetic-preview-public-key-only",
};
