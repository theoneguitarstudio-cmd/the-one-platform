import { SignOutForm } from "@/components/auth/sign-out-form";

export default function StudentPage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-3xl items-center px-6">
      <section className="w-full rounded-2xl border border-[var(--border)] p-8">
        <p className="text-sm font-semibold text-[var(--text-secondary)]">
          Protected route
        </p>
        <h1 className="mt-2 text-3xl font-semibold">Student</h1>
        <div className="mt-6">
          <SignOutForm />
        </div>
      </section>
    </main>
  );
}
