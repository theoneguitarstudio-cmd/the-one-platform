import { AuthMessage } from "@/components/auth/auth-message";
import { resetPassword } from "@/modules/auth/actions";

type ResetPasswordPageProps = {
  searchParams: Promise<{ error?: string }>;
};

export default async function ResetPasswordPage({
  searchParams,
}: ResetPasswordPageProps) {
  const { error } = await searchParams;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">設定新密碼</h1>
        <p className="mt-2 text-sm text-[var(--text-secondary)]">
          此頁需要有效的 Supabase recovery session。
        </p>
      </div>
      <AuthMessage code={error} />
      <form action={resetPassword} className="space-y-4">
        <label className="block text-sm font-medium">
          新密碼
          <input
            autoComplete="new-password"
            className="mt-2 w-full rounded-xl border border-[var(--border)] px-4 py-3"
            minLength={12}
            name="password"
            required
            type="password"
          />
        </label>
        <button
          className="w-full rounded-xl bg-[var(--brand-yellow)] px-4 py-3 font-semibold"
          type="submit"
        >
          更新密碼
        </button>
      </form>
    </div>
  );
}
