# Epic 6 Remote Smoke Test Plan

Status: prepared only. Do not run until the Epic 6 migration has passed human
pre-push review and has been explicitly approved for the linked remote project.

Use timestamped `example.invalid` users and test-only UUIDs. Privileged fixture
creation and cleanup may use a server-only service role; slot discovery must use
an authenticated Student session, Teacher operations a real Teacher session,
and Admin overrides a real authorized Admin server boundary. Always clean up in
`finally`, deleting only IDs created by the smoke run.

Validate, in order:

1. Teacher settings, weekly availability, unavailable/opening exceptions, lead
   time, horizon, and safe slot DTO fields.
2. Flexible booking, same-key retry, two-Student same-slot race, Student and
   Teacher self-conflicts, explicit entitlement mode/scope, and one shared
   credit reservation/ledger entry.
3. Fixed series, bounded priority claims, overlapping Teacher/Student series
   rejection, fixed-vs-flexible priority, explicit occurrence materialization,
   duplicate materialization, and `credit_required` without partial rows.
4. Series pause/resume/end and one-occurrence release/reschedule while retaining
   history and allowing a renewed package to be selected later.
5. Atomic reschedule race, cancellation with each approved credit outcome,
   Lesson completion with exactly-once credit consumption, meeting join reuse,
   and Trial isolation.
6. Anonymous denial, Student/Teacher cross-access denial, raw DML denial,
   service-role private-helper denial, and authorized Admin override audit.
7. IANA/UTC correctness and local-only DST resolver checks for ambiguous and
   nonexistent `America/New_York` wall times.
8. Cleanup verification: zero smoke users, profiles, roles, relationships,
   entitlements, ledger/reservations, settings/rules/exceptions, series,
   occurrences, bookings, Lessons, Lesson records, and audit rows remain.

Report each case PASS/FAIL plus `40P01`, `23505`, `23P01`, unexpected `23xxx`,
partial-state count, public/participant DTO field lists, and cleanup residue.
