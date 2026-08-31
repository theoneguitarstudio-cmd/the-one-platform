import { describe, expect, it } from "vitest";

import { getSafeRedirectPath } from "../src/modules/auth/safe-redirect";

describe("auth redirect validation", () => {
  it.each(["https://evil.example", "//evil.example", "/unknown", "admin"])(
    "rejects unsafe destination %s",
    (candidate) => {
      expect(getSafeRedirectPath(candidate)).toBe("/student");
    },
  );

  it("allows only known local destinations and drops query injection", () => {
    expect(getSafeRedirectPath("/teacher")).toBe("/teacher");
    expect(getSafeRedirectPath("/admin?next=https://evil.example")).toBe(
      "/admin",
    );
  });
});
