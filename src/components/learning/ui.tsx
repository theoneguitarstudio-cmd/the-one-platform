import Link from "next/link";
import type { ReactNode } from "react";

export function PrimaryCTA({ href, children, secondary = false }: { href: string; children: ReactNode; secondary?: boolean }) {
  return <Link className={secondary ? "cta cta-secondary" : "cta"} href={href}>{children}<span aria-hidden="true">↗</span></Link>;
}
export function SectionHeader({ eyebrow, title, text }: { eyebrow: string; title: string; text?: string }) {
  return <header className="section-heading"><p className="eyebrow">{eyebrow}</p><h2>{title}</h2>{text && <p className="body-copy">{text}</p>}</header>;
}
export function Progress({ value, label }: { value: number; label: string }) {
  return <div className="learning-progress"><div><span>{label}</span><strong>{value}%</strong></div><div role="progressbar" aria-label={label} aria-valuenow={value} aria-valuemin={0} aria-valuemax={100}><i style={{ width: value + "%" }} /></div></div>;
}
export function PublicHeader() {
  return <header className="public-header"><Link href="/" className="wordmark">the one<span>●</span></Link><nav aria-label="主要導覽"><Link href="/#courses">系統課程</Link><Link href="/teachers">老師</Link><Link href="/#how-it-works">學習方式</Link><Link href="/#membership">會員方案</Link></nav><div className="header-actions"><Link href="/auth/sign-in">登入</Link><PrimaryCTA href="/student">開始學習</PrimaryCTA></div><details className="mobile-menu"><summary>選單 ☰</summary><nav aria-label="手機主要導覽"><Link href="/#courses">系統課程</Link><Link href="/teachers">老師</Link><Link href="/#how-it-works">學習方式</Link><Link href="/#membership">會員方案</Link><Link href="/auth/sign-in">登入</Link></nav></details></header>;
}
export function PageShell({ children }: { children: ReactNode }) {
  return <><PublicHeader /><main className="public-main">{children}</main><footer className="site-footer"><Link href="/" className="wordmark">the one<span>●</span></Link><p>讓每一步練習，都更靠近喜歡的自己。</p><span>Learning, with direction.</span></footer></>;
}
export function ResourceRow({ kind, title, detail }: { kind: string; title: string; detail: string }) {
  return <div className="resource-row"><span className="resource-icon">{kind}</span><div><strong>{title}</strong><small>{detail}</small></div><span className="muted">準備中</span></div>;
}
