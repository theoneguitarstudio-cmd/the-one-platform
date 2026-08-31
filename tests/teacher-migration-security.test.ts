import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

const migration = readFileSync(
  new URL(
    "../supabase/migrations/20260831000200_teacher_profiles_public_discovery.sql",
    import.meta.url,
  ),
  "utf8",
);

describe("teacher migration security contract", () => {
  it.each([
    "teacher_profiles",
    "teacher_public_profiles",
    "teacher_specialties",
    "teacher_stage_capabilities",
  ])("enables RLS on %s", (table) => {
    expect(migration).toContain(
      "alter table public." + table + " enable row level security;",
    );
  });

  it("does not grant anonymous access to private teacher profiles", () => {
    expect(migration).toContain(
      "revoke all on table public.teacher_profiles from anon, authenticated;",
    );
    expect(migration).not.toMatch(
      /grant\s+select\s+on table public\.teacher_profiles to anon/i,
    );
  });

  it("limits teacher updates to explicitly editable fields", () => {
    const grant = migration.match(
      /grant update \(([\s\S]*?)\) on table public\.teacher_profiles to authenticated;/,
    )?.[1];

    expect(grant).toContain("bio");
    expect(grant).toContain("trial_price_twd");
    expect(grant).not.toContain("is_public");
    expect(grant).not.toContain("public_slug");
    expect(grant).not.toContain("teaching_status");
  });

  it("seeds the canonical five stages and specialty catalog without teacher data", () => {
    expect(migration).toContain("(1, 'stage_1', '0 到 1 基礎伴奏篇')");
    expect(migration).toContain("(5, 'stage_5', '改編創作篇')");
    expect(migration).toContain("('adult_beginner', '成人初學')");
    expect(migration).not.toMatch(/@example\.(com|invalid).*teacher/i);
  });
});
