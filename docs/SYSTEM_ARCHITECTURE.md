# SYSTEM ARCHITECTURE

## Accepted hosting decision — 2026-09-08

OWNER accepted Cloudflare Workers + vinext as the target hosting/runtime path.
Supabase PostgreSQL, Auth, Storage and RPC/API remain the backend; the modular
monolith and server/database authorization boundaries remain unchanged.
Preview uses an isolated Cloudflare Worker from preview-test. Future Production
uses a separate Worker from main; Production deployment is NOT AUTHORIZED.
Vercel is no longer the primary hosting target. The earlier Vercel recommendation
in THE_ONE_CLOUDFLARE_HOSTING_EVALUATION is a superseded proposal, retained as audit history.
No D1, KV, Durable Objects or R2 product is introduced. R2 stays future/optional.
Canonical Epic7–Epic13 and accepted Product Decisions are unchanged.
See [local compatibility proof and Preview plan](THE_ONE_CLOUDFLARE_PREVIEW_DEPLOYMENT.md).
Epic7 Backup/Recovery gates still block Production migration/smoke/launch.


## Epic 6 — Scheduling & Booking Core (REMOTE CLOSED)

P2 remote closure is complete; see [Project Status](PROJECT_STATUS.md) for
historical deployment, recovery and smoke evidence.

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

The canonical contract is the branch-aware DAG documented in
`docs/LOCK_ORDER_CONTRACT.md` and enforced by
`global_lock_order_contract.test.sql`. Ordinary Scheduling uses deterministic
Student/Teacher schedule advisory locks, Entitlement, Reservation, Booking,
optional recurring Occurrence, then Lesson. Commerce/Fulfillment, Fixed
attachment/Renewal, Makeup, and Entitlement Revoke use declared branches rather
than being forced into a false total order. Nested helpers may only reacquire an
inherited lock or acquire a later resource in their branch. The machine
contract rejects graph cycles, unregistered mutation-capable SECURITY DEFINER
functions, unexpected overloads, and critical SQL source-order reversals.

Booking-bound reservations are released by Scheduling orchestration so
Booking, Lesson, credit, and audit state commit or roll back together.

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

**Implementation status:** Epic7 content/version/self-activity foundations are
LOCAL CLOSED; other boundaries below remain future architecture. The four
decisions are approved in [Epic 7 Scope Definition](EPIC7_SCOPE_DEFINITION.md).
[Local execution evidence](EPIC7_LOCAL_EXECUTION.md) identifies actual migrations,
RPCs and server-only inspection. No remote deployment or F authorization exists.

Membership and System Course are separate concepts. A Membership Catalog links
approved System Courses to plans through inclusion/access policy and
Entitlement. The architecture supports multiple System Courses; The One Guitar
Roadmap 2.0 is the first flagship course, not a singleton platform assumption.

| Boundary | Owns | Does not own |
| --- | --- | --- |
| System Course | Course identity, objectives, authorship, curriculum/Map association | Billing plan, access authority, settlement |
| Learning Map | Course-scoped maps, stages/levels, modules, nodes, standards, practice requirements, provider-neutral resources | Billing, review decisions, certificates |
| Learning Progress | Private personal activity and explicit Self Complete foundation in Epic 7 | Enrollment, subscription lifecycle, formal verified/assessed outcomes or reviewer authorization |
| Assignments & Evidence | Submission instructions, evidence, private assets | Public content delivery/certificates |
| Reviews & Verification | Assignment, rubric feedback, human decision | Role assignment or plan billing |
| Assessment & Achievement | Assessment and immutable completion/certificate records | Active membership state |
| Membership & Entitlement | Plans, Membership Catalog, System Course inclusion/access policy, subscriptions, capabilities, entitlements, quota ledger | Course authorship, Auth role, evidence, settlement |
| Commerce Fulfillment | Idempotent `order.paid` consumption and entitlement grant/revocation | Progress or achievement mutation |

`paid order → order.paid outbox → fulfillment → entitlement → server authorization → resource/review access`

Commerce is not entitlement; entitlement is not achievement; achievement is
not a subscription row. A subscription affects future capability access, never
the survival of verified history.

Epic 7 uses the generic Course → Learning Map → Stage/Level → Module → Node →
Resource hierarchy. The existing five-stage `learning_map_stages` catalog and
its Teacher/Trial references stay intact. New course-scoped Stage/Level IDs
are distinct; Guitar Roadmap uses Level 1–6, other courses their own structure.
Only explicit future mapping/policy may relate them; no 1:1 identity binding
or inherited Teacher authority is implied.

Epic 7's representative content slice verifies multiple Modules/Nodes,
multi-Resource links, objectives/skills, advisory prerequisites, ordering and
versions. It does not require all six Levels' formal content. Immutable
version snapshots and minimal internal/Admin inspection are foundations, not
an Epic 13 Creator approval or production publishing system.

### Resource-provider boundary

`learning_resources` will abstract video, article, PDF, diagram, tab,
chord-chart, audio, backing/practice track, download, external link, and
self-check/instructional material. Each Node has a variable ordered set of
Resources, not a single video or fixed horizontal columns. Future submission,
async review, verification and assessment use optional capability attachment
points; they are not Resource delivery or workflow records.

Video providers may include YouTube, VdoCipher, Cloudflare Stream, Mux or
internal services. Provider identity is not access authority. Epic 8 decides
resource/capability use through Membership Plan + Inclusion/Access Policy +
Entitlement; no PDF = Plus or Review = Pro constant exists. A deliberately
free resource may be available under that policy. Protected playback tokens
are issued server-side after authorization, never from browser claims.

### Progress, access and workspace boundaries

Advisory prerequisites do not prevent skipping ahead when target access allows.
Prerequisite != Access/Entitlement != formal Verification/Assessment. Personal
Self Complete neither certifies mastery nor creates formal Level completion,
verification, assessment pass or achievement. Formal outcomes remain Epic 10/11.

Course/Node support for review is content metadata; Student eligibility is
Epic 8 authority; actual upload, assignment, feedback and resubmission is
Epic 10 execution. Epic 7 exposes stable structure/resource/version IDs and
capability attachment points without implementing these engines.

Epic 9's personal workspace/map requires formal course joining/use eligibility.
A recommendation or suggested starting Level grants neither enrollment nor
certification; no unjoined Course gets a 0%/Level-progress personal roadmap.
Diagnosis/recommendation journeys remain future interface notes, not assigned
new Epics or Epic 7 blockers. No production Student Workspace is part of Epic 7.

### Human verification and multi-teacher review

The platform owns a Student's course-scoped learning state. A review may later
go to the current Teacher, a pool, a stage specialist, or manual Admin
assignment, based on
authorized stage capability and eventually language/workload/expertise rules.
No automatic dispatch is introduced here. Existing
`teacher_stage_capabilities` retains its legacy Stage 1–5 scope. Future `teach`,
`review`, `assess`, `mentor`, and `content_author` authority needs explicit
course/stage capability policy; legacy assignments do not automatically apply
to new Levels. Content authorship is neither access nor revenue authority.
AI may assist preparation or
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
and credit state. Epic 6 Scheduling owns time, Booking, recurring series,
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
