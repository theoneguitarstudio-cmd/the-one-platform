import { SignOutForm } from "@/components/auth/sign-out-form";
import Link from "next/link";

export default function TeacherPage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-3xl items-center px-6">
      <section className="w-full rounded-2xl border border-[var(--border)] p-8">
        <p className="text-sm font-semibold text-[var(--text-secondary)]">
          Protected route
        </p>
        <h1 className="mt-2 text-3xl font-semibold">Teacher</h1>
        <Link
          className="mt-5 inline-flex rounded-xl bg-[var(--brand-yellow)] px-4 py-2 text-sm font-semibold"
          href="/teacher/profile"
        >
          編輯公開老師資料
        </Link>
        <Link
          className="ml-3 mt-5 inline-flex rounded-xl border border-[var(--border)] px-4 py-2 text-sm font-semibold"
          href="/teacher/trials"
        >
          體驗課工作台
        </Link>
        <Link className="ml-3 mt-5 inline-flex rounded-xl border border-[var(--border)] px-4 py-2 text-sm font-semibold" href="/teacher/packages">
          學生課程方案
        </Link>
        <Link className="ml-3 mt-5 inline-flex rounded-xl border border-[var(--border)] px-4 py-2 text-sm font-semibold" href="/teacher/schedule">
          Availability 與課表
        </Link>
        <div className="mt-6">
          <SignOutForm />
        </div>
      </section>
    </main>
  );
}
