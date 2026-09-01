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
  Trusted schedule mutations first serialize on deterministic Student and
  Teacher schedule-resource locks; the exclusion constraints remain the final
  integrity guard.
- Online Lessons snapshot an allowlisted Google Meet or `zoom.us` HTTPS meeting
  reference. Arbitrary manual URLs are not redirect targets in Epic 3. Onsite
  Lessons snapshot the lesson-safe Teacher location text.
- Only the assigned Teacher can complete a Trial. Completion atomically creates
  one record and assessment and advances `trial` to `awaiting_conversion`.
- Epic 3 MVP uses first-committer/lock-winner semantics when Trial completion
  races Admin cancellation. Either transition may win, but the transaction must
  leave a fully completed Trial or a fully cancelled Trial, never partial state.
  Admin cancellation priority would require a future explicit state machine.
- Authorization is evaluated while a mutation transaction executes. Role or
  account revocation rejects every mutation that begins after revocation; an
  already-authorized in-flight transaction may still complete.
- Trial confirmation/completion never creates packages, consumes credits,
  creates earnings, or creates rewards.

## Epic 4 Commerce Core

- Commerce is not entitlement. Payment success does not grant Lesson Credits.
- Checkout price, seller, and item identity are database snapshots; clients
  cannot submit totals. Discounts and taxes are explicit zero-valued fields in
  Epic 4, not assumptions that those domains will never exist.
- Bank transfers require Buyer submission and Admin review. Cash confirmation
  is an Admin-only transaction. Both create durable audit records.
- Only pending or awaiting-payment Orders can be cancelled or expired. Paid
  Orders require the future refund workflow.
- `order.paid` is an unconsumed, retryable Epic 5 bridge, not proof that any
  package, course, or credit was fulfilled.
- Epic 3 Trial remains on `trial_orders` during Phase A. Phase B will migrate
  through an explicit `trial_legacy` source mapping and reconciliation plan;
  Epic 4 deliberately performs no dual-write and has one payment truth per flow.
