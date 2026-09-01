import {readFileSync} from "node:fs";import {join} from "node:path";import {describe,expect,it} from "vitest";
const root=process.cwd();const migration=readFileSync(join(root,"supabase/migrations/20260901000200_commerce_products_orders_payments.sql"),"utf8");const webhook=readFileSync(join(root,"src/app/api/payments/[provider]/webhook/route.ts"),"utf8");
describe("Epic 4 migration security contract",()=>{
  it("keeps Trial legacy flow separate",()=>{expect(migration).toContain("does not dual-write");expect(migration).not.toMatch(/insert into public\.trial_orders/i)});
  it("uses integer monetary columns and consistency checks",()=>{expect(migration).toContain("base_price_amount bigint");expect(migration).toContain("total_amount = subtotal_amount - discount_amount + tax_amount")});
  it("uses buyer-scoped checkout idempotency",()=>expect(migration).toContain("unique (buyer_user_id, idempotency_key)"));
  it("locks checkout retries",()=>expect(migration).toContain("pg_advisory_xact_lock"));
  it("locks order and payment confirmation",()=>{expect(migration).toMatch(/from public\.orders where id=requested_order_id for update/);expect(migration).toMatch(/from public\.payments where id=requested_payment_id for update/)});
  it("does not grant direct payment access",()=>expect(migration).not.toMatch(/grant select[^;]*on public\.payments to authenticated/i));
  it("does not grant audit access",()=>expect(migration).not.toMatch(/grant select[^;]*on public\.audit_logs to authenticated/i));
  it("has an explicit safe payment DTO",()=>expect(migration).toContain("get_own_payment_summaries"));
  it("creates an atomic unique outbox",()=>{expect(migration).toContain("unique (order_id, event_type)");expect(migration).toContain("order.paid")});
  it("keeps security definer search paths empty",()=>{const defs=migration.match(/security definer/gi)??[];const paths=migration.match(/security definer set search_path\s*=\s*''/gi)??[];expect(paths).toHaveLength(defs.length)});
  it("revokes RPCs before granting authenticated",()=>{expect(migration).toContain("from public,anon,authenticated");expect(migration).toContain("to authenticated")});
  it("keeps product metadata out of public projection grants",()=>{const grant=migration.match(/grant select\(product_id[\s\S]*?on public\.product_public_catalog to anon, authenticated;/)?.[0]??"";expect(grant).not.toContain("metadata");expect(grant).not.toContain("owner_teacher_user_id")});
  it("prevents ordinary cancellation of paid orders",()=>expect(migration).toContain("order_row.payment_status='paid'"));
  it("reserves refund attempts without implementing engine",()=>{expect(migration).toContain("create table public.refunds");expect(migration).not.toContain("create or replace function public.refund")});
});
describe("webhook boundary",()=>{
  it("reads raw body before verification",()=>expect(webhook.indexOf("request.text()")).toBeLessThan(webhook.indexOf("verifyCallback")));
  it("rejects unconfigured providers",()=>expect(webhook).toContain("status:501"));
  it("does not use client sessions as callback proof",()=>expect(webhook).not.toMatch(/auth|getUser|getSession/));
});
