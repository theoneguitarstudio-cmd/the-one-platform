# SECURITY

## Security incident recovery

Remote rollout must stop on an RLS, grant, service-role authority, private
helper, or authorization regression. Classification, write-freeze, evidence,
and forward-fix requirements are defined only in the canonical
[Remote Backup and Recovery Runbook](REMOTE_BACKUP_RECOVERY_RUNBOOK.md).

## Epic 6 Scheduling / one-on-one security

- Fixed-slot priority, Flexible availability, booking, series exception,
  cancellation, and reschedule use transactional server/database authorization;
  route/UI state is never authority.
- Credit reservation, consumption, and release use Epic 5 shared private cores
  in an auditable transaction linked to the Booking or Lesson. Epic 6 contains
  no independent ledger writer. A Teacher cannot directly mutate a Student
  entitlement balance, and a Booking-bound reservation cannot be released
  outside Booking cancellation orchestration.
- Teacher/Student collision protection retains Epic 3 UTC/IANA semantics,
  advisory-lock discipline, and database final integrity guard. Recurring
  generation needs the same protection, not browser-only calendar checks.
- Admin overrides record actor, reason, scope, credit outcome, and earning
  outcome; they do not grant broad access to unrelated submissions, feedback,
  or private profiles.
- All Epic 6 tables have RLS, raw DML is revoked from `anon`, `authenticated`,
  and `service_role`, and mutation functions are `SECURITY DEFINER`, owned by
  `postgres`, schema-qualified, and pinned to an empty `search_path`.
- All Booking, occurrence, series, and availability mutations converge on the
  branch-aware global lock DAG in `docs/LOCK_ORDER_CONTRACT.md`. Ordinary paths
  use deterministic Epic 3 Student/Teacher advisory locks, Entitlement, credit
  Reservation, Booking, optional recurring Occurrence, then Lesson. Fixed,
  Makeup, Revoke, Commerce, and Fulfillment paths have explicit nested-lock and
  inherited-lock rules. The executable contract rejects cycles, source-order
  reversal, and any new mutation-capable SECURITY DEFINER function or overload
  that lacks an inventory entry or justified exemption. GiST exclusion
  constraints remain the final UTC-instant integrity guard; constraint and
  deadlock errors are translated to stable domain errors.
- Teacher mutation authorization requires an active account, Teacher role,
  existing Teacher profile, and `teaching_status = 'active'`. Paused, draft,
  inactive, suspended, and role-removed Teachers cannot mutate scheduling or
  materialize new occurrences. Active Admin/Super Admin override remains
  separately authorized and audited.

## Learning Verification & Membership security architecture (proposed)

**Status:** requirements for future implementation; no new storage policy, RLS,
RPC, migration, or remote configuration is made by this document update.

- Premium resource, assessment, review, and certificate eligibility require
  fresh server-side entitlement/authorization checks. UI visibility, browser
  plan labels, and a client-submitted Teacher ID are never trusted.
- Student submissions and feedback are private. Future storage uses private
  buckets with short-lived signed URLs issued only after ownership, assigned
  reviewer, or authorized Admin checks. Public buckets and durable public asset
  URLs are not acceptable for practice evidence.
- Premium PDF/audio/download delivery is similarly entitlement-gated with
  short-lived signed delivery. VdoCipher playback tokens are minted server-side
  after the same check; provider secrets and tokens never enter browser bundles
  or logs.
- Reviewers receive minimum necessary evidence only for work assigned to them,
  inside their approved stage capability. Students see only their own records;
  Admin overrides need an audited server-side privileged path.
- Human review/verification, assessment, certificate issue/revoke/supersede,
  membership entitlement changes, quota allocations/adjustments, and manual
  overrides require durable audit records with actor, subject, reason, version,
  and timestamp.
- Public certificate verification, if introduced, exposes only a minimal
  non-PII projection and never broadens access to profiles, submissions,
  feedback, or internal assessment data.
- Future security-definer database functions must pin `search_path` to empty,
  schema-qualify object access, validate `auth.uid()` and active account state,
  revoke `EXECUTE` from `PUBLIC`, grant only the necessary database role, and
  make quota/evidence/verification transitions transactional and idempotent.
- AI integrations must use approved server-side data minimization and cannot
  execute final verification, assessment, certificate, entitlement, or quota
  decisions.

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

## Epic 2 post-closure operational work

- Epic 2 is included in the applied remote chain reported through `00600`.
  Future remote changes still require the canonical migration and recovery
  gates.
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

## Epic 3 post-closure operational work

- Epic 3 is included in the applied remote chain reported through `00600`.
  Future remote changes still require local pgTAP and the canonical migration
  and recovery gates.
