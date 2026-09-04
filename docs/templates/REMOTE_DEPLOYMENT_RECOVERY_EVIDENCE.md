# Remote Deployment Recovery Evidence

This record is secret-free. Do not include credentials, connection strings,
tokens, database dumps, or personal data. Complete it under the canonical
[Remote Backup and Recovery Runbook](../REMOTE_BACKUP_RECOVERY_RUNBOOK.md).

## Deployment identity

- Deployment ID:
- Environment:
- Git SHA:
- `origin/main` SHA:
- Project Ref:
- Project Name:
- Region:
- Start Time (UTC):
- End Time (UTC):
- Operator Identity:
- Operator Approval Reference:

## Backup and restore gates

- BR-1 Backup Capability: PASS / FAIL
- Backup Type: managed daily / PITR / verified manual logical
- Backup Timestamp or Recovery Point (UTC):
- Backup Status and Evidence Reference:
- Retention Window:
- PITR: enabled / disabled / unknown
- PITR Earliest Recovery Point (UTC):
- PITR Latest Recovery Point (UTC):
- BR-2 Backup Freshness: PASS / FAIL
- Accepted RPO and Approval Reference:
- BR-3 Restore Readiness: PASS / FAIL
- Restore Path: Dashboard / approved Management API / verified logical restore
- Restore Target: in-place / named recovery project
- Overwrites Existing Project: yes / no
- Expected Downtime:
- DNS/Application/Storage/Auth/Realtime Implications:
- Recovery Operator:

## Migration and application state

- Remote Latest Before:
- Planned Migrations:
- Planned Latest After:
- Application Release Before:
- Application Rollback Release:
- Old Application Compatibility: PASS / FAIL / UNKNOWN
- Preflight Evidence Reference:

## Result and recovery

- Result: PASS / STOPPED / FAILED
- Remote Latest After:
- Application Release After:
- Smoke Evidence Reference:
- Incident: none / incident reference
- Recovery Class: R0 / R1 / R2 / R3 / R4 / R5 / R6
- Write Freeze: not required / scoped / full
- Recovery Action:
- Forward-Fix Migration or Release:
- Reopen Approval and Time (UTC):
- Notes:
