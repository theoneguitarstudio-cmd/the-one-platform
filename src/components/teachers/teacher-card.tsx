import Link from "next/link";

import { TeacherAvatar } from "@/components/teachers/teacher-avatar";
import {
  TEACHING_MODE_LABELS,
  type PublicTeacher,
} from "@/modules/teachers/domain";

type TeacherCardProps = {
  teacher: PublicTeacher;
};

function formatTwd(value: number | null): string {
  return value === null
    ? "價格洽詢"
    : "體驗課 NT$" + value.toLocaleString("zh-TW");
}

export function TeacherCard({ teacher }: TeacherCardProps) {
  return (
    <article className="flex h-full flex-col rounded-2xl border border-[var(--border)] bg-white p-5">
      <div className="flex items-start gap-4">
        <TeacherAvatar
          alt={teacher.displayName + " 的頭像"}
          name={teacher.displayName}
          src={teacher.avatarUrl}
        />
        <div className="min-w-0">
          <h2 className="text-xl font-semibold">{teacher.displayName}</h2>
          <p className="mt-1 text-sm text-[var(--text-secondary)]">
            {teacher.yearsExperience} 年教學經驗
          </p>
          <p className="mt-2 text-sm text-[var(--text-secondary)]">
            {teacher.teachingModes.map((mode) => TEACHING_MODE_LABELS[mode]).join("・")}
            {teacher.locationText ? " · " + teacher.locationText : ""}
          </p>
        </div>
      </div>
      <p className="mt-5 line-clamp-3 text-sm leading-6 text-[var(--text-secondary)]">
        {teacher.bio || "老師正在整理個人介紹。"}
      </p>
      <div className="mt-5 flex flex-wrap gap-2">
        {teacher.specialties.map((specialty) => (
          <span
            className="rounded-full bg-[var(--surface)] px-3 py-1 text-xs"
            key={specialty.id}
          >
            {specialty.displayName}
          </span>
        ))}
      </div>
      <div className="mt-6 flex items-center justify-between gap-3">
        <span className="text-sm font-semibold">{formatTwd(teacher.trialPriceTwd)}</span>
        <Link
          aria-label={"查看 " + teacher.displayName + " 老師"}
          className="rounded-xl bg-[var(--brand-yellow)] px-4 py-2 text-sm font-semibold"
          href={"/teachers/" + teacher.publicSlug}
        >
          查看老師
        </Link>
      </div>
    </article>
  );
}
