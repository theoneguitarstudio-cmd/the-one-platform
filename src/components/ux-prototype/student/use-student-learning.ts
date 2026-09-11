"use client";

import { useCallback } from "react";
import { usePrototype } from "@/modules/ux-prototype/store";
import { availableSlots, balance, guidanceEligibility, studentBookings, visibleFeedback } from "@/modules/ux-prototype/model";

/** Adapter for the approved student surfaces, backed by the same three-role store. */
export function useStudentLearning(packageId?: string) {
  const context = usePrototype();
  const { state, studentId, dispatch } = context;
  const student = state.students.find(item => item.id === studentId) || state.students[0];
  const progress = student.progress.find(item => item.courseId === "c1");
  const packages = state.packages.filter(item => item.studentId === student.id && item.status === "active");
  const pack = packages.find(item => item.id === packageId) || packages[0];
  const bookings = studentBookings(state, student.id);
  const nextBooking = bookings.filter(item => item.status === "reserved" && item.start >= state.clock && item.packageId === pack?.id).sort((a, b) => a.start.localeCompare(b.start))[0];
  const teacher = state.teachers.find(item => item.id === (pack?.teacherId || student.teacherId));
  const actor = { role: "student" as const, id: student.id };
  const visitLesson = useCallback((lessonId: string, activity: string) => {
    dispatch({ type: "progress", studentId, courseId: "c1", lessonId, activity, moduleId: Number(lessonId.slice(1)) > 3 ? "m2" : "m1" });
  }, [dispatch, studentId]);
  return {
    ...context, student, progress, pack, packages, bookings, nextBooking, teacher,
    enrolled: student.joinedCourseIds.includes("c1"),
    fresh: progress?.stage === 1,
    membership: student.membership.toLowerCase(),
    done: progress?.selfCompleted || [],
    practiced: progress?.practiced || [],
    currentLessonId: progress?.lessonId || "l3",
    credit: pack ? balance(state, pack.id) : { allocated: 0, consumed: 0, reserved: 0, available: 0 },
    slots: pack ? availableSlots(state, pack.id, actor) : [],
    feedback: visibleFeedback(state, actor),
    eligibility: guidanceEligibility(state, student.id, "c1"),
    visitLesson,
    toggleComplete: (lessonId: string) => {
      const result = dispatch({ type: "progress", studentId, courseId: "c1", lessonId, selfComplete: !progress?.selfCompleted.includes(lessonId) });
      return result.ok ? "已更新本機自報完成；沒有老師驗證、評級或證書。" : result.error || "無法記錄。";
    },
    togglePractice: (practiceId: string) => dispatch({ type: "progress", studentId, courseId: "c1", lessonId: progress?.lessonId || "l3", practiceId }),
    comments: state.discussionComments.filter(item => item.studentId === studentId),
    addComment: (lessonId: string, text: string) => dispatch({ type: "addDiscussionComment", courseId: "c1", lessonId, text }),
  };
}
