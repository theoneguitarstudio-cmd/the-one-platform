"use client";
import { BrandLogo } from "@/components/brand-logo";
import Link from "@/components/platform-experience/link";
import { useState, useSyncExternalStore, type ReactNode } from "react";
import { usePrototype } from "@/modules/ux-prototype/store";
import { Btn, Foot, Icon, Modal, WorkspaceActions } from "./shared";
import "./workspace.css";
import { TeacherToday, TeacherStudents, TeacherReviews, TeacherLesson, TeacherRecords, TeacherSchedule, WorkspaceSettings } from "./teaching";
import { AdminContentPage } from "./admin-content";
import { TeacherCourses, TeacherProfilePage } from "./teacher-content";
import { FinancePage } from "./finance";
import { PoliciesPage } from "./policies";
import { canOperate } from "@/modules/ux-prototype/model";
import { AdminBookings, AdminGuidance, AdminHome, AdminStudents, AuditPage, OperationDenied, OversightPage, TeacherBooking } from "./operations";

const teacherNav = [["","home","今日教學"],["courses","book","我的課程與提案"],["schedule","calendar","我的課表"],["book-for-student","calendar","幫學生預約"],["students","people","我的學生"],["reviews","chat","作業與回饋"],["earnings","wallet","我的收入"],["records","file","教學紀錄"],["profile","edit","我的展示頁"],["policies","book","老師合作守則"]];
const adminNav = [["","home","營運總覽"],["finance","wallet","平台財務"],["courses","book","課程管理"],["review","edit","提案與上架審核"],["students","people","學生與權益"],["bookings","calendar","預約管理"],["guidance","video","Pro 指導調度"],["articles","file","文章管理"],["policies","book","平台守則管理"],["oversight","chat","師生互動檢視"],["audit","shield","操作紀錄"]];
const subscribeSystem = (callback:()=>void) => {const media=window.matchMedia("(prefers-color-scheme: dark)");media.addEventListener("change",callback);return()=>media.removeEventListener("change",callback)};

