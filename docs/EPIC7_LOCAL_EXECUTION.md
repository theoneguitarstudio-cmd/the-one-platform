# Epic 7 Local Execution Contracts and Evidence

## Authority and status

Baseline: `main`, HEAD/origin/main `588811d1d5617788b162f4e0a275d64d6a248dce`,
clean, 0/0 at entry. The Product Owner's **Epic7 Autonomous Local Execution**
instruction authorizes A → E, per-slice local gates and local commits, followed
by STOP. It does not authorize F, remote migration/deployment/smoke/cleanup,
production mutations, force pushes or history rewriting. No push before E.
Epic 5/6 remain REMOTE CLOSED; production payment webhook remains NOT COMPLETE.

The Resource cardinality question is resolved by explicit Product Owner
clarification: draft/construction 0..N, frozen Node >=1 Objective and >=1
Resource; no mandatory video or fixed resource combination. This preserves
[approved scope](EPIC7_SCOPE_DEFINITION.md), not a new feature decision.

## A: legacy inventory

Preserve all 29 baseline migration files byte-for-byte. Direct references to
`learning_map_stages.stage_number` are:

| Table.column | Domain | FK deletion behavior |
| --- | --- | --- |
| teacher_stage_capabilities.stage_number | Teacher discovery/assignment | RESTRICT |
| student_profiles.current_stage | Student placement hint | SET NULL |
| lesson_records.stage_number | Existing lesson record | SET NULL |
| assessments.primary_stage | Teacher Trial assessment | SET NULL |

Catalog definition/seeds/grants are in `20260831000200`; Student/Trial FKs
are in `20260831000400`. The effective `complete_trial_lesson` stage validation
and writes are in `20260901000100`, following `20260831000500` hardening.
Consumers: teachers/catalog.ts, public-discovery.ts, admin-actions.ts and
domain.ts; trials/domain.ts, actions.ts, data.ts; Admin Teacher, public Teacher,
Teacher Trial and Student Trial pages. Both domain validators remain 1–5.
`lessons` means a scheduled occurrence and is not a recorded learning Node.
Existing capability allowed/certified status never grants new-course authority.
No mapping bridge, backfill, rekey, rename, conversion or legacy validator edit.

## A: identity, ownership and version contract

System Course, Map and content have stable UUIDs and reserved slugs. Map belongs
to one Course; Level/Module/Node identities are Course-scoped, with no level
count limit. Placement belongs to an exact version; composite FKs must reject
cross-course/map/version parents. Sibling positions are positive and unique.
Resources have stable identity, immutable revision and ordered Node links;
multiple Nodes in the same Course can reference the same revision. No
cross-course reuse of content identities. Skills may be shared by definition.
Changed capability meaning creates a new Node/Objective/Skill identity.

Content author/contributor is private attribution, not access/edit/payout
authority or a new Auth role. Resource and Course credit snapshots retain
display attribution without leaking linked Auth identities. Course metadata,
objectives, skills, standard/guidance, capabilities and resources are pinned
when a version freezes. No version/current pointer grants enrollment or access.
Archive/withdrawal never delete historical frozen versions or self-progress.

## A: migration batches and B/C freeze contract

1. B first migration: Course, Map and version identity/draft revision, required
   composite constraints/indexes, RLS and grants together; no freeze or public
   projection. No production content seeds.
2. B next migration: stable Level/Module/Node and exact version placements,
   transactional internal construction contract and draft guard. Two courses
   can have different structures. Draft may be incomplete.
3. C: Resource/revisions/ordered links, Objectives, Skill mappings, advisory
   DAG, contributor credits, optional supported-capability relationships.
   Only after these exist may complete freeze validate all required content.
4. D: private version-bound personal activity and minimal internal inspection.
   All production learner mutations fail closed until Epic 8 authority exists.
5. E: full local regression, clean rebuild and populated incremental upgrade.

B exit does not claim complete curriculum freeze or all AC-01/04 results.
C integration owns complete freeze: every included Level has a Module, every
Module a Node, every Node an Objective and 1..N Resources. Text alone qualifies.
Freeze validates DAG and pins all versioned rows/links atomically; retries bind
actor, key, version, exact draft revision and payload. Full Creator publishing,
approval workflows, production delivery and public/student UI remain excluded.

## A: mutation, security and concurrency contract

- New tables: RLS plus explicit least-privilege grants in the same migration.
  Revoke raw INSERT/UPDATE/DELETE/TRUNCATE from anon/authenticated/service_role.
  No general service-role raw writer or privilege expansion.
