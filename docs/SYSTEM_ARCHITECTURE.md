# SYSTEM ARCHITECTURE

## Epic 6 — Scheduling & Booking Core (implemented locally)

One-on-one teaching is a first-class domain beside LMS membership. Scheduling
owns availability, booking behavior, recurring-series semantics, exceptions,
collision orchestration, and authorized overrides. Commerce owns price;
Entitlement owns lesson eligibility; Scheduling owns time; and `lessons`
represents the actual occurrence:

`lesson entitlement / credit ≠ booking or recurring slot ≠ lesson instance`.

Both fixed and flexible modes consume the same Lesson Credit entitlement
ledger. Epic 5 Entitlement/Credit is the sole owner of reservation, release,
consumption, balance, ledger, idempotency, and exhausted-state invariants.
Scheduling delegates those transitions to shared private Epic 5 cores; it does
not insert credit-ledger entries or create mode-specific credit balances.

### Canonical cross-domain lock order

Every path that crosses Epic 3 scheduling, Epic 5 credit, and Epic 6 Booking
uses one order: deterministic Student/Teacher schedule advisory locks,
Entitlement row, credit Reservation row, Booking row, recurring Occurrence row
when present, then Lesson row. A path that begins inside Epic 5 omits the
schedule locks but still locks Entitlement before Reservation. Booking-bound
reservations are released by Scheduling orchestration so Booking, Lesson,
credit, and audit state commit or roll back together.

Fixed uses `recurring_lesson_series`, bounded `recurring_lesson_occurrences`,
series exceptions, priority reservation, and lazily generated lesson instances
(never a batch of 100 future Lessons). It must handle pause/end/change, leave,
Teacher unavailability, holiday/exception, temporary release, credit expiry,
IANA timezone/DST, and Teacher/Admin override. Priority slots are excluded from
Flexible availability unless an authorized exception releases them.

Flexible Booking exposes only generated slot DTOs and atomically creates one Lesson
per chosen slot. It reuses Epic 3 `lessons`, Student–Teacher relationships, UTC
`timestamptz` plus IANA anchor, collision/exclusion constraints, deterministic
advisory locking, Lesson Records, and participant access controls. It needs
availability/exception rules, credit reservation lifecycle, cancellation/
reschedule primitives, and audited Admin overrides. Lesson participation never
grants wholesale access to LMS submissions or private learning data.

The first migration is `20260901000600_scheduling_booking_core.sql`. Weekly
series store local wall time plus an IANA timezone; actual bookings and Lessons
store UTC `timestamptz` instants. Ambiguous and nonexistent DST occurrences are
recorded as failed occurrence claims instead of selecting an offset silently.
All mutations use role-checked RPCs and the canonical cross-domain lock order.
Teacher mutations require an active account, Teacher role, an existing Teacher
profile, and `teaching_status = 'active'`; Admin/Super Admin authorization is
independent of Teacher teaching status.

## Architecture Update — Learning Verification LMS (proposed)

**Implementation status:** documentation only. These are future
modular-monolith boundaries, not deployed tables, APIs, workers, or migrations.

| Boundary | Owns | Does not own |
| --- | --- | --- |
| Learning Map | Maps, stages, modules, nodes, standards, practice requirements, provider-neutral resources | Billing, review decisions, certificates |
| Learning Progress | Student activity and node state | Subscription lifecycle or reviewer authorization |
| Assignments & Evidence | Submission instructions, evidence, private assets | Public content delivery/certificates |
| Reviews & Verification | Assignment, rubric feedback, human decision | Role assignment or plan billing |
| Assessment & Achievement | Assessment and immutable completion/certificate records | Active membership state |
| Membership & Entitlement | Plans, subscriptions, capabilities, entitlements, quota ledger | Auth role, evidence, settlement |
| Commerce Fulfillment | Idempotent `order.paid` consumption and entitlement grant/revocation | Progress or achievement mutation |

`paid order → order.paid outbox → fulfillment → entitlement → server authorization → resource/review access`

Commerce is not entitlement; entitlement is not achievement; achievement is
not a subscription row. A subscription affects future capability access, never
the survival of verified history.

### Resource-provider boundary

`learning_resources` will abstract video, article, PDF, diagram, tab,
chord-chart, audio, backing/practice track, download, assignment, external
link, and future interactive-tool resources. Video provider may be YouTube,
VdoCipher, Cloudflare Stream, Mux, internal, or another provider. YouTube can
be free and carries no entitlement requirement. VdoCipher is only a premium
provider: a short-lived playback token comes from a server-side entitlement
check and never from the browser.

### Human verification and multi-teacher review

