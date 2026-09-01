# DATABASE DOMAIN MODEL

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
projection with no seller UUID or internal metadata.

`orders` separates order lifecycle from payment lifecycle and scopes checkout
idempotency to `(buyer_user_id, idempotency_key)`. `order_items` snapshots the
name, type, price, quantity, and seller at checkout. PostgreSQL computes all
amounts from the locked Product and enforces subtotal/discount/tax/total checks.

`payments` and `payment_submissions` are private. Buyers receive a minimal DTO;
bank evidence and provider references are not granted directly. `refunds`
reserves multiple future attempts but has no refund engine. `audit_logs` records
privileged state changes and is service-only.

`order_fulfillment_events` is the transactional outbox. Its unique
`(order_id, event_type)` row records `order.paid`, remains retryable, and does
not mean fulfillment or lesson credits have occurred.
