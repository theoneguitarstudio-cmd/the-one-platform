import Link from "next/link";

import { AuthMessage } from "@/components/auth/auth-message";
import { signUp } from "@/modules/auth/actions";

type SignUpPageProps = {
  searchParams: Promise<{ error?: string }>;
};

export default async function SignUpPage({ searchParams }: SignUpPageProps) {
  const { error } = await searchParams;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">建立帳號</h1>
        <p className="mt-2 text-sm text-[var(--text-secondary)]">
          Email 將作為唯一登入身份來源。
        </p>
      </div>
      <AuthMessage code={error} />
      <form action={signUp} className="space-y-4">
        <label className="block text-sm font-medium">
          顯示名稱
          <input
            autoComplete="name"
            className="mt-2 w-full rounded-xl border border-[var(--border)] px-4 py-3"
            maxLength={80}
            name="displayName"
            required
          />
        </label>
        <label className="block text-sm font-medium">
          Email
          <input
            autoComplete="email"
            className="mt-2 w-full rounded-xl border border-[var(--border)] px-4 py-3"
            name="email"
            required
            type="email"
          />
        </label>
        <label className="block text-sm font-medium">
          密碼
          <input
            autoComplete="new-password"
            className="mt-2 w-full rounded-xl border border-[var(--border)] px-4 py-3"
            minLength={12}
            name="password"
            required
            type="password"
          />
        </label>
        <p className="text-xs text-[var(--text-secondary)]">
          至少 12 字元，並包含英文字母與數字。
        </p>
        <button
          className="w-full rounded-xl bg-[var(--brand-yellow)] px-4 py-3 font-semibold"
          type="submit"
        >
          建立帳號
        </button>
      </form>
      <Link className="text-sm" href="/auth/sign-in">
        已有帳號？登入
      </Link>
    </div>
  );
}
