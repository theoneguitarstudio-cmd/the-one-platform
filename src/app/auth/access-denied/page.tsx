import Link from "next/link";

export default function AccessDeniedPage() {
  return (
    <div className="space-y-5">
      <h1 className="text-2xl font-semibold">無法存取</h1>
      <p className="text-sm text-[var(--text-secondary)]">
        此帳號沒有該區域權限，或帳號目前無法使用受保護功能。
      </p>
      <Link className="text-sm font-semibold" href="/">
        返回首頁
      </Link>
    </div>
  );
}
