# ROLE PERMISSION MATRIX

## Epic 6 Scheduling & lesson-credit authorization

| Capability | Student | Teacher | Admin / Super Admin |
| --- | --- | --- | --- |
| Create eligible Flexible Booking | Own credit and allowed availability | Own Teacher schedule for an active relationship | Audited management path |
| Manage Fixed series | Read own safe summary only | Own assigned series only | Audited management path |
| Set availability / exception | No | Own approved availability | Audited management path |
| Release priority slot / override | No | Limited approved exception | Reasoned, audited override |
| Consume/release Lesson Credit | No direct mutation | No direct mutation | Authorized transaction only |

Scheduling and credit authorization are independent. A participant cannot alter
the other party's booking, a Teacher cannot mutate Student credit, and an
exceptional Admin change records its credit/earning outcome.

Anonymous users have no Scheduling-domain table or RPC access. Authenticated
clients have no raw mutation grants; participant reads are via RLS and allowlisted
DTO RPCs. Fixed-series creation is Teacher/Admin only.

## Learning Verification & Membership architecture proposal

**Status:** planned authorization model only; no role, policy, grant, or table
is changed by this document update.
Epic 7 product approvals are synchronized from
[Epic 7 Scope Definition](EPIC7_SCOPE_DEFINITION.md); implementation remains
**NOT STARTED / NOT AUTHORIZED**. Later review/assessment rows below belong
to Epic 10/11, not Epic 7 permissions already implemented.

`student`, `teacher`, `admin`, and `super_admin` remain the Auth roles. Free,
Plus, and Pro are membership tiers expressed through plans, subscriptions,
entitlements, and capabilities. A premium-resource or review decision requires
an active account plus live server-side entitlement; frontend plan labels are
never authority.

| Capability | Student | Teacher | Admin / Super Admin |
| --- | --- | --- | --- |
| Read learning records | Own only | Assigned review minimum only | Audited server path |
| Record basic Self Progress / Self Complete | Own eligible course/Node/version via constrained operation | Only own learner progress when also Student and eligible | No impersonated self-completion or formal-result shortcut |
| Submit evidence | Own eligible assignment | Only if also Student | Support path only |
| Review / verify node | No | Assigned work plus stage `review` | Audited exception path |
| Assess stage | No | Assigned work plus stage `assess` | Audited exception path |
| Certificate outcome | No | No unilateral publication | Audited authorized path |
| Premium resources / review quota | Entitlement-aware own use | Entitlement-aware learner use | Management path |
| Change entitlement/quota | No | No | Audited privileged path |

The future course/stage-scoped vocabulary is `teach`, `review`, `assess`,
`mentor`, and `content_author`. Existing `teacher_stage_capabilities` keeps its
legacy Stage 1–5 scope. Any relation to new course-scoped Levels requires
explicit mapping/capability policy, not automatic authority transfer or
client-controlled role state. Every protected action rechecks account status,
assignment/ownership and capability on server/database boundaries.

### Epic 7 foundation restrictions (requirements, not implemented grants)

- Students can record their own personal Self Complete after trusted course-use
  authorization. They cannot change another Student's progress, write VERIFIED,
  mastery, Assessment Passed, formal Stage completion or certificates. Self
  Complete cannot satisfy those formal outcomes; viewing does not auto-complete.
- Teachers have no raw DML authority over Student formal outcomes. Actual
  verification/assessment needs assigned, authorized, audited Epic 10/11
  transitions. A Teacher role or legacy capability alone is insufficient.
- Creator is an attribution concept here, not a new Auth role. Authorship grants
  no Student access authority, private-progress access, revenue ownership or
  right to change immutable versions. New content requires a new version;
  Creator CMS and production publishing workflows remain Epic 13.
- Node support for review is content metadata; eligibility is Epic 8 policy;
  execution is Epic 10. No membership tier, Resource kind or author alone
  authorizes a capability. Prerequisites are advisory, not access checks.
- `service_role` is not general business authority. No raw content/progress
  DML grants or bypass of actor/scope checks are justified by its use. Retain
  server reauthorization, database enforcement and audited privileged paths.
- Epic 7 has only minimal internal/Admin structure inspection, no public
  learning surface or Student Workspace. Future personal maps require joined/
  eligible courses; recommendations create neither enrollment nor 0% progress.
  Missing future access authority fails closed. No RLS or RPC is implemented
  by this synchronization.

Status: Draft

## Purpose

Define access boundaries for Student, Teacher, Admin, and Super Admin.

## Epic 1 roles

One user may hold multiple rows in `user_roles`.

| Role | Student route | Teacher route | Admin route |
| --- | --- | --- | --- |
| student | Allowed | Denied | Denied |
| teacher | Denied unless also student | Allowed | Denied |
| admin | Denied unless also student | Denied unless also teacher | Allowed |
| super_admin | Denied unless also student | Denied unless also teacher | Allowed |

All route access also requires `account_status = active`. Anonymous,
`suspended`, and `disabled` users are denied.

## Enforcement

- Permission names and role mappings are centralized in
  `src/modules/auth/permissions.ts`.
- Protected layouts call server-only authorization. Client-rendered role values
  are never an authority.
- Role assignment and account-status mutation have no authenticated-client
  grants or RLS policies. They require a future audited privileged server path.

## Pending formal PRD input

Fine-grained permissions and administrative role-assignment procedures remain
to be completed from the approved formal PRD.

## Epic 2 teacher permissions

| Actor | Public teacher projection | Private teacher profile | Admin controls |
| --- | --- | --- | --- |
| Anonymous | Read active, public rows only | No access | No access |
| Student | Same as Anonymous | No access | No access |
| Teacher | Same as Anonymous, plus own private row | May update approved presentation fields and own specialties | Cannot set slug, publishing, teaching status, or stage certification |
| Admin / Super Admin | Through server-only privileged path | Through server-only privileged path | May create/enable teacher profiles, set slug/public status, specialties, and stage capabilities |

The UI does not grant authority. Teacher and Admin server actions independently
verify protected-route access, while database grants and RLS enforce the
same ownership limits for normal user-scoped data access.

## Epic 3 Trial permissions

| Actor | Student profile | Relationship / Lesson | Record / Assessment | Mutation |
| --- | --- | --- | --- | --- |
| Anonymous | None | None | None | None |
| Student | Own row only | Own participation only | Own Student-safe columns and assessment | Request pending Trial checkout only through RPC |
| Teacher | Minimal Trial Student DTO only | Own participation only | Own workflow DTO includes private Teacher notes | Meeting defaults and assigned Trial completion through RPC |
| Admin / Super Admin | Server-only management | Server-only management | Server-only management | Authenticated Admin RPC for payment confirm, reschedule, and cancel |

No authenticated client receives direct insert, update, or delete grants on
Trial domain tables. High-risk actions re-check active account and role in both
the Next.js server action and database function.

## Epic 4 Commerce permissions

| Capability | Anonymous | Buyer | Teacher | Admin / Super Admin |
| --- | --- | --- | --- | --- |
| Read active public Product projection | Yes | Yes | Yes | Server path |
| Read private Product fields | No | No | Own products only | Server path |
| Create/edit Teacher Product | No | No | Own draft via RPC | Server path |
| Read Order and Item | No | Own only | No sales/payment detail | Server path |
| Read payment-safe summary | No | Own Order only | No | Server path |
| Submit bank-transfer evidence | No | Own open Order | No | Review only |
| Confirm cash/payment or cancel/expire administratively | No | No | No | Authorized RPC |
| Read or mutate audit/outbox/refunds | No | No | No | Service-only |
