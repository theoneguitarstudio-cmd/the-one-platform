"use client";

import { BrandLogo } from "@/components/brand-logo";
import { usePrototype } from "@/modules/ux-prototype/store";
import Link from "./link";
import styles from "./auth-page.module.css";

export function StudentAccessDenied() {
  const { state, studentId, setActor } = usePrototype();
  const knownStudent = state.students.some(student => student.id === studentId);
  return <div className={styles.page}>
    <header><Link href="/ux-prototype" aria-label="The One 首頁"><BrandLogo /></Link><Link href="/ux-prototype/support">需要協助？</Link></header>
    <main className={styles.card}>
      <p className={styles.kicker}>THE ONE / YOUR MUSIC JOURNEY</p>
      <h1>這個帳號目前無法開啟此空間</h1>
      <p className={styles.status}>目前的 Mock 視角不會取得所選學生的個人資料、課程或回饋。</p>
      <p>請回到自己可使用的工作空間，或明確切換學生示意視角繼續體驗。</p>
      {knownStudent && <button className={styles.primary} onClick={() => setActor({ role: "student", id: studentId })}>切換至所選學生的 Mock 視角</button>}
      <Link href="/ux-prototype/account">返回我的帳戶</Link>
    </main>
  </div>;
}
