# P2 Remote Closure Evidence

Status: **COMPLETE — Epic 5 and Epic 6 REMOTE CLOSED (2026-09-05)**.

This secret-free reconciliation supports [Project Status](PROJECT_STATUS.md).
It records completed operations; it does not authorize another deployment,
production smoke, restore, or Epic 7 implementation.

## Identity and evidence provenance

- Environment: production; project ref: `ygxeihtcolpiulupieeq`.
- Execution baseline: `main`, `HEAD = origin/main`, ahead/behind 0/0;
  SHA `899906b556b4dc282538920baec8cdfb0546f6df`.
- Both production JSON artifacts below were inspected directly in this
  documentation task, including all case statuses, security counts, cleanup,
  residue, errors, timestamps, target, migration, and Git SHA.
- Remote Deployment PASS and the completed operational logical restore method
  are confirmed by the operator's P2 closure handoff in this task. BR-3 reuses
  that verified operational evidence; it is not a new restore drill result.
- Earlier safe preflights in this same task history directly verified linked
  identity, migration parity, aggregate counts, successful dump exits, and
  backup file sizes/timestamps. Their results are recorded below.
- No separate deployment execution log or completed recovery-template file was
  found in repository artifacts. Later parity and production smoke corroborate
  deployment; original restore verification relies on the operator handoff.
  No original execution timestamp, restore target, RTO, or approval identifier
  is invented here.
- This documentation task performs no production database operation.

## Canonical closure gate review

Criteria come from [Project Status](PROJECT_STATUS.md), the
[recovery runbook](REMOTE_BACKUP_RECOVERY_RUNBOOK.md), and the
[Epic 5](EPIC5_REMOTE_SMOKE_PLAN.md) / [Epic 6](EPIC6_REMOTE_SMOKE_PLAN.md) runbooks.

| Gate | Result | Evidence |
| --- | --- | --- |
| Backup capability / BR-1 | PASS | Successful external logical dumps; operator-confirmed verified logical recovery method |
| Backup freshness / BR-2 | PASS at operation time | Backup timestamps below are less than one hour before each smoke run |
| Restore readiness / BR-3 | PASS | Existing verified operational restore evidence accepted in operator handoff; no repeat restore |
| Remote migration preflight / deployment | PASS | Operator deployment confirmation plus directly checked 29/29 parity |
| Migration identity | PASS | Local-only 0; remote-only 0; latest `20260904001100` in both production artifacts |
| Epic 5 production smoke | PASS | 15 PASS, 0 FAIL, 0 SKIP; security and cleanup PASS; all residue categories 0 |
| Epic 6 production smoke | PASS | 16 PASS, 0 FAIL, 0 SKIP; security and cleanup PASS; both residue categories 0 |
| Closure documentation | COMPLETE | Canonical status, current work, and operational documents reconciled with this record |

Decision: **Epic 5 = REMOTE CLOSED; Epic 6 = REMOTE CLOSED; P2 = COMPLETE**.
This decision covers the deployed schema and tested domain smoke scope.

## Migration and aggregate evidence

Prior read-only `migration list --linked` checks returned 29 local and 29 remote
versions, with no local-only or remote-only entry. There are 29 local SQL
migration files. Latest on both sides is `20260904001100`, named locally
`20260904001100_harden_commerce_service_role_authority.sql`.

The pre-Epic 6 read-only aggregate (after Epic 5 PASS) returned
`learning_map_stages = 5`; `auth.users`, `public_profiles`, `teacher_profiles`,
`user_roles`, `bookings`, `lesson_credit_reservations`, `lessons`, `entitlements`,
and `orders` were all 0. `makeup_rights` was also checked and was 0.
Post-smoke evidence is the independent run-scoped residue checks below; no
new full-database aggregate is claimed after Epic 6.

## Logical backup evidence

Method: Supabase CLI `db dump --linked --role-only`, `db dump --linked`, and
`db dump --linked --data-only --schema public`, each writing with `-f` outside
the repository. All six dump commands completed successfully. No dump contents,
credentials, or private recovery material are included in Git.

