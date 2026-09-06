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
| B | WARN (format only) | Correctness/security PASS: two additive migrations; 23 structure/security and 29 lock assertions; 192 application tests; ESLint PASS; PostgreSQL function lint zero errors; 13 baseline table snapshots unchanged after populated 29 → 31 upgrade. The staged check found two whitespace-only lines in the new 002 migration after the initial unstaged check; no SQL behavior changes. Applied file is retained; this non-blocking formatting warning does not authorize editing the original 29 migrations. |
| C | PASS | 122 content/isolation/grant assertions, 23 structure and 29 lock assertions; three independent-session races (inverse graph edges, freeze retry and freeze/edit) PASS. Text-only Nodes freeze; V1 survives V2; attribution grants no authority; ESLint and current diff check PASS. Additive local upgrade 31 → 32. |
| D | PASS | Owner-only activity and internal inspection; 75 PostgreSQL assertions and three progress races PASS; shipped course-use helper remains false after tests. 219 application tests PASS, full ESLint/typecheck/current diff PASS; 23 structure and 29 lock assertions PASS (106 mutators). Local migration 32 → 33. Explicit Node test scripts use `.regression.mjs` so Vitest does not execute Docker fixtures. |
| E | WARN (non-blocking only); LOCAL CLOSED | Clean 34-migration rebuild and populated 29 → 34 upgrade PASS; all 13 populated snapshots unchanged. 39 SQL suites / 1,480 assertions plus 237 Epic7 assertions and six race scenarios PASS. All 24 tables / 20 functions pass security and migration lint. 219 application tests, full ESLint/typecheck and Webpack production build PASS. Current/staged diff and relative links PASS; retained B whitespace and host Turbopack warnings below. |
| F | NOT AUTHORIZED | Explicit operator gate required |

## E: implemented object inventory

Five new, additive, locally applied migrations; none has been deployed remotely:

| Migration | Responsibility |
| --- | --- |
| `20260906000100_learning_course_versions.sql` | Course/Map identities and draft version foundation |
| `20260906000200_learning_hierarchy.sql` | Stable hierarchy, ordered draft placement, mutation receipts and transactional construction |
| `20260906000300_learning_content_freeze.sql` | Resource revisions, objectives, Skills, advisory DAG, attribution, capability descriptors, complete freeze |
| `20260906000400_learning_self_activity.sql` | Owner-only activity, deny-only course-use boundary, internal inspection and Course retention |
| `20260906000500_learning_freeze_graph_validation.sql` | Forward-only full DAG validation at freeze, in addition to write-time checks |

All 29 baseline migration files remain unchanged. New schema is course-scoped;
there is no new migration seed, legacy backfill, 1:1 Stage mapping or modification
of Teacher/Trial/Commerce/Entitlement/Scheduling behavior.

Exact 24 public tables (RLS + no raw application SELECT/DML/TRUNCATE):

- `system_courses`, `learning_maps`, `curriculum_publications`,
  `learning_mutation_receipts`;
- `curriculum_stages`, `curriculum_stage_versions`, `learning_modules`,
  `learning_module_versions`, `learning_nodes`, `learning_node_versions`;
- `learning_resources`, `learning_resource_versions`, `learning_node_resources`,
  `learning_objectives`, `learning_objective_versions`, `learning_skills`,
  `learning_objective_skills`, `learning_node_prerequisites`;
- `content_contributors`, `learning_author_credits`, `learning_capabilities`,
  `learning_node_capability_attachments`;
- `learning_self_activity`, `learning_activity_requests`.

Eight public authenticated RPCs: `learning_create_course`,
`learning_create_draft`, `learning_put_structure`, `learning_put_content`,
`learning_freeze_version`, `learning_set_activity`, `learning_get_own_activity`,
`learning_inspect_version`. Twelve private helper/trigger functions complete
the 20-function inventory. All are postgres-owned, empty-search-path functions;
private helpers have no application EXECUTE and service_role has no new writer.
The global mutation inventory is 106, including the six new mutation RPCs.

