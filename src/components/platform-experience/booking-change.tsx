"use client";
import { useState, type FormEvent } from "react";
import { BrandLogo } from "@/components/brand-logo";
import Link from "./link";
import { usePrototype } from "@/modules/ux-prototype/store";
import { cancellationSchema, rescheduleSchema, mapSchedulingDomainError } from "@/modules/scheduling/domain";
import { formatSchedulingInstant, resolveSchedulingLocalDateTime } from "@/modules/scheduling/timezone";
import { getLocalIdentity, validateWorkspaceSwitch, LOCAL_REFERENCE_MAP } from "@/modules/platform-experience/gateway";
import styles from "./auth-page.module.css";

export function BookingChangePage({ bookingId }: { bookingId?: string }) {
  const {state,studentId,actor,timeZone}=usePrototype();
  const booking=state.bookings.find(item=>item.id===bookingId&&item.studentId===studentId);
  const [kind,setKind]=useState("reschedule");
  const [notice,setNotice]=useState("");
  const [review,setReview]=useState<string|null>(null);
  const identity=getLocalIdentity(studentId==="s2"?"student-2":studentId==="s3"?"student-3":"student");
  const allowed=actor.role==="student"&&actor.id===studentId&&validateWorkspaceSwitch(identity,"student").ok;
  function submit(event:FormEvent<HTMLFormElement>){
    event.preventDefault();setNotice("");
    if(!booking||!allowed){setNotice("請使用自己的學生空間開啟預約。");return;}
    const data=new FormData(event.currentTarget);
    // Shared ab1/ab2 use synthetic UUID format tokens only, never independent DTO records.
    // Newly created local IDs have no token and remain unavailable for this contract preview.
    const id=LOCAL_REFERENCE_MAP[booking.id as keyof typeof LOCAL_REFERENCE_MAP];
    if(!id){setNotice("這筆示意預約尚未提供調整流程預覽；預約與堂數均未更動。");return;}
    try{
      const instant=kind==="reschedule"?resolveSchedulingLocalDateTime(String(data.get("newTime")),timeZone):null;
      const result=kind==="cancel"?cancellationSchema.safeParse({bookingId:id,creditOutcome:"manual_review_required",reason:data.get("reason")}):rescheduleSchema.safeParse({bookingId:id,newStartsAt:instant,timezone:timeZone,reason:data.get("reason")});
      if(!result.success){setNotice("請填寫至少 3 個字的原因，並確認新時間。");return;}
      setReview(kind==="cancel"?"取消本次預約；是否返還堂數或需要人工確認，由適用政策與正式服務決定。":`希望改到 ${formatSchedulingInstant(instant!,timeZone)}。這是時間偏好，尚未確認老師空檔。`);
    }catch(error){setNotice(mapSchedulingDomainError(error instanceof Error?error.message:undefined));}
  }
  return <div className={styles.page}><header><Link href="/ux-prototype"><BrandLogo/></Link><Link href="/ux-prototype/student/private">返回私人課</Link></header><main className={styles.card}><p className={styles.kicker}>PRIVATE LESSON / YOUR SCHEDULE</p><h1>調整這一堂課</h1><p className={styles.status}>HYBRID · 沿用 Epic6 取消／改期與時區驗證。正式時段、政策與交易尚未接線。</p>{!booking||!allowed?<p>找不到你可操作的預約。請從自己的私人課頁重新開啟。</p>:<><p>{formatSchedulingInstant(booking.start,timeZone)}<br/>{booking.mode==="fixed"?"固定安排":"預約制"} · {Math.round((Date.parse(booking.end)-Date.parse(booking.start))/60000)} 分鐘<br/>預約 {booking.id} · {timeZone}</p>{review?<div className={styles.message}><h2>再次確認調整內容</h2><p>{review}</p><p>僅調整單堂。取消預約不同於取消會員；老師造成取消可能轉為補課權利，不能一律換算成普通堂數。</p><button className={styles.primary} onClick={()=>setNotice("已走完資料確認步驟。正式服務尚未接線，這筆預約、堂數和會員資格都未更動。")}>確認內容（本機驗證）</button><button onClick={()=>{setReview(null);setNotice("")}}>返回修改</button></div>:<form onSubmit={submit}><label>想要怎麼調整<select value={kind} onChange={e=>setKind(e.target.value)} style={{padding:12,border:"1px solid #ddd",borderRadius:8}}><option value="reschedule">改到另一個時間</option><option value="cancel">取消這堂預約</option></select></label>{kind==="reschedule"&&<label>希望的新時間<input name="newTime" type="datetime-local" required/><span className={styles.hint}>依 {timeZone} 顯示；正式可用時間仍待查詢。</span></label>}<label>調整原因<textarea name="reason" rows={3} required minLength={3} maxLength={1000} style={{padding:12,border:"1px solid #ddd",borderRadius:8,resize:"vertical"}}/></label><button className={styles.primary}>查看本次調整內容</button></form>}{notice&&<p role="status" className={styles.message}>{notice}</p>}<Link href="/ux-prototype/account/help">需要平台協助</Link></>}</main></div>;
}
