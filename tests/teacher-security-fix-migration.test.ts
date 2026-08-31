import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

const migration = readFileSync(
  new URL(
    "../supabase/migrations/20260831000300_harden_teacher_visibility_and_self_updates.sql",
    import.meta.url,
  ),
  "utf8",
);

describe("teacher security-fix migration contract", () => {
  it("makes discoverability depend on current account and teacher state", () => {
    expect(migration).toContain("account.account_status = 'active'");
    expect(migration).toContain("teacher.is_public");
    expect(migration).toContain("teacher.teaching_status = 'active'");
    expect(migration).toContain(
      "after update of display_name, account_status on public.profiles",
    );
  });

  it("uses the current-state helper for public projection RLS", () => {
    expect(migration).toContain(
      "using ((select private.is_discoverable_teacher_profile(teacher_profile_id)));",
    );
  });

  it("removes direct Teacher writes and exposes only the protected RPC", () => {
    expect(migration).toContain(
      "revoke update on table public.teacher_profiles from authenticated;",
    );
    expect(migration).toContain(
      "revoke insert, delete on table public.teacher_specialties from authenticated;",
    );
    expect(migration).toContain(
      "create or replace function public.update_own_teacher_profile(",
    );
    expect(migration).toContain(") from public, anon;");
    expect(migration).toContain(") to authenticated;");
  });

  it("pins SECURITY DEFINER RPC lookup and validates authorization and catalog IDs", () => {
    expect(migration).toContain("security definer");
    expect(migration).toContain("set search_path = ''");
    expect(migration).toContain("current_user_id uuid := (select auth.uid())");
    expect(migration).toContain("assignment.role = 'teacher'");
    expect(migration).toContain("or not specialty.is_active");
    expect(migration).toContain("raise exception 'invalid specialty'");
  });
});
