# Project Status

Status date: 2026-09-05

This file is the canonical engineering-status record for The One 2.0. Product
sequencing is canonical in [CANONICAL_ROADMAP.md](CANONICAL_ROADMAP.md), and
accepted product rules are canonical in
[PRODUCT_DECISIONS.md](PRODUCT_DECISIONS.md).

## Epic status

| Epic | Scope | Status |
| --- | --- | --- |
| Epic 0 | Foundation | **CLOSED** |
| Epic 1 | Auth / Roles | **CLOSED** |
| Epic 2 | Teacher Public Discovery | **CLOSED** |
| Epic 3 | Trial Flow | **CLOSED** |
| Epic 4 | Commerce | **CLOSED** |
| Epic 5 | Entitlement & Lesson Credit | **LOCAL CLOSURE CANDIDATE** |
| Epic 6 | Scheduling & Booking | **LOCAL CLOSURE CANDIDATE** |

The handoff baseline for this governance update is Git commit
`f3744472d22e01a509a808b4af4acf48717cbbd2`.

## Remote closure state

- P2-3A Backup / Recovery Runbook: **DONE — PASS WITH WARNINGS**.
- Remote database: **UNCHANGED** by P2-3A and this governance update.
- Remote latest migration reported at handoff:
  `20260901000600_scheduling_booking_core.sql`.
- Local latest migration:
  `20260904001100_harden_commerce_service_role_authority.sql`.
- Local-only migrations after the reported remote boundary: **18**.
- A currently usable backup/restore point has not yet been proven. Deployment
  gates BR-1, BR-2, and BR-3 therefore remain open.

## Remaining closure sequence

1. Operator backup/restore capability verification.
2. Remote Migration Preflight.
3. Remote Deployment.
4. Epic 5 Remote Smoke.
5. Epic 6 Remote Smoke.
6. Closure Documentation.
7. Mark Epic 5 and Epic 6 **REMOTE CLOSED** only after all prior steps pass.

## Production payment boundary

Production payment-provider webhook processing is **NOT COMPLETE**. It does not
block schema migration deployment, but it blocks full production payment
closure.

## AI handoff contract

At the start of a new ChatGPT or Codex conversation, read in this order:

1. [CURRENT_WORK.md](CURRENT_WORK.md)
2. [PROJECT_STATUS.md](PROJECT_STATUS.md)
3. [CANONICAL_ROADMAP.md](CANONICAL_ROADMAP.md)
4. [PRODUCT_DECISIONS.md](PRODUCT_DECISIONS.md)
5. Relevant Epic, security, migration, and domain documents.

Repository documentation is the canonical project source of truth.
Conversation memory is supplemental only. Do not renumber Epic 7+, redefine an
accepted product decision, or promote future scope into a current blocker. If
repository evidence conflicts with this status file, report the discrepancy
instead of guessing or silently changing either source.
