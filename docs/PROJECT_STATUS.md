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
| Epic 5 | Entitlement & Lesson Credit | **REMOTE CLOSED** |
| Epic 6 | Scheduling & Booking | **REMOTE CLOSED** |

The verified production smoke baseline is branch `main`, with Git `HEAD` and
`origin/main` at `899906b556b4dc282538920baec8cdfb0546f6df` (ahead/behind 0/0).
This documentation reconciliation follows that execution baseline.

## Remote closure state

- **P2 Remote Closure: COMPLETE — 2026-09-05**.
- Remote Deployment: **PASS**, target `ygxeihtcolpiulupieeq`.
- Migration parity: **29 local / 29 remote; local-only 0 / remote-only 0**.
- Local and remote latest: `20260904001100`
  (`20260904001100_harden_commerce_service_role_authority.sql`).
- Backup/recovery: **BR-1 PASS / BR-2 PASS / BR-3 PASS** at the approved
  operation gates, using the verified logical recovery method. Freshness must
  be rechecked for any future operation; no restore was rerun for closure docs.
- Epic 5 production smoke: **15 PASS / 0 FAIL / 0 SKIP; Overall PASS**.
  Run: `remote-smoke-epic5-20260905140007-98c7d02e`.
  Security PASS; Cleanup PASS; operational residue 0; immutable expected
  evidence 0; unexpected evidence 0.
- Epic 6 production smoke: **16 PASS / 0 FAIL / 0 SKIP; Overall PASS**.
  Run: `epic6-smoke-20260905144629-8e8710f0`.
  Security PASS; Cleanup PASS; operational/unexpected residue 0; immutable
  expected evidence 0. Both artifacts contain no errors.
- [P2 Remote Closure Evidence](P2_REMOTE_CLOSURE_EVIDENCE.md) records evidence
  provenance, timestamps, backup metadata, artifact hashes, and gate review.

## Closure decision and next step

The required sequence is complete: backup/restore capability verification →
remote migration preflight → remote deployment → Epic 5 production smoke →
Epic 6 production smoke → closure documentation. Both Epics satisfy the
canonical schema/smoke criteria for **REMOTE CLOSED**.

Next: **Epic 7 — Learning Map Core scope definition and approval** under
[Canonical Roadmap](CANONICAL_ROADMAP.md). Implementation has not started in
this task. No Epic numbering or accepted Product Decision changes are implied.

Non-blocking operational follow-up: retain the external backups and smoke
artifacts, maintain restore drills, and revalidate logical recovery when data
is populated. The circular-FK dump warning involved tables verified empty at
preflight. Managed backup/PITR coverage must not be inferred from logical dumps.

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
