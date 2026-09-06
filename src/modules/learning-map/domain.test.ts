import { describe, expect, it } from "vitest";
import { activityCommandSchema, activityPatchSchema, ownActivitySchema } from "./domain";

const uuid = "97000000-0000-4000-8000-000000000001";
const command = { versionId: uuid, nodeId: uuid, expectedRevision: 0, requestId: uuid, patch: { self_completed: true } };
describe("personal activity contract", () => {
  it("accepts explicit completion without a viewing requirement", () => {
    expect(activityCommandSchema.parse(command).patch).toEqual({ self_completed: true });
  });
  it.each(["subjectId", "actorId", "courseId", "verified", "assessment_passed", "stage_completed", "certificate", "eligible"])("rejects caller-supplied %s", (key) => {
    expect(activityCommandSchema.safeParse({ ...command, [key]: uuid }).success).toBe(false);
    expect(activityCommandSchema.safeParse({ ...command, patch: { ...command.patch, [key]: true } }).success).toBe(false);
  });
  it.each([{}, { opened: false }, { self_completed: "true" }, { needs_revisit: null }, { self_completed: undefined }, { resume_resource_id: "other" }])("rejects invalid or empty patches %j", (patch) => {
    expect(activityPatchSchema.safeParse(patch).success).toBe(false);
  });
  it.each([-1, 1.2, Infinity, NaN, 2147483647])("rejects unsafe revision %s", (expectedRevision) => {
    expect(activityCommandSchema.safeParse({ ...command, expectedRevision }).success).toBe(false);
  });
  it("allows correction and clearing a resume reference", () => {
    expect(activityPatchSchema.parse({ self_completed: false, needs_revisit: true, resume_resource_id: null })).toBeTruthy();
  });
  it("rejects formal outcomes in returned personal data", () => {
    expect(ownActivitySchema.safeParse({ revision: 1, opened_at: null, last_opened_at: null, resume_resource_id: null, needs_revisit: false, self_completed: true, self_completed_at: "2026-09-06", verified: true }).success).toBe(false);
  });
});
