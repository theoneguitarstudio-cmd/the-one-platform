# ROLE PERMISSION MATRIX

## Learning Verification & Membership architecture proposal

**Status:** planned authorization model only; no role, policy, grant, or table
is changed by this document update.

`student`, `teacher`, `admin`, and `super_admin` remain the Auth roles. Free,
Plus, and Pro are membership tiers expressed through plans, subscriptions,
entitlements, and capabilities. A premium-resource or review decision requires
an active account plus live server-side entitlement; frontend plan labels are
never authority.

| Capability | Student | Teacher | Admin / Super Admin |
| --- | --- | --- | --- |
| Read learning records | Own only | Assigned review minimum only | Audited server path |
| Submit evidence | Own eligible assignment | Only if also Student | Support path only |
| Review / verify node | No | Assigned work plus stage `review` | Audited exception path |
| Assess stage | No | Assigned work plus stage `assess` | Audited exception path |
| Certificate outcome | No | No unilateral publication | Audited authorized path |
| Premium resources / review quota | Entitlement-aware own use | Entitlement-aware learner use | Management path |
| Change entitlement/quota | No | No | Audited privileged path |

The future stage-scoped vocabulary is `teach`, `review`, `assess`, `mentor`,
and `content_author`. It extends existing `teacher_stage_capabilities`, not
client-controlled role state. Every protected action rechecks account status,
assignment/ownership, and capability on server/database boundaries.

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
