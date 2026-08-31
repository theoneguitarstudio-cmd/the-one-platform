import { SignOutForm } from "@/components/auth/sign-out-form";

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
        <div className="mt-6">
          <SignOutForm />
        </div>
      </section>
    </main>
  );
}
