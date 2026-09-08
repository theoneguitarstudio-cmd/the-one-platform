"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
const items = [["/student","今日學習","◉"],["/student/map","我的學習","⌁"],["/student#practice","練習","♫"],["/student/schedule","私人課程","◷"],["/student#feedback","老師回饋","✧"],["/student#profile","個人檔案","◌"]] as const;
export function StudentNavigation() {
 const path=usePathname();
 return <header className="student-header"><Link className="wordmark" href="/"><span className="brand-symbol" aria-hidden="true">♫</span>The One</Link><nav aria-label="學生導覽">{items.map(([href,label,icon])=><Link key={href} href={href} aria-current={(href===path || (href==="/student/map" && path.startsWith("/student/learn/"))) ? "page":undefined}><span aria-hidden="true">{icon}</span>{label}</Link>)}</nav><Link className="avatar-link" href="/student#profile" aria-label="個人檔案">我</Link></header>;
}