- Add durable privileged-operation audit events before production staff scale.
- Replace manual payment and meeting references only in their dedicated future
  integration epics; do not broaden Trial table client grants.

## Epic 4 implemented baseline

- Product discovery uses an allowlisted projection plus current source-state
  RLS; private metadata, Teacher UUIDs, and technical Product UUIDs are not
  public. Public slugs are the external Product identifiers.
- Checkout trusts only Product slug and quantity. A security-definer RPC
  rechecks the active buyer/product and live Teacher eligibility, locks the
  idempotency scope, reads authoritative pricing, and creates immutable item
  snapshots atomically. Teacher eligibility requires an active account,
  Teacher role, active teaching status, and public Teacher profile.
- Buyers have RLS access only to their Orders and Items. Payments, submissions,
  audit logs, refunds, and fulfillment events have no direct client SELECT.
- Payment confirmation locks Order before Payment, validates amount/currency
  and provider-event consistency, and writes paid states plus exactly one
  outbox event in one transaction. A partial unique index permits at most one
  paid Payment per Order; competing attempts receive a domain rejection rather
  than leaking a uniqueness error. Paid Orders cannot use cancellation or
  expiry paths.
- Buyer cancellation and Teacher Product archive are audited transactionally.
  Client roles cannot write or read the audit table. The private Teacher
  eligibility helper is callable only from trusted database code/service role,
  not directly by authenticated clients.
- All privileged RPCs revalidate `auth.uid()`, active account, and database
  Admin role. Security-definer functions use empty `search_path`, qualified
  names, pinned ownership, and explicit execute grants.
- The webhook boundary reads the raw body first and rejects every provider
  until a real signature-verifying adapter and idempotent callback RPC exist.

Operationally, provider secrets and manual bank instructions remain server-only
environment configuration. A dedicated pre-push review is required before the
new migration reaches remote Supabase.

## Epic 5 implemented baseline

- Every Epic 5 table has RLS enabled. Students receive only an allowlisted view
  of their own active Lesson Package entitlements; raw ledger, reservation,
  fulfillment snapshot, config, expiry-history, and audit data have no direct
  browser grants.
- Fulfillment locks the event and relevant item state, validates paid Order
  truth, uses item-level unique constraints and operation keys, and changes the
  event to processed only after all grants allocate successfully. Any item
  failure rolls the transaction back and leaves a retryable failed event.
- Service-role fulfillment explicitly verifies `auth.role()`. Admin retry,
  credit adjustment, revoke, and Product config functions separately verify
  `auth.uid()`, active account status, and Admin/Super Admin role in the
  database.
- Student reserve and Teacher consume authorization derives from `auth.uid()`;
  a client-supplied user ID is never the authority. Composite foreign keys bind
  reservation and ledger subjects to the Entitlement beneficiary.
- Credit mutations lock the Entitlement before reservation rows, use unique
  idempotency keys, validate retry payloads, and return stable domain errors
  rather than leaking uniqueness failures. Append-only triggers reject ledger
  updates/deletes.
- Teacher expiry extension rechecks active Teacher state, relationship, and
  scope in the transaction. Admin adjustment/revoke requires a reason and
  writes audit/history; revocation compensates remaining available/reserved
  balance without deleting history.
- Epic 5 security-definer functions are owned by `postgres`, set an empty
  `search_path`, schema-qualify references, revoke execute from `PUBLIC`/`anon`,
  and grant only the exact authenticated or service-role entry points.
- DTO functions expose minimum role-specific fields. The UI, route protection,
  and Server Actions are defense-in-depth and do not replace RLS/RPC checks.
- Supabase `service_role` is a production application role, not a database
  superuser for business logic. It has no raw INSERT/UPDATE/DELETE grant on
  Epic 5 tables and can invoke only the automatic fulfillment RPC. PostgreSQL
  owners/superusers used for migrations and isolated test fixtures remain an
  operationally separate trust boundary.
- Ledger, purchase snapshots, expiry history, and manual-retry attempts reject
  UPDATE/DELETE through append-only triggers. Entitlements reject DELETE and
  protect beneficiary, source, type, scope, and commercial snapshot fields;
  legitimate status/expiry mutations remain inside authorized domain RPCs.
- Automatic fulfillment retry is service-only and tracked by outbox status,
  attempt count, and safe error state. Manual retry is a separate authenticated
  Admin/Super Admin RPC requiring a reason and idempotency key. Every successful
  or failed manual attempt writes one immutable actor/role/result record and one
  central audit event; retries with the same key do not duplicate either.

Before remote rollout, operators must confirm every purchasable existing
`lesson_package` Product has an approved fulfillment config. Missing config
fails checkout safely; no production value is guessed by the migration.
