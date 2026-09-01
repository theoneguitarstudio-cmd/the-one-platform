import Link from "next/link";
import { adminAdjustLessonCredits, adminRetryFulfillment, extendLessonPackage } from "@/modules/entitlements/actions";
import { listAdminLessonPackages } from "@/modules/entitlements/data";

export default async function AdminPackagesPage() {
  const packages = await listAdminLessonPackages();
  return <main className="mx-auto max-w-6xl px-5 py-10">
    <Link href="/admin">← 返回管理區</Link><h1 className="mt-5 text-3xl font-semibold">Entitlement 管理</h1>
    <form action={adminRetryFulfillment} className="mt-6 flex flex-wrap gap-3 rounded-2xl bg-[var(--surface)] p-5">
      <input name="idempotencyKey" type="hidden" value={crypto.randomUUID()} />
      <label className="grid flex-1 gap-1 text-sm">Fulfillment Event ID<input className="rounded-xl border bg-white px-3 py-2" name="eventId" required /></label>
      <label className="grid flex-1 gap-1 text-sm">人工重試原因<input className="rounded-xl border bg-white px-3 py-2" name="reason" required /></label>
      <button className="self-end rounded-xl bg-[var(--brand-yellow)] px-4 py-2 font-semibold" type="submit">安全重試 Fulfillment</button>
    </form>
    <div className="mt-8 space-y-5">{packages.length === 0 ? <p>目前沒有 Lesson Package Entitlement。</p> : packages.map((item) =>
      <article className="rounded-2xl border border-[var(--border)] p-5" key={item.id}>
        <h2 className="font-semibold">{item.package_name}</h2>
        <p className="mt-2 text-sm text-[var(--text-secondary)]">{item.beneficiary_name} · {item.beneficiary_user_id}</p>
        <p className="mt-2 text-sm">總數 {item.credits_total} · 可用 {item.credits_available} · 預留 {item.credits_reserved} · 已用 {item.credits_consumed} · {item.status}</p>
        <div className="mt-4 grid gap-4 lg:grid-cols-2">
          <form action={extendLessonPackage} className="grid gap-2 rounded-xl bg-[var(--surface)] p-4">
            <input name="area" type="hidden" value="admin" /><input name="entitlementId" type="hidden" value={item.id} /><input name="idempotencyKey" type="hidden" value={crypto.randomUUID()} />
            <label className="grid gap-1 text-sm">新效期（ISO 8601）<input className="rounded-xl border bg-white px-3 py-2" name="newExpiresAt" required /></label>
            <label className="grid gap-1 text-sm">原因<input className="rounded-xl border bg-white px-3 py-2" name="reason" required /></label>
            <button className="rounded-xl border px-4 py-2 font-semibold" type="submit">延長效期</button>
          </form>
          <form action={adminAdjustLessonCredits} className="grid gap-2 rounded-xl bg-[var(--surface)] p-4">
            <input name="entitlementId" type="hidden" value={item.id} /><input name="idempotencyKey" type="hidden" value={crypto.randomUUID()} />
            <label className="grid gap-1 text-sm">點數調整<input className="rounded-xl border bg-white px-3 py-2" name="quantityDelta" type="number" min="-1000" max="1000" required /></label>
            <label className="grid gap-1 text-sm">原因<input className="rounded-xl border bg-white px-3 py-2" name="reason" required /></label>
            <button className="rounded-xl border px-4 py-2 font-semibold" type="submit">寫入調整 Ledger</button>
          </form>
        </div>
      </article>)}</div>
  </main>;
}
