"use client";

import { PublicPage } from "./public";
import { StudentPage } from "./student";
import { LessonPage } from "./lesson";
import { WorkspacePage } from "./workspace";
import { LocalAuthPage, UnavailablePage } from "@/components/platform-experience/auth-page";
import { BookingChangePage } from "@/components/platform-experience/booking-change";
import { AccountPage } from "@/components/platform-experience/account-pages";
import { PlatformPublicPage } from "@/components/platform-experience/public-pages";
import { StudentAccessDenied } from "@/components/platform-experience/student-access-denied";
import { canReadStudentExperience } from "@/modules/platform-experience/student-access";
import { usePrototype } from "@/modules/ux-prototype/store";

export function PrototypePage({ segments }: { segments: string[] }) {
  const { actor, studentId, state } = usePrototype();
  if (segments[0] === "student" && !canReadStudentExperience(actor, studentId, state.students.map(student => student.id))) return <StudentAccessDenied />;
  if (segments[0] === "account") return <AccountPage segments={segments.slice(1)} />;
  if (segments[0] === "notifications" || segments[0] === "search") return <AccountPage key={segments[0]} segments={[segments[0]]} />;
  if (["products", "system-courses", "membership", "checkout", "onboarding", "faq", "about", "support", "help", "legal"].includes(segments[0])) return <PlatformPublicPage segments={segments} />;
  if (segments[0] === "auth") return <LocalAuthPage key={segments[1]} route={segments[1]} />;
  if (segments[0] === "unavailable" || segments[0] === "error") return <UnavailablePage kind={segments[0]} />;
  if (segments[0] === "student") {
    if (segments[1] === "orders") return <AccountPage key={segments.join("/")} segments={["orders", ...segments.slice(2)]} />;
    if (["packages", "schedule"].includes(segments[1])) return <StudentPage segments={["private"]} />;
    if (segments[1] === "bookings" && segments[3] === "change") return <BookingChangePage key={segments[2]} bookingId={segments[2]} />;
    if (segments[1] === "courses" && segments[3] === "lessons") return <LessonPage segments={segments.slice(1)} />;
    return <StudentPage segments={segments.slice(1)} />;
  }
  if (segments[0] === "teacher" || segments[0] === "admin") return <WorkspacePage role={segments[0]} segments={segments.slice(1)} />;
  if (!segments.length || ["teachers", "courses", "articles", "policies", "diagnosis"].includes(segments[0])) return <PublicPage segments={segments} />;
  return <UnavailablePage />;
}
