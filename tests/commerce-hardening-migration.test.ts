import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const migration = readFileSync(
  join(process.cwd(), "supabase/migrations/20260901000400_harden_commerce_payment_and_product_authorization.sql"),
  "utf8",
);

describe("Epic 4 commerce hardening migration", () => {
  it("enforces one paid payment per order at the database boundary", () => {
    expect(migration).toMatch(/create unique index payments_one_paid_per_order_idx[\s\S]*where status = 'paid'/i);
  });

  it("serializes confirmation on the order before the payment", () => {
    const orderLock = migration.indexOf("where id = requested_order_id for update");
    const paymentLock = migration.indexOf("where id = requested_payment_id for update");
    expect(orderLock).toBeGreaterThan(-1);
    expect(paymentLock).toBeGreaterThan(orderLock);
    expect(migration).toContain("ORDER_ALREADY_PAID");
  });

  it("checks all live Teacher checkout eligibility inputs", () => {
    expect(migration).toContain("profile.account_status = 'active'");
    expect(migration).toContain("teacher.teaching_status = 'active'");
    expect(migration).toContain("teacher.is_public = true");
    expect(migration).toContain("assignment.role = 'teacher'");
  });

  it("does not expose the technical catalog UUID", () => {
    expect(migration).toContain("revoke select(product_id) on public.product_public_catalog from anon,authenticated");
  });

  it("audits Buyer cancellation and Teacher archive", () => {
    expect(migration).toContain("'buyer_cancel_order'");
    expect(migration).toContain("'teacher_archive_product'");
  });

  it("removes direct authenticated access to the private eligibility helper", () => {
    expect(migration).toContain("revoke all on function private.teacher_owner_is_active(uuid) from public,anon,authenticated");
    expect(migration).not.toMatch(/grant execute on function private\.teacher_owner_is_active\(uuid\) to authenticated/);
  });

  it("keeps every security-definer search path empty", () => {
    const definitions = migration.match(/security definer/gi) ?? [];
    const emptyPaths = migration.match(/security definer\s+set search_path = ''/gi) ?? [];
    expect(emptyPaths).toHaveLength(definitions.length);
  });
});
