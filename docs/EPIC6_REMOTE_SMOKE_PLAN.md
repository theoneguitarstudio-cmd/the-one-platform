# Epic 6 Remote Smoke Runbook

Status: **PRODUCTION SMOKE PASS — Epic 6 REMOTE CLOSED (2026-09-05)**.
Run `epic6-smoke-20260905144629-8e8710f0`: 16 PASS / 0 FAIL / 0 SKIP;
Security, Cleanup, and Overall PASS; operational/unexpected residue 0 and
immutable expected evidence 0. See
[P2 Remote Closure Evidence](P2_REMOTE_CLOSURE_EVIDENCE.md).
Any future run still requires target, migration, backup, and operator approval
to be confirmed again; this result is not permission to rerun production smoke.

Before `-Execute`, `BackupConfirmed` means BR-1, BR-2, and BR-3 have all passed
under the canonical
[Remote Backup and Recovery Runbook](REMOTE_BACKUP_RECOVERY_RUNBOOK.md) and a
secret-free evidence record exists. The switch alone is not confirmation.

## Before

Record and verify all of the following before a remote run:

- the exact Git SHA being tested;
- the supplied, expected, and currently linked Supabase project refs are equal;
- the intended environment is `staging`, `recovery`, or `production`;
- the remote latest migration is exactly `20260904001100`;
- a suitable backup or recovery point has been confirmed separately;
- the operator has explicitly approved this run.

The harness never relinks a project. Production is denied unless the additional
`-AllowProduction` switch is supplied. A linked project alone is not approval.

## Commands

Static validation, with no database access:

```powershell
.\scripts\remote-smoke-test-epic6.ps1 -ValidateOnly
```

Local Supabase validation:

```powershell
.\scripts\remote-smoke-test-epic6.ps1 -LocalValidation
```

Future staging or recovery execution (do not run until remotely approved):

```powershell
.\scripts\remote-smoke-test-epic6.ps1 `
  -ProjectRef '<target-project-ref>' `
  -ExpectedProjectRef '<target-project-ref>' `
  -Environment staging `
  -BackupConfirmed `
  -OperatorApproved `
  -Execute
```

Production additionally requires `-Environment production -AllowProduction`.
Never place a database password, JWT, service-role key, or payment secret in the
command or evidence artifact.

## Preflight and STOP conditions

Before fixture setup the runner checks project identity, environment intent,
production approval, migration parity, required RPC signatures, RLS, raw table
mutation grants, private helper execution grants, and SECURITY DEFINER
`search_path`. It fails closed and performs no smoke fixture work if any check
does not match.

The search-path predicate is symmetrical with Epic 5: application functions
require an empty path, with only the verified RLS event-trigger exception
specified in [Security](SECURITY.md#remote-smoke-search-path-exception).

Stop on project-ref mismatch, missing intent or approval, an unconfirmed backup,
migration drift, a missing RPC, a security finding, fixture failure, any failed
case, cleanup failure, or non-zero residue. Do not relink, weaken a check, or
continue to another environment.

## Fixture and privilege model

Each execution gets a unique `run_id`. Synthetic `example.invalid` users and all
fixture labels, operation keys, products, orders, entitlements, series, cycles,
bookings, holds, renewals, and Makeup Rights are traceable to that run.

Fixture bootstrap uses privileged direct inserts only to create isolated actors,
roles, relationships, initial test products/entitlements, credit allocation, and
deliberately stale defensive-test states. Business mutations use the formal
authenticated Admin, Teacher, and Student SECURITY DEFINER RPCs. `service_role`
is used only for the formal fulfillment and fixed-cycle attachment RPCs; the
harness does not rely on generic `service_role` table mutation.

It never changes `session_replication_role`, disables triggers or RLS, truncates
tables, or performs broad cleanup deletes.

## Cases

| ID | Assertion |
| --- | --- |
| E6-RS-001 | Flexible booking creation, reschedule, and completion path |
| E6-RS-002 | Explicit entitlement source, cancellation, and reservation release |
| E6-RS-003 | Exact duration compatibility; mismatch rejected |
| E6-RS-004 | Fixed priority cannot be taken by an ordinary flexible booking |
| E6-RS-005 | Recurring occurrence refresh is idempotent |
| E6-RS-006 | IANA timezone recurrence maps local weekday/wall time to correct UTC |
| E6-RS-007 | Compatible entitlement attaches an active fixed cycle and preferred pointer |
| E6-RS-008 | Checkout hold exclusivity prevents a second active holder |
| E6-RS-009 | Fulfillment-linked renewal creates the next cycle and retains priority |
| E6-RS-010 | Teacher cancellation creates exactly one Makeup Right |
| E6-RS-011 | Makeup booking reserves the Right without ordinary credit |
| E6-RS-012 | Cancellation restores the same Right without duplicate compensation |
| E6-RS-013 | Entitlement revoke reconciles booking, lesson, and reservation |
| E6-RS-014 | Entitlement revoke invalidates cycle, clears pointer, and retains series |
| E6-RS-015 | Reschedule rejects a revoked value source without partial mutation |
| E6-RS-016 | Completion rejects a released value source without partial mutation |

## Cleanup and zero residue

The entire synthetic lifecycle runs inside an exception-backed PostgreSQL
subtransaction. Success deliberately raises the dedicated
`EPIC6_REMOTE_SMOKE_ROLLBACK` sentinel; real failures also roll back the same
subtransaction. The runner recognizes success only when the sentinel includes
all 16 case markers.

An independent post-run query checks both categories even after a SQL failure:

- operational residue must be `0`, including users, bookings, lessons,
  entitlements, reservations, series, cycles, active holds, Makeup Rights,
  orders, and synthetic products;
- expected immutable evidence must be `0`, including ledger, audit, entitlement
  expiry, and fulfillment snapshot rows owned by the run namespace.

Because rollback is the cleanup boundary, no destructive remote cleanup authority
or deletion of immutable financial/audit history is required.

## Expected result and evidence

A successful run prints `# Epic6 Remote Smoke Result` with project ref, Git SHA,
migration, run ID, environment, timestamps, case counts, security, cleanup,
residue, and overall status. It also writes:

`artifacts/remote-smoke/<run_id>/epic6-remote-smoke.json`

The ignored local artifact contains machine-readable cases, errors, cleanup,
residue, security results, and timestamps. It must contain no secrets, tokens,
passwords, service-role credentials, or real-user data. Preserve the JSON with
the deployment evidence; do not commit runtime artifacts.
