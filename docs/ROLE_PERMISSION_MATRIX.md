# ROLE PERMISSION MATRIX

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
