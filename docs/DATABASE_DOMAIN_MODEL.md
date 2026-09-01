# DATABASE DOMAIN MODEL

## Epic 6 Scheduling & Lesson-credit domain

Epic 6 adds the scheduling commitment layer while retaining Epic 3 `lessons`,
`student_teacher_relationships`, `lesson_records`, UTC/IANA fields, and
collision guarantees as the occurrence foundation.

| Record | Purpose |
| --- | --- |
| `teacher_scheduling_settings` | IANA timezone, notice, horizon, slot interval |
| `teacher_availability_rules` / `teacher_availability_exceptions` | Flexible source and absence/holiday/opening handling |
| `bookings` | One scheduled commitment, lifecycle, Lesson and credit-reservation linkage |
| `recurring_lesson_series` | Fixed weekly local-time commitment, optional preferred entitlement |
| `recurring_lesson_occurrences` | Bounded UTC priority claims and materialization state |
| `recurring_lesson_series_exceptions` | Leave, reschedule, release, Teacher unavailable, holiday |
| `audit_logs` | Actor, reason, before/after, credit and earning outcome |

`lesson_package` entitlements serve both a Fixed series
occurrence and a Flexible booking. Products may later distinguish fixed,
flexible, generic lesson package, membership, training, review pack, and
assessment pack offerings without changing the existing Epic 4 Product enum in
the scheduling schema. Series lifetime is never bound to one package; each
occurrence supplies an explicit eligible entitlement.

## Learning Verification architecture proposal (not implemented)

No migration is created by this documentation update. The following names are
proposed future records, to be versioned only in an approved delivery epic.

| Domain | Proposed records | Responsibility |
| --- | --- | --- |
| Content | `learning_maps`, map-stage links, `learning_modules`, `learning_nodes`, `learning_resources`, `practice_requirements` | Versioned curriculum and provider-neutral resources |
| Progress | `student_node_progress` | `VIEWED` → `PRACTICED` → `SUBMITTED` → `UNDER_REVIEW` / `REVISION_REQUIRED` / `VERIFIED` |
| Evidence | `assignments`, `submissions`, `submission_assets` | Practice instructions and private learner evidence |
| Review | `submission_reviews`, `review_feedback`, `review_rubric_results` | Authorized human decisions, feedback, tags, next practice, reviewer and version snapshots |
| Standards | `learning_standard_versions`, `rubrics`, `rubric_versions` | Criteria governance and historical reproducibility |
| Assessment | `stage_assessments`, `assessment_versions`, `assessment_attempts` | Stage assessment after required verified nodes |
| Achievement | `stage_completions`, `certificates` | Durable completion and immutable certificate issue/revoke/supersede history |
| Membership | `membership_plans`, `subscriptions`, `entitlements`, capability catalog, entitlement-capability links | Commercial access lifecycle, not role/achievement |
| Quota | `review_quota_allocations`, `review_quota_ledger` | Allocated, reserved, consumed, restored, expired, manually adjusted review capacity |

Existing `learning_map_stages` and `teacher_stage_capabilities` remain the
canonical Stage 1–5/capability base. Future map/version linkage must not
silently redefine them.

### Relationships and invariants

- A Node has objective, prerequisites, ordered stage/module placement,
  resources, requirements, verification/pass criteria, and standard version.
- Only an authorized human verification can set `student_node_progress` to
  `VERIFIED`; viewing or practice alone cannot complete a stage.
- A submission snapshots its assignment/standard context. Reviews retain
  reviewer, time, `pass`/`revision_required`/`resubmit` decision, feedback,
  rubric result, rubric version, and standard version.
- A stage completion needs configured verified nodes. A certificate retains
  Student, stage, standard/assessment version, passed time, authorized
  examiner, certificate number, and revoke/supersede history; it is never
  silently rewritten.
- Subscription states may be `active`, `trialing`, `past_due`,
  `cancel_at_period_end`, `cancelled`, `expired`, or `paused`. Entitlements are
  independently time-bounded; progress/achievement are not tied to them.
- A future idempotent fulfillment consumer turns `order.paid` into entitlement.
  Review use is an allocation/ledger transaction, not a mutable remaining-count
  field.

Status: Draft

## Purpose

Document the approved domain entities and their relationships before database implementation.

## Epic 1 implemented model

### Supabase Auth

`auth.users` remains the identity and email source. The application does not
create a second credential or email identity table.

### profiles

Private account data:
`id`, `user_id`, `display_name`, `phone`, `avatar_url`, IANA
`timezone`, `locale`, `account_status`,
`legacy_wordpress_user_id`, `created_at`, and `updated_at`.

`account_status` supports `active`, `suspended`, and `disabled`.
Authenticated users can read only their own active row.

### user_roles

Many-to-one role assignments from users to the `student`, `teacher`,
`admin`, and `super_admin` enum. The unique key on `(user_id, role)`
allows multiple different roles without duplicates.

New Auth users receive a `profiles` row and the initial `student` role from
a database trigger. User-editable metadata is never used to assign a role or
account status.

### public_profiles

A separate public-presentation boundary containing only `user_id`,
`display_name`, `avatar_url`, and timestamps. It is not client-accessible
and no public teacher page is implemented in Epic 1.

## Migration

`supabase/migrations/20260831000100_identity_auth_roles.sql` is the source of
truth for this model, grants, triggers, and RLS.

## Pending formal PRD input

Additional profile fields, public-profile publication rules, audit history, and
later domain relationships await the approved formal PRD.

## Epic 2 implemented model

### Teacher public/private boundary

`teacher_profiles` is the private teacher platform record. It holds the
teacher account reference, admin-controlled publication controls, public slug,
prices, and editable teaching content; it is never granted to anonymous users.

