import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const migration = readFileSync(
  "supabase/migrations/20260831000400_student_teacher_trial_flow.sql",
  "utf8",
).toLowerCase();
const hardeningMigration = readFileSync(
  "supabase/migrations/20260831000500_harden_trial_security_and_integrity.sql",
  "utf8",
).toLowerCase();
const actions = readFileSync("src/modules/trials/actions.ts", "utf8");
const data = readFileSync("src/modules/trials/data.ts", "utf8");
const joinRoute = readFileSync("src/app/lesson/[id]/join/route.ts", "utf8");
const trialRequestPage = readFileSync(
  "src/app/teachers/[slug]/trial/page.tsx",
  "utf8",
);

describe("Epic 3 trial flow contracts", () => {
  it("creates the required normalized domain tables", () => {
    for (const table of [
      "student_profiles",
      "student_teacher_relationships",
      "trial_orders",
      "lessons",
      "lesson_records",
      "assessments",
    ]) expect(migration).toContain(`create table public.${table}`);
  });

  it("stores lesson instants as timestamptz with a duration invariant", () => {
    expect(migration).toContain("starts_at timestamptz not null");
    expect(migration).toContain("ends_at timestamptz not null");
    expect(migration).toContain("lesson_type <> 'trial' or duration_minutes = 50");
    expect(migration).toContain("starts_at < ends_at");
  });

  it("protects teacher and student collision races in PostgreSQL", () => {
    expect(migration).toContain("lessons_teacher_no_overlap");
    expect(migration).toContain("lessons_student_no_overlap");
    expect(migration).toContain("exclude using gist");
  });

  it("makes payment confirmation and completion atomic RPCs", () => {
    expect(migration).toContain("function public.confirm_trial_payment");
    expect(migration).toContain("function public.complete_trial_lesson");
    expect(migration).toContain("for update");
    expect(migration).toContain("on conflict (lesson_id)");
  });

  it("has database idempotency keys for orders, relationships and lessons", () => {
    expect(migration).toContain("idempotency_key text not null unique");
    expect(migration).toContain("student_teacher_one_open_relationship_idx");
    expect(migration).toContain("trial_order_id uuid unique");
    expect(migration).toContain("lesson_id uuid not null unique");
  });

  it("denies anonymous access and grants no client writes", () => {
    expect(migration).toContain("revoke all on table public.lessons from anon, authenticated");
    expect(migration).toContain("revoke all on function public.confirm_trial_payment(uuid, timestamptz) from public, anon");
    expect(migration).not.toContain("grant insert on table public.lessons to authenticated");
    expect(migration).not.toContain("grant update on table public.lessons to authenticated");
  });

  it("keeps private teacher notes out of authenticated column grants", () => {
    const safeGrant = migration.slice(
      migration.indexOf("grant select (\n  id, lesson_id"),
      migration.indexOf(") on table public.lesson_records to authenticated"),
    );
    expect(safeGrant).not.toContain("private_teacher_notes");
    expect(data).toContain('supabase.rpc("get_own_teacher_trials")');
  });

  it("re-authorizes all high-risk actions on the server", () => {
    expect(actions.match(/requireAreaAccess\("admin"\)/g)?.length).toBe(3);
    expect(actions).toContain('requireAreaAccess("teacher")');
    expect(actions).toContain('requireAreaAccess("student")');
  });

  it("authorizes the join endpoint and never reads public teacher data", () => {
    expect(joinRoute).toContain("getAuthenticatedIdentity()");
    expect(joinRoute).toContain('.from("lessons")');
    expect(joinRoute).toContain('data.status !== "scheduled"');
    expect(joinRoute).not.toContain("teacher_public_profiles");
  });

  it("does not create out-of-scope credit or earnings side effects", () => {
    expect(migration).not.toContain("credit_ledger");
    expect(migration).not.toContain("teacher_earnings");
    expect(migration).not.toContain("course_packages");
  });

  it("hardens meeting URLs at the database and join boundaries", () => {
    expect(hardeningMigration).toContain("private.is_safe_trial_meeting_url");
    expect(hardeningMigration).toContain("requested_provider = 'manual_url' then false");
    expect(hardeningMigration).toContain("meet[.]google[.]com([/?#]|$)");
    expect(hardeningMigration).toContain("zoom[.]us([/?#]|$)");
    expect(joinRoute).toContain("normalizeMeetingUrl");
    expect(joinRoute).toContain("meeting_provider, meeting_url");
  });

  it("enforces relationship and participant integrity in PostgreSQL", () => {
    expect(hardeningMigration).toContain("relationship does not permit a trial");
    expect(hardeningMigration).toContain("trial relationship transition failed");
    expect(hardeningMigration).toContain("assessments_lesson_participants_fkey");
    expect(hardeningMigration).toContain(
      "lesson_records_completed_by_assigned_teacher_fkey",
    );
  });

  it("uses retry-safe scoped idempotency with deterministic locking", () => {
    expect(hardeningMigration).toContain(
      "unique (student_user_id, idempotency_key)",
    );
    expect(hardeningMigration).toContain(
      "on conflict (student_user_id, idempotency_key) do nothing",
    );
    expect(hardeningMigration).toContain("pg_advisory_xact_lock");
    expect(hardeningMigration).toContain("a trial request is already pending");
    expect(trialRequestPage).toContain("query.intent");
    expect(trialRequestPage).toContain('value={intent.data}');
    expect(trialRequestPage).not.toContain('value={randomUUID()}');
  });

  it("prevents early completion and validates IANA timezones at the DB layer", () => {
    expect(hardeningMigration).toContain("trial_lesson.starts_at > now()");
    expect(hardeningMigration).toContain("private.is_valid_iana_timezone");
    expect(hardeningMigration).toContain("lessons_timezone_anchor_is_iana");
    expect(hardeningMigration).toContain("trial_orders_timezone_is_iana");
  });

  it("minimizes participant columns and pins trusted function ownership", () => {
    expect(hardeningMigration).toContain(
      "revoke select on table public.lessons from authenticated",
    );
    expect(hardeningMigration).toContain(
      "revoke select on table public.assessments from authenticated",
    );
    expect(hardeningMigration).toContain("owner to postgres");
  });
});
