import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

const migration = readFileSync(
  new URL(
    "../supabase/migrations/20260831000100_identity_auth_roles.sql",
    import.meta.url,
  ),
  "utf8",
);

describe("identity migration security contract", () => {
  it.each(["profiles", "user_roles", "public_profiles"])(
    "enables RLS on %s",
    (table) => {
      expect(migration).toContain(
        `alter table public.${table} enable row level security;`,
      );
    },
  );

  it("grants profile updates only to explicitly editable columns", () => {
    const grant = migration.match(
      /grant update \(([\s\S]*?)\) on table public\.profiles to authenticated;/,
    )?.[1];

    expect(grant).toContain("display_name");
    expect(grant).toContain("phone");
    expect(grant).not.toContain("account_status");
    expect(grant).not.toContain("legacy_wordpress_user_id");
    expect(grant).not.toContain("user_id");
  });

  it("does not grant client access to public_profiles in Epic 1", () => {
    expect(migration).not.toMatch(
      /grant\s+(select|insert|update|delete).*public_profiles\s+to\s+(anon|authenticated)/i,
    );
  });

  it("does not derive application roles from user-editable metadata", () => {
    expect(migration).toContain("values (new.id, 'student')");
    expect(migration).not.toMatch(
      /raw_user_meta_data[\s\S]{0,80}(role|account_status)/,
    );
  });
});