`teacher_public_profiles` is the explicit minimal projection for public
discovery. It contains only the fields rendered on `/teachers` and
`/teachers/[slug]`. A security-definer database trigger synchronizes allowed
display name data from `profiles` and allowed teacher presentation data from
`teacher_profiles`. Public routes query this projection, never
`profiles` or `teacher_profiles`.

### Teacher capability model

- `specialties`: platform-defined catalog, seeded conflict-safely.
- `teacher_specialties`: normalized many-to-many assignment.
- `learning_map_stages`: canonical seeded Stage 1–5 catalog.
- `teacher_stage_capabilities`: admin-controlled teacher-to-stage assignment
  with `allowed` or `certified` status.

### Money and location

All current prices are nullable non-negative `integer` TWD amounts:
`trial_price_twd`, `fixed_lesson_price_twd`, and
`flexible_lesson_price_twd`. No JavaScript float is used as a stored monetary
value. MVP location is nullable public `location_text`; structured geography
can be introduced later without changing existing public URL identity.

## Epic 2 migration

`supabase/migrations/20260831000200_teacher_profiles_public_discovery.sql`
creates the tables, policies, triggers, and deterministic catalog seeds.

## Epic 3 implemented model

`student_profiles` owns learning goals, preferred delivery mode/location,
onboarding state, and an optional current Learning Map Stage. Student learning
data remains separate from the private account `profiles` table.

`student_teacher_relationships` is the durable teaching relationship and does
not derive its state from an order. A partial unique index permits only one
open `trial`, `awaiting_conversion`, `active`, or `paused` relationship for a
Student–Teacher pair.

`trial_orders` is the deliberately small commerce boundary. It snapshots the
trial price, requested UTC instant, delivery mode, IANA timezone, payment state,
and an idempotency key. No payment-provider or financial instrument data is
stored in Epic 3.

`lessons` is the extensible lesson base for `trial`, `fixed`, `flexible`, and
`makeup`, while Epic 3 creates only `trial`. It stores UTC `timestamptz`
intervals, an IANA timezone anchor, duration, delivery details, and a snapshot
of the participant-only meeting or lesson-safe location. Composite foreign
keys guarantee the relationship and order participants match the lesson.

`lesson_records` and `assessments` are one-to-one with a Trial Lesson. The
record separates Student-visible notes from Teacher-private notes; assessment
stores the primary stage, recommendation category, and formal summary.

The source of truth is
`supabase/migrations/20260831000400_student_teacher_trial_flow.sql`.

## Epic 4 implemented model

`products` is the private product source with platform/Teacher ownership, ISO
currency, integer minor-unit price, lifecycle timestamps, tax placeholders,
and private metadata. `product_public_catalog` is a synchronized public-safe
projection with no seller UUID, technical Product UUID grant, or internal
metadata. `public_slug` is the public identifier. A non-purchasable row may be
visible as Coming Soon; checkout separately enforces purchasability and live
Teacher eligibility.

`orders` separates order lifecycle from payment lifecycle and scopes checkout
idempotency to `(buyer_user_id, idempotency_key)`. `order_items` snapshots the
name, type, price, quantity, and seller at checkout. PostgreSQL computes all
amounts from the locked Product and enforces subtotal/discount/tax/total checks.

`payments` and `payment_submissions` are private. An Order may have multiple
Payment attempts, while the partial unique index
`payments_one_paid_per_order_idx` guarantees at most one paid attempt. The paid
transition serializes on the Order and then the target Payment; different
attempts remaining pending cannot later be confirmed. Buyers receive a minimal
DTO; bank evidence and provider references are not granted directly. `refunds`
reserves multiple future attempts but has no refund engine. `audit_logs` records
privileged payment/order/product state changes, including Buyer cancellation
and Teacher archive, and is service-only.

`order_fulfillment_events` is the transactional outbox. Its unique
`(order_id, event_type)` row records `order.paid`, remains retryable, and does
not mean fulfillment or lesson credits have occurred.

## Epic 5 implemented model

`lesson_package_product_configs` stores the fulfillment rules for a Commerce
Lesson Package Product. `order_item_fulfillment_snapshots` freezes those rules
when an Order Item is created, so later Product/config edits cannot rewrite an
already purchased right.

`entitlements` is the access grant. Epic 5 implements the
`lesson_package` type and reserves the broader type catalog for later approved
epics. Each paid Order Item can create at most one entitlement of a given type.
The beneficiary is an Auth user in this phase; parent, gift, and school-owned
benefits remain a future modeling decision.

`lesson_credit_ledger` is the append-only balance source of truth. Allocation,
reservation, release, consumption, adjustment, expiration, refund reversal,
and revocation are distinct entry types; fixed and flexible lessons will use
this same ledger. `lesson_credit_reservations` links a reserved credit to one
future Booking or an existing Lesson without making credit, Booking, and
Lesson the same entity.

`entitlement_expiry_history` records authorized expiry extensions. Admin credit
adjustments and revocation retain audit/history instead of deleting the
entitlement.

The implemented source of truth is
`supabase/migrations/20260901000500_entitlement_lesson_credits.sql`.

### Explicitly pending decisions

- Epic 5 activates Lesson Packages at successful fulfillment. First-booking,
  scheduled, and admin-specified activation are modeled but not executed.
- Validity supports configured days, weeks, or months. Whether an already
  reserved lesson may occur after expiry is deferred to Epic 6 policy.
- Credit primitives require an explicit entitlement ID. Automatic selection
  across multiple packages is deferred to Epic 6.
- Refund-provider reconciliation and automatic expiry workers are not
  implemented. Manual audited Admin revoke/adjust primitives are present.
- Review quota, membership, subscription, LMS access, assessment,
  certification, and achievement engines are not implemented by Epic 5.
