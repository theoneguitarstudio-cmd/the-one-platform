"use client";
import Link from "@/components/platform-experience/link";
import { useState } from "react";
import { usePrototype } from "@/modules/ux-prototype/store";
import styles from "./tools.module.css";
import { useExperienceViewState } from "@/modules/platform-experience/view-state";

export function PrototypeTools() {
  const [open, setOpen] = useState(false);
  const { reset, setActor, studentId, actor, dispatch } = usePrototype();
  const { setCancelledPreviews, setReadNotificationIds } = useExperienceViewState();
  const resetAll = () => { reset(); setCancelledPreviews([]); setReadNotificationIds([]); };
  return <aside className={styles.tools} aria-label="本機 Mock 工具">
    {open && <div className={styles.panel}>
      <strong>本機 Mock 預覽</strong><p>重新整理會重設示意資料。</p>
      <Link href="/ux-prototype" onClick={()=>setOpen(false)}>公開首頁</Link>
      <Link href="/ux-prototype/student" onClick={()=>{setActor({role:"student",id:studentId});setOpen(false)}}>學生空間</Link>
      <Link href="/ux-prototype/student/courses/c1/lessons/l1" onClick={()=>{setActor({role:"student",id:studentId});setOpen(false)}}>錄播教室</Link>
      <Link href="/ux-prototype/teacher" onClick={()=>{setActor({role:"teacher",id:"t1"});setOpen(false)}}>老師工作台</Link>
      <Link href="/ux-prototype/admin" onClick={()=>{setActor({role:"admin",id:"admin",capability:"owner"});setOpen(false)}}>管理員工作台</Link>
      <Link href="/ux-prototype/account" onClick={()=>setOpen(false)}>帳戶與會員</Link>
      <Link href="/ux-prototype/products" onClick={()=>setOpen(false)}>三種購買流程</Link>
      <button onClick={()=>{resetAll();setOpen(false)}}>重設示意資料</button>
      {actor.role==="admin" && actor.capability!=="finance" && <label>師資版面情境（會重設全部 Mock）<select aria-label="師資版面情境" defaultValue="" onChange={event=>{const scenario=event.target.value as "empty"|"many"|"long"|"missing-image"|"no-public-offer";if(!scenario)return;resetAll();dispatch({type:"setRosterScenario",scenario});setOpen(false)}}><option value="">選擇本機 QA 情境</option><option value="empty">0 位推薦老師</option><option value="many">3 位老師（含 2 位 QA 示意）</option><option value="long">長中文名稱與說明</option><option value="missing-image">圖片載入失敗</option><option value="no-public-offer">沒有公開課程包</option></select></label>}
    </div>}
    <button className={styles.trigger} aria-expanded={open} onClick={()=>setOpen(!open)} onKeyDown={e=>{if(e.key==="Escape")setOpen(false)}}>{open?"關閉預覽工具":"Mock 預覽"}</button>
  </aside>;
}
