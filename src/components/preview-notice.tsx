import Link from "next/link";
import { isMockDataMode } from "@/lib/preview/mode";
export function PreviewNotice() {
  if (!isMockDataMode()) return null;
  return <aside className="bg-[var(--brand-yellow)] px-4 py-3 text-sm text-black" aria-label="Preview 說明">
    <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-4 gap-y-2">
      <strong>PREVIEW · MOCK</strong><span>全部是假資料；不收款、不寄信、不儲存變更。</span>
      <nav className="flex flex-wrap gap-3" aria-label="Preview 導覽">
        <Link href="/">首頁</Link><Link href="/auth/sign-in">示範登入／切換角色</Link><Link href="/teachers">師資</Link><Link href="/products">商品</Link><Link href="/student/orders">示範訂單</Link>
      </nav>
    </div>
  </aside>;
}
