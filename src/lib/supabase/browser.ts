import { supabaseTransportOptions } from "@/lib/preview/transport";
import { createBrowserClient } from "@supabase/ssr";

import { getPublicSupabaseEnv } from "@/lib/env/public";

export function createBrowserSupabaseClient() {
  const env = getPublicSupabaseEnv();

  return createBrowserClient(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    supabaseTransportOptions(),
  );
}
