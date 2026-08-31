import Link from "next/link";

import { AuthMessage } from "@/components/auth/auth-message";

type VerifyEmailPageProps = {
  searchParams: Promise<{ status?: string }>;
};

export default async function VerifyEmailPage({
  searchParams,
}: VerifyEmailPageProps) {
  const { status } = await searchParams;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">驗證你的 Email</h1>
      <AuthMessage code={status ?? "check_email"} />
      <p className="text-sm text-[var(--text-secondary)]">
        完成驗證後，系統會建立安全 session 並導向你的學生區。
      </p>
      <Link className="text-sm font-semibold" href="/auth/sign-in">
        返回登入
      </Link>
    </div>
  );
}
