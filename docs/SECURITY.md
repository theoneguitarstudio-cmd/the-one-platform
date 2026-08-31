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
