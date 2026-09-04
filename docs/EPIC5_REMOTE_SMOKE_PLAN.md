# Epic 5 Remote Smoke Runbook

## Purpose and scope

This harness verifies the deployed Epic 5 authority chain from paid commerce
fulfillment through Entitlement creation, explicit-source lesson credit
reservation, release, consumption, revocation, duration snapshots, and
append-only economic history. Epic 6 owns broader Booking, recurring, Fixed,
Renewal, and Makeup coverage; this harness includes only the minimum downstream
assertions needed to prove Epic 5 value-source integrity.

Remote execution is an operator-controlled closure activity. The harness added
by P2-4B is implemented and validated locally; it must not be run remotely as
part of implementation review.

Before `-Execute`, `BackupConfirmed` means BR-1, BR-2, and BR-3 have all passed
under the canonical
[Remote Backup and Recovery Runbook](REMOTE_BACKUP_RECOVERY_RUNBOOK.md) and a
secret-free evidence record exists. The switch alone is not confirmation.

## Safety model

The PowerShell wrapper and Node runner use the shared Epic 5/Epic 6 target gate.
Every remote run requires all of the following:

- explicit `ProjectRef` and independently supplied `ExpectedProjectRef`;
- an existing linked project with the same ref (the harness never relinks);
- `Environment` equal to `staging`, `recovery`, or `production`;
- `BackupConfirmed`, `OperatorApproved`, and `Execute` switches;
- `AllowProduction` in addition to every other gate for production;
- latest remote migration exactly `20260904001100`;
- a clean security preflight.

A linked production project is denied by default. No service-role key, database
password, payment provider secret, or real user data is an input.

The `.sql.template` extension keeps the remote payload outside pgTAP discovery;
only the gated runner may execute it. The SQL payload is one statement.
Synthetic fixture bootstrap and all domain
operations run inside a PL/pgSQL subtransaction. A mandatory success sentinel
raises an exception that rolls the entire subtransaction back. The runner then
executes an independent run-scoped residue query. It never changes replication
role, disables RLS or triggers, bypasses constraints, truncates tables, or
deletes immutable history.

## Required environment and project identity

- Repository dependencies installed, including the repository Supabase CLI.
- Node.js available on `PATH`.
- Supabase project already linked by an operator.
- Backup or PITR readiness independently confirmed before any remote run.
- Remote schema fully migrated through `20260904001100`.

The synthetic namespace is `remote-smoke-epic5-<timestamp>-<uuid>`. Emails,
Product slugs, idempotency keys, provider event IDs, reasons, and artifacts use
the run ID so retries do not collide.

## Commands

Static validation only:

```powershell
./scripts/remote-smoke-test-epic5.ps1 -ValidateOnly
```

Optional local execution against an already running, fully migrated local
Supabase stack:

```powershell
./scripts/remote-smoke-test-epic5.ps1 -LocalValidation
```

Future authorized staging or recovery execution:

```powershell
./scripts/remote-smoke-test-epic5.ps1 `
  -ProjectRef '<target-project-ref>' `
  -ExpectedProjectRef '<target-project-ref>' `
  -Environment staging `
  -BackupConfirmed `
  -OperatorApproved `
  -Execute
```

Production additionally requires `-Environment production -AllowProduction`.
Providing only `-Execute`, relying only on the linked project, or omitting
backup/operator confirmation fails closed.

## Case manifest

| ID | Assertion |
| --- | --- |
| E5-RS-001 | Fulfillment creates a compatible Entitlement. |
| E5-RS-002 | Duplicate fulfillment creates no duplicate value. |
| E5-RS-003 | Reservation uses the explicitly supplied Entitlement. |
| E5-RS-004 | Multiple active packages never trigger FIFO fallback. |
| E5-RS-005 | Reserve writes the correct ledger movement. |
| E5-RS-006 | Release is idempotent and writes one movement. |
| E5-RS-007 | Consume writes the correct ledger movement. |
| E5-RS-008 | Repeated consume writes no duplicate movement. |
| E5-RS-009 | An invalid Entitlement source is rejected. |
| E5-RS-010 | Purchase-time duration survives later Product changes. |
| E5-RS-011 | A downstream duration mismatch is rejected atomically. |
| E5-RS-012 | Revocation reaches the terminal revoked state. |
| E5-RS-013 | A repeated revoke key produces one operation and audit. |
| E5-RS-014 | Revoke reconciles future ordinary reservation/Booking/Lesson state. |
| E5-RS-015 | Ledger and revoke-operation history retain immutable semantics. |

Synthetic users, profiles, relationships, scheduling availability, Products,
and one completed Lesson are infrastructure fixtures. Checkout, payment
confirmation, fulfillment, Entitlement creation, credit movement, Booking, and
revocation use the public SECURITY DEFINER domain operations. The payload never
directly mutates Entitlements, reservations, ledger, payments, fulfillment
events/snapshots, or revoke operations.

## Security preflight

Execution stops unless every required RPC exists, every protected table has RLS
enabled, authenticated has no generic raw mutation grant, service_role has no
high-risk commerce/credit raw mutation grant, application roles cannot execute
private mutation helpers, and all inspected SECURITY DEFINER functions pin an
empty search path.

## Evidence

The console prints `# Epic5 Remote Smoke Result`. A secret-free JSON artifact is
written under `artifacts/remote-smoke/<run-id>/epic5-remote-smoke.json` with:

- run ID, project ref, environment, Git SHA, and latest migration;
- all case results and errors;
- security and cleanup status;
- operational residue, bounded expected immutable evidence, and unexpected
  evidence counts;
- start and end timestamps.

The generated runtime SQL is stored in the same run directory for local operator
review. It contains synthetic identifiers only and no credentials.

## Cleanup and residue policy

The required cleanup outcome comes from transaction rollback, rather than
destructive DELETE statements. Operational residue must be zero: no synthetic
users, Products, Orders, active Entitlements, active reservations, Bookings, or
Lessons may remain.

Immutable ledger, fulfillment, payment, revoke-operation, snapshot, and audit
rows are classified separately. The rollback strategy normally leaves their
count at zero. If a future approved execution model intentionally commits
terminal history, it must remain run-scoped and bounded by the validator;
unexpected evidence must always be zero. Immutable history must never be
deleted merely to make cleanup appear successful.

## STOP conditions

Stop immediately on a wrong or missing project ref, production without the
explicit production flag, missing backup/operator confirmation, migration
mismatch, security failure, missing RPC, fixture setup failure, case failure,
missing rollback sentinel, cleanup failure, operational residue, or unexpected
evidence. Do not relink, weaken security, reset a remote database, or retry with
bypass SQL.
