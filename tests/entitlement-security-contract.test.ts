import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const migration = readFileSync(join(process.cwd(), "supabase/migrations/20260901000500_entitlement_lesson_credits.sql"), "utf8");

describe("Epic 5 migration security contract", () => {
  it("is additive and keeps Trial isolated", () => {
    expect(migration).not.toMatch(/insert into public\.trial_orders/i);
    expect(migration).not.toMatch(/alter table public\.trial_orders/i);
    expect(migration).not.toMatch(/drop table|drop type/i);
  });

  it("uses item-granular fulfillment source uniqueness", () => {
    expect(migration).toContain("unique (source_fulfillment_event_id, source_order_item_id, entitlement_type)");
    expect(migration).toContain("order_item_fulfillment_snapshots");
  });

  it("keeps authoritative history append-only for application roles", () => {
    expect(migration).toContain("lesson_credit_ledger_append_only");
    expect(migration).toContain("entitlement_expiry_history_append_only");
    expect(migration).toContain("fulfillment_manual_retry_attempts_append_only");
    expect(migration).toContain("from public,anon,authenticated,service_role");
    expect(migration).not.toMatch(/grant (insert|update|delete)[^;]*lesson_credit_ledger[^;]*authenticated/i);
    expect(migration).not.toMatch(/grant all[^;]*lesson_credit_ledger[^;]*service_role/i);
    expect(migration).toContain("lesson_credit_ledger_nonzero");
    expect(migration).toContain("unique (entitlement_id, operation_key)");
  });

  it("protects Entitlement source and commercial authority fields", () => {
    expect(migration).toContain("ENTITLEMENT_AUTHORITY_FIELDS_IMMUTABLE");
    expect(migration).toContain("entitlements_protect_authority_fields");
    expect(migration).toContain("entitlements_prevent_delete");
  });

  it("locks Entitlement before Reservation in credit functions", () => {
    const consume = migration.match(/create or replace function public\.consume_lesson_credit[\s\S]*?end; \$\$;/i)?.[0] ?? "";
    expect(consume.indexOf("for update of e")).toBeGreaterThan(-1);
    expect(consume.indexOf("for update of e")).toBeLessThan(consume.indexOf("where id=p_reservation_id for update"));
  });

  it("prevents one logical Booking or Lesson from reserving across packages", () => {
    expect(migration).toContain("unique (beneficiary_user_id, reservation_key)");
    expect(migration).toContain("lesson_credit_reservations_one_per_lesson_idx");
    expect(migration).toContain("lesson_credit_reservations_one_per_booking_idx");
    expect(migration).toContain("on conflict do nothing");
    expect(migration).toContain("CREDIT_ALREADY_RESERVED");
  });

  it("authorizes consumption before idempotent terminal return", () => {
    const consume = migration.match(/create or replace function public\.consume_lesson_credit[\s\S]*?end; \$\$;/i)?.[0] ?? "";
    expect(consume.indexOf("not private.current_user_has_role")).toBeLessThan(consume.indexOf("if res.status='consumed'"));
  });

  it("keeps fulfillment service-only and DTOs authenticated", () => {
    expect(migration).toContain("grant execute on function public.process_order_fulfillment_event(uuid) to service_role");
    expect(migration).not.toMatch(/grant execute on function public\.process_order_fulfillment_event\(uuid\) to authenticated/i);
    expect(migration).toContain("admin_retry_order_fulfillment_event(uuid,text,text)");
    expect(migration).toContain("fulfillment_manual_retry_attempts");
    expect(migration).toContain("unique (idempotency_key)");
    expect(migration).toContain("the-one:v1:manual-fulfillment-retry:");
    expect(migration).toContain("fulfillment.manual_retry");
    expect(migration).toContain("get_own_lesson_entitlement_summaries");
    expect(migration).toContain("get_teacher_student_lesson_entitlement_summaries");
  });

  it("pins all security-definer search paths", () => {
    const definitions = migration.match(/security definer/gi) ?? [];
    const pinned = migration.match(/security definer set search_path = ''/gi) ?? [];
    expect(pinned).toHaveLength(definitions.length);
  });

  it("revokes public execution and pins owners", () => {
    expect(migration).toContain("from public,anon,authenticated,service_role");
    expect(migration).toContain("owner to postgres");
  });

  it("does not implement membership, review quota, or achievement behavior", () => {
    expect(migration).not.toMatch(/create table public\.(subscriptions|review_quota_ledger|certificates|stage_completions)/i);
  });
});
