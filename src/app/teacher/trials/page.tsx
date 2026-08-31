import Link from "next/link";

import { getTeacherCatalog } from "@/modules/teachers/catalog";
import {
  completeTrialLesson,
  saveTeacherMeetingDefaults,
} from "@/modules/trials/actions";
import { listOwnTeacherTrials } from "@/modules/trials/data";
import { formatInTimezone } from "@/modules/trials/timezone";

type TeacherTrialsPageProps = {
  searchParams: Promise<{ error?: string; status?: string }>;
};

export default async function TeacherTrialsPage({ searchParams }: TeacherTrialsPageProps) {
  const [trials, catalog, query] = await Promise.all([
    listOwnTeacherTrials(),
    getTeacherCatalog(),
    searchParams,
  ]);
  return (
    <main className="mx-auto w-full max-w-5xl px-5 py-10 sm:px-8">
      <Link className="text-sm font-semibold" href="/teacher">← 返回教師區</Link>
      <h1 className="mt-5 text-3xl font-semibold">體驗課工作台</h1>
      {query.status ? <p className="mt-5 rounded-xl bg-[var(--surface)] p-4 text-sm">操作已完成。</p> : null}
      {query.error ? <p className="mt-5 rounded-xl bg-red-50 p-4 text-sm text-red-800">操作失敗，請檢查資料或聯絡管理員。</p> : null}

      <section className="mt-8 rounded-2xl border border-[var(--border)] p-6">
        <h2 className="text-xl font-semibold">線上教室預設連結</h2>
        <p className="mt-2 text-sm text-[var(--text-secondary)]">只會掛到已確認的 participant lesson，不會公開在老師頁。</p>
        <form action={saveTeacherMeetingDefaults} className="mt-5 grid gap-4 sm:grid-cols-[220px_1fr_auto]">
          <select className="rounded-xl border border-[var(--border)] px-3 py-2" name="provider">
            <option value="manual_google_meet">Google Meet（手動）</option>
            <option value="manual_zoom">Zoom（手動）</option>
          </select>
          <input className="rounded-xl border border-[var(--border)] px-3 py-2" name="url" placeholder="https://…" required type="url" />
          <button className="rounded-xl bg-[var(--brand-yellow)] px-4 py-2 font-semibold" type="submit">儲存</button>
        </form>
      </section>

      <section className="mt-8 space-y-5">
        {trials.length === 0 ? <p className="rounded-2xl bg-[var(--surface)] p-6">目前沒有體驗課。</p> : trials.map((trial) => (
          <article className="rounded-2xl border border-[var(--border)] p-6" key={trial.lessonId}>
            <div className="flex flex-wrap justify-between gap-3">
              <div><p className="text-sm text-[var(--text-secondary)]">{trial.status}</p><h2 className="mt-1 text-xl font-semibold">{trial.studentDisplayName}</h2></div>
              <span className="rounded-full bg-[var(--surface)] px-3 py-1 text-sm">{trial.deliveryMode === "online" ? "線上" : "實體"}</span>
            </div>
            <p className="mt-4">你的時間：{formatInTimezone(trial.startsAt, trial.teacherTimezone)}（{trial.teacherTimezone}）</p>
            <p className="mt-1 text-sm text-[var(--text-secondary)]">學生本地：{formatInTimezone(trial.startsAt, trial.studentTimezone)}（{trial.studentTimezone}）</p>
            <p className="mt-3 text-sm"><strong>學習目標：</strong>{trial.learningGoal}</p>
            {trial.hasMeeting && trial.status === "scheduled" ? <Link className="mt-4 inline-flex rounded-xl bg-[var(--brand-yellow)] px-4 py-2 text-sm font-semibold" href={`/lesson/${trial.lessonId}/join`}>進入線上教室</Link> : null}
            {trial.status === "completed" && trial.privateTeacherNotes ? <p className="mt-4 rounded-xl bg-[var(--surface)] p-4 text-sm"><strong>教師私人筆記：</strong>{trial.privateTeacherNotes}</p> : null}
            {trial.status === "scheduled" ? (
              <form action={completeTrialLesson} className="mt-6 grid gap-4 border-t border-[var(--border)] pt-6 sm:grid-cols-2">
                <input name="lessonId" type="hidden" value={trial.lessonId} />
                <label className="text-sm font-medium">Primary Stage<select className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2" name="stageNumber">{catalog.stages.map((stage) => <option key={stage.stageNumber} value={stage.stageNumber}>Stage {stage.stageNumber} · {stage.displayName}</option>)}</select></label>
                <label className="text-sm font-medium">推薦方案<select className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2" name="recommendationType"><option value="one_to_one">一對一</option><option value="recorded_course">錄播課</option><option value="hybrid">混合方案</option></select></label>
                <label className="text-sm font-medium sm:col-span-2">學生可見筆記<textarea className="mt-2 min-h-24 w-full rounded-xl border border-[var(--border)] p-3" name="studentVisibleNotes" /></label>
                <label className="text-sm font-medium sm:col-span-2">教師私人筆記<textarea className="mt-2 min-h-24 w-full rounded-xl border border-[var(--border)] p-3" name="privateTeacherNotes" /></label>
                <label className="text-sm font-medium">表現摘要<textarea className="mt-2 min-h-24 w-full rounded-xl border border-[var(--border)] p-3" name="performanceSummary" /></label>
                <label className="text-sm font-medium">下一步<textarea className="mt-2 min-h-24 w-full rounded-xl border border-[var(--border)] p-3" name="nextGoal" /></label>
                <label className="text-sm font-medium">回家練習<textarea className="mt-2 min-h-24 w-full rounded-xl border border-[var(--border)] p-3" name="homework" /></label>
                <label className="text-sm font-medium">正式評估摘要<textarea className="mt-2 min-h-24 w-full rounded-xl border border-[var(--border)] p-3" name="assessmentSummary" required /></label>
                <button className="w-fit rounded-xl bg-[var(--brand-yellow)] px-5 py-3 font-semibold sm:col-span-2" type="submit">完成體驗課</button>
              </form>
            ) : null}
          </article>
        ))}
      </section>
    </main>
  );
}
