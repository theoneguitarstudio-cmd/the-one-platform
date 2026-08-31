# SYSTEM ARCHITECTURE

Status: Draft

## Purpose

Describe the modular-monolith architecture, system boundaries, and future integrations.

## Pending formal PRD input

To be completed from the approved formal PRD.

## Epic 2 public discovery architecture

The web application remains a modular monolith. The Teacher module owns:

- server-only public-discovery queries;
- private Teacher self-edit actions;
- server-only Admin management actions; and
- input validation, catalog definitions, and presentation labels.

Public server-rendered pages call the public projection query module. Browser
components receive already allowed public fields only. The database projection
is synchronized by migration-managed triggers and guarded by RLS; it is not a
view over private account records exposed to the Data API.

The Admin management page is route-protected and its mutations require both
server authorization and the server-only service-role client. This is a
deliberate administrative boundary, not a client-side role check.

## Epic 3 Trial Flow architecture

The Trial module is a vertical slice inside the modular monolith:

- Server Components call server-only DTO modules for Student, Teacher, and
  Admin views.
- Server Actions validate untrusted form input, convert IANA local time, and
  re-authorize the role at the mutation boundary.
- Authenticated security-definer RPCs own the payment-confirmation and
  Trial-completion transactions. Database grants/RLS remain the final boundary.
- PostgreSQL uniqueness, row locks, advisory pair locks, and interval exclusion
  constraints provide idempotency and race-safe scheduling.
- `/lesson/[id]/join` is the only meeting redirect. It performs fresh identity
  validation and a participant-RLS Lesson lookup; public pages never receive a
  meeting reference.

Epic 3 intentionally uses an Admin/Teacher-controlled requested-time workflow.
It does not introduce availability recurrence, payment providers, credits,
earnings, packages, notifications, or calendar integrations.
