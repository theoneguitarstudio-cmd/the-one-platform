import Link from "next/link";
import type { ReactNode } from "react";
import { BrandLogo } from "@/components/brand-logo";

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <main className="flex min-h-screen items-center justify-center bg-[var(--surface)] px-5 py-12">
      <section className="w-full max-w-md rounded-2xl border border-[var(--border)] bg-white p-7 shadow-sm sm:p-9">
        <Link
          className="mb-7 inline-flex"
          href="/"
        >
          <BrandLogo />
        </Link>
        {children}
      </section>
    </main>
  );
}