New server module files are `domain.ts`, `data.ts` and their tests under
`src/modules/learning-map`. They validate strict inputs, obtain fresh server
identity and use the authenticated client; database RPCs independently recheck
authority. There is no new route/page/component, service-role client, UI,
Membership engine, submission/review/assessment workflow or formal-outcome table.

## E: actual validation and representative slice

All SQL tests ran against isolated databases inside the existing local
`supabase_db_the-one-platform` container. No remote URL, linked CLI execution,
production data or private backup was used. Bootstrap copies managed Auth
schema only from the local container, never Auth rows or a dump file into Git.

| Evidence | Actual result |
| --- | --- |
| Application tests | 24 Vitest files, 219/219 PASS; includes original 192 and 27 new domain/server tests |
| Existing smoke tooling subset | 49/49 PASS, included in the 219 above |
| Existing SQL + B structure/lock suite | 39 `.test.sql` files, 1,480/1,480 assertions PASS, including Teacher/Trial, Commerce, Entitlement, Scheduling and security |
| C content/isolation | 122 PostgreSQL assertions PASS |
| D owner activity/access boundaries | 79 PostgreSQL assertions PASS (75 at D gate; E added cross-course/access-lost checks) |
| E draft/frozen completeness matrix | 36 PostgreSQL assertions PASS; Objective-only and Resource-only drafts independently fail freeze, text-only complete Nodes pass |
| Concurrency on final 34-migration schema | Six scenarios PASS in two independent-session suites: inverse DAG edits, same freeze retry, freeze/edit, competing initial activity writes, exact old retries after correction, cross-Node request-key race |
| Migration/security review | 24 tables and 20 functions PASS; ordinary function and trigger `plpgsql_check` lint zero errors; shipped authority remains false |
| Prior search-path exception regression | 36 read-only PostgreSQL predicate cases PASS |
| Epic5 ValidateOnly | 15 PASS / 0 FAIL / 0 SKIP; Overall PASS; no production smoke |
| Epic6 ValidateOnly | 16 PASS / 0 FAIL / 0 SKIP; Overall PASS; no production smoke |
| ESLint / TypeScript | PASS |
| Production build | `next build --webpack` PASS; 31 static pages generated and existing route set retained |
| Diff / docs | Current/staged diff PASS; 70 relative-file links PASS; no conflict markers or detected credentials in added material; protected canonical files and original 29 migrations unchanged; baseline-range formatting warning explicitly retained below |

Course A synthetic fixture has two Levels, three Modules and four Nodes: a
representative first-Level rhythm/chord/whole-song sequence, plus a minimal
next-Level accompaniment sample. It has five Resource revisions (four text,
one audio descriptor), an ordered multi-Resource Node, four Objectives, shared
Skill mapping, advisory prerequisite, two credited contributors, and an optional
async-review descriptor. Text-only content satisfies freeze. Six fixed product
Level outcomes are not redefined. These are synthetic test assets/guidance,
not a claim that production curriculum media or licensing is ready.

Course B uses a different structure and can share a Skill/contributor without
sharing content identity or authority. Cross-course Resource/Node/prerequisite
references and cross-course progress are denied. V1 and V2 remain independently
addressable; V1 content and activity survive V2. All frozen relationship INSERT,
UPDATE and DELETE operations are rejected, including owner-path corruption tests.
Freeze independently rejects a deliberately corrupted DAG and rolls back its
revision, receipt and audit transaction.

Positive progress tests temporarily replace the private deny-only policy only
inside a rolled-back fixture transaction, or in the explicitly disposable race
database with restoration in `finally`. The application cannot invoke/replace
that helper, supply a subject, claim eligibility or create a policy row.
Recommended/unjoined/missing-policy contexts create no personal map. Eligible
fixtures may self-complete without viewing or satisfying advisory prerequisites;
opening never auto-completes. Cross-user reads/writes, forged fields, role loss,
inactive accounts, stale writes and cross-Node Resource references are denied.
Access loss/archive/withdrawal retain history. Completing every Node creates no
assessment, legacy placement, VERIFIED state, mastery or certificate.