- Only active authenticated Admin/Super Admin may construct/inspect structure
  through constrained RPCs. Fresh server identity and DB active-role checks
  are both required; no client actor/course-author claim is authority.
- Empty search_path, qualified references, postgres ownership, exact EXECUTE
  grants; private helpers not executable by application roles. No dynamic
  arbitrary table/column mutation endpoint or arbitrary URL fetch.
- Immutable guards protect version rows and all referenced metadata/links,
  including privileged application calls. Course/Map/identity deletion and
  rekeying cannot bypass history retention. Internal creation is not publishing.
- Single-map edits serialize map/version locking; graph changes use the same
  draft lock before reachability checks. Deterministic lock order precedes
  audit append; no Commerce/Entitlement/Scheduling locks are added.
- Every new mutation-capable SECURITY DEFINER and overload is registered in
  `global_lock_order_contract.test.sql` with order or specific exemption.
  The existing 100-function coverage is extended, never disabled.
- Optimistic revision errors reject stale edits. Retry keys bind actor and
  request payload. Same successful request returns its recorded outcome;
  a different payload with the same key is rejected. Failed operations roll
  back all writes and audit; no partial freeze or half-applied graph.

## A: progress and Epic 8 handoff

Progress key is (authenticated Student, version, Node); resource resume must
reference that Node's exact resource link. Fields express opened, resume,
revisit and explicit Self Complete only. No VERIFIED/mastery/assessment/pass/
Stage completion/certificate/enrollment columns or derived outcomes.
Viewing never auto-completes; set/clear is explicit with idempotent request and
revision conflict protection. No cross-user, old-version rebinding or implicit
copy at V2. Suspension/access loss deny use but preserve history.

Course-use authorization is a private fail-closed contract, not a Membership
engine, fake plan rows or client booleans. Isolated owner-controlled test
fixtures may supply a test authority solely in disposable local databases;
no production allow-all flag/GUC/JWT claim grants new access. Tests must also
prove the shipped default denies learner operations. Recommended/unjoined
courses create no progress or personal 0% map. Capability support metadata
never grants eligibility, quota, assignment or workflow execution.

## A: local fixture, regression and recovery specification

Representative Course A: one coherent Level plus next-Level sample; multiple
Modules/Nodes, one multi-Resource Node, text-only Node, objectives/skills,
advisory edges and V1/V2. Synthetic Course B uses different grouping and a
shared Skill/contributor without access inheritance. Two Students and an
unassigned Teacher, attributed Creator, Admin/Super Admin, inactive accounts
and service_role exercise positive and negative permissions.

Required database tests: valid/invalid composite FKs, duplicate positions,
zero-resource draft accepted and freeze rejected; text-only freeze accepted;
cross-course/version isolation; all immutable relation mutations rejected;
graph self/cross/cycle/race rejection; two-session edit/freeze and freeze retry;
owner-only self activity and stale writes; cross-user/forged subject rejection;
all-Nodes-self-complete produces no formal outcome; V1 history survives V2.

Before each B/C/D gate: relevant unit/domain tests, SQL/pgTAP, security/lock
contract, lint and diff check. E additionally runs the full existing SQL and
application suites (Teacher/Trial, Commerce, Entitlement, Scheduling), migration
lint, clean rebuild and a 29-migration populated incremental upgrade. Preserve
old stage rows/FKs/validators, synthetic capability assignments, placements,
lesson records, assessments and financial/schedule rows. Compare before/after.

Local tests use isolated databases in the verified local Docker Supabase
PostgreSQL container; never use linked/remote URL or environment credentials.
No production dump or private backup enters Git. Failure leaves evidence;
recovery uses local disposable rebuild or a new forward fix. Operational
rollback disables new use, not deletion of frozen content/learner history.

## Slice gates (actual evidence only)

| Slice | Status | Evidence |
| --- | --- | --- |
| A | PASS | Contracts/security/legacy review PASS; 192/192 application tests; ESLint PASS; diff check PASS; 45 relative links valid; only four authorized documentation files changed; migration tests N/A (no DDL) |
| B | NOT STARTED | Depends on A PASS |
| C | NOT STARTED | Depends on B PASS |
| D | NOT STARTED | Depends on C PASS |
| E | NOT STARTED | Depends on D PASS |
| F | NOT AUTHORIZED | Explicit operator gate required |
