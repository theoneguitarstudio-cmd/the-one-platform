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
