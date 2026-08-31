# BUSINESS RULES

Status: Draft

## Purpose

Record approved business rules and their domain ownership.

## Pending formal PRD input

To be completed from the approved formal PRD.

## Epic 3 Trial Flow

- Trial requests begin as `pending`; clicking the Student confirmation button
  is not payment confirmation.
- An authenticated Admin manually confirms payment in Epic 3. Confirmation is
  idempotent and atomically creates or reuses the relationship, then creates
  exactly one scheduled Trial Lesson.
- Trial Lessons are 50 minutes in this Epic. The lesson schema retains an
  explicit duration for future lesson types.
- All instants are stored as UTC `timestamptz`. Forms accept local wall time
  plus an IANA timezone and convert on the server.
- Admin/Teacher-controlled scheduling is used instead of Student self-service
  availability. Weekly availability and recurring booking remain out of scope.
- Scheduled Teacher and Student intervals may not overlap. PostgreSQL exclusion
  constraints provide race-safe enforcement using half-open UTC ranges.
- Online Lessons snapshot the Teacher's manually configured HTTPS meeting
  reference. Onsite Lessons snapshot the lesson-safe Teacher location text.
- Only the assigned Teacher can complete a Trial. Completion atomically creates
  one record and assessment and advances `trial` to `awaiting_conversion`.
- Trial confirmation/completion never creates packages, consumes credits,
  creates earnings, or creates rewards.
