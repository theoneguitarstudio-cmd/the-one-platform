import type { EmailOtpType } from "@supabase/supabase-js";
import { NextResponse } from "next/server";

import { getSiteUrl } from "@/lib/env/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { getSafeRedirectPath } from "@/modules/auth/safe-redirect";

const EMAIL_OTP_TYPES = new Set<EmailOtpType>([
  "email",
  "email_change",
  "invite",
  "magiclink",
  "recovery",
  "signup",
]);

function isEmailOtpType(value: string): value is EmailOtpType {
  return EMAIL_OTP_TYPES.has(value as EmailOtpType);
}

export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const trustedOrigin = getSiteUrl();
  const tokenHash = requestUrl.searchParams.get("token_hash");
  const type = requestUrl.searchParams.get("type");
  const next = getSafeRedirectPath(requestUrl.searchParams.get("next"));

  if (!tokenHash || !type || !isEmailOtpType(type)) {
    return NextResponse.redirect(
      new URL("/auth/sign-in?error=auth_callback_failed", trustedOrigin),
    );
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.auth.verifyOtp({
    token_hash: tokenHash,
    type,
  });

  return NextResponse.redirect(
    new URL(
      error ? "/auth/sign-in?error=auth_callback_failed" : next,
      trustedOrigin,
    ),
  );
}
