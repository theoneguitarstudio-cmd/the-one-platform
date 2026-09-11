"use client";
import { BrandLogo } from "@/components/brand-logo";

import Image from "next/image";
import Link from "@/components/platform-experience/link";
import { useEffect, useRef, useState, type ReactNode } from "react";

export const PUBLIC_ROOT = "/ux-prototype";
export const LESSON_PREVIEW = `${PUBLIC_ROOT}/student/courses/c1/lessons/l3?activity=learn`;

export function Icon({ name = "arrow" }: { name?: "arrow" | "right" | "left" | "menu" | "chat" | "video" | "play" }) {
  const paths = { arrow: "M5 12h14m-6-6 6 6-6 6", right: "m9 5 7 7-7 7", left: "m15 5-7 7 7 7", menu: "M4 6h16M4 12h16M4 18h16", chat: "M21 11.5a8.4 8.4 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.4 8.4 0 0 1-3.8-.9L3 21l1.9-5.7a8.4 8.4 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.4 8.4 0 0 1 3.8-.9H13a8.5 8.5 0 0 1 8 8v.5ZM8 9h8M8 13h5", video: "m16 8 5-3v14l-5-3M5 6h8a3 3 0 0 1 3 3v6a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3V9a3 3 0 0 1 3-3Z", play: "m8 5 11 7-11 7Z" };
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={paths[name]} /></svg>;
}

export function Asset({ name = "guitar", alt, className = "", src, onFailure }: { name?: string; alt: string; className?: string; src?: string; onFailure?: () => void }) {
  const [failed, setFailed] = useState(false);
  return <Image unoptimized width={600} height={800} src={!failed && src ? src : `${PUBLIC_ROOT}/${name}.${name === "mobile" ? "png" : "jpg"}`} alt={failed ? "吉他教學概念影像，並非真實師資照片" : alt} className={className} onError={() => { if (!failed) { setFailed(true); onFailure?.(); } }} />;
}

export function DiagnosisCTA({ children = "找到我的學習方向", className = "" }: { children?: ReactNode; className?: string }) {
  return <Link className={`p5-btn ${className}`} href={`${PUBLIC_ROOT}/diagnosis`}>{children} <Icon /></Link>;
}

export function PublicNav() {
  const [open, setOpen] = useState(false);
  const menuButton = useRef<HTMLButtonElement>(null);
  const nav = useRef<HTMLElement>(null);
  useEffect(() => {
    if (!open) return;
    const close = (event: KeyboardEvent) => { if (event.key === "Escape") { setOpen(false); menuButton.current?.focus(); } };
    const outside = (event: PointerEvent) => { if (!nav.current?.contains(event.target as Node)) setOpen(false); };
    document.addEventListener("keydown", close);
    document.addEventListener("pointerdown", outside);
    return () => { document.removeEventListener("keydown", close); document.removeEventListener("pointerdown", outside); };
  }, [open]);
  const closeMenu = () => setOpen(false);
  return <nav className="p5-nav" aria-label="The One 網站導覽" ref={nav}>
    <Link className="p5-logo" href={PUBLIC_ROOT} aria-label="The One 首頁" onClick={closeMenu}><BrandLogo /></Link>
    <div className="p5-nav-links"><Link href={`${PUBLIC_ROOT}#p5-how`}>怎麼學</Link><Link href={`${PUBLIC_ROOT}/courses/guitar-roadmap`}>吉他學習地圖</Link><Link href={`${PUBLIC_ROOT}#p5-teacher`}>線上一對一</Link></div>
    <div className="p5-nav-right"><Link className="p5-login" href={`${PUBLIC_ROOT}/auth/sign-in`}>登入</Link><DiagnosisCTA className="small">開始診斷</DiagnosisCTA><button ref={menuButton} className="p5-menu-btn" aria-label={open ? "關閉網站選單" : "開啟網站選單"} aria-expanded={open} aria-controls="p5-mobile-nav" onClick={() => setOpen(!open)}><Icon name="menu" /></button></div>
    <div className="p5-mobile-nav" id="p5-mobile-nav" hidden={!open} onClick={closeMenu}><Link href={`${PUBLIC_ROOT}#p5-how`}>怎麼學</Link><Link href={`${PUBLIC_ROOT}/courses/guitar-roadmap`}>吉他學習地圖</Link><Link href={`${PUBLIC_ROOT}#p5-teacher`}>線上一對一</Link><Link href={`${PUBLIC_ROOT}#p5-teacher`}>認識老師</Link><Link href={`${PUBLIC_ROOT}/articles`}>學習文章</Link><Link href={`${PUBLIC_ROOT}/membership`}>會員方案</Link><Link href={`${PUBLIC_ROOT}/system-courses`}>系統課程</Link><Link href={`${PUBLIC_ROOT}/account`}>我的帳戶</Link><Link href={`${PUBLIC_ROOT}/auth/sign-in`}>登入</Link></div>
  </nav>;
}

export function PublicFooter() {
  return <footer className="p5-footer"><div className="p5-footer-main"><div><div className="p5-footer-brand"><BrandLogo /></div><p>讓音樂，成為生活的一部分。</p></div><div className="p5-footer-links"><Link href={`${PUBLIC_ROOT}/membership`}>會員方案</Link><Link href={`${PUBLIC_ROOT}/faq`}>常見問題</Link><Link href={`${PUBLIC_ROOT}/support`}>聯絡與客服</Link><Link href={`${PUBLIC_ROOT}/about`}>關於我們</Link><Link href={`${PUBLIC_ROOT}/legal/terms`}>服務條款</Link><Link href={`${PUBLIC_ROOT}/legal/refund`}>退款與取消政策</Link><Link href={`${PUBLIC_ROOT}/articles`}>學習文章</Link><Link href={`${PUBLIC_ROOT}/policies/students`}>學生守則</Link><Link href={`${PUBLIC_ROOT}/policies/privacy`}>隱私與資料使用</Link></div></div><div className="p5-footer-small"><span>The One 2.0 · 公開首頁 v1.6 原生雛形<br />目前以吉他與線上教學為主。示意素材與範例介面不代表正式上線的功能。</span><Link href={`${PUBLIC_ROOT}/student`}>預覽學生空間</Link></div></footer>;
}