## E: clean rebuild and populated upgrade

`epic7_clean_20260906`: template0 + local managed Auth schema + all 34 migrations,
then the full SQL suite and final Epic7 assertions/security review: PASS.
Existing SQL fixture `\ir` includes are expanded from allowlisted repository
paths by the local helper. Fixture-only files are not mistaken for test suites.

`epic7_upgrade_20260906`: rebuilt to the original 29 first; populated the
existing synthetic Entitlement/Booking fixture and the explicit legacy Stage
fixture, then applied all five Epic7 migrations. The before/after complete
JSON row snapshots below are identical, not just equal row counts:

| Preserved table | Populated rows |
| --- | ---: |
| learning_map_stages | 5 |
| teacher_stage_capabilities | 1 |
| student_profiles | 1 |
| lesson_records | 2 |
| assessments | 1 |
| lessons | 5 |
| teacher_profiles | 2 |
| student_teacher_relationships | 2 |
| products | 1 |
| orders | 1 |
| entitlements | 3 |
| lesson_credit_ledger | 7 |
| bookings | 4 |

The earlier `epic7_local_20260906` B upgrade also preserved 13 snapshots, with
its financial tables empty; E's new populated database supplies the stronger
financial/booking evidence. `epic7_race_20260906` was explicitly reset from the
clean final schema after confirming only known synthetic IDs; both race suites
passed again. These four named disposable databases are retained locally for
inspection. Their synthetic fixtures are not production residue.

## Reproduction entry points (local only)

- `node node_modules/vitest/vitest.mjs run`
- `node node_modules/eslint/bin/eslint.js`
- `node node_modules/typescript/bin/tsc --noEmit`
- `node node_modules/next/dist/bin/next build --webpack`
- `node scripts/epic7-local-db.mjs tests` with `EPIC7_LOCAL_DATABASE` set to
  the clean disposable database for the existing SQL suite.
- `node --test scripts/epic7-content.regression.mjs scripts/epic7-progress.regression.mjs scripts/epic7-closure.regression.mjs`
- `node scripts/epic7-database-review.mjs`
- `node scripts/epic7-populated-upgrade.mjs` with the explicitly named upgrade
  database selected; it refuses an existing database rather than overwriting it.
- The two `epic7-*-concurrency.regression.mjs` scripts require the disposable
  race database and their documented synthetic construction order (content,
  then activity). They never target the local main or a remote database.

## Remaining warnings and exact operator gate

1. The locally applied new `20260906000200` migration has whitespace-only lines
   47 and 54. The initial B unstaged check did not cover this then-untracked file;
   its staged check exposed the warning. The SQL parsed/applied and all later
   gates passed. It is retained to obey the no-applied-migration-edit rule.
   `git diff --check` for current/staged changes passes; checking the entire
   range from the planning SHA reports these two formatting lines. This is
   non-blocking formatting only, not a silent claim of a clean range check.
2. Turbopack worker spawning fails with host OS error 5, including after a
   sandbox retry. The documented Webpack production build passes without any
   config/dependency/source workaround. No Epic7 UI or route was introduced.

No remaining product decision, security-authority ambiguity, integrity failure,
legacy conversion or future-epic dependency blocks LOCAL closure. Canonical
status is synchronized; PRODUCT_DECISIONS and CANONICAL_ROADMAP remain unchanged.
Production payment-provider webhook is still NOT COMPLETE, independent of
Epic5/Epic6 REMOTE CLOSED. The historical remote chain is 29, not the new local
34; no fresh remote parity/backup/smoke evidence is claimed.

**STOP after E.** Ready for Epic7-F **operator review/preparation: YES**.
Ready to push the reviewed local work: **YES (not performed)**.
Ready to execute remote migration: **NO** until explicit authorization and
fresh target/Git/parity/recovery gates, reviewed five-migration rollout and an
Epic7-specific smoke/cleanup plan exist. Do not start F, production operations,
Epic8–13, or a Student/Creator workspace automatically.
