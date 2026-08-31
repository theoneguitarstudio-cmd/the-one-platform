import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const migration = readFileSync(
  "supabase/migrations/20260831000400_student_teacher_trial_flow.sql",
  "utf8",
).toLowerCase();
const actions = readFileSync("src/modules/trials/actions.ts", "utf8");
const data = readFileSync("src/modules/trials/data.ts", "utf8");
const joinRoute = readFileSync("src/app/lesson/[id]/join/route.ts", "utf8");

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
});
