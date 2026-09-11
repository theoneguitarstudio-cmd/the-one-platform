import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { entitlementSummarySchema } from "@/modules/entitlements/domain";
import { schedulingBookingSchema } from "@/modules/scheduling/domain";
import {
  getLearningAccessStatus, getLocalIdentity, getLocalProfile, getWorkspaceOptions,
  listLocalBookings, listLocalLessonPackages, listLocalProducts, LOCAL_IDS, LOCAL_PRODUCTS,
  LOCAL_REFERENCE_MAP, requestExistingOperation, validateBookingCancellation,
  validateBookingReschedule, validateCheckout, validateProfileUpdate, validateWorkspaceSwitch,
  type GatewayResult,
} from "./gateway";

const student = () => getLocalIdentity("student");
const requestId = "98100000-0000-4000-8000-000000000001";
function data<T>(result: GatewayResult<T>): T {
  if (!result.ok) throw new Error(result.message);
  return result.data;
}

describe("existing-contract local gateway", () => {
  it("keeps preview identities distinct without creating backend roles", () => {
    expect(student().userId).toBe(LOCAL_REFERENCE_MAP.s1);
    expect(getLocalIdentity("student-2").userId).toBe(LOCAL_REFERENCE_MAP.s2);
    expect(getLocalIdentity("student-3").userId).toBe(LOCAL_REFERENCE_MAP.s3);
    expect(getWorkspaceOptions(student())).toEqual(["student"]);
    expect(getWorkspaceOptions(getLocalIdentity("teacher"))).toEqual(["teacher"]);
    expect(getWorkspaceOptions(getLocalIdentity("admin"))).toEqual(["admin"]);
    expect(getWorkspaceOptions(getLocalIdentity("multi"))).toEqual(["student", "teacher", "admin"]);
    expect(validateWorkspaceSwitch(student(), "admin")).toMatchObject({ ok: false, code: "forbidden" });
    expect(getWorkspaceOptions({ ...student(), roles: ["admin"] })).toEqual([]);
    expect(getWorkspaceOptions({ ...student(), accountStatus: "suspended" })).toEqual([]);
  });

  it("does not mutate role grants when a workspace is selected", () => {
    const actor = getLocalIdentity("multi");
    const before = structuredClone(actor);
    const selected = validateWorkspaceSwitch(actor, "teacher");
    expect(selected).toMatchObject({ ok: true, data: { area: "teacher" }, receipt: { simulated: true, transactionExecuted: false } });
    expect(actor).toEqual(before);
    actor.roles.length = 0;
    expect(getLocalIdentity("multi").roles).toHaveLength(3);
  });

  it("validates self profile using the existing allowlist without saving or echoing authority fields", () => {
    const before = getLocalProfile(student());
    const result = validateProfileUpdate(student(), {
      displayName: "  測試學生  ", phone: "", timezone: "Asia/Tokyo", locale: "zh-TW", avatarUrl: "",
      roles: ["super_admin"], accountStatus: "active", userId: LOCAL_IDS.admin,
    });
    expect(data(result).displayName).toBe("測試學生");
    expect(data(result)).not.toHaveProperty("roles");
    expect(data(result)).not.toHaveProperty("userId");
    expect(result).toMatchObject({ ok: true, mode: "HYBRID", receipt: { persisted: false, transactionExecuted: false } });
    expect(getLocalProfile(student())).toEqual(before);
    expect(validateProfileUpdate(student(), { displayName: "a" })).toMatchObject({ ok: false, code: "invalid_input" });
    expect(data(getLocalProfile(getLocalIdentity("teacher"))).userId).toBe(LOCAL_IDS.teacher);
    expect(data(getLocalProfile(getLocalIdentity("student-2"))).userId).not.toBe(LOCAL_IDS.student);
  });

  it("accepts the three checkout input contracts while never creating orders or pricing authority", () => {
    expect(data(listLocalProducts()).map(item => item.productType)).toEqual(["subscription", "recorded_course", "lesson_package"]);
    for (const product of LOCAL_PRODUCTS) {
      const result = validateCheckout(student(), {
        productSlug: product.slug, quantity: "1", idempotencyKey: requestId,
        totalAmount: 1, currency: "USD", buyerId: LOCAL_IDS.admin,
      });
      const validated = data(result);
      expect(validated.request).toEqual({ productSlug: product.slug, quantity: 1, idempotencyKey: requestId });
      expect(validated.product.priceTwd).toBeNull();
      expect(result).toMatchObject({ receipt: { simulated: true, persisted: false, transactionExecuted: false } });
      expect(validated).not.toHaveProperty("orderId");
      expect(validated).not.toHaveProperty("paymentId");
    }
    expect(data(listLocalProducts())[0].policyStatus).toBe("proposed");
    expect(validateCheckout(student(), { productSlug: "../private", quantity: 0, idempotencyKey: requestId })).toMatchObject({ ok: false, code: "invalid_input" });
    expect(validateCheckout(student(), { productSlug: "unknown-product", quantity: 1, idempotencyKey: requestId })).toMatchObject({ ok: false, code: "not_found" });
    expect(validateCheckout(getLocalIdentity("teacher"), { productSlug: LOCAL_PRODUCTS[0].slug, quantity: 1, idempotencyKey: requestId })).toMatchObject({ ok: false, code: "forbidden" });
  });

  it("returns contract-compatible participant DTOs without private ledger or another student's booking", () => {
    const packages = data(listLocalLessonPackages(student()));
    expect(entitlementSummarySchema.safeParse(packages[0]).success).toBe(true);
    const bookings = data(listLocalBookings(student()));
    expect(bookings).toHaveLength(1);
    expect(schedulingBookingSchema.safeParse(bookings[0]).success).toBe(true);
    expect(bookings[0].id).toBe(LOCAL_IDS.booking);
    expect(bookings[0]).not.toHaveProperty("studentId");
    expect(bookings[0]).not.toHaveProperty("credit_reservation_id");
    expect(packages[0]).not.toHaveProperty("ledger");
    expect(data(listLocalBookings(getLocalIdentity("teacher")))).toHaveLength(1);
    expect(data(listLocalBookings(getLocalIdentity("admin")))).toHaveLength(2);
    expect(data(listLocalBookings(getLocalIdentity("student-3")))).toEqual([]);
    bookings[0].status = "cancelled";
    packages[0].credits_available = 0;
    expect(data(listLocalBookings(student()))[0].status).toBe("confirmed");
    expect(data(listLocalLessonPackages(student()))[0].credits_available).toBe(2);
  });

  it("validates cancellation and rescheduling without changing credits, status, or time", () => {
    const before = { bookings: listLocalBookings(student()), packages: listLocalLessonPackages(student()) };
    const cancel = { bookingId: LOCAL_IDS.booking, creditOutcome: "released", reason: "學生修改學習時間" };
    expect(validateBookingCancellation(student(), cancel)).toMatchObject({ ok: true, receipt: { transactionExecuted: false } });
    expect(validateBookingCancellation(student(), { ...cancel, reason: "" })).toMatchObject({ ok: false, code: "invalid_input" });
    expect(validateBookingCancellation(student(), { ...cancel, bookingId: LOCAL_IDS.otherBooking })).toMatchObject({ ok: false, code: "forbidden" });
    const reschedule = { bookingId: LOCAL_IDS.booking, newStartsAt: "2026-09-15T12:00:00Z", timezone: "Asia/Taipei", reason: "提出另一個上課時間" };
    expect(validateBookingReschedule(student(), reschedule)).toMatchObject({ ok: true, receipt: { transactionExecuted: false } });
    expect(validateBookingReschedule(student(), { ...reschedule, newStartsAt: "tomorrow" })).toMatchObject({ ok: false, code: "invalid_input" });
    expect(validateBookingReschedule(getLocalIdentity("student-2"), reschedule)).toMatchObject({ ok: false, code: "forbidden" });
    expect({ bookings: listLocalBookings(student()), packages: listLocalLessonPackages(student()) }).toEqual(before);
  });

  it("always rejects actual execution and retains Epic 7 fail-closed authority", () => {
    for (const operation of ["profile-update", "create_checkout_order", "cancel_lesson_booking", "reschedule_lesson_booking", "learning_set_activity", "learning_get_own_activity"] as const) {
      expect(requestExistingOperation(operation)).toMatchObject({ ok: false, mode: "HYBRID", code: "unavailable" });
    }
    expect(getLearningAccessStatus()).toMatchObject({ ok: false, code: "unavailable" });
  });

  it("has no runtime DAL, action, database, network or storage dependency", () => {
    const source = readFileSync(new URL("./gateway.ts", import.meta.url), "utf8");
    const imports = [...source.matchAll(/from\s+["']([^"']+)["']/g)].map(match => match[1]);
    expect(imports).not.toEqual(expect.arrayContaining([expect.stringMatching(/supabase|\/data$|actions|session|server-authorization|ux-prototype/)]));
    expect(source).not.toMatch(/\bfetch\s*\(|\blocalStorage\b|\bsessionStorage\b|\bprocess\.env\b/);
  });
});
