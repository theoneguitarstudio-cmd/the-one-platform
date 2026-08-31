import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { TeacherAvatar } from "@/components/teachers/teacher-avatar";
import {
  TEACHING_MODE_LABELS,
  type PublicTeacher,
} from "@/modules/teachers/domain";
import { getPublicTeacherBySlug } from "@/modules/teachers/public-discovery";

type TeacherDetailPageProps = {
  params: Promise<{ slug: string }>;
};

function formatTwd(label: string, value: number | null): string {
  return value === null
    ? label + "：價格洽詢"
    : label + "：NT$" + value.toLocaleString("zh-TW");
}

export async function generateMetadata({
  params,
}: TeacherDetailPageProps): Promise<Metadata> {
  const { slug } = await params;
  const teacher = await getPublicTeacherBySlug(slug);

  if (!teacher) {
    return { title: "找不到老師" };
  }

  return {
    alternates: { canonical: "/teachers/" + teacher.publicSlug },
    description: teacher.bio.slice(0, 150) || teacher.displayName + " 的公開教學資料",
    title: teacher.displayName,
  };
}

export default async function TeacherDetailPage({
  params,
}: TeacherDetailPageProps) {
  const { slug } = await params;
  const teacher = await getPublicTeacherBySlug(slug);

  if (!teacher) {
    notFound();
  }

  return <TeacherDetail teacher={teacher} />;
}

function TeacherDetail({ teacher }: { teacher: PublicTeacher }) {
  return (
    <main className="mx-auto w-full max-w-4xl px-5 py-12 sm:px-8 sm:py-16">
      <article className="rounded-3xl border border-[var(--border)] bg-white p-6 sm:p-10">
        <header className="flex flex-col gap-6 sm:flex-row sm:items-start">
          <TeacherAvatar
            alt={teacher.displayName + " 的頭像"}
            name={teacher.displayName}
            size="detail"
            src={teacher.avatarUrl}
          />
          <div>
            <p className="text-sm font-semibold text-[var(--text-secondary)]">
              公開師資
            </p>
            <h1 className="mt-2 text-4xl font-semibold tracking-tight">
              {teacher.displayName}
            </h1>
            <p className="mt-3 text-[var(--text-secondary)]">
              {teacher.yearsExperience} 年教學經驗
              {teacher.locationText ? " · " + teacher.locationText : ""}
            </p>
            <div className="mt-4 flex flex-wrap gap-2">
              {teacher.teachingModes.map((mode) => (
                <span
                  className="rounded-full bg-[var(--surface)] px-3 py-1 text-sm"
                  key={mode}
                >
                  {TEACHING_MODE_LABELS[mode]}
                </span>
              ))}
            </div>
          </div>
        </header>

        <section className="mt-10">
          <h2 className="text-xl font-semibold">老師介紹</h2>
          <p className="mt-3 whitespace-pre-wrap leading-7 text-[var(--text-secondary)]">
            {teacher.bio || "老師正在整理個人介紹。"}
          </p>
        </section>

        <section className="mt-10 grid gap-8 md:grid-cols-2">
          <div>
            <h2 className="text-xl font-semibold">教學專長</h2>
            <div className="mt-4 flex flex-wrap gap-2">
              {teacher.specialties.length > 0 ? (
                teacher.specialties.map((specialty) => (
                  <span
                    className="rounded-full bg-[var(--surface)] px-3 py-1 text-sm"
                    key={specialty.id}
                  >
                    {specialty.displayName}
                  </span>
                ))
              ) : (
                <p className="text-sm text-[var(--text-secondary)]">
                  專長資料整理中。
                </p>
              )}
            </div>
          </div>
          <div>
            <h2 className="text-xl font-semibold">可教學習階段</h2>
            <ol className="mt-4 space-y-2 text-sm text-[var(--text-secondary)]">
              {teacher.stages.length > 0 ? (
                teacher.stages.map((stage) => (
                  <li key={stage.code}>
                    Stage {stage.stageNumber} · {stage.displayName}
                  </li>
                ))
              ) : (
                <li>學習階段資料整理中。</li>
              )}
            </ol>
          </div>
        </section>

        <section className="mt-10 rounded-2xl bg-[var(--surface)] p-5">
          <h2 className="text-xl font-semibold">課程價格</h2>
          <ul className="mt-3 space-y-2 text-sm text-[var(--text-secondary)]">
            <li>{formatTwd("體驗課", teacher.trialPriceTwd)}</li>
            <li>{formatTwd("固定制課程", teacher.fixedLessonPriceTwd)}</li>
            <li>{formatTwd("預約制課程", teacher.flexibleLessonPriceTwd)}</li>
          </ul>
        </section>

        <section className="mt-10 border-t border-[var(--border)] pt-8">
          <h2 className="text-xl font-semibold">學員評價</h2>
          <p className="mt-3 text-sm text-[var(--text-secondary)]">
            評論功能將在後續規格確認後開放。
          </p>
        </section>

        <Link
          className="mt-10 flex w-full justify-center rounded-xl bg-[var(--brand-yellow)] px-5 py-3 font-semibold text-[var(--text-primary)]"
          href={`/teachers/${teacher.publicSlug}/trial`}
        >
          預約 50 分鐘體驗課
        </Link>
      </article>
    </main>
  );
}
