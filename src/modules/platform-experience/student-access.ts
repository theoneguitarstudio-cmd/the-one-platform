import type { Actor } from "@/modules/ux-prototype/model";

/** Local fixture visibility only; real sessions and database policies remain separate. */
export function canReadStudentExperience(
  actor: Actor,
  studentId: string,
  knownStudentIds: readonly string[],
): boolean {
  return actor.role === "student"
    && actor.id === studentId
    && knownStudentIds.includes(studentId);
}
