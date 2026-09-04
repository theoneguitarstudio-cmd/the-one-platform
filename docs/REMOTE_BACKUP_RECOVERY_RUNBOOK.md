# Remote Backup and Recovery Runbook

Status: **REMOTE DEPLOYMENT READY RUNBOOK CANDIDATE**

This is the canonical backup and recovery policy for The One 2.0 remote
database deployments. The migration, security, and Epic 5/Epic 6 smoke
documents reference this file instead of defining separate recovery policy.

## Scope and non-negotiable boundaries

This runbook governs remote migration preflight, deployment incidents, remote
smoke failures, and restore drills. It does not authorize a deployment,
database mutation, restore, PITR operation, project relink, or production reset.

- Never edit an applied migration. Correct it with a new migration.
- Never reset, wipe, recreate, or seed production as a recovery technique.
- Application rollback, schema rollback, and data recovery are separate
  decisions. Approval of one does not approve another.
- Preserve orders, payments, fulfillment, entitlements, credit ledger, revoke
  history, and audit history. Do not repair them with ad-hoc `UPDATE` or
  `DELETE` statements.
- The default after any partially or fully applied remote migration is a
  forward-fix.
- A restore is an incident operation of last resort, not a routine response to
  a migration error.

## Current capability audit

Audit date: 2026-09-05 UTC+08:00. This audit used repository files, Supabase CLI
help, a local link ref, and read-only backup metadata. It performed no SQL,
migration, smoke, or restore operation.

| Item | Evidence | Result |
| --- | --- | --- |
| Target project ref | `supabase/.temp/project-ref` | `ygxeihtcolpiulupieeq` |
| Project name | Deployment input says `the-one-platform`; current CLI account did not return the target in `projects list` | **OPERATOR VERIFICATION REQUIRED** |
| Region | Read-only `backups list` metadata | `ap-southeast-1` |
| Physical backup service | Metadata returned `walg_enabled=true` | Capability visible; this is not proof of a usable restore point |
| Available physical backups | Metadata returned an empty backup list | No usable listed backup was proven |
| PITR | Metadata returned `pitr_enabled=false` | Not enabled at audit time |
| Subscription/retention | Not available from repository or accessible project metadata | **OPERATOR VERIFICATION REQUIRED** |
| Migration history read | CLI supports `migration list --linked` | Capability confirmed; remote history was not queried in this documentation task |
| Project identity read | CLI supports `projects list`; local ref and backup region were readable | Name and account visibility still require operator verification |
| Backup metadata read | CLI supports `backups list --project-ref` | Capability confirmed |

