# BUSINESS RULES

## Core 1-on-1 and configurable quota architecture proposal

- One-on-one Fixed/Recurring and Flexible Booking are both core services, not
  subordinate LMS features. Free, Plus, and Pro do not prevent independent
  one-on-one purchase.
- Review quota supports configurable allocation, reservation, consumption,
  adjustment, reset/expiry, audit, history, extra purchase, reversal,
  compensation, plan change, and resubmission policy. Exact numbers, periods,
  resets, packs, prices, and resubmission consumption are explicitly TBD.
- Fixed Lessons reserve an agreed recurring weekly local-time slot with priority
  over Flexible availability. A series has lifecycle/exceptions; each actual
  occurrence remains a separate Lesson and consumes a Lesson Credit.
- Flexible Bookings select Teacher availability, make one Lesson, check
  Teacher/Student collision and sufficient credit, and follow cancellation/
  reschedule policy. Instants are UTC with IANA context.
- Credit is eligibility, Booking is a scheduled commitment, Lesson is an actual
  occurrence. Fixed and Flexible share one entitlement/credit ledger.
- Flexible may currently be NT$100 above Fixed per lesson, but this is
  Commerce/Product configuration—not Scheduling logic or a permanent rule.
- Admin overrides for both modes require actor, reason, audit, credit outcome,
  and earning outcome.
- LMS review can recommend one-on-one escalation. A lesson Teacher sees only
  separately authorized minimum learning-map data, never all submissions or
  private feedback by default.

## Learning Verification & Membership architecture proposal

**Status:** future policy direction only. No LMS or subscription behavior is
implemented by this documentation update.

### Learning and verification

- The curriculum hierarchy is map → stage → module → node → resources →
  practice → evidence → verification. Stage 1–5 remain the approved canonical
  progression.
- Nodes declare objectives, prerequisites, practice requirements (for example
  tempo/BPM, repetitions, duration, or required artifact), verification method,
  pass criteria, and standard version.
- `VIEWED` and `PRACTICED` represent learner activity. `SUBMITTED` begins an
  evidence workflow; `UNDER_REVIEW` is assigned review; `REVISION_REQUIRED`
  returns actionable feedback; only `VERIFIED` is a demonstrated outcome.
- Teacher review includes a decision, text/video feedback, rubric result,
  issue tags, next-practice instruction, reviewer, reviewed time, rubric
  version, and learning-standard version. A Teacher cannot verify work outside
  assigned, authorized stage capability.
- A stage assessment is allowed only after its configured nodes are verified.
  Certificate records are durable and immutable; later revocation or supersede
  is a new auditable event, not a rewrite of the original pass.
- A later standard/rubric/assessment version applies forward. A prior verified
  result remains evidence against the historical version and is not silently
  invalidated by a new standard.

### Membership, entitlement, and quota

- Membership plans/tiers are not roles. Their expected lifecycle is `active`,
  `trialing`, `past_due`, `cancel_at_period_end`, `cancelled`, `expired`, and
  `paused`.
- Entitlement types are planned as `membership_access`,
  `learning_content_access`, `premium_resource_access`, `training_access`,
  `coaching_access`, `review_quota`, `assessment_access`,
  `certification_attempt`, `lesson_package`, and `lesson_credit`.
- Free supports basic-map/free-resource/progress use; Plus supports full
  structured self-study and premium tools/resources; Pro adds human review,
  verified progress, assessment/certificate access, and finite review capacity.
  Exact plan matrix remains PRD work.
- One-on-one lesson access is independent from membership. Commerce payment
  success creates an outbox event; fulfillment later grants entitlement
  idempotently. Payment/order state alone is never access or achievement.
- First valid review submission is expected to reserve/consume quota. A bounded
  reasonable resubmission policy may be offered, but no infinite free
  resubmission is permitted. Counts, validity period, renewal, rollover, and
  final resubmission rule await PRD approval.
- Cancellation/expiry stops future premium access, new review consumption, and
  future assessment access according to policy. It never erases learning
  progress, submitted evidence, feedback, verification, completion, or
  certificates.

### AI and escalation

- Future AI may assist onboarding, recommendation, progress summaries,
  pre-screening, reviewer assistance, or reviewer matching. It cannot make a
  formal verification, assessment, or certificate decision.
- Review feedback may recommend one-on-one escalation; a lesson offer/credit
  is a separate commercial entitlement, not an automatic consequence of a
  review.

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
- Public visibility and purchasability are separate. An active public Product
  may remain visible as Coming Soon while `is_purchasable=false`, but checkout
  always requires `is_purchasable=true`.
- Teacher-owned checkout authoritatively rechecks the live private Teacher
  record: active account, Teacher role, active teaching status, and public
  publication must all remain true when the Order is created.
- Checkout price, seller, and item identity are database snapshots; clients
  cannot submit totals. Discounts and taxes are explicit zero-valued fields in
  Epic 4, not assumptions that those domains will never exist.
- Bank transfers require Buyer submission and Admin review. Cash confirmation
  is an Admin-only transaction. Both create durable audit records.
- An Order may retain multiple Payment attempts, but at most one attempt may
  become paid. A paid Order rejects every different Payment attempt; the losing
  attempt remains unchanged for review. Same-Payment retries require the same
  provider event identity.
- Only pending or awaiting-payment Orders can be cancelled or expired. Paid
  Orders require the future refund workflow.
- Buyer self-cancellation and Teacher self-archive write minimal durable audit
  snapshots in the same transaction as the state change.
- `order.paid` is an unconsumed, retryable Epic 5 bridge, not proof that any
  package, course, or credit was fulfilled.
- Epic 3 Trial remains on `trial_orders` during Phase A. Phase B will migrate
  through an explicit `trial_legacy` source mapping and reconciliation plan;
  Epic 4 deliberately performs no dual-write and has one payment truth per flow.
