# Current Work

Read this file first in every new ChatGPT or Codex conversation.

## Current phase

**Epic 7 — Learning Map Core: LOCAL CLOSED (A–E); F LOCAL READINESS TOOLING COMPLETE; STOP BEFORE PRODUCTION**

Approved Planning Baseline **ESTABLISHED** at
`588811d1d5617788b162f4e0a275d64d6a248dce`. The Product Owner subsequently
authorized autonomous LOCAL A → E with a gate after each slice. A–E are complete
locally; non-blocking format/build-environment warnings are recorded in
[execution contracts and closure evidence](EPIC7_LOCAL_EXECUTION.md)
and [approved scope](EPIC7_SCOPE_DEFINITION.md). Subsequently authorized F local
tooling/rehearsal is complete; see [current evidence](EPIC7_F_LOCAL_TOOLING_EVIDENCE.md).
Push and all production backup/restore/deployment/migration/smoke/cleanup remain **NOT AUTHORIZED**.

## Completed P2 baseline

**P2 — Remote Closure of Epic 5 / Epic 6: COMPLETE (2026-09-05)**

Epic 5 and Epic 6 are **REMOTE CLOSED**. Remote Deployment, BR-1/BR-2/BR-3,
migration parity at that historical gate (29 local / 29 remote, no differences), both production smoke
runs, and closure documentation are complete. Remote latest is `20260904001100`.
The verified execution baseline is `899906b556b4dc282538920baec8cdfb0546f6df`.
See [Project Status](PROJECT_STATUS.md) and
[P2 Remote Closure Evidence](P2_REMOTE_CLOSURE_EVIDENCE.md).

## Next canonical step

Post-preservation update (2026-09-07 Asia/Taipei): the original F tools/evidence
were saved locally at `c61cdb6c757499b875fc9e9f41657f8b2c1a4ef1`, not pushed.
The tested application/migration candidate remains `d5f98434106797afc65c59953aa3bc61ba26ecb4`.
Use `node scripts/epic7-preserved-validation.mjs --validate-only` for fixed-content
offline verification after preservation; prerequisites and limitations are in
[the appended verification record](EPIC7_F_LOCAL_TOOLING_EVIDENCE.md).
Recovery drill versus service recovery and per-branch coverage/retention proposals
are now explicit in the linked existing documents; all remain NOT APPROVED.
The following uncommitted wording describes the original preparation snapshot.

STOP for review of the uncommitted F local tools, [37-case coverage](EPIC7_F_CASE_COVERAGE.md)
and [recovery authorization package](EPIC7_RECOVERY_AUTHORIZATION_PACKAGE.md).
All 34 migration files remain unchanged. Previous F read-only evidence confirms remote 29,
latest `20260904001100`; this local-tooling task did not query or modify production.
User-provided GitHub screenshots confirm Vercel App installation for
theoneguitarstudio-cmd and Repository access = All repositories. Actual hosting
project/repository/branch linkage and main-push deployment behavior remain unverified.
Do not request the same GitHub authorization page again. Local commits/tools have not been pushed.
Next: review production coverage/retention, named recovery operator/encryption/RPO and
exact backup/isolated-restore scope before any separate authorization. Do not start Epic8–13.
Preserve [Canonical Roadmap](CANONICAL_ROADMAP.md) numbering and Product Decisions.

Production payment-provider webhook processing is **NOT COMPLETE**. It blocks
full production payment closure, not this completed schema/smoke remote closure.
Future remote operations still require fresh backup/recovery and approval gates.
Never modify an applied migration, including `20260901000600`.
