import { NextResponse } from "next/server";

import { getSiteUrl } from "@/lib/env/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { getSafeRedirectPath } from "@/modules/auth/safe-redirect";

export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const trustedOrigin = getSiteUrl();
  const code = requestUrl.searchParams.get("code");
  const next = getSafeRedirectPath(requestUrl.searchParams.get("next"));

  if (!code) {
    return NextResponse.redirect(
      new URL("/auth/sign-in?error=auth_callback_failed", trustedOrigin),
    );
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);

  return NextResponse.redirect(
    new URL(
      error ? "/auth/sign-in?error=auth_callback_failed" : next,
      trustedOrigin,
    ),
  );
}
