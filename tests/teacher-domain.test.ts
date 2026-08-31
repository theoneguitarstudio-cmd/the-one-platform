import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

import {
  adminTeacherProfileSchema,
  editableTeacherProfileSchema,
} from "../src/modules/teachers/domain";

describe("teacher profile validation", () => {
  const editableProfile = {
    avatarUrl: "",
    bio: "安全的公開介紹",
    fixedLessonPriceTwd: "1800",
    flexibleLessonPriceTwd: "",
    locationText: "高雄苓雅",
    teachingModes: ["onsite", "online"],
    trialPriceTwd: "1000",
    yearsExperience: "8",
  };

  it("uses integer TWD amounts and accepts a blank optional price", () => {
    const result = editableTeacherProfileSchema.parse(editableProfile);

    expect(result.trialPriceTwd).toBe(1000);
    expect(result.fixedLessonPriceTwd).toBe(1800);
    expect(result.flexibleLessonPriceTwd).toBeNull();
  });

  it("rejects negative and fractional prices", () => {
    expect(
      editableTeacherProfileSchema.safeParse({
        ...editableProfile,
        trialPriceTwd: "-1",
      }).success,
    ).toBe(false);
    expect(
      editableTeacherProfileSchema.safeParse({
        ...editableProfile,
        trialPriceTwd: "1000.5",
      }).success,
    ).toBe(false);
  });

  it("requires a URL-safe lower-case public slug for admin settings", () => {
    expect(
      adminTeacherProfileSchema.safeParse({
        isPublic: true,
        publicSlug: "Jack Guitar",
        teachingStatus: "active",
        userId: "00000000-0000-0000-0000-000000000001",
      }).success,
    ).toBe(false);
  });
});

describe("public discovery boundary", () => {
  const source = readFileSync(
    new URL("../src/modules/teachers/public-discovery.ts", import.meta.url),
    "utf8",
  );

  it("reads from the public projection, not private teacher records", () => {
    expect(source).toContain('.from("teacher_public_profiles")');
    expect(source).not.toContain('.from("teacher_profiles")');
    expect(source).not.toContain('.from("profiles")');
  });
});

describe("teacher self-update boundary", () => {
  const actionSource = readFileSync(
    new URL("../src/modules/teachers/actions.ts", import.meta.url),
    "utf8",
  );

  it("uses the atomic database mutation instead of table-by-table writes", () => {
    expect(actionSource).toContain('.rpc("update_own_teacher_profile"');
    expect(actionSource).not.toContain('.from("teacher_specialties")');
    expect(actionSource).not.toContain('.from("teacher_profiles")');
  });
});
