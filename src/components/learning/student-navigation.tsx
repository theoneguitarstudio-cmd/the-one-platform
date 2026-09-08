"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { isMockDataMode } from "@/lib/preview/mode";
import { learningPreview } from "@/lib/preview/learning";
const items = [["/student","Today","◉"],["/student/map","我的學習","⌁"],["/student#feedback","Coaching / 回饋","✧"],["/student#practice","Practice / 練習","♫"],["/student/schedule","私人課程","◷"],["/student#profile","個人檔案","◌"]] as const;
export function StudentNavigation() {
  const path = usePathname();
  const mock = isMockDataMode();
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState(false);
  const [query, setQuery] = useState("");
  const results = learningPreview.lessons.filter(x => x.state !== "locked" && x.title.includes(query));
  return <header className={"student-header" + (open ? " nav-open" : "")}>
    <Link className="wordmark" href="/" aria-label="The One 首頁"><span className="brand-symbol" aria-hidden="true">♫</span><span className="nav-brand-name">The One</span></Link>
    <button className="app-menu-toggle" aria-expanded={open} aria-controls="student-global-nav" onClick={() => setOpen(!open)}>☰ <span>導覽</span></button>
    <nav id="student-global-nav" aria-label="學生導覽">
      <div className="nav-primary">{items.map(([href,label,icon]) => <Link key={href} href={href} title={label} onClick={() => setOpen(false)} aria-current={href === path || (href === "/student/map" && path.startsWith("/student/learn/")) ? "page" : undefined}><span aria-hidden="true">{icon}</span><span className="nav-label">{label}</span></Link>)}</div>
      <div className="nav-secondary">{mock && <button title="搜尋課節" aria-label="搜尋課節" onClick={() => { setSearch(!search); setOpen(false); }}><span aria-hidden="true">⌕</span><span className="nav-label">Search / 搜尋</span></button>}<details className="nav-support"><summary title="使用說明"><span aria-hidden="true">?</span><span className="nav-label">Support / 支援</span></summary><p>目前為 Mock 預覽。從「我的學習」進入課程；練習標記不會保存，也不會送出訊息。</p></details><Link href="/student#profile" title="Account" onClick={() => setOpen(false)}><span aria-hidden="true">◌</span><span className="nav-label">Account / 帳戶</span></Link></div>
    </nav>
    {mock && search && <div className="lesson-search" role="dialog" aria-label="搜尋示範課節"><div><label htmlFor="lesson-search-input">搜尋示範課節</label><button aria-label="關閉搜尋" onClick={() => setSearch(false)}>×</button></div><input id="lesson-search-input" autoFocus value={query} onChange={e => setQuery(e.target.value)} placeholder="輸入課節名稱"/><ul>{results.map(x => <li key={x.id}><Link href={"/student/learn/"+x.id} onClick={() => setSearch(false)}>{x.title}</Link></li>)}</ul>{results.length === 0 && <p>找不到符合的示範課節。</p>}</div>}
  </header>;
}
