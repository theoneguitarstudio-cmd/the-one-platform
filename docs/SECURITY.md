# SECURITY

Status: Draft

## Purpose

Define security-by-design requirements, data-handling rules, and secret-management expectations.

## Epic 1 implemented baseline

- Supabase browser clients receive only the public project URL and publishable
  key. The service-role key is read only by modules guarded with `server-only`.
- Server Components, Server Actions, Route Handlers, and Proxy use the Supabase
  SSR cookie integration. Server authorization validates the user with
  `auth.getUser()`; it does not trust a browser-supplied role or
  `auth.getSession()`.
- Next.js 16 `proxy.ts` refreshes sessions. Protected layouts independently
  load the account status and roles before rendering.
- Callback destinations pass through an allowlist to prevent open redirects.
- Password-reset requests return the same response whether or not an account
  exists. UI errors are generic and tokens, passwords, secrets, and provider
  error details are not logged.
- Database grants and RLS are both applied. Authenticated users can select only
  their own active private profile and roles. Profile update grants name only
  `display_name`, `phone`, `avatar_url`, `timezone`, and `locale`.
- Suspended and disabled accounts retain history but cannot use protected
  application routes. User deletion is not the suspension mechanism.
- Public profile data has a separate table with no client grants or policies in
  Epic 1.

## Operational work still required

- Set real credentials only in local/Vercel environment settings.
- Apply the versioned migration to a Supabase project and run the pgTAP suite.
- Configure the Supabase Site URL, redirect allowlist, email templates, SMTP,
  password policy, and production cookie/HTTPS behavior before launch.
- A formal threat model, incident response policy, audit-log design, and
  privileged admin workflow remain pending the approved PRD.

## Epic 2 implemented baseline

- Public discovery reads `teacher_public_profiles`, a minimal projection with
  an explicit allowlist of public fields. It never reads from private
  `profiles` or `teacher_profiles`.
- Anonymous and authenticated users can read only rows where a teacher is both
  public and `active`. They receive no private teacher table grants.
- Teacher self-service presentation and specialty updates run through one
  authenticated database RPC. It validates the authenticated user, active
  account status, Teacher role, permitted fields, non-negative integer prices,
  and active catalog specialties before changing any row. Direct Teacher table
  writes are not granted.
- Public discovery has layered account-status protection: profile triggers
  refresh the projection when account status changes, and public RLS verifies
  current account and teacher publication state rather than trusting the
  projection flag alone.
- Privileged Admin mutations are server actions guarded by server-side Admin
  authorization. The service-role client remains in a `server-only` module.
- All money is validated as a non-negative integer TWD amount on both server
  input and database constraints.
- Database trigger functions use `security definer`, a pinned empty
  `search_path`, schema-qualified object references, and revoked direct
  execution permissions.

## Epic 2 operational work still required

- Apply and test the Epic 2 migration in local/staging before any production
  rollout.
- Establish an audited Admin assignment workflow and slug-change redirect
  history before operational staff use the management screen at scale.

## Epic 3 implemented baseline

- Anonymous users have no grants on Student, relationship, order, lesson,
  record, or assessment tables and cannot execute Trial business RPCs.
- Participant RLS is backed by explicit column grants. In particular,
  `private_teacher_notes` is absent from the authenticated Lesson Record grant;
  Teachers receive it only from an ownership-checking DTO RPC.
- Student-to-Teacher data sharing is minimized to display name, learning goal,
  preferred mode, timezone, and necessary Lesson details.
- Meeting URLs are absent from every public projection. The join Route Handler
  verifies a fresh active identity and relies on participant RLS before issuing
  an external redirect. The database and Route Handler independently enforce
  exact Google Meet or safe-boundary `zoom.us` hosts; arbitrary URLs, userinfo,
  local/private IP hosts, and provider/domain mismatches are rejected.
- Student and Teacher collision races are blocked by PostgreSQL GiST exclusion
  constraints, not by a browser-only availability check.
- Trial confirmation and completion functions are security-definer functions
  with empty `search_path`, schema-qualified access, revoked anonymous/public
  execution, row locking, unique constraints, and idempotent return behavior.
- The Epic 3 hardening migration binds Assessments and Lesson Record completers
  to Lesson participants, narrows participant column grants, rejects repeat
  Trial requests for existing open relationships, and prevents completion
  before `starts_at`.
- Admin Trial mutations use the authenticated session so database role checks
  remain effective; the service role is used only for server-only Admin reads.

## Epic 3 operational work still required

- Apply the migration to local/staging and run pgTAP before remote rollout.
- Add durable privileged-operation audit events before production staff scale.
- Replace manual payment and meeting references only in their dedicated future
  integration epics; do not broaden Trial table client grants.

## Epic 4 implemented baseline

- Product discovery uses an allowlisted projection plus current source-state
  RLS; private metadata and Teacher UUIDs are not public.
- Checkout trusts only Product slug and quantity. A security-definer RPC
  rechecks the active buyer/product/Teacher, locks the idempotency scope, reads
  authoritative pricing, and creates immutable item snapshots atomically.
- Buyers have RLS access only to their Orders and Items. Payments, submissions,
  audit logs, refunds, and fulfillment events have no direct client SELECT.
- Payment confirmation locks both Order and Payment, validates amount/currency,
  writes paid states and exactly one outbox event in one transaction. Paid
  Orders cannot use cancellation or expiry paths.
- All privileged RPCs revalidate `auth.uid()`, active account, and database
  Admin role. Security-definer functions use empty `search_path`, qualified
  names, pinned ownership, and explicit execute grants.
- The webhook boundary reads the raw body first and rejects every provider
  until a real signature-verifying adapter and idempotent callback RPC exist.

Operationally, provider secrets and manual bank instructions remain server-only
environment configuration. A dedicated pre-push review is required before the
new migration reaches remote Supabase.
