import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { Actor } from "@/modules/ux-prototype/model";
import { canReadStudentExperience } from "@/modules/platform-experience/student-access";

const context = vi.hoisted(() => ({
  actor: { role: "student", id: "s1" } as Actor,
  studentId: "s1",
  state: { students: [{ id: "s1" }, { id: "s2" }] },
  setActor: vi.fn(),
}));
vi.mock("@/modules/ux-prototype/store", () => ({ usePrototype: () => context }));
vi.mock("@/components/ux-prototype/public", () => ({ PublicPage: () => <p>public surface</p> }));
vi.mock("@/components/ux-prototype/student", () => ({ StudentPage: () => <p>private student surface</p> }));
vi.mock("@/components/ux-prototype/lesson", () => ({ LessonPage: () => <p>private lesson surface</p> }));
vi.mock("@/components/ux-prototype/workspace", () => ({ WorkspacePage: () => <p>workspace surface</p> }));
vi.mock("@/components/platform-experience/auth-page", () => ({ LocalAuthPage: () => <p>auth surface</p>, UnavailablePage: () => <p>unavailable</p> }));
vi.mock("@/components/platform-experience/booking-change", () => ({ BookingChangePage: () => <p>private booking surface</p> }));
vi.mock("@/components/platform-experience/account-pages", () => ({ AccountPage: () => <p>private account surface</p> }));
vi.mock("@/components/platform-experience/public-pages", () => ({ PlatformPublicPage: () => <p>public catalog</p> }));
import { PrototypePage } from "@/components/ux-prototype/page";

const studentRoutes = [
  ["student"], ["student", "private"], ["student", "feedback"],
  ["student", "courses", "c1", "lessons", "l3"],
  ["student", "orders"], ["student", "orders", "order-1"],
  ["student", "packages"], ["student", "schedule"],
  ["student", "bookings", "ab1", "change"],
];

describe("student experience read boundary", () => {
  beforeEach(() => {
    context.actor = { role: "student", id: "s1" };
    context.studentId = "s1";
    context.setActor.mockClear();
  });

  it("requires an existing student matching the selected identity", () => {
    expect(canReadStudentExperience(context.actor, "s1", ["s1", "s2"])).toBe(true);
    expect(canReadStudentExperience(context.actor, "s2", ["s1", "s2"])).toBe(false);
    expect(canReadStudentExperience({ role: "student", id: "unknown" }, "unknown", ["s1", "s2"])).toBe(false);
    expect(canReadStudentExperience({ role: "teacher", id: "s1" }, "s1", ["s1"])).toBe(false);
  });

  it.each(studentRoutes)("blocks every student subtree before private pages mount: %j", (...segments) => {
    for (const actor of [
      { role: "teacher", id: "t1" },
      { role: "admin", id: "admin", capability: "finance" },
      { role: "admin", id: "admin", capability: "owner" },
      { role: "student", id: "s2" },
    ] satisfies Actor[]) {
      context.actor = actor;
      const html = renderToStaticMarkup(<PrototypePage segments={segments} />);
      expect(html).toContain("這個帳號目前無法開啟此空間");
      expect(html).toContain("切換至所選學生的 Mock 視角");
      expect(html).not.toContain("private ");
      expect(context.setActor).not.toHaveBeenCalled();
    }
  });

  it.each(studentRoutes)("keeps existing student pages available for their own identity: %j", (...segments) => {
    const html = renderToStaticMarkup(<PrototypePage segments={segments} />);
    expect(html).toContain("private ");
    expect(html).not.toContain("這個帳號目前無法開啟此空間");
  });

  it("does not invent a fallback identity when the selected student is unknown", () => {
    context.actor = { role: "student", id: "unknown" };
    context.studentId = "unknown";
    const html = renderToStaticMarkup(<PrototypePage segments={["student", "feedback"]} />);
    expect(html).toContain("這個帳號目前無法開啟此空間");
    expect(html).not.toContain("切換至所選學生的 Mock 視角");
    expect(html).not.toContain("private student surface");
  });

  it("leaves public navigation available for other roles", () => {
    context.actor = { role: "teacher", id: "t1" };
    expect(renderToStaticMarkup(<PrototypePage segments={[]} />)).toContain("public surface");
  });
});
