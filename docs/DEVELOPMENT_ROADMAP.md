# DEVELOPMENT ROADMAP

Status: Draft

## Purpose

Track approved epics, delivery sequence, and dependencies.

## Pending formal PRD input

To be completed from the approved formal PRD.

## Completed: Epic 2 — Teacher Profiles & Public Discovery

- Teacher private/public data separation and public projection
- Public teacher list and SEO-ready detail routes
- Specialty and Learning Map Stage catalogs
- Teacher capability, self-edit, and minimum Admin management foundations
- Versioned migration, RLS/grants, pgTAP coverage, and local contract tests

## Not started

Matching, reviews, ratings calculation, teacher applications, WordPress
migration, complete booking, external payment-provider integrations, packages,
credits, earnings, and recurring scheduling remain out of scope.

## Implemented: Epic 3 — Student–Teacher Trial Flow

- Student learning profile and durable Student–Teacher relationship
- Pending Trial commerce boundary with authenticated Admin confirmation
- UTC/IANA 50-minute Trial Lessons with database collision protection
- Participant-only online join and lesson-safe onsite location
- Atomic, idempotent Trial completion, Lesson Record, and assessment
- Student result, Teacher workflow, and minimum Admin management routes
- RLS/grants, pgTAP coverage, server contract tests, and documentation

## Implemented: Epic 4 — Commerce Core

- Platform/Teacher Product model and minimal public catalog
- Buyer-isolated Orders with immutable item snapshots and authoritative pricing
- Manual bank-transfer and cash payment review with atomic paid transition
- Transactional, idempotent `order.paid` outbox and durable audit log
- Cancellation, expiry, refund/tax/discount reservations, provider interface,
  secure webhook boundary, minimal Product/Student/Admin routes, and tests

Epic 5 entitlement consumption is not started.
