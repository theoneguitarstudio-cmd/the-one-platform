import Link from "next/link";

import { AuthMessage } from "@/components/auth/auth-message";
import { requestPasswordReset } from "@/modules/auth/actions";

type ForgotPasswordPageProps = {
  searchParams: Promise<{ status?: string }>;
};

export default async function ForgotPasswordPage({
  searchParams,
}: ForgotPasswordPageProps) {
  const { status } = await searchParams;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">忘記密碼</h1>
        <p className="mt-2 text-sm text-[var(--text-secondary)]">
          輸入 Email 以取得密碼重設連結。
        </p>
      </div>
      <AuthMessage code={status} />
      <form action={requestPasswordReset} className="space-y-4">
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
        <button
          className="w-full rounded-xl bg-[var(--brand-yellow)] px-4 py-3 font-semibold"
          type="submit"
        >
          寄送重設連結
        </button>
      </form>
      <Link className="text-sm" href="/auth/sign-in">
        返回登入
      </Link>
    </div>
  );
}