The platform owns a Student's map. A review may later go to the current
Teacher, a pool, a stage specialist, or manual Admin assignment, based on
authorized stage capability and eventually language/workload/expertise rules.
No automatic dispatch is introduced here. Existing
`teacher_stage_capabilities` is the future base for `teach`, `review`,
`assess`, `mentor`, and `content_author`. AI may assist preparation or
recommendations, but no AI can formally verify, assess, or certify.

Status: Draft

## Purpose

Describe the modular-monolith architecture, system boundaries, and future integrations.

## Pending formal PRD input

To be completed from the approved formal PRD.

## Epic 4 Commerce boundary

The modular monolith now has separate Commerce and Payments modules. Server
Components read through minimal DAL DTOs; UI mutations use Server Actions that
re-authorize and call transactional PostgreSQL RPCs. Product/Order code depends
only on a provider-neutral payment interface, never a gateway SDK.

Payment confirmation and the `order.paid` outbox insert share one transaction.
An Epic 5 consumer may claim and retry pending outbox rows, but fulfillment is
not part of the Payment RPC.

The Order row is the serialization boundary for payment confirmation,
cancellation, expiry, and rejection. Multiple Payment attempts may exist, but a
partial unique index on paid attempts is the final invariant. Competing
confirmations lock Order then Payment, so exactly one attempt can create the
financial audit and unique `order.paid` outbox event.

The public Product catalog uses `public_slug` and intentionally distinguishes
visibility from purchasability for Coming Soon presentation. Checkout does not
trust that projection: it reads the private Product and revalidates current
Teacher account, role, teaching, and publication state inside PostgreSQL.

## Epic 2 public discovery architecture

The web application remains a modular monolith. The Teacher module owns:

- server-only public-discovery queries;
- private Teacher self-edit actions;
- server-only Admin management actions; and
- input validation, catalog definitions, and presentation labels.

Public server-rendered pages call the public projection query module. Browser
components receive already allowed public fields only. The database projection
is synchronized by migration-managed triggers and guarded by RLS; it is not a
view over private account records exposed to the Data API.

The Admin management page is route-protected and its mutations require both
server authorization and the server-only service-role client. This is a
deliberate administrative boundary, not a client-side role check.

## Epic 3 Trial Flow architecture

The Trial module is a vertical slice inside the modular monolith:

- Server Components call server-only DTO modules for Student, Teacher, and
  Admin views.
- Server Actions validate untrusted form input, convert IANA local time, and
  re-authorize the role at the mutation boundary.
- Authenticated security-definer RPCs own the payment-confirmation and
  Trial-completion transactions. Database grants/RLS remain the final boundary.
- PostgreSQL uniqueness, row locks, advisory pair locks, deterministic Student
  and Teacher schedule-resource locks, and interval exclusion constraints
  provide idempotency and race-safe scheduling. Every trusted mutation that
  enters, changes, or leaves the `scheduled` exclusion predicate acquires the
  same resource keys in ascending numeric order before locking or writing the
  Lesson row. GiST remains the final integrity guard.
- `/lesson/[id]/join` is the only meeting redirect. It performs fresh identity
  validation and a participant-RLS Lesson lookup; public pages never receive a
  meeting reference.

Epic 3 intentionally uses an Admin/Teacher-controlled requested-time workflow.
It does not introduce availability recurrence, payment providers, credits,
earnings, packages, notifications, or calendar integrations.

## Epic 5 Entitlement boundary

The Entitlement module completes the current transactional path:

`Commerce Order Item snapshot → order.paid outbox → idempotent fulfillment → Entitlement → append-only Lesson Credit ledger`

Commerce still owns Product price and payment truth. Entitlement owns access
and credit state. Epic 6 Scheduling will own time, Booking, recurring series,
and the reserve/release/consume lifecycle. A credit is therefore neither a
Booking nor a Lesson.

The fulfillment consumer operates at Order Item granularity and fails closed
for unsupported Product types. Its public service entry point requires the
database `service_role`; the Admin retry entry point independently verifies an
active Admin/Super Admin identity. Both call the same transactional private
implementation, and a failed event remains retryable rather than being marked
processed.

Student, Teacher, and Admin pages read allowlisted DTO RPCs. Browser clients
cannot read raw ledgers, fulfillment snapshots, reservations, or Product
fulfillment configuration. Server Actions validate input and re-authorize the
route role, while PostgreSQL remains the final authorization boundary.

Epic 5 intentionally has no background queue/cron, Booking UI, subscription,
review quota, LMS, or achievement workflow. Production scheduling of the
outbox consumer and refund/expiry automation require later approved work.
