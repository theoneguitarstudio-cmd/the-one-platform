# MIGRATION PLAN

Status: Draft

## Applied P2 remote state — 2026-09-05

Remote Deployment: **PASS** for project `ygxeihtcolpiulupieeq`.
Parity: **29 local / 29 remote; local-only 0 / remote-only 0**.
Latest: `20260904001100_harden_commerce_service_role_authority.sql`.
BR-1/BR-2/BR-3 and both production smoke gates passed; Epic 5 and Epic 6 are
**REMOTE CLOSED**. See [P2 Remote Closure Evidence](P2_REMOTE_CLOSURE_EVIDENCE.md).
The remaining Draft/PRD sections concern future migration planning, not a
pending P2 deployment. Applied migrations were not edited during reconciliation.

## Epic7 local chain — 2026-09-06

Epic7 A–E are LOCAL CLOSED. Five additive migrations `20260906000100` through
`20260906000500` create content/version/activity foundations and the freeze
graph check. Repository and isolated local chains are **34**; original 29
files remain unchanged. No legacy Stage rekey, backfill, data conversion,
existing domain rewrite or commercial data mutation is part of these migrations.

Clean rebuild and populated 29 → 34 upgrade PASS; 13 populated legacy/business
snapshots are identical after upgrade. Function/trigger lint, RLS/grants and
full SQL regressions PASS. See [local evidence](EPIC7_LOCAL_EXECUTION.md).
The new 002 file retains two whitespace-only lines because it was applied
locally; no historical migration is rewritten for formatting.

Remote last verified state remains the historical P2 29-file chain above;
it was not queried or changed. Epic7-F is NOT AUTHORIZED. Fresh
Git/target/parity/recovery gates and a reviewed Epic7 smoke/cleanup plan are
required before an operator authorizes remote execution.

## Purpose

Plan approved data and system migrations without introducing production data into this repository.

## Remote deployment gate

Every remote migration requires BR-1, BR-2, and BR-3 to pass under the
canonical [Remote Backup and Recovery Runbook](REMOTE_BACKUP_RECOVERY_RUNBOOK.md),
with a completed
[recovery evidence record](templates/REMOTE_DEPLOYMENT_RECOVERY_EVIDENCE.md).
An applied migration is never edited; partial or completed remote changes use a
new forward-fix migration.

## Pending formal PRD input

To be completed from the approved formal PRD.
