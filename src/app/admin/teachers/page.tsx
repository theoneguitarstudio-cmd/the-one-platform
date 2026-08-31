import Link from "next/link";

import {
  saveAdminTeacherCapability,
  saveAdminTeacherProfile,
  saveAdminTeacherSpecialties,
} from "@/modules/teachers/admin-actions";
import { listAdminTeachers } from "@/modules/teachers/admin-data";
import { getTeacherCatalog } from "@/modules/teachers/catalog";

type AdminTeachersPageProps = {
  searchParams: Promise<{ error?: string; status?: string }>;
};

export default async function AdminTeachersPage({
  searchParams,
}: AdminTeachersPageProps) {
  const [teachers, catalog, params] = await Promise.all([
    listAdminTeachers(),
    getTeacherCatalog(),
    searchParams,
  ]);
  const message =
    params.status === "saved"
      ? "老師資料已儲存。"
      : params.error
        ? "無法儲存，請檢查輸入資料後再試。"
        : null;

  return (
    <main className="mx-auto w-full max-w-5xl px-6 py-12">
      <Link className="text-sm font-semibold" href="/admin">
        ← 返回管理區
      </Link>
      <h1 className="mt-5 text-3xl font-semibold">老師管理</h1>
      <p className="mt-3 text-sm text-[var(--text-secondary)]">
        此頁只提供 Epic 2 必要的啟用、公開狀態、Slug、專長與學習階段能力設定。
      </p>
      {message ? (
        <p className="mt-5 rounded-xl bg-[var(--surface)] px-4 py-3 text-sm">
          {message}
        </p>
      ) : null}

      <section className="mt-9 rounded-2xl border border-[var(--border)] p-5">
        <h2 className="text-xl font-semibold">建立或啟用老師 Profile</h2>
        <form action={saveAdminTeacherProfile} className="mt-5 grid gap-4 sm:grid-cols-2">
          <label className="text-sm font-medium sm:col-span-2">
            Auth User ID
            <input
              className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2"
              name="userId"
              placeholder="UUID"
              required
            />
          </label>
          <label className="text-sm font-medium">
            Public slug
            <input
              className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2"
              name="publicSlug"
              placeholder="teacher-slug"
              required
            />
          </label>
          <label className="text-sm font-medium">
            Teaching status
            <select
              className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2"
              defaultValue="draft"
              name="teachingStatus"
            >
              <option value="draft">Draft</option>
              <option value="active">Active</option>
              <option value="paused">Paused</option>
              <option value="inactive">Inactive</option>
            </select>
          </label>
          <label className="text-sm font-medium sm:col-span-2">
            <input name="isPublic" type="checkbox" /> 公開顯示（僅 active 狀態會出現在公開頁）
          </label>
          <button
            className="w-fit rounded-xl bg-[var(--brand-yellow)] px-5 py-3 font-semibold"
            type="submit"
          >
            儲存老師 Profile
          </button>
        </form>
      </section>

      <section className="mt-9 space-y-5">
        <h2 className="text-xl font-semibold">現有老師</h2>
        {teachers.length === 0 ? (
          <p className="rounded-2xl bg-[var(--surface)] p-5 text-sm text-[var(--text-secondary)]">
            尚無老師 Profile。
          </p>
        ) : (
          teachers.map((teacher) => (
            <article
              className="rounded-2xl border border-[var(--border)] p-5"
              key={teacher.id}
            >
              <p className="text-sm text-[var(--text-secondary)]">
                Teacher Profile ID：{teacher.id}
              </p>
              <form action={saveAdminTeacherProfile} className="mt-4 grid gap-4 sm:grid-cols-2">
                <input name="userId" type="hidden" value={teacher.userId} />
                <label className="text-sm font-medium">
                  Public slug
                  <input
                    className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2"
                    defaultValue={teacher.publicSlug}
                    name="publicSlug"
                    required
                  />
                </label>
                <label className="text-sm font-medium">
                  Teaching status
                  <select
                    className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2"
                    defaultValue={teacher.teachingStatus}
                    name="teachingStatus"
                  >
                    <option value="draft">Draft</option>
                    <option value="active">Active</option>
                    <option value="paused">Paused</option>
                    <option value="inactive">Inactive</option>
                  </select>
                </label>
                <label className="text-sm font-medium sm:col-span-2">
                  <input
                    defaultChecked={teacher.isPublic}
                    name="isPublic"
                    type="checkbox"
                  />{" "}
                  公開顯示
                </label>
                <button
                  className="w-fit rounded-xl border border-[var(--border)] px-4 py-2 text-sm font-semibold"
                  type="submit"
                >
                  更新公開設定
                </button>
              </form>

              <div className="mt-6 grid gap-6 border-t border-[var(--border)] pt-6 md:grid-cols-2">
                <form action={saveAdminTeacherCapability}>
                  <input name="teacherProfileId" type="hidden" value={teacher.id} />
                  <h3 className="text-sm font-semibold">設定學習階段能力</h3>
                  <div className="mt-3 flex flex-wrap gap-3">
                    <select
                      className="rounded-xl border border-[var(--border)] px-3 py-2 text-sm"
                      name="stageNumber"
                    >
                      {catalog.stages.map((stage) => (
                        <option key={stage.stageNumber} value={stage.stageNumber}>
                          Stage {stage.stageNumber}
                        </option>
                      ))}
                    </select>
                    <select
                      className="rounded-xl border border-[var(--border)] px-3 py-2 text-sm"
                      name="capabilityStatus"
                    >
                      <option value="allowed">Allowed</option>
                      <option value="certified">Certified</option>
                    </select>
                    <button
                      className="rounded-xl bg-[var(--brand-yellow)] px-3 py-2 text-sm font-semibold"
                      type="submit"
                    >
                      儲存
                    </button>
                  </div>
                </form>

                <form action={saveAdminTeacherSpecialties}>
                  <input name="teacherProfileId" type="hidden" value={teacher.id} />
                  <h3 className="text-sm font-semibold">管理教學專長</h3>
                  <select
                    aria-label="教學專長"
                    className="mt-3 min-h-32 w-full rounded-xl border border-[var(--border)] p-2 text-sm"
                    defaultValue={teacher.specialtyIds}
                    multiple
                    name="specialtyIds"
                  >
                    {catalog.specialties.map((specialty) => (
                      <option key={specialty.id} value={specialty.id}>
                        {specialty.displayName}
                      </option>
                    ))}
                  </select>
                  <button
                    className="mt-3 rounded-xl border border-[var(--border)] px-3 py-2 text-sm font-semibold"
                    type="submit"
                  >
                    儲存專長
                  </button>
                </form>
              </div>
            </article>
          ))
        )}
      </section>
    </main>
  );
}
