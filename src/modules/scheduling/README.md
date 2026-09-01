# Scheduling Module

Owns Epic 6 Teacher availability, safe slot discovery, Flexible Bookings,
Fixed recurring series, bounded priority occurrences, cancellation/reschedule,
and Lesson-credit integration. PostgreSQL remains the scheduling authority;
UI code never calculates final availability or mutates schedule tables directly.

The boundaries are deliberately separate:

`Entitlement / credit ≠ Booking ≠ recurring series ≠ Lesson ≠ billing`.

Recurring rules use local wall-clock time plus an IANA timezone. Priority
occurrences are generated only inside the configured booking horizon. A Lesson
and credit reservation are created lazily for one occurrence with an explicit
eligible entitlement. Ambiguous and nonexistent DST wall times are rejected.

Epic 5 is the sole Lesson Credit invariant authority. Epic 6 delegates reserve,
release, consume, ledger, balance, idempotency, and exhausted-state transitions
to shared private credit cores, then atomically binds a verified reservation to
its Booking. Scheduling code must never insert `lesson_credit_ledger` directly.

Canonical cross-domain locking is: deterministic Student/Teacher schedule
advisory locks → Entitlement → Reservation → Booking → optional recurring
Occurrence → Lesson. Epic 5-only operations begin at Entitlement and still lock
Reservation second. Never introduce a Reservation → Entitlement path.

Teacher mutations require an active account and role plus an existing
`teacher_profiles` row with `teaching_status = 'active'`. Read-only historical
DTOs may remain available under their own authorization; Admin/Super Admin
override does not depend on Teacher teaching status.
