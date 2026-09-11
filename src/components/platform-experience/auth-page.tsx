"use client";

import { useState, type FormEvent } from "react";
import { BrandLogo } from "@/components/brand-logo";
import Link from "./link";
import { emailSchema, passwordSchema, signInSchema, signUpSchema } from "@/modules/auth/validation";
import styles from "./auth-page.module.css";
import { usePrototype } from "@/modules/ux-prototype/store";

const titles: Record<string,string> = { "sign-in":"歡迎回來", "sign-up":"開始你的音樂旅程", "forgot-password":"找回你的帳號", "reset-password":"設定新的密碼", "verify-email":"確認你的電子郵件", "access-denied":"這個帳號目前無法開啟此空間" };

export function LocalAuthPage({ route = "sign-in" }: { route?: string }) {
  const {studentId,setStudentId,setActor}=usePrototype();
  const [notice,setNotice]=useState("");
  const [complete,setComplete]=useState(false);
  const [pending,setPending]=useState(false);
  const isSignup=route==="sign-up";
  const isReset=route==="reset-password";
  const emailOnly=route==="forgot-password";
  function submit(event:FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form=new FormData(event.currentTarget);
    const values={email:form.get("email"),password:form.get("password"),displayName:form.get("displayName")};
    const result=isSignup?signUpSchema.safeParse(values):emailOnly?emailSchema.safeParse(values.email):isReset?passwordSchema.safeParse(values.password):signInSchema.safeParse(values);
    if(!result.success){setNotice(isSignup||isReset?"請確認姓名至少 2 個字、電子郵件格式，以及密碼至少 12 字且包含英文字母與數字。":"請檢查電子郵件與密碼欄位。");return;}
    setPending(true);
    setNotice(emailOnly?"資料格式已確認；本機不會寄出重設密碼信。":isReset?"新密碼格式已確認；正式密碼沒有變更。":"已通過既有帳戶欄位驗證；以下可繼續體驗，未建立或登入正式帳號。");
    event.currentTarget.reset();
    if(isSignup){setStudentId("s2");setActor({role:"student",id:"s2"});}
    setComplete(true);setPending(false);
  }
  return <div className={styles.page}><header><Link href="/ux-prototype" aria-label="The One 首頁"><BrandLogo /></Link><Link href="/ux-prototype/support">需要協助？</Link></header><main className={styles.card}><p className={styles.kicker}>THE ONE / YOUR MUSIC JOURNEY</p><h1>{titles[route]||"找不到帳戶頁面"}</h1><p className={styles.lead}>讓音樂，慢慢成為生活的一部分。</p><p className={styles.status}>HYBRID · 沿用 Epic1 表單驗證 · 本機流程預覽，未連接登入服務。請使用示意資料。</p>
    {route==="verify-email"?<><div className={styles.message}><h2>信箱驗證會出現在這一步</h2><p>正式版會顯示寄送結果與驗證連結。本機沒有寄信，也不會宣稱信箱已驗證。</p></div><Link className={styles.primary} href="/ux-prototype/onboarding">繼續體驗新生引導</Link><Link href="/ux-prototype/auth/sign-in">返回登入</Link></>:route==="access-denied"?<><p>請回到自己可使用的工作空間，或向平台尋求協助。</p><Link className={styles.primary} href="/ux-prototype/account">返回我的帳戶</Link></>:!titles[route]?<Link href="/ux-prototype/auth/sign-in">前往登入</Link>:<>
      {!complete?<form onSubmit={submit} noValidate>{isSignup&&<label>怎麼稱呼你<input name="displayName" autoComplete="nickname" required minLength={2} maxLength={80} placeholder="示意名字" /></label>}{!isReset&&<label>電子郵件<input name="email" type="email" autoComplete="email" required placeholder="learner@example.test" /></label>}{!emailOnly&&<label>{isReset?"新密碼":"密碼"}<input name="password" type="password" autoComplete={isSignup||isReset?"new-password":"current-password"} required maxLength={128} aria-describedby={isSignup||isReset?"password-hint":undefined}/></label>}{(isSignup||isReset)&&<p id="password-hint" className={styles.hint}>至少 12 個字，包含英文字母和數字。</p>}<button className={styles.primary} disabled={pending} type="submit">{pending?"正在確認…":emailOnly?"確認重設資料":isReset?"確認新密碼格式":isSignup?"建立帳號流程預覽":"登入流程預覽"}</button></form>:<div className={styles.message}><h2>資料確認完成</h2><Link className={styles.primary} href={isSignup?"/ux-prototype/auth/verify-email":emailOnly?"/ux-prototype/auth/reset-password":isReset?"/ux-prototype/auth/sign-in":"/ux-prototype/student"} onNavigate={route==="sign-in"?()=>setActor({role:"student",id:studentId}):undefined}>{isSignup?"查看信箱驗證步驟":emailOnly?"查看重設密碼步驟":isReset?"返回登入":"進入學生空間（Mock）"}</Link><button onClick={()=>{setComplete(false);setNotice("")}}>返回修改</button></div>}
      {notice&&<p role="status" className={styles.message}>{notice}</p>}
      <div className={styles.links}>{route==="sign-in"?<><Link href="/ux-prototype/auth/forgot-password">忘記密碼</Link><span>還沒有帳號？ <Link href="/ux-prototype/auth/sign-up">開始註冊</Link></span></>:<Link href="/ux-prototype/auth/sign-in">已有帳號，返回登入</Link>}</div>
    </>}
    <footer><Link href="/ux-prototype/legal/terms">服務條款</Link><Link href="/ux-prototype/legal/privacy">隱私說明</Link></footer></main></div>;
}

export function UnavailablePage({ kind = "not-found" }: { kind?: "not-found"|"unavailable"|"error" }) {
  return <div className={styles.page}><header><Link href="/ux-prototype"><BrandLogo /></Link></header><main className={styles.card}><p className={styles.kicker}>{kind==="not-found"?"404 / PAGE NOT FOUND":"THE ONE / SERVICE STATUS"}</p><h1>{kind==="not-found"?"這一頁還沒有內容":kind==="error"?"暫時無法開啟":"這項服務暫時無法使用"}</h1><p>你可以回到首頁，或在說明中心找到下一步。正式服務尚未接線的項目不會顯示為空資料。</p><Link className={styles.primary} href="/ux-prototype">回到首頁</Link><Link href="/ux-prototype/support">前往說明中心</Link></main></div>;
}
