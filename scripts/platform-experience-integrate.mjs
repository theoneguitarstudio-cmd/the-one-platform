import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

function update(path, pairs) {
  let text=readFileSync(path,'utf8');
  for(const [from,to] of pairs) {
    if(!text.includes(from)) throw new Error(`Missing integration anchor: ${path}: ${from.slice(0,60)}`);
    text=text.replaceAll(from,to);
  }
  writeFileSync(path,text);
}
function files(root) { return readdirSync(root,{withFileTypes:true}).flatMap(item=>item.isDirectory()?files(join(root,item.name)):[join(root,item.name)]); }
for(const file of files('src/components/ux-prototype').filter(path=>path.endsWith('.tsx'))) {
  let text=readFileSync(file,'utf8');
  text=text.replaceAll('import Link from "next/link";','import Link from "@/components/platform-experience/link";')
    .replaceAll('import { useRouter, useSearchParams } from "next/navigation";','import { useSearchParams } from "next/navigation";\nimport { useRouter } from "@/components/platform-experience/link";')
    .replaceAll('import { useRouter } from "next/navigation";','import { useRouter } from "@/components/platform-experience/link";');
  writeFileSync(file,text);
}
const branded=['public/shared.tsx','student/index.tsx','workspace/index.tsx','lesson/index.tsx'];
for(const name of branded) {
  const path=`src/components/ux-prototype/${name}`;
  update(path,[['"use client";','"use client";\nimport { BrandLogo } from "@/components/brand-logo";']]);
}
update('src/components/ux-prototype/public/shared.tsx',[
  ['<span className="p5-logo-mark">1.</span><span>The One<small>LEARN · PRACTICE · PLAY</small></span>','<BrandLogo />'],
  ['<div className="p5-footer-brand">The One<span>.</span></div>','<div className="p5-footer-brand"><BrandLogo /></div>'],
  ['className="p5-login" href={`${PUBLIC_ROOT}/student`}','className="p5-login" href={`${PUBLIC_ROOT}/auth/sign-in`}'],
  ['<Link href={`${PUBLIC_ROOT}/student`}>登入／預覽學生空間</Link>','<Link href={`${PUBLIC_ROOT}/membership`}>會員方案</Link><Link href={`${PUBLIC_ROOT}/system-courses`}>系統課程</Link><Link href={`${PUBLIC_ROOT}/account`}>我的帳戶</Link><Link href={`${PUBLIC_ROOT}/auth/sign-in`}>登入</Link>'],
  ['<div className="p5-footer-links">','<div className="p5-footer-links"><Link href={`${PUBLIC_ROOT}/membership`}>會員方案</Link><Link href={`${PUBLIC_ROOT}/faq`}>常見問題</Link><Link href={`${PUBLIC_ROOT}/support`}>聯絡與客服</Link><Link href={`${PUBLIC_ROOT}/about`}>關於我們</Link><Link href={`${PUBLIC_ROOT}/legal/terms`}>服務條款</Link><Link href={`${PUBLIC_ROOT}/legal/refund`}>退款與取消政策</Link>'],
]);
for(const name of ['student/index.tsx','workspace/index.tsx']) update(`src/components/ux-prototype/${name}`,[
  ['<span className="brand-symbol">1.</span><span className="brand-word">The One<small>LEARN · PRACTICE · PLAY</small></span>','<BrandLogo compact={collapsed} />'],
  ['<span className="brand-symbol">1.</span><span className="brand-word">The One</span>','<BrandLogo size="small" />'],
]);
update('src/components/ux-prototype/student/index.tsx',[
  ['<button className="nav-button account-row" onClick={() => openModal("scenarios")} aria-label="你的示範帳號">','<Link className="nav-button account-row" href="/ux-prototype/account" aria-label="我的帳戶">'],
  ['<small>學生空間站</small></span></button><button className="nav-button collapse-btn"','<small>帳戶與會員</small></span></Link><button className="nav-button collapse-btn"'],
  ['<h2>The One</h2>','<h2><BrandLogo size="small" /></h2>'],
  ['<div className="nav-divider" /><Link className="nav-button" href={studentHref("settings")} onClick={() => menu.current?.close()}>','<div className="nav-divider" /><Link className="nav-button" href="/ux-prototype/account" onClick={() => menu.current?.close()}>我的帳戶與會員</Link><Link className="nav-button" href="/ux-prototype/account/notifications" onClick={() => menu.current?.close()}>通知與回饋</Link><Link className="nav-button" href={studentHref("settings")} onClick={() => menu.current?.close()}>'],
]);
update('src/components/ux-prototype/workspace/index.tsx',[
  ['<div className="nav-button account-row">','<Link href="/ux-prototype/account" className="nav-button account-row">'],
  ['<small>僅本機雛形，不是正式帳號</small></span></div>','<small>帳戶與工作空間</small></span></Link>'],
]);
update('src/components/ux-prototype/lesson/index.tsx',[
  ['<span className="brand-symbol">1.</span><span className="brand-name">The One</span>','<BrandLogo compact={!wide} size="small" />'],
  ['<Link className="mobile-brand" href={studentHref()}>The One<span> .</span></Link>','<Link className="mobile-brand" href={studentHref()}><BrandLogo size="small" /></Link>'],
  ['<span className="video-brand">The One<span> .</span></span>','<span className="video-brand"><BrandLogo size="small" /></span>'],
  ['href={studentHref("settings")} aria-label="個人帳號"','href="/ux-prototype/account" aria-label="個人帳號"'],
]);
console.log('Reused native surfaces now share local routing and original brand asset.');
