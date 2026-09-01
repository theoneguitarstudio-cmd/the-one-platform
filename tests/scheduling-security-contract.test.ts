import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const migration = readFileSync(
  "supabase/migrations/20260901000600_scheduling_booking_core.sql",
  "utf8",
);
const actions = readFileSync("src/modules/scheduling/actions.ts", "utf8");

describe("Epic 6 scheduling security contract", () => {
  it("is additive and leaves remote-applied migrations untouched", () => {
    expect(migration).not.toMatch(/drop\s+(table|column|type)/i);
    expect(migration).not.toMatch(/truncate\s+/i);
    expect(migration).not.toMatch(/delete\s+from\s+public\.lessons/i);
  });

  it("reuses Epic 3 schedule locks and Lesson collision constraints", () => {
    expect(migration).toContain("private.lock_lesson_schedule_resources");
    expect(migration).toContain("the-one:v1:lesson-schedule:teacher:");
    expect(migration).not.toContain("create table public.scheduling_lessons");
  });

  it("uses one Epic 5 ledger and explicit Entitlement selection", () => {
    expect(migration).toContain("public.lesson_credit_ledger");
    expect(migration).toContain("p_entitlement_id uuid");
    expect(migration).not.toMatch(/fixed_credits|flexible_credits/);
  });

  it("keeps recurring series entitlement preference optional", () => {
    expect(migration).toContain("preferred_entitlement_id uuid");
    expect(migration).toContain("p_entitlement_id uuid,p_idempotency_key text");
  });

  it("revokes raw table DML and private helper execution", () => {
    expect(migration).toMatch(/revoke all on table public\.teacher_scheduling_settings[\s\S]+from public,anon,authenticated,service_role/);
    expect(migration).toMatch(/revoke all on function private\.resolve_scheduling_local_datetime[\s\S]+from public,anon,authenticated,service_role/);
  });

  it("hardens definer functions", () => {
    expect(migration).not.toMatch(/security definer(?!\s+set search_path='')/i);
    expect(migration).toContain("owner to postgres");
    expect(migration).toContain("auth.uid()");
  });

  it("converts raw collision errors to stable domain errors", () => {
    expect(migration).toContain("exception when exclusion_violation");
    expect(migration).toContain("message='SLOT_NOT_AVAILABLE'");
    expect(migration).toContain("message='RECURRING_SERIES_CONFLICT'");
  });

  it("re-authorizes every exported Server Action before RPC mutation", () => {
    expect(actions).toContain('await requireAreaAccess("student")');
    expect(actions).toContain('await requireAreaAccess("teacher")');
    expect(actions).toContain('await requireAreaAccess("admin")');
    expect(actions).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
  });
});
