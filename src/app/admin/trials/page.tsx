import Link from "next/link";

import {
  cancelTrialLesson,
  confirmTrialPayment,
  rescheduleTrialLesson,
} from "@/modules/trials/actions";
import { listAdminTrialData } from "@/modules/trials/data";
import { formatInTimezone } from "@/modules/trials/timezone";

type AdminTrialsPageProps = { searchParams: Promise<{ error?: string; status?: string }> };

export default async function AdminTrialsPage({ searchParams }: AdminTrialsPageProps) {
  const [{ orders, lessons, relationships }, query] = await Promise.all([listAdminTrialData(), searchParams]);
  return (
    <main className="mx-auto w-full max-w-6xl px-5 py-10 sm:px-8">
      <Link className="text-sm font-semibold" href="/admin">← 返回管理區</Link>
      <h1 className="mt-5 text-3xl font-semibold">體驗課管理</h1>
      <p className="mt-3 text-sm text-[var(--text-secondary)]">Epic 3 使用人工付款確認；所有確認、改期與取消都會在 server 重新驗證 Admin。</p>
      {query.status ? <p className="mt-5 rounded-xl bg-[var(--surface)] p-4 text-sm">操作已完成。</p> : null}
      {query.error ? <p className="mt-5 rounded-xl bg-red-50 p-4 text-sm text-red-800">操作失敗，可能是撞堂、老師尚未設定線上教室或資料無效。</p> : null}

      <section className="mt-9"><h2 className="text-xl font-semibold">Trial relationships</h2><div className="mt-4 grid gap-3 sm:grid-cols-2">{relationships.length === 0 ? <p className="rounded-2xl bg-[var(--surface)] p-5">尚無 Trial relationship。</p> : relationships.map((relationship) => <article className="rounded-2xl border border-[var(--border)] p-4 text-sm" key={relationship.id}><p className="font-semibold">{relationship.status} · {relationship.preferredMode}</p><p className="mt-2 break-all text-[var(--text-secondary)]">Student {relationship.studentUserId}</p><p className="mt-1 break-all text-[var(--text-secondary)]">Teacher {relationship.teacherUserId}</p></article>)}</div></section>

      <section className="mt-9"><h2 className="text-xl font-semibold">待付款確認</h2><div className="mt-4 space-y-4">{orders.length === 0 ? <p className="rounded-2xl bg-[var(--surface)] p-5">尚無申請。</p> : orders.map((order) => <article className="rounded-2xl border border-[var(--border)] p-5" key={order.id}><p className="text-sm text-[var(--text-secondary)]">Order {order.id}</p><p className="mt-2">{formatInTimezone(order.proposedStartsAt, order.timezone)} · {order.deliveryMode} · NT${order.priceTwd.toLocaleString("zh-TW")}</p><p className="mt-1 text-sm">狀態：{order.paymentStatus}</p>{order.paymentStatus === "pending" ? <form action={confirmTrialPayment} className="mt-4"><input name="orderId" type="hidden" value={order.id} /><button className="rounded-xl bg-[var(--brand-yellow)] px-4 py-2 text-sm font-semibold" type="submit">人工確認已付款並排課</button></form> : null}</article>)}</div></section>

      <section className="mt-10"><h2 className="text-xl font-semibold">已建立體驗課</h2><div className="mt-4 space-y-4">{lessons.length === 0 ? <p className="rounded-2xl bg-[var(--surface)] p-5">尚無 Lesson。</p> : lessons.map((lesson) => <article className="rounded-2xl border border-[var(--border)] p-5" key={lesson.id}><p className="text-sm text-[var(--text-secondary)]">Lesson {lesson.id}</p><p className="mt-2">{formatInTimezone(lesson.startsAt, lesson.timezone)} · {lesson.deliveryMode} · {lesson.status}</p>{lesson.status === "scheduled" ? <div className="mt-4 flex flex-col gap-4 sm:flex-row"><form action={rescheduleTrialLesson} className="flex flex-wrap gap-2"><input name="lessonId" type="hidden" value={lesson.id} /><input name="timezone" type="hidden" value={lesson.timezone} /><input className="rounded-xl border border-[var(--border)] px-3 py-2" name="localStartsAt" required type="datetime-local" /><button className="rounded-xl border border-[var(--border)] px-4 py-2 text-sm font-semibold" type="submit">改期</button></form><form action={cancelTrialLesson}><input name="lessonId" type="hidden" value={lesson.id} /><button className="rounded-xl border border-red-200 px-4 py-2 text-sm font-semibold text-red-700" type="submit">取消</button></form></div> : null}</article>)}</div></section>
    </main>
  );
}
