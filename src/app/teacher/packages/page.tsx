import Link from "next/link";
import { extendLessonPackage } from "@/modules/entitlements/actions";
import { listTeacherStudentLessonPackages } from "@/modules/entitlements/data";
import { studentLookupSchema } from "@/modules/entitlements/domain";

type Props = { searchParams: Promise<{ studentId?: string }> };

export default async function TeacherPackagesPage({ searchParams }: Props) {
  const { studentId } = await searchParams;
  const validStudentId = studentLookupSchema.safeParse(studentId);
  const packages = validStudentId.success ? await listTeacherStudentLessonPackages(validStudentId.data) : [];
  return <main className="mx-auto max-w-5xl px-5 py-10">
    <Link href="/teacher">← 返回老師區</Link>
    <h1 className="mt-5 text-3xl font-semibold">學生課程方案</h1>
    <form className="mt-6 flex flex-wrap gap-3" method="get">
      <label className="sr-only" htmlFor="studentId">Student User ID</label>
      <input className="min-w-72 rounded-xl border px-4 py-2" id="studentId" name="studentId" placeholder="Student User ID" defaultValue={studentId} />
      <button className="rounded-xl bg-[var(--brand-yellow)] px-4 py-2 font-semibold" type="submit">查詢授權學生</button>
    </form>
    <div className="mt-8 space-y-4">{packages.map((item) =>
      <article className="rounded-2xl border border-[var(--border)] p-5" key={item.id}>
        <h2 className="font-semibold">{item.package_name}</h2>
        <p className="mt-2 text-sm">可用 {item.credits_available} · 預留 {item.credits_reserved} · {item.status}</p>
        <p className="mt-1 text-sm">效期：{item.expires_at ? new Date(item.expires_at).toLocaleString("zh-TW") : "無期限"}</p>
        <form action={extendLessonPackage} className="mt-4 grid gap-3 md:grid-cols-3">
          <input name="area" type="hidden" value="teacher" /><input name="entitlementId" type="hidden" value={item.id} /><input name="idempotencyKey" type="hidden" value={crypto.randomUUID()} />
          <label className="grid gap-1 text-sm">新效期（ISO 8601）<input className="rounded-xl border px-3 py-2" name="newExpiresAt" placeholder="2027-01-01T00:00:00+08:00" required /></label>
          <label className="grid gap-1 text-sm">原因<input className="rounded-xl border px-3 py-2" name="reason" required /></label>
          <button className="self-end rounded-xl border px-4 py-2 font-semibold" type="submit">延長效期</button>
        </form>
      </article>)}</div>
  </main>;
}
