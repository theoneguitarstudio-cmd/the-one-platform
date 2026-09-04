# Global Lock-Order Contract

Status: local closure contract for Commerce, Entitlement, and Scheduling
mutations. The executable source of truth is
`supabase/tests/database/global_lock_order_contract.test.sql`; this document
explains its resource vocabulary, branch-aware graph, and review rules.

## Scope and vocabulary

The contract inventories every mutation-capable `SECURITY DEFINER` function in
the `public` and `private` schemas. A function is either managed by the lock
graph or explicitly exempt because it is a single-aggregate/catalog mutation or
an append-only trigger/projection sink that acquires no second domain lock.
Exemptions are named and justified in the executable inventory; a new function
or overload fails the coverage guard until it is classified.

Canonical resources are:

- `REQUEST_IDEMPOTENCY`: operation-specific advisory identity.
- `PARTICIPANT_SCHEDULE`: deterministic Student/Teacher advisory locks.
- `ORDER`, `PAYMENT`, `FULFILLMENT_EVENT`: Commerce payment and outbox rows.
- `ENTITLEMENT`, `RESERVATION`, `LEDGER`: ordinary lesson-value authority.
- `REVOKE_OPERATION`: immutable Entitlement-revoke request identity.
- `MAKEUP_RIGHT`: the single value source for a Makeup Booking.
- `CHECKOUT_HOLD`, `FIXED_RENEWAL`, `RENEWAL_HOLD`: expiring Fixed ownership
  and renewal lifecycle rows.
- `FIXED_SERIES`, `FIXED_CYCLE`: long-lived slot ownership and package-period
  value. A Series is not a Cycle and neither is ordinary credit.
- `BOOKING`, `OCCURRENCE`, `LESSON`: scheduling commitment and realization.
- `AUDIT`: terminal append-only evidence.

An insert of a previously nonexistent identity is not modeled as a row-lock
edge. For example, payment confirmation locks `ORDER -> PAYMENT` and inserts a
new outbox event; fulfillment of an already-visible event locks
`FULFILLMENT_EVENT -> ORDER`. Conflating those operations would create a false
cycle that PostgreSQL cannot realize because another transaction cannot lock an
uncommitted inserted event.

## Branch-aware directed acyclic graph

The global contract is a DAG, not one artificial total order:

- Payment: `ORDER -> PAYMENT -> AUDIT/outbox insert`.
- Fulfillment: `FULFILLMENT_EVENT -> ORDER -> ENTITLEMENT -> LEDGER -> AUDIT`.
- Ordinary Booking: `REQUEST_IDEMPOTENCY -> PARTICIPANT_SCHEDULE -> ENTITLEMENT
  -> RESERVATION -> BOOKING -> optional OCCURRENCE -> LESSON`.
- Fixed materialization: `PARTICIPANT_SCHEDULE -> ENTITLEMENT -> FIXED_SERIES
  -> OCCURRENCE -> RESERVATION -> BOOKING -> LESSON`.
- Fixed attachment: `PARTICIPANT_SCHEDULE -> FULFILLMENT_EVENT -> ORDER
  -> ENTITLEMENT -> FIXED_SERIES`; Cycle creation is a new-row sink.
- Checkout conversion: `PARTICIPANT_SCHEDULE -> CHECKOUT_HOLD` followed by the
  Fixed attachment branch.
- Renewal conversion: `PARTICIPANT_SCHEDULE -> FIXED_RENEWAL -> RENEWAL_HOLD`
  followed by the Fixed attachment branch.
- Makeup Booking/lifecycle: `REQUEST_IDEMPOTENCY -> MAKEUP_RIGHT
  -> PARTICIPANT_SCHEDULE -> BOOKING -> LESSON`.
- Entitlement revoke: `ENTITLEMENT -> REVOKE_OPERATION -> FIXED_CYCLE
  -> FIXED_SERIES -> RESERVATION -> BOOKING -> LESSON`.

`LEDGER` and `AUDIT` are append-only sinks. They never become the first lock of
a flow that later requests an upstream domain resource.

## Nested calls and inherited locks

Nested helpers must acquire only a lock already held by the caller or a later
resource in the caller's declared branch. PostgreSQL advisory and row locks are
transaction-reentrant, so deliberate reacquisition of the same Entitlement or
participant schedule resource is allowed.

Critical nested chains include:

- `admin_confirm_payment/admin_confirm_cash_payment
  -> private.confirm_payment_locked`.
- `process_order_fulfillment_event/admin_retry_order_fulfillment_event
  -> private.fulfill_order_paid_event`.
- `attach_fixed_entitlement_cycle -> attach_fixed_entitlement_cycle_core
  -> attach_fixed_entitlement_cycle_without_renewal_core`.
- `convert_fixed_checkout_hold -> attach_fixed_entitlement_cycle_core`.
- `convert_fixed_renewal
  -> attach_fixed_entitlement_cycle_without_renewal_core`.
- `create_lesson_booking/materialize_recurring_lesson_occurrence
  -> reserve_lesson_credit_core -> bind_lesson_credit_reservation_booking_core`.
- Booking cancellation, reschedule, and completion dispatch to either the
  ordinary or Makeup private authority; the dispatch read retains no row lock.
- Teacher cancellation calls
  `convert_lesson_credit_reservation_to_makeup_core
  -> create_makeup_right_core` only after the ordinary value and Lesson locks
  are held. The new Right is inserted; no existing `MAKEUP_RIGHT` row is locked.
- `admin_revoke_entitlement -> claim_entitlement_revoke_operation
  -> reconcile_fixed_cycles_on_entitlement_revoke
  -> reconcile_bookings_on_entitlement_revoke
  -> complete_entitlement_revoke_operation`.

## Cross-domain safety decisions

### Fulfillment and Fixed Renewal

Renewal conversion can wait for a Fulfillment Event while holding schedule,
Renewal, and Hold locks. Fulfillment locks Event then Order, but never requests
participant schedule, Renewal, or Hold locks. There is therefore no return edge
to form a cycle. The reverse-order concurrency harness holds Event first in one
session while conversion enters schedule-first in the other.

### Makeup and ordinary Scheduling

Makeup lifecycle functions consistently lock an existing Right before the
participant schedule. Ordinary scheduling locks the participant schedule and
then an Entitlement; it never requests an existing Makeup Right. Teacher
cancellation creates a new Right rather than locking an existing one. The two
branches can contend on the schedule but do not form `schedule -> Makeup Right
-> schedule`.

### Revoke and Booking

Revoke intentionally does not take participant schedule advisory locks. It
locks Entitlement first and then the same Reservation, Booking, and Lesson rows
used by Booking lifecycle operations. A schedule-first Booking cannot hold a
Booking row while waiting for Entitlement because it acquires Entitlement
before Reservation/Booking. Revoke never waits for the schedule advisory lock,
so the apparent `schedule -> Entitlement` / `Entitlement -> Booking` overlap has
no return edge. Row locks serialize state validation, and the reverse-order
test forces schedule-first and Entitlement-first sessions to prove the valid
terminal state.

## Enforcement and change rule

The pgTAP contract enforces:

1. complete explicit mutation inventory and overload counts;
2. justified exemptions;
3. an acyclic resource graph;
4. registered nested calls that exist in live function source; and
5. semantic source markers for critical lock acquisition order.

Whitespace and formatting are normalized before source-order checks. Any new
mutation-capable `SECURITY DEFINER` function, new overload, lock resource, or
nested mutation must update the executable manifest and this document when it
changes the canonical architecture. Application roles still may not execute
private mutating helpers directly, and all trusted functions must retain a safe
`search_path`.
