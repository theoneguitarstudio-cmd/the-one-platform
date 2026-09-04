import { describe, expect, it } from "vitest";

import {
  availabilityExceptionSchema,
  availabilityRuleSchema,
  flexibleBookingSchema,
  mapSchedulingDomainError,
  makeupBookingSchema,
  recurringSeriesSchema,
  schedulingBookingSchema,
  seriesExceptionSchema,
} from "@/modules/scheduling/domain";
import {
  resolveSchedulingLocalDateTime,
  weeklyOccurrenceDates,
} from "@/modules/scheduling/timezone";

describe("scheduling domain", () => {
  it("parses a minimal safe Booking DTO", () => {
    const booking = schedulingBookingSchema.parse({
      credit_outcome: null,
      ends_at: "2026-09-10T12:50:00.000Z",
      id: "11111111-1111-4111-8111-111111111111",
      lesson_id: "22222222-2222-4222-8222-222222222222",
      recurring_series_id: null,
      source: "flexible",
      starts_at: "2026-09-10T12:00:00.000Z",
      status: "confirmed",
      timezone_anchor: "Asia/Taipei",
    });
    expect(booking).not.toHaveProperty("credit_reservation_id");
    expect(booking).not.toHaveProperty("cancellation_reason");
  });

  it("requires explicit Entitlement and relationship IDs for Flexible Booking", () => {
    expect(flexibleBookingSchema.safeParse({
      entitlementId: "11111111-1111-4111-8111-111111111111",
      idempotencyKey: "22222222-2222-4222-8222-222222222222",
      relationshipId: "33333333-3333-4333-8333-333333333333",
      startsAt: "2026-09-10T12:00:00.000Z",
      studentUserId: "44444444-4444-4444-8444-444444444444",
      teacherUserId: "55555555-5555-4555-8555-555555555555",
      timezone: "Asia/Taipei",
    }).success).toBe(true);
    expect(flexibleBookingSchema.safeParse({}).success).toBe(false);
  });

  it("requires an explicit Makeup Right for Makeup Booking", () => {
    expect(makeupBookingSchema.safeParse({
      idempotencyKey: "11111111-1111-4111-8111-111111111111",
      makeupRightId: "22222222-2222-4222-8222-222222222222",
      relationshipId: "33333333-3333-4333-8333-333333333333",
      startsAt: "2026-09-10T12:00:00.000Z",
      studentUserId: "44444444-4444-4444-8444-444444444444",
      teacherUserId: "55555555-5555-4555-8555-555555555555",
      timezone: "Asia/Taipei",
    }).success).toBe(true);
    expect(makeupBookingSchema.safeParse({
      relationshipId: "33333333-3333-4333-8333-333333333333",
    }).success).toBe(false);
  });

  it("validates local weekly availability without hard-coding 50 minutes", () => {
    expect(availabilityRuleSchema.safeParse({
      effectiveFrom: "2026-09-01",
      effectiveUntil: "",
      localEndTime: "23:00",
      localStartTime: "20:00",
      reason: "Regular availability",
      teacherUserId: "11111111-1111-4111-8111-111111111111",
      timezone: "America/Los_Angeles",
      weekday: 1,
    }).success).toBe(true);
    expect(recurringSeriesSchema.safeParse({
      durationMinutes: 75,
      effectiveFrom: "2026-09-01",
      effectiveUntil: "",
      localStartTime: "20:00",
      preferredEntitlementId: "",
      reason: "Fixed arrangement",
      relationshipId: "22222222-2222-4222-8222-222222222222",
      studentUserId: "33333333-3333-4333-8333-333333333333",
      teacherUserId: "44444444-4444-4444-8444-444444444444",
      timezone: "America/Los_Angeles",
      weekday: 1,
    }).success).toBe(true);
  });

  it("validates availability and recurring occurrence exceptions", () => {
    expect(availabilityExceptionSchema.safeParse({
      endsAt: "2026-09-10T13:00:00.000Z",
      exceptionKind: "unavailable",
      reason: "Teacher leave",
      startsAt: "2026-09-10T12:00:00.000Z",
      teacherUserId: "11111111-1111-4111-8111-111111111111",
    }).success).toBe(true);
    expect(seriesExceptionSchema.safeParse({
      exceptionKind: "release",
      occurrenceDate: "2026-09-10",
      reason: "Student leave",
      releaseThisOccurrence: true,
      replacementEndsAt: "",
      replacementStartsAt: "",
      seriesId: "22222222-2222-4222-8222-222222222222",
    }).success).toBe(true);
  });

  it("preserves recurring local wall time across DST offsets", () => {
    expect(resolveSchedulingLocalDateTime("2026-01-12T20:00", "America/Los_Angeles"))
      .toBe("2026-01-13T04:00:00.000Z");
    expect(resolveSchedulingLocalDateTime("2026-07-13T20:00", "America/Los_Angeles"))
      .toBe("2026-07-14T03:00:00.000Z");
  });

  it("rejects DST spring-forward nonexistent local time", () => {
    expect(() => resolveSchedulingLocalDateTime("2026-03-08T02:30", "America/Los_Angeles"))
      .toThrow("NONEXISTENT_LOCAL_TIME");
  });

  it("rejects DST fall-back ambiguous local time", () => {
    expect(() => resolveSchedulingLocalDateTime("2026-11-01T01:30", "America/Los_Angeles"))
      .toThrow("AMBIGUOUS_LOCAL_TIME");
  });

  it("expands only a bounded weekly date window", () => {
    expect(weeklyOccurrenceDates("2026-09-01", 3, "2026-09-30"))
      .toEqual(["2026-09-02", "2026-09-09", "2026-09-16", "2026-09-23", "2026-09-30"]);
    expect(weeklyOccurrenceDates("2026-01-01", 1, "2030-01-01", 3)).toHaveLength(3);
  });

  it("maps stable domain errors without exposing SQL details", () => {
    expect(mapSchedulingDomainError("SLOT_NOT_AVAILABLE")).toContain("不可預約");
    expect(mapSchedulingDomainError("RECURRING_SERIES_CONFLICT")).toContain("衝突");
    expect(mapSchedulingDomainError("23505 duplicate key")).toBe("排程操作未完成，請重新整理後再試。");
  });
});
