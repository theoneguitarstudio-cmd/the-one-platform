# Current Work

Read this file first in every new ChatGPT or Codex conversation.

## Current phase

**Epic 7 — Learning Map Core: LOCAL CLOSED (A–E); STOP AT F OPERATOR GATE**

Approved Planning Baseline **ESTABLISHED** at
`588811d1d5617788b162f4e0a275d64d6a248dce`. The Product Owner subsequently
authorized autonomous LOCAL A → E with a gate after each slice. A–E are complete
locally; non-blocking format/build-environment warnings are recorded in
[execution contracts and closure evidence](EPIC7_LOCAL_EXECUTION.md)
and [approved scope](EPIC7_SCOPE_DEFINITION.md). Epic 7-F and all remote
deployment/migration/smoke/cleanup remain **NOT AUTHORIZED**.

## Completed P2 baseline

**P2 — Remote Closure of Epic 5 / Epic 6: COMPLETE (2026-09-05)**

Epic 5 and Epic 6 are **REMOTE CLOSED**. Remote Deployment, BR-1/BR-2/BR-3,
migration parity at that historical gate (29 local / 29 remote, no differences), both production smoke
runs, and closure documentation are complete. Remote latest is `20260904001100`.
The verified execution baseline is `899906b556b4dc282538920baec8cdfb0546f6df`.
See [Project Status](PROJECT_STATUS.md) and
[P2 Remote Closure Evidence](P2_REMOTE_CLOSURE_EVIDENCE.md).

## Next canonical step

STOP for Product Owner/operator review of Epic7-E local evidence and the five
additive migrations. Local chain: 34; clean rebuild and populated 29 → 34
upgrade PASS. Original 29 files and legacy Stage 1–5 remain unchanged.
Last verified remote chain remains 29, latest `20260904001100`; it was not
queried or changed in this task. Local commits have not been pushed.

Next is separately authorized Epic7-F preparation: review Git/push permission,
exact target/parity, fresh recovery evidence and an Epic7 smoke/cleanup plan
before any remote operation. F remains NOT AUTHORIZED. Do not start Epic8–13.
Preserve [Canonical Roadmap](CANONICAL_ROADMAP.md) numbering and Product Decisions.

Production payment-provider webhook processing is **NOT COMPLETE**. It blocks
full production payment closure, not this completed schema/smoke remote closure.
Future remote operations still require fresh backup/recovery and approval gates.
Never modify an applied migration, including `20260901000600`.
