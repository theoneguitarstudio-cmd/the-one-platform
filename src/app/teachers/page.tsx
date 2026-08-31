import type { Metadata } from "next";

import { TeacherCard } from "@/components/teachers/teacher-card";
import { listPublicTeachers } from "@/modules/teachers/public-discovery";

export const metadata: Metadata = {
  alternates: { canonical: "/teachers" },
  description: "瀏覽 The One 樂玩吉他的公開師資與教學專長。",
  title: "老師列表",
};

export default async function TeachersPage() {
  const teachers = await listPublicTeachers();

  return (
    <main className="mx-auto w-full max-w-6xl px-5 py-12 sm:px-8 sm:py-16">
      <header className="max-w-2xl">
        <p className="inline-flex rounded-full bg-[var(--brand-yellow)] px-3 py-1 text-sm font-semibold">
          The One Teachers
        </p>
        <h1 className="mt-5 text-4xl font-semibold tracking-tight sm:text-5xl">
          找到適合你的吉他老師
        </h1>
        <p className="mt-4 leading-7 text-[var(--text-secondary)]">
          從教學方式、專長與學習階段，認識 The One 的公開師資。
        </p>
      </header>

      {teachers.length === 0 ? (
        <p className="mt-12 rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-6 text-[var(--text-secondary)]">
          目前尚無公開老師資料，敬請期待。
        </p>
      ) : (
        <section
          aria-label="公開老師列表"
          className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3"
        >
          {teachers.map((teacher) => (
            <TeacherCard key={teacher.publicSlug} teacher={teacher} />
          ))}
        </section>
      )}
    </main>
  );
}