export function WorkspacePage({ role, segments }: { role: "teacher" | "admin"; segments: string[] }) {
  const { theme, actor, setActor } = usePrototype();
  const [collapsed,setCollapsed] = useState(false);
  const [menu,setMenu]=useState(false);
  const [notice,setNotice]=useState("");
  const [confirmation,setConfirmation]=useState<{title:string;body:ReactNode;action:()=>boolean}|null>(null);
  const systemDark=useSyncExternalStore(subscribeSystem,()=>window.matchMedia("(prefers-color-scheme: dark)").matches,()=>true);
  const nav=role==="teacher"?teacherNav:adminNav;
  const navItems=nav.map(([path,icon,label])=><Link key={path} className={`nav-button ${(segments[0]||"")===path?"current":""}`} href={`/ux-prototype/${role}${path?`/${path}`:""}`} onClick={()=>setMenu(false)}><Icon name={icon}/><span className="nav-text">{label}</span><span className="nav-tip">{label}</span></Link>);
  return <WorkspaceActions.Provider value={{notify:setNotice,confirm:(title,body,action)=>setConfirmation({title,body,action})}}><div className="ux-workspace" data-theme={theme==="system"?(systemDark?"dark":"light"):theme}><div className={`app ${collapsed?"collapsed":""}`}>
    <aside className="sidebar"><Link className="brand" href="/ux-prototype"><BrandLogo compact={collapsed} /></Link><p className="nav-group-label">{role==="teacher"?"你的教學空間":"平台管理員工作台"}</p><nav className="mainnav">{navItems}</nav><div className="nav-divider"/><Link href={`/ux-prototype/${role}/students`} className="nav-button"><Icon name="search"/><span className="nav-text">搜尋學生</span></Link><div className="nav-bottom"><Link className="nav-button" href={`/ux-prototype/${role}/settings`}><Icon name="settings"/><span className="nav-text">設定<small className="micro">　外觀：{theme==="dark"?"黑色":theme==="light"?"白色":"系統"}</small></span></Link><Link href="/ux-prototype/account" className="nav-button account-row"><span className="user-dot">{role==="teacher"?"師":"管"}</span><span className="account-text">{role==="teacher"?"The One 老師":"平台管理視角"}<small>帳戶與工作空間</small></span></Link><button className="nav-button collapse-btn" onClick={()=>setCollapsed(!collapsed)}><Icon name="arrow"/><span className="nav-text">收合選單</span></button></div></aside>
    <header className="mobile-header"><Link className="brand" href="/ux-prototype"><BrandLogo size="small" /></Link><div className="mobile-actions">{actor.role===role&&(role==="teacher"||canOperate(actor))&&<Link className="icon-button" aria-label={role==="teacher"?"搜尋我的學生":"搜尋學生"} href={`/ux-prototype/${role}/students`}><Icon name="search"/></Link>}<button className="icon-button" aria-label="開啟工作台選單" onClick={()=>setMenu(true)}><Icon name="menu"/></button></div></header>
    <main className="main"><div className="page">{actor.role!==role?<div className="v4-locked"><Icon name="shield"/><h1>請先選擇對應的 Mock 視角</h1><p>目前是{actor.role}。這個入口不會自動取得另一個角色的操作能力。</p><Btn onClick={()=>setActor(role==="teacher"?{role:"teacher",id:"t1"}:{role:"admin",id:"admin",capability:"owner"})}>切換至{role==="teacher"?"老師":"管理員"}示意視角</Btn></div>:<>
      {role==="admin"&&<div className="v4-toolbar"><p className="micro">管理視角 · 示意資料，並非正式權限</p><label className="micro">目前身分　<select aria-label="管理員能力情境" className="t-select" style={{marginTop:0}} value={actor.capability||"owner"} onChange={e=>setActor({...actor,capability:e.target.value as "ops"|"finance"|"owner"})}><option value="owner">平台負責人 · 含完整財務</option><option value="ops">營運管理員 · 不含財務</option><option value="finance">財務人員 · 僅財務</option></select></label></div>}
      <WorkspaceRoute role={role} segments={segments} key={`${role}/${segments.join("/")}/${actor.id}/${actor.capability}`}/>
    </>}</div></main>
  </div>{menu&&<Modal title="工作台選單" onClose={()=>setMenu(false)}><nav>{navItems}</nav><Link className="nav-button" href={`/ux-prototype/${role}/settings`} onClick={()=>setMenu(false)}>設定</Link></Modal>}{confirmation&&<Modal title={confirmation.title} onClose={()=>setConfirmation(null)}><div className="x-confirm-details">{confirmation.body}</div><div className="x-bottom-actions"><Btn onClick={()=>setConfirmation(null)}>返回修改</Btn><Btn primary onClick={()=>{if(confirmation.action())setConfirmation(null)}}>確認執行（本機 Mock）</Btn></div></Modal>}{notice&&<div role="status" className="toast" onClick={()=>setNotice("")}>{notice}<button aria-label="關閉提示" onClick={()=>setNotice("")}>　×</button></div>}</div></WorkspaceActions.Provider>;
}

function WorkspaceRoute({role,segments}:{role:"teacher"|"admin";segments:string[]}) {
  const {actor}=usePrototype();
  const [page,id]=segments;
  if(page==="settings")return <WorkspaceSettings/>;
  if(page==="policies")return <PoliciesPage role={role}/>;
  if(page==="finance"||page==="earnings")return <FinancePage role={role}/>;
  if(role==="admin"&&page==="audit")return <AuditPage/>;
  if(role==="admin"&&!canOperate(actor))return !page?<FinancePage role="admin"/>:<OperationDenied/>;
  if(role==="admin"&&["courses","review","articles"].includes(page))return <AdminContentPage segments={segments}/>;
  if(role==="admin"){
    if(!page)return <AdminHome/>;
    if(page==="bookings")return <AdminBookings/>;
    if(page==="students")return <AdminStudents/>;
    if(page==="guidance")return <AdminGuidance/>;
    if(page==="oversight")return <OversightPage/>;
    if(page==="audit")return <AuditPage/>;
  }
  if(role==="teacher"){
    if(!page)return <TeacherToday/>;
    if(page==="students")return <TeacherStudents id={id}/>;
    if(page==="reviews")return <TeacherReviews id={id}/>;
    if(page==="lessons")return <TeacherLesson id={id}/>;
    if(page==="records")return <TeacherRecords/>;
    if(page==="schedule")return <TeacherSchedule/>;
    if(page==="courses")return <TeacherCourses/>;
    if(page==="proposals")return <TeacherCourses proposalId={id}/>;
    if(page==="profile")return <TeacherProfilePage/>;
    if(page==="book-for-student")return <TeacherBooking/>;
  }
  return <><header className="page-header"><div><div className="eyebrow">LOCAL MOCK</div><h1>找不到這個工作台頁面</h1><p className="subtitle">請從左側選單開啟可用的流程。</p></div></header><Foot/></>;
}
