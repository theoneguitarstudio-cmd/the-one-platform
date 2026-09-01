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
