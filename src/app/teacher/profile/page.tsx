import Link from "next/link";

import { requireAreaAccess } from "@/modules/auth/server-authorization";
import { saveOwnTeacherProfile } from "@/modules/teachers/actions";
import { getTeacherCatalog } from "@/modules/teachers/catalog";
import { getOwnEditableTeacherProfile } from "@/modules/teachers/private-data";

type TeacherProfilePageProps = {
  searchParams: Promise<{ error?: string; status?: string }>;
};

export default async function TeacherProfilePage({
  searchParams,
}: TeacherProfilePageProps) {
  const [identity, catalog, params] = await Promise.all([
    requireAreaAccess("teacher"),
    getTeacherCatalog(),
    searchParams,
  ]);
  const profile = await getOwnEditableTeacherProfile(identity.userId);

  if (!profile) {
    return (
      <main className="mx-auto w-full max-w-3xl px-6 py-12">
        <h1 className="text-3xl font-semibold">老師公開資料</h1>
        <p className="mt-4 text-[var(--text-secondary)]">
          尚未建立老師 Profile，請聯絡平台管理員啟用。
        </p>
      </main>
    );
  }

  const selectedSpecialties = new Set(profile.specialties.map(({ id }) => id));
  const selectedModes = new Set(profile.teachingModes);
  const message =
    params.status === "saved"
      ? "公開資料已儲存。"
      : params.error
        ? "無法儲存，請檢查輸入資料後再試。"
        : null;

  return (
    <main className="mx-auto w-full max-w-3xl px-6 py-12">
      <Link className="text-sm font-semibold" href="/teacher">
        ← 返回老師區
      </Link>
      <h1 className="mt-5 text-3xl font-semibold">編輯公開老師資料</h1>
      <p className="mt-3 text-sm text-[var(--text-secondary)]">
        公開狀態、公開網址與學習階段能力由平台管理員設定。
      </p>
      {message ? (
        <p className="mt-5 rounded-xl bg-[var(--surface)] px-4 py-3 text-sm">
          {message}
        </p>
      ) : null}

      <form action={saveOwnTeacherProfile} className="mt-8 space-y-7">
        <label className="block text-sm font-medium">
          個人介紹
          <textarea
            className="mt-2 min-h-36 w-full rounded-xl border border-[var(--border)] p-3"
            defaultValue={profile.bio}
            maxLength={4000}
            name="bio"
          />
        </label>
        <label className="block text-sm font-medium">
          公開頭像網址
          <input
            className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2"
            defaultValue={profile.avatarUrl ?? ""}
            name="avatarUrl"
            type="url"
          />
        </label>
        <label className="block text-sm font-medium">
          教學年資
          <input
            className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2"
            defaultValue={profile.yearsExperience}
            max={80}
            min={0}
            name="yearsExperience"
            type="number"
          />
        </label>
        <fieldset>
          <legend className="text-sm font-medium">教學方式</legend>
          <div className="mt-3 flex gap-5">
            <label>
              <input
                defaultChecked={selectedModes.has("onsite")}
                name="teachingModes"
                type="checkbox"
                value="onsite"
              />{" "}
              實體
            </label>
            <label>
              <input
                defaultChecked={selectedModes.has("online")}
                name="teachingModes"
                type="checkbox"
                value="online"
              />{" "}
              線上
            </label>
          </div>
        </fieldset>
        <label className="block text-sm font-medium">
          公開地區
          <input
            className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2"
            defaultValue={profile.locationText ?? ""}
            maxLength={160}
            name="locationText"
          />
        </label>
        <div className="grid gap-4 sm:grid-cols-3">
          <PriceInput
            defaultValue={profile.trialPriceTwd}
            label="體驗課價格（TWD）"
            name="trialPriceTwd"
          />
          <PriceInput
            defaultValue={profile.fixedLessonPriceTwd}
            label="固定制價格（TWD）"
            name="fixedLessonPriceTwd"
          />
          <PriceInput
            defaultValue={profile.flexibleLessonPriceTwd}
            label="預約制價格（TWD）"
            name="flexibleLessonPriceTwd"
          />
        </div>
        <fieldset>
          <legend className="text-sm font-medium">教學專長</legend>
          <div className="mt-3 grid gap-3 sm:grid-cols-2">
            {catalog.specialties.map((specialty) => (
              <label key={specialty.id}>
                <input
                  defaultChecked={selectedSpecialties.has(specialty.id)}
                  name="specialtyIds"
                  type="checkbox"
                  value={specialty.id}
                />{" "}
                {specialty.displayName}
              </label>
            ))}
          </div>
        </fieldset>
        <button
          className="rounded-xl bg-[var(--brand-yellow)] px-5 py-3 font-semibold"
          type="submit"
        >
          儲存公開資料
        </button>
      </form>
    </main>
  );
}

function PriceInput({
  defaultValue,
  label,
  name,
}: {
  defaultValue: number | null;
  label: string;
  name: string;
}) {
  return (
    <label className="block text-sm font-medium">
      {label}
      <input
        className="mt-2 w-full rounded-xl border border-[var(--border)] px-3 py-2"
        defaultValue={defaultValue ?? ""}
        min={0}
        name={name}
        step={1}
        type="number"
      />
    </label>
  );
}
