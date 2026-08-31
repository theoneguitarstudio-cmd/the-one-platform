import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";

import { requireAreaAccess } from "@/modules/auth/server-authorization";
import { getAuthenticatedIdentity } from "@/modules/auth/session";
import { requestTrialCheckout } from "@/modules/trials/actions";
import {
  checkoutIntentKeySchema,
  teacherSlugSchema,
} from "@/modules/trials/domain";
import {
  getOwnProfileTimezone,
  getTrialTeacherContext,
} from "@/modules/trials/data";

type TrialPageProps = {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ error?: string; intent?: string }>;
};

export default async function TrialPage({ params, searchParams }: TrialPageProps) {
  const { slug } = await params;
  if (!teacherSlugSchema.safeParse(slug).success) notFound();
  const session = await getAuthenticatedIdentity();
  if (!session) {
    redirect(`/auth/sign-in?next=${encodeURIComponent(`/teachers/${slug}/trial`)}`);
  }
  const identity = await requireAreaAccess("student");
  const query = await searchParams;
  const intent = checkoutIntentKeySchema.safeParse(query.intent);
  if (!intent.success) {
    const nextQuery = new URLSearchParams({ intent: randomUUID() });
    if (query.error) nextQuery.set("error", query.error);
    redirect(`/teachers/${slug}/trial?${nextQuery.toString()}`);
  }
  const [teacher, studentTimezone] = await Promise.all([
    getTrialTeacherContext(slug),
    getOwnProfileTimezone(identity.userId),
  ]);
  if (!teacher) notFound();

  return (
    <main className="mx-auto w-full max-w-3xl px-5 py-10 sm:px-8 sm:py-14">
      <Link className="text-sm font-semibold" href={`/teachers/${teacher.publicSlug}`}>
        ← 返回老師頁
      </Link>
      <section className="mt-5 overflow-hidden rounded-3xl border border-[var(--border)] bg-white">
        <div className="bg-[var(--surface)] px-6 py-7 sm:px-9">
          <p className="text-sm font-semibold">50 分鐘一對一體驗課</p>
          <h1 className="mt-2 text-3xl font-semibold">和 {teacher.displayName} 開始學吉他</h1>
          <p className="mt-3 text-[var(--text-secondary)]">
            NT${teacher.trialPriceTwd.toLocaleString("zh-TW")} · 送出後為待確認，尚未視為付款。
          </p>
        </div>
        <form action={requestTrialCheckout} className="space-y-6 px-6 py-8 sm:px-9">
          <input name="teacherSlug" type="hidden" value={teacher.publicSlug} />
          <input name="timezone" type="hidden" value={studentTimezone} />
          <input name="idempotencyKey" type="hidden" value={intent.data} />
          {query.error ? (
            <p className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-800">
              無法送出體驗課申請，請檢查資料或改選其他時間。
            </p>
          ) : null}
          <label className="block text-sm font-medium">
            你的學習目標
            <textarea className="mt-2 min-h-28 w-full rounded-xl border border-[var(--border)] p-3" name="learningGoal" required />
          </label>
          <div className="grid gap-5 sm:grid-cols-2">
            <label className="text-sm font-medium">
              上課模式
              <select className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2" name="preferredMode" required>
                {teacher.teachingModes.map((mode) => (
                  <option key={mode} value={mode}>{mode === "online" ? "線上" : "實體"}</option>
                ))}
              </select>
            </label>
            <label className="text-sm font-medium">
              希望日期與時間
              <input className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2" name="localStartsAt" required type="datetime-local" />
            </label>
          </div>
          <label className="block text-sm font-medium">
            實體上課偏好地點（線上可留空）
            <input className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2" maxLength={160} name="preferredLocation" />
          </label>
          <div className="rounded-2xl bg-[var(--surface)] p-4 text-sm text-[var(--text-secondary)]">
            <p>你的時區：{studentTimezone}</p>
            <p className="mt-1">老師時區：{teacher.teacherTimezone}</p>
            <p className="mt-2">系統以 IANA timezone 轉成 UTC 儲存；Admin 確認後，雙方工作台會顯示各自本地時間。</p>
          </div>
          <button className="w-full rounded-xl bg-[var(--brand-yellow)] px-5 py-3 font-semibold" type="submit">
            確認體驗課申請
          </button>
        </form>
      </section>
    </main>
  );
}
