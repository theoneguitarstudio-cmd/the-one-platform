# Current Work

Read this file first in every new ChatGPT or Codex conversation.

## Current phase

**P2 — Remote Closure of Epic 5 / Epic 6**

Done: P2-3A Backup / Recovery Runbook.

Current next step: confirm a currently usable backup and restore path that
passes BR-1, BR-2, and BR-3 in the
[Remote Backup and Recovery Runbook](REMOTE_BACKUP_RECOVERY_RUNBOOK.md).

Then:

`Remote Migration Preflight → Remote Deployment → Epic 5 Remote Smoke → Epic 6 Remote Smoke → Closure Documentation`

Do not start Epic 7 implementation, modify the applied `00600` migration, push
remote migrations before all gates pass, or assume the production payment
provider webhook is complete.
