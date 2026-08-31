import Link from "next/link";

import { requireAreaAccess } from "@/modules/auth/server-authorization";
import {
  getOwnProfileTimezone,
  listOwnStudentTrialResults,
  listOwnTrialOrders,
} from "@/modules/trials/data";
import { RECOMMENDATION_LABELS } from "@/modules/trials/domain";
import { formatInTimezone } from "@/modules/trials/timezone";

type StudentTrialPageProps = { searchParams: Promise<{ status?: string }> };

export default async function StudentTrialPage({ searchParams }: StudentTrialPageProps) {
  const identity = await requireAreaAccess("student");
  const [trials, orders, query] = await Promise.all([
    listOwnStudentTrialResults(),
    listOwnTrialOrders(),
    searchParams,
  ]);
  const timezone = await getOwnProfileTimezone(identity.userId);
  return (
    <main className="mx-auto w-full max-w-4xl px-5 py-10 sm:px-8">
      <Link className="text-sm font-semibold" href="/student">← 返回學生區</Link>
      <h1 className="mt-5 text-3xl font-semibold">我的體驗課</h1>
      {query.status === "requested" ? <p className="mt-5 rounded-xl bg-[var(--surface)] p-4 text-sm">申請已送出，目前等待人工付款確認與排課。</p> : null}
      {orders.some((order) => order.paymentStatus === "pending") ? (
        <section className="mt-8 rounded-2xl bg-[var(--surface)] p-5">
          <h2 className="font-semibold">待確認申請</h2>
          {orders.filter((order) => order.paymentStatus === "pending").map((order) => (
            <p className="mt-2 text-sm text-[var(--text-secondary)]" key={order.id}>
              {formatInTimezone(order.proposedStartsAt, order.timezone)} · {order.deliveryMode === "online" ? "線上" : "實體"} · NT${order.priceTwd.toLocaleString("zh-TW")} · 尚未付款確認
            </p>
          ))}
        </section>
      ) : null}
      <div className="mt-8 space-y-5">
        {trials.length === 0 ? <p className="rounded-2xl border border-[var(--border)] p-6 text-[var(--text-secondary)]">目前沒有已確認的體驗課。</p> : trials.map((trial) => (
          <article className="rounded-2xl border border-[var(--border)] p-6" key={trial.lessonId}>
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div><p className="text-sm text-[var(--text-secondary)]">{trial.status}</p><h2 className="mt-1 text-xl font-semibold">{trial.teacherDisplayName}</h2></div>
              <span className="rounded-full bg-[var(--surface)] px-3 py-1 text-sm">{trial.deliveryMode === "online" ? "線上" : "實體"}</span>
            </div>
            <p className="mt-4">{formatInTimezone(trial.startsAt, timezone)}（{timezone}）</p>
            {trial.locationText ? <p className="mt-2 text-sm text-[var(--text-secondary)]">地點：{trial.locationText}</p> : null}
            {trial.hasMeeting && trial.status === "scheduled" ? <Link className="mt-4 inline-flex rounded-xl bg-[var(--brand-yellow)] px-4 py-2 text-sm font-semibold" href={`/lesson/${trial.lessonId}/join`}>進入線上教室</Link> : null}
            {trial.status === "completed" ? (
              <section className="mt-6 border-t border-[var(--border)] pt-5">
                <h3 className="font-semibold">老師的試上建議</h3>
                {trial.studentVisibleNotes ? <p className="mt-3 text-sm leading-6">{trial.studentVisibleNotes}</p> : null}
                <p className="mt-3 text-sm leading-6 text-[var(--text-secondary)]">{trial.assessmentSummary}</p>
                <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-2">
                  <div><dt className="font-semibold">Primary Stage</dt><dd>{trial.primaryStage ?? "待確認"}</dd></div>
                  <div><dt className="font-semibold">推薦方案</dt><dd>{trial.recommendation ? RECOMMENDATION_LABELS[trial.recommendation] : "待確認"}</dd></div>
                  <div><dt className="font-semibold">下一步</dt><dd>{trial.nextGoal || "—"}</dd></div>
                  <div><dt className="font-semibold">練習作業</dt><dd>{trial.homework || "—"}</dd></div>
                </dl>
              </section>
            ) : null}
          </article>
        ))}
      </div>
    </main>
  );
}
