import { describe, expect, it } from "vitest";

import {
  formatInTimezone,
  isValidIanaTimezone,
  zonedLocalDateTimeToUtc,
} from "../src/modules/trials/timezone";

describe("trial lesson timezone", () => {
  it("converts an IANA local time to UTC without a handwritten offset", () => {
    expect(
      zonedLocalDateTimeToUtc("2026-09-10T19:30", "Asia/Taipei"),
    ).toBe("2026-09-10T11:30:00.000Z");
    expect(
      zonedLocalDateTimeToUtc("2026-09-10T19:30", "America/Los_Angeles"),
    ).toBe("2026-09-11T02:30:00.000Z");
  });

  it("formats the same UTC lesson in each participant timezone", () => {
    const instant = "2026-09-10T11:30:00.000Z";
    expect(formatInTimezone(instant, "Asia/Taipei")).toMatch(/(?:19|7):30/);
    expect(formatInTimezone(instant, "America/Los_Angeles")).toMatch(/(?:04|4):30/);
  });

  it("rejects invalid IANA timezone input and DST gaps", () => {
    expect(isValidIanaTimezone("UTC+8")).toBe(false);
    expect(() =>
      zonedLocalDateTimeToUtc("2026-03-08T02:30", "America/Los_Angeles"),
    ).toThrow();
  });
});