Supabase documents that daily managed backups are available for Pro, Team, and
Enterprise projects with plan-specific retention, while PITR is a paid add-on
and replaces daily backups while enabled. The current plan and an actual
restorable checkpoint must be verified at deployment time. See the official
[Database Backups](https://supabase.com/docs/guides/platform/backups),
[PITR usage](https://supabase.com/docs/guides/platform/manage-your-usage/point-in-time-recovery),
and [restore-to-new-project](https://supabase.com/docs/guides/platform/clone-project)
documentation.

As documented on 2026-09-05, Pro retains 7 days of daily backups, Team 14
days, and Enterprise up to 30 days. Free projects do not receive that managed
daily-backup guarantee and are advised to maintain off-site logical exports.
PITR can be enabled as an add-on on Pro, Team, and Enterprise and requires at
least Small compute; its retention is separately configured. These are
platform capabilities, not evidence of this project's plan or entitlement.
Recheck the official documentation and target Dashboard before each deployment.

Database backups do not restore Storage objects. A restore to a new project is
database-only and requires application/platform reconfiguration. An in-place
restore makes the project inaccessible during restoration. These boundaries
must be included in the recovery decision and downtime plan.

### Read-only verification procedure

Before seeking deployment approval, an operator must:

1. Match the supplied ref against the local link and the target shown in the
   Supabase Dashboard; record its name and region.
2. Open **Database > Backups** for that exact project or use the read-only
   `supabase backups list --project-ref <ref>` command. Record a completed
   backup timestamp; an empty list does not pass BR-1.
3. If PITR is enabled, record its earliest and latest recovery points and the
   configured retention. Never infer PITR from WAL-G capability.
4. Read remote migration history with `supabase migration list --linked` and
   compare it to the reviewed local chain. This command requires an already
   linked project; this runbook never authorizes relinking.
5. Identify the approved Dashboard or Management API restore procedure and
   target. Do not execute it during preflight.

During an approved R6 recovery, keep writes frozen, select a recovery point
before the first known bad transaction, record the accepted data-loss window,
and obtain a second operator's approval before starting an in-place restore or
restore-to-new-project operation. After completion, verify migration parity,
roles/grants/RLS, integrity counts, application connectivity, and smoke results
before reopening writes. The actual restore action always requires a separate
incident authorization.

## Required deployment evidence

Copy [the recovery evidence template](templates/REMOTE_DEPLOYMENT_RECOVERY_EVIDENCE.md)
for every remote deployment. Record evidence before execution and complete the
result fields afterward. A checkbox, CLI flag, or verbal statement alone is
not backup confirmation.

Required pre-deployment fields are:

- deployment ID, current UTC time, environment, and operator approval reference;
- local Git `HEAD`, `origin/main`, and application release before deployment;
- exact project ref, project name, and region from an authorized source;
- current remote latest migration and every planned migration;
- backup type, successful recovery-point timestamp, retention window, and
  evidence reference;
- PITR status and earliest/latest recovery points when enabled;
- restore location, restore target, overwrite behavior, expected downtime,
  DNS/application implications, and responsible operator;
- application rollback release and a recorded compatibility decision.

## Deployment backup gates

All three gates must be `PASS`. `UNKNOWN`, missing evidence, or
`OPERATOR VERIFICATION REQUIRED` is a failure and a STOP condition.

### BR-1 — Backup capability

`PASS` requires at least one currently usable restore path:

1. a completed managed daily backup visible for the exact target project;
2. enabled PITR with an acceptable recovery point inside the active retention
   window; or
3. a verified manual logical backup when managed recovery is unavailable.

Managed recovery is preferred. A logical dump is a fallback only when its
creation completed, its scope and encrypted storage location are recorded, and
a non-production restore drill has proven it usable. `walg_enabled`, a paid
plan, or the presence of a Backups page does not by itself pass BR-1.

### BR-2 — Backup freshness

Default maximum age is **24 hours before migration execution**, measured from
the successful backup or recovery point in UTC. This value is configurable by
the release owner only when a stricter product RPO is documented. A deployment
that reconciles existing data, changes financial/credit invariants, or has
significant writes during that 24-hour window requires a recovery point no more
than **1 hour old**, or a written incident-owner exception that states the
maximum accepted data loss.

For PITR, record both the requested recovery time and the latest available
recovery point; do not assume the UI clock equals recoverable WAL coverage. If
freshness cannot be proved, BR-2 fails.

### BR-3 — Restore readiness

`PASS` requires a named operator and a written path that answers all of these:

- Will restoration run in the Supabase Dashboard or through an approved
  Management API procedure?
- Will it overwrite the existing project or restore to a new recovery project?
- Is the chosen timestamp available, and does the path support PITR?
- What downtime and write freeze are expected?
- How will application traffic, DNS/custom domains, connection strings, Auth,
  Storage objects, Edge Functions, Realtime settings, extensions, replicas,
  and secrets be handled?
- How will migration parity, security checks, application connectivity, and
  Epic 5/Epic 6 smoke be verified before reopening writes?

An untested or unspecified destination fails BR-3. Never discover the restore
procedure during an active deployment.

## Recovery classes

| Class | Trigger | Required response |
| --- | --- | --- |
| **R0 — No-impact failure** | Dry run/preflight fails, project ref is wrong, or execution never began | STOP; preserve evidence; correct locally; no rollback |
| **R1 — Failed before apply** | Migration was not marked applied and its transaction rolled back completely | STOP; inspect error and catalog; reproduce and fix locally; schedule a new attempt |
| **R2 — Partially applied sequence** | Some migration files succeeded before a later file failed, or catalog/history state is uncertain | STOP; inspect migration list and catalog at the exact boundary; assess app compatibility; use a new forward-fix migration |
| **R3 — Schema applied, app failed** | Database deployment succeeded but application deployment or startup failed | Test backward compatibility; roll back the app only if every compatibility check passes; otherwise forward-fix |
| **R4 — Data consistency defect** | Orphan booking, wrong entitlement, fixed-priority corruption, financial mismatch, repeated integrity failure, or partial writes | Stop affected writes; enter incident mode; preserve evidence; choose approved domain repair, scoped repair migration, or PITR/restore evaluation |
| **R5 — Security regression** | RLS disabled, grant leakage, raw service-role authority, private helper exposure, or authorization bypass | Stop rollout and affected writes immediately; restrict exposure through an reviewed security forward-fix; preserve audit evidence |
| **R6 — Widespread/irrecoverable corruption** | Controlled forward repair cannot establish integrity within the incident window | Freeze writes and evaluate managed restore/PITR with incident approval, accepted data-loss window, and BR-3 plan |

Migration files are separate deployment units; a sequence is not one
cross-file transaction. Never infer that earlier files rolled back because a
later file failed.

## Schema rollback policy

Potentially reversible objects include a new unused nullable column, unused
index, new function, or new policy. Reversal still requires proof that no app
or data depends on it and must be delivered as a new reviewed migration.

The following are normally **FORWARD-FIX ONLY**:

- enum value additions;
- reconciliation or destructive data transforms;
- immutable history and economic events;
- schema behavior already consumed by an application;
- data written under a new invariant;
- any change whose inverse would discard or reinterpret valid data.

In this migration chain,
`20260904000400_integrate_makeup_rights_with_booking.sql` adds the `makeup`
booking source enum value, and
`20260904000700_reconcile_fixed_cycles_on_entitlement_revoke.sql` adds the
`invalidated` fixed-cycle enum value. Both are explicitly
**FORWARD-FIX ONLY** unless a separately reviewed manual recovery plan proves a
safe path.

## Data rollback policy

Production data correction is allowed only through:

- an approved managed restore or PITR incident procedure;
- a reviewed, scoped, idempotent repair migration with before/after evidence;
- an approved domain correction RPC that preserves authorization and audit.

Manual ad-hoc deletion, direct ledger updates, payment history edits, and
deletion of fulfillment, revoke, or audit history are prohibited. Snapshot the
affected identifiers and counts before a controlled repair, verify invariants
afterward, and retain the evidence without personal data or secrets.

## Migration history policy

Never delete a migration history row, insert a fake applied row, or edit an
applied migration file. `migration repair` is an **EXCEPTIONAL OPERATION**. It
requires complete migration/catalog evidence, explicit human approval, a
verified actual schema state, an incident record, and an exact statement of why
history metadata is wrong. It must not be used to make an unexplained mismatch
disappear.

## Forward-fix procedure

When any migration was partially or fully applied:

1. Stop deployment and remote smoke.
2. Preserve logs, timestamps, Git SHA, migration output, and catalog evidence.
3. Confirm applied migrations and the exact failed boundary.
4. Confirm schema, grants, constraints, functions, and relevant data state.
5. Classify R0-R6 and decide whether affected writes must freeze.
6. Reproduce the state locally without copying production personal data.
7. Add a **new** migration; do not edit an applied file.
8. Run the full local DB suite plus relevant concurrency and security tests.
9. Review the forward-fix and recovery impact with the deployment operator.
10. Re-run BR-1 through BR-3, then deploy only under a new approval.

## Application rollback policy

Application rollback is allowed only after proving that the old release:

- does not write an incompatible row shape;
- does not depend on privileges that the new schema revoked;
- does not bypass a new domain RPC or authorization boundary;
- understands every enum and lifecycle state it may read;
- cannot create data that violates the new constraints or invariant.

If any answer is `UNKNOWN`, do not roll back the application. Keep traffic
stopped or restricted and use a forward-fix or compatible application release.

## Production write-freeze decision

Consider immediate maintenance mode or a scoped write freeze for financial or
entitlement corruption, booking-source corruption, repeated integrity errors,
partial writes, security regression, or any defect that can compound with each
request. Freeze the smallest proven-safe scope only when isolation is reliable;
otherwise freeze all writes. Record start time, affected routes/workers,
operator, customer impact, and reopen criteria. Do not reopen writes until the
relevant invariants, security catalog, and application path pass verification.

## Formal STOP conditions

Stop before or during deployment when any of these occurs:

- wrong project ref or environment;
- a migration exists remotely but not in the reviewed repository;
- migration history mismatch, schema drift, or unexpected migration;
- backup unavailable, backup stale, or restore path unknown;
- preflight invalid count or security catalog regression;
- migration, constraint, or integrity failure;
- partial writes or an uncertain transaction boundary;
- remote smoke case, rollback sentinel, cleanup, or residue failure;
- missing operator approval or incomplete evidence;
- unknown application rollback compatibility.

After STOP: preserve evidence, prevent further deployment, classify R0-R6, and
follow the matching procedure. Do not relink, weaken checks, reset production,
repair history speculatively, or retry with bypass SQL.

## Recovery decision tree

```text
Did execution begin?
├─ No → R0 → preserve evidence → fix locally → retry under new approval
└─ Yes
   ├─ Migration failed
   │  ├─ Not applied and transaction fully rolled back → R1 → inspect → fix locally
   │  └─ Any earlier/partial apply or uncertainty → R2 → inspect history/catalog
   │     → compatibility check → forward-fix
   └─ Migration succeeded
      ├─ App failed
      │  ├─ Old app proven compatible → R3 → application rollback may proceed
      │  └─ Compatibility false/unknown → R3 → forward-fix or compatible release
      ├─ Security regression → R5 → freeze affected writes → security forward-fix
      └─ Data defect
         ├─ Localized and domain/scoped repair is safe → R4 → controlled repair
         └─ Widespread or irrecoverable → R6 → write freeze → PITR/restore evaluation
```

## Remote smoke failure policy

If Epic 5 or Epic 6 remote smoke fails after migrations applied:

1. Stop closure and do not start the next environment.
2. Preserve the JSON artifact, console output, run ID, Git SHA, migration, and
   residue evidence without secrets.
3. Let the harness transaction rollback complete and run its independent
   residue check. If cleanup fails, treat it as an incident; use only an
   approved run-scoped cleanup for mutable fixtures and never delete immutable
   economic/audit history to make the result look clean.
4. Classify the failure as harness, application, schema, or data compatibility.
5. Choose a new forward-fix or harness correction after local reproduction.

A smoke failure does not authorize wholesale database rollback or restore.

## Restore drill policy

Run a periodic restore drill in a staging or dedicated recovery project; a
quarterly cadence is the initial configurable default and after any material
recovery-platform change. Never use production as the drill target. The drill
must verify backup usability, chosen recovery point, migration parity, security
catalog, application connection, Storage/configuration gaps, and both smoke
harnesses. Record measured RPO/RTO and teardown approval.

No recovery project is established by this repository. Creating one and
performing the first drill are **FUTURE REQUIREMENTS** and require separate
operator approval.

## Secrets and evidence handling

Never commit `.env` files, database passwords, access tokens, service-role
credentials, provider/payment secrets, real-user dumps, or raw production
personal data. Never paste them into issues, documentation, ChatGPT, or Codex.
Secrets may exist only in an approved local environment, secret manager, or
hosting environment variable store. Documentation and evidence name variables
but never include their values. Redact connection strings and review artifacts
before retention.
