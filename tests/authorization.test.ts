import { describe, expect, it } from "vitest";

import { hasPermission } from "../src/modules/auth/permissions";
import { canAccessArea } from "../src/modules/auth/route-access";

describe("role permissions", () => {
  it("allows a teacher to enter the teacher area but not admin", () => {
    const identity = {
      accountStatus: "active" as const,
      roles: ["teacher"] as const,
    };

    expect(canAccessArea(identity, "teacher")).toEqual({ allowed: true });
    expect(canAccessArea(identity, "admin")).toEqual({
      allowed: false,
      reason: "missing_permission",
    });
  });

  it("allows an admin or super admin to enter the admin area", () => {
    expect(hasPermission(["admin"], "admin.dashboard.view")).toBe(true);
    expect(hasPermission(["super_admin"], "admin.dashboard.view")).toBe(true);
  });

  it("supports users with more than one role", () => {
    const identity = {
      accountStatus: "active" as const,
      roles: ["student", "teacher"] as const,
    };

    expect(canAccessArea(identity, "student")).toEqual({ allowed: true });
    expect(canAccessArea(identity, "teacher")).toEqual({ allowed: true });
  });

  it.each(["suspended", "disabled"] as const)(
    "denies protected features for a %s account",
    (accountStatus) => {
      expect(
        canAccessArea(
          {
            accountStatus,
            roles: ["super_admin"],
          },
          "admin",
        ),
      ).toEqual({ allowed: false, reason: "account_inactive" });
    },
  );
});
