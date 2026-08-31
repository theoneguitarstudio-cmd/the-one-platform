import "server-only";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import {
  isAccountStatus,
  isAppRole,
  type AccountStatus,
  type AppRole,
} from "@/modules/auth/domain";

export type AuthenticatedIdentity = {
  accountStatus: AccountStatus;
  roles: AppRole[];
  userId: string;
};

export async function getAuthenticatedIdentity(): Promise<AuthenticatedIdentity | null> {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return null;
  }

  const [profileResult, rolesResult] = await Promise.all([
    supabase
      .from("profiles")
      .select("account_status")
      .eq("user_id", user.id)
      .maybeSingle(),
    supabase.from("user_roles").select("role").eq("user_id", user.id),
  ]);

  if (
    profileResult.error ||
    rolesResult.error ||
    !profileResult.data ||
    !isAccountStatus(profileResult.data.account_status)
  ) {
    return null;
  }

  const roles = (rolesResult.data ?? [])
    .map(({ role }) => role)
    .filter(isAppRole);

  return {
    accountStatus: profileResult.data.account_status,
    roles,
    userId: user.id,
  };
}
