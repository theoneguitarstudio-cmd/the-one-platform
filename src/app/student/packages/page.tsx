import Link from "next/link";
import { listOwnLessonPackages } from "@/modules/entitlements/data";

export default async function StudentPackagesPage() {
  const packages = await listOwnLessonPackages();
  return <main className="mx-auto max-w-5xl px-5 py-10">
    <Link href="/student">← 返回學生區</Link>
    <h1 className="mt-5 text-3xl font-semibold">我的課程方案</h1>
    <p className="mt-2 text-sm text-[var(--text-secondary)]">點數、預留與使用紀錄來自同一套 Lesson Credit Ledger。</p>
    <div className="mt-8 grid gap-4 md:grid-cols-2">
      {packages.length === 0 ? <p className="rounded-2xl bg-[var(--surface)] p-6">目前沒有課程方案。</p> : packages.map((item) =>
        <article className="rounded-2xl border border-[var(--border)] p-5" key={item.id}>
          <h2 className="text-lg font-semibold">{item.package_name}</h2>
          <p className="mt-2 text-sm text-[var(--text-secondary)]">{item.status} · {item.booking_mode_eligibility}</p>
          <dl className="mt-4 grid grid-cols-4 gap-2 text-center">
            <div><dt className="text-xs text-[var(--text-secondary)]">總數</dt><dd className="text-xl font-semibold">{item.credits_total}</dd></div>
            <div><dt className="text-xs text-[var(--text-secondary)]">可用</dt><dd className="text-xl font-semibold">{item.credits_available}</dd></div>
            <div><dt className="text-xs text-[var(--text-secondary)]">預留</dt><dd className="text-xl font-semibold">{item.credits_reserved}</dd></div>
            <div><dt className="text-xs text-[var(--text-secondary)]">已用</dt><dd className="text-xl font-semibold">{item.credits_consumed}</dd></div>
          </dl>
          <p className="mt-4 text-sm">效期：{item.expires_at ? new Date(item.expires_at).toLocaleDateString("zh-TW") : "無期限"}</p>
        </article>) }
    </div>
  </main>;
}
