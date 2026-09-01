# Entitlements Module

Epic 5 owns the boundary:

`Commerce → order.paid outbox → Fulfillment → Entitlement → Lesson Credits`

Commerce records what was purchased. Entitlement records a beneficiary's
current commercial right. Learning Achievement remains a separate future
domain. `Credit ≠ Booking ≠ Lesson`.

Lesson packages use a purchase-time configuration snapshot and an append-only
ledger. Available, reserved, and consumed balances are derived from ledger
deltas; reservation rows are an idempotent workflow projection, not the balance
source of truth. Fixed and Flexible scheduling will share this ledger in Epic 6.

The fulfillment consumer is retry-safe and item-granular. Trial commerce remains
the independent Epic 3 source and never receives generic credits in Epic 5.

All mutations re-authorize in PostgreSQL. Fulfillment is service-only, UI
mutations are Server Actions plus authenticated RPC authorization, and raw
ledger/internal fulfillment metadata is not exposed to browser clients.