Epic 5 directory: `C:\TheOneBackups\2026-09-05-pre-epic5-smoke-final`.

| File | Bytes | Last write UTC, 2026-09-05 |
| --- | ---: | --- |
| roles.sql | 370 | 13:53:06 |
| schema.sql | 550007 | 13:54:17 |
| data-public.sql | 6914 | 13:54:48 |

Epic 6 directory: `C:\TheOneBackups\2026-09-05-pre-epic6-smoke`.

| File | Bytes | Last write UTC, 2026-09-05 |
| --- | ---: | --- |
| roles.sql | 370 | 14:37:16 |
| schema.sql | 550007 | 14:38:27 |
| data-public.sql | 6914 | 14:39:01 |

The oldest files were about 7 minutes and 9 minutes old at the respective smoke
starts. These are historical freshness results, not perpetual backup approval.
The logical scope is roles, schema, and public data; it does not imply Storage
object coverage, full Auth-data recovery, managed backup retention, or PITR.

Data dumps emitted circular-FK warnings for bookings, reservations, and Makeup
Rights. Those tables were directly verified empty at preflight, so this warning
was accepted as non-blocking for the recorded operations. Revalidate restore
behavior for populated data; do not infer authority to disable production
triggers or drop constraints from pg_dump's generic hints.

## Production smoke artifacts

Raw artifacts remain under ignored `artifacts/remote-smoke/`; retain them with
operator evidence. The SHA-256 values below identify the inspected bytes.

| Field | Epic 5 | Epic 6 |
| --- | --- | --- |
| Run ID | `remote-smoke-epic5-20260905140007-98c7d02e` | `epic6-smoke-20260905144629-8e8710f0` |
| Artifact filename | `epic5-remote-smoke.json` | `epic6-remote-smoke.json` |
| Start UTC | 2026-09-05 14:00:07.214 | 2026-09-05 14:46:29.582 |
| End UTC | 2026-09-05 14:00:23.379 | 2026-09-05 14:46:52.104 |
| PASS / FAIL / SKIP | 15 / 0 / 0 | 16 / 0 / 0 |
| Security / Cleanup / Overall | PASS / PASS / PASS | PASS / PASS / PASS |
| Operational residue | 0 | 0 |
| Immutable expected evidence | 0 | 0 |
| Unexpected evidence/residue | 0 | 0 |
| Errors | empty array | empty array |

Epic 5 SHA-256:
`B7D0892204750908F63D6E0122303127F4A9336DB4ACA1EC7F9052C2749CD9EF`.

Epic 6 SHA-256:
`E0D18C4BD8399EB1A78F35E5585FC889112C383A3ECBEB9EFC024B02F296115A`.

Epic 6 stores `residue.operational=0` and `residue.immutable=0`; its console's
unexpected-residue result corresponds to the operational residue field. It
does not have Epic 5's separate `unexpected` object. Both harnesses require the
rollback sentinel and independent residue checks for success.

## Tooling and remaining boundaries

The execution baseline includes remote `--linked` targeting, whole-document
JSON parsing (array or rows envelope), and the narrow verified RLS event-trigger
search-path exception documented in [Security](SECURITY.md). Prior verification:
36/36 local PostgreSQL security regressions, 49/49 tooling tests, Epic 5
ValidateOnly 15/15, Epic 6 ValidateOnly 16/16, ESLint and diff checks PASS.
These static/local results supplement the production artifacts above.

Production payment-provider webhook processing is **NOT COMPLETE**. It does
not block schema migration deployment or this Epic 5/Epic 6 schema/smoke closure;
it **does block full production payment closure**. No full launch readiness or
live payment-provider integration is claimed.

Next canonical step: **Epic 7 — Learning Map Core scope definition and
approval**, under the unchanged [Canonical Roadmap](CANONICAL_ROADMAP.md).
Epic 7 implementation has not started in this task. Product Decisions and
Epic 7–Epic 13 numbering remain unchanged.
