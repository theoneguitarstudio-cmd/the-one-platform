# Current Work

Read this file first in every new ChatGPT or Codex conversation.

## Current phase

**Epic 7 — Learning Map Core: LOCAL AUTONOMOUS EXECUTION (A–E)**

Approved Planning Baseline **ESTABLISHED** at
`588811d1d5617788b162f4e0a275d64d6a248dce`. The Product Owner subsequently
authorized autonomous LOCAL A → E with a gate after each slice. Work begins
with A contracts, not runtime schema. See [execution contracts](EPIC7_LOCAL_EXECUTION.md)
and [approved scope](EPIC7_SCOPE_DEFINITION.md). Epic 7-F and all remote
deployment/migration/smoke/cleanup remain **NOT AUTHORIZED**.

## Completed P2 baseline

**P2 — Remote Closure of Epic 5 / Epic 6: COMPLETE (2026-09-05)**

Epic 5 and Epic 6 are **REMOTE CLOSED**. Remote Deployment, BR-1/BR-2/BR-3,
migration parity (29 local / 29 remote, no differences), both production smoke
runs, and closure documentation are complete. Remote latest is `20260904001100`.
The verified execution baseline is `899906b556b4dc282538920baec8cdfb0546f6df`.
See [Project Status](PROJECT_STATUS.md) and
[P2 Remote Closure Evidence](P2_REMOTE_CLOSURE_EVIDENCE.md).

## Next canonical step

Complete A technical contracts, then proceed B → C → D → E only after each
local gate passes. Security/integrity/canonical warnings stop execution.
Local commits are authorized; no push before E closure. Stop after E for the
operator remote gate. Preserve [Canonical Roadmap](CANONICAL_ROADMAP.md)
numbering and accepted Product Decisions.

Production payment-provider webhook processing is **NOT COMPLETE**. It blocks
full production payment closure, not this completed schema/smoke remote closure.
Future remote operations still require fresh backup/recovery and approval gates.
Never modify an applied migration, including `20260901000600`.
