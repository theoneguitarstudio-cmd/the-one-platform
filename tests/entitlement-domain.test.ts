import { describe, expect, it } from "vitest";

import {
  entitlementSummarySchema,
  isEntitlementUsable,
  lessonPackageSnapshotSchema,
  mapEntitlementDomainError,
} from "@/modules/entitlements/domain";

describe("entitlement domain", () => {
  it("parses a version-safe lesson package snapshot", () => {
    expect(lessonPackageSnapshotSchema.safeParse({
      activation_rule: "on_fulfillment",
      booking_mode_eligibility: "both",
      lesson_count: 4,
      lesson_duration_minutes: 50,
      validity_unit: "weeks",
      validity_value: 5,
    }).success).toBe(true);
  });

  it("rejects non-positive package quantities and validity", () => {
    expect(lessonPackageSnapshotSchema.safeParse({
      activation_rule: "on_fulfillment",
      booking_mode_eligibility: "fixed",
      lesson_count: 0,
      lesson_duration_minutes: 50,
      validity_unit: "days",
      validity_value: -1,
    }).success).toBe(false);
  });

  it("accepts a safe student DTO without internal fulfillment metadata", () => {
    const result = entitlementSummarySchema.parse({
      booking_mode_eligibility: "flexible",
      credits_available: 2,
      credits_consumed: 1,
      credits_reserved: 1,
      credits_total: 4,
      expires_at: "2027-01-01T00:00:00.000Z",
      id: "11111111-1111-4111-8111-111111111111",
      package_name: "Lesson Package 4",
      starts_at: "2026-09-01T00:00:00.000Z",
      status: "active",
    });
    expect(result.credits_available).toBe(2);
    expect(result).not.toHaveProperty("source_fulfillment_event_id");
  });

  it("derives effective expiration without trusting active alone", () => {
    const now = new Date("2026-09-01T00:00:00.000Z");
    expect(isEntitlementUsable("active", "2026-08-01T00:00:00.000Z", "2026-09-02T00:00:00.000Z", now)).toBe(true);
    expect(isEntitlementUsable("active", "2026-08-01T00:00:00.000Z", "2026-08-31T00:00:00.000Z", now)).toBe(false);
    expect(isEntitlementUsable("revoked", "2026-08-01T00:00:00.000Z", null, now)).toBe(false);
  });

  it("maps stable database domain errors to non-sensitive UI messages", () => {
    expect(mapEntitlementDomainError("INSUFFICIENT_LESSON_CREDITS")).toContain("不足");
    expect(mapEntitlementDomainError("CREDIT_ALREADY_RESERVED")).toContain("預約");
    expect(mapEntitlementDomainError("ENTITLEMENT_EXTENSION_PAYLOAD_MISMATCH")).toContain("不一致");
    expect(mapEntitlementDomainError("internal database detail")).toBe("操作未完成，請稍後再試。");
  });
});
