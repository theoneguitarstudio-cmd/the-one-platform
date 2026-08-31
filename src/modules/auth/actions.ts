"use server";

import "server-only";

import { redirect } from "next/navigation";

import { getSiteUrl } from "@/lib/env/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { getSafeRedirectPath } from "@/modules/auth/safe-redirect";
import {
  emailSchema,
  passwordSchema,
  signInSchema,
  signUpSchema,
} from "@/modules/auth/validation";

function readString(formData: FormData, field: string): string {
  const value = formData.get(field);
  return typeof value === "string" ? value : "";
}

export async function signUp(formData: FormData) {
  const parsed = signUpSchema.safeParse({
    displayName: readString(formData, "displayName"),
    email: readString(formData, "email"),
    password: readString(formData, "password"),
  });

  if (!parsed.success) {
    redirect("/auth/sign-up?error=invalid_input");
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.auth.signUp({
    email: parsed.data.email,
    password: parsed.data.password,
    options: {
      data: { display_name: parsed.data.displayName },
      emailRedirectTo: `${getSiteUrl()}/auth/callback?next=/student`,
    },
  });

  redirect(
    error
      ? "/auth/sign-up?error=signup_failed"
      : "/auth/verify-email?status=check_email",
  );
}

export async function signIn(formData: FormData) {
  const parsed = signInSchema.safeParse({
    email: readString(formData, "email"),
    password: readString(formData, "password"),
  });
  const next = getSafeRedirectPath(readString(formData, "next"));

  if (!parsed.success) {
    redirect(`/auth/sign-in?error=invalid_credentials&next=${encodeURIComponent(next)}`);
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);

  if (error) {
    redirect(`/auth/sign-in?error=invalid_credentials&next=${encodeURIComponent(next)}`);
  }

  redirect(next);
}

export async function signOut() {
  const supabase = await createServerSupabaseClient();
  await supabase.auth.signOut();
  redirect("/auth/sign-in?status=signed_out");
}

export async function requestPasswordReset(formData: FormData) {
  const parsed = emailSchema.safeParse(readString(formData, "email"));

  if (parsed.success) {
    try {
      const supabase = await createServerSupabaseClient();
      await supabase.auth.resetPasswordForEmail(parsed.data, {
        redirectTo: `${getSiteUrl()}/auth/callback?next=/auth/reset-password`,
      });
    } catch {
      // Always return the same response to prevent account enumeration.
    }
  }

  redirect("/auth/forgot-password?status=check_email");
}

export async function resetPassword(formData: FormData) {
  const parsed = passwordSchema.safeParse(readString(formData, "password"));

  if (!parsed.success) {
    redirect("/auth/reset-password?error=invalid_password");
  }

  const supabase = await createServerSupabaseClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/auth/sign-in?error=expired_link");
  }

  const { error } = await supabase.auth.updateUser({
    password: parsed.data,
  });

  redirect(
    error
      ? "/auth/reset-password?error=reset_failed"
      : "/auth/sign-in?status=password_updated",
  );
}
