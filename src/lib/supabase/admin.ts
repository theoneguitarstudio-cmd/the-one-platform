import { supabaseTransportOptions } from "@/lib/preview/transport";
import "server-only";

import { createClient } from "@supabase/supabase-js";

import { getServiceRoleEnv } from "@/lib/env/server";

export function createPrivilegedSupabaseClient() {
  const env = getServiceRoleEnv();

  return createClient(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.SUPABASE_SERVICE_ROLE_KEY,
    {
      ...supabaseTransportOptions(),
      auth: {
        autoRefreshToken: false,
        detectSessionInUrl: false,
        persistSession: false,
      },
    },
  );
}
