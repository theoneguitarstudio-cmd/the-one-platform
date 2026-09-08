import { isMockDataMode } from "@/lib/preview/mode";
import { previewUsers, previewPassword } from "@/lib/preview/fixtures";
import Link from "next/link";

import { AuthMessage } from "@/components/auth/auth-message";
import { signIn } from "@/modules/auth/actions";
import { getSafeRedirectPath } from "@/modules/auth/safe-redirect";

type SignInPageProps = {
  searchParams: Promise<{
    error?: string;
    next?: string;
    status?: string;
  }>;
};

export default async function SignInPage({ searchParams }: SignInPageProps) {
  const params = await searchParams;
  const next = getSafeRedirectPath(params.next);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">登入</h1>
        <p className="mt-2 text-sm text-[var(--text-secondary)]">
          使用你的 The One 帳號繼續。
        </p>
      </div>
      {isMockDataMode() && <section className="space-y-3" aria-label="Preview 示範登入">
        <p className="text-sm">不用輸入真實帳號或密碼，選一個示範身分。這不是真正的登入驗證。</p>
        {previewUsers.map(user => <form key={user.id} action={signIn}>
          <input type="hidden" name="email" value={user.email} />
          <input type="hidden" name="password" value={previewPassword} />
          <input type="hidden" name="next" value={user.path} />
          <button className="w-full rounded-xl bg-[var(--surface)] px-4 py-3 text-left font-medium" type="submit">{user.name}</button>
        </form>)}
      </section>}
      <AuthMessage code={params.error ?? params.status} />
      <form action={signIn} className="space-y-4">
        <input name="next" type="hidden" value={next} />
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
            autoComplete="current-password"
            className="mt-2 w-full rounded-xl border border-[var(--border)] px-4 py-3"
            name="password"
            required
            type="password"
          />
        </label>
        <button
          className="w-full rounded-xl bg-[var(--brand-yellow)] px-4 py-3 font-semibold"
          type="submit"
        >
          登入
        </button>
      </form>
      <div className="flex justify-between text-sm">
        <Link href="/auth/sign-up">建立帳號</Link>
        <Link href="/auth/forgot-password">忘記密碼</Link>
      </div>
    </div>
  );
}
