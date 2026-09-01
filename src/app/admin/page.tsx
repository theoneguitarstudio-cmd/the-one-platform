import { SignOutForm } from "@/components/auth/sign-out-form";
import Link from "next/link";

export default function AdminPage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-3xl items-center px-6">
      <section className="w-full rounded-2xl border border-[var(--border)] p-8">
        <p className="text-sm font-semibold text-[var(--text-secondary)]">
          Protected route
        </p>
        <h1 className="mt-2 text-3xl font-semibold">
          Admin access foundation
        </h1>
        <p className="mt-3 text-sm text-[var(--text-secondary)]">
          正式 Admin Dashboard 尚未建立。
        </p>
        <Link
          className="mt-5 inline-flex rounded-xl bg-[var(--brand-yellow)] px-4 py-2 text-sm font-semibold"
          href="/admin/teachers"
        >
          管理老師
        </Link>
        <Link
          className="ml-3 mt-5 inline-flex rounded-xl border border-[var(--border)] px-4 py-2 text-sm font-semibold"
          href="/admin/trials"
        >
          管理體驗課
        </Link>
        <Link className="ml-3 mt-5 inline-flex rounded-xl border border-[var(--border)] px-4 py-2 text-sm font-semibold" href="/admin/packages">
          管理課程方案
        </Link>
        <div className="mt-6">
          <SignOutForm />
        </div>
      </section>
    </main>
  );
}
