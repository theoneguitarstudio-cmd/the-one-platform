# MIGRATION PLAN

Status: Draft

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
