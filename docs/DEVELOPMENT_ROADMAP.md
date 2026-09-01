# DEVELOPMENT ROADMAP

## Architecture Update — Learning Verification LMS & Membership

**Status:** architecture direction documented; implementation pending approval.
This update has no migration, schema change, remote push, or production code.

### Proposed delivery sequence

1. **Architecture Update A — Learning/Verification Model** (this docs-only
   decision): map/node/resource, evidence, review, human verification,
   assessment, achievement, versioning, and security boundaries.
2. **Architecture Update B — Membership/Entitlement Model** (this docs-only
   decision): plans, subscriptions, capability/entitlement separation, review
   quota ledger, and Commerce fulfillment boundary.
3. **Epic 5 — Entitlement Core & Lesson Credits:** consume existing
   `order.paid` events idempotently; introduce entitlement foundation and
   independent lesson-credit/package fulfillment. No LMS feature is implied by
   this stage.
4. **LMS A — Content Engine:** approved map/node/resource/standard schema and
   provider-neutral content delivery.
5. **LMS B — Student Progress:** learner progress and practice workflow.
6. **LMS C — Assignments:** submission/evidence storage and private delivery.
7. **LMS D — Reviews & Verification:** reviewer assignment, rubrics, feedback,
   verified outcomes, and quota consumption.
8. **LMS E — Stage Assessment & Certificates:** assessment attempts, immutable
   achievement records, certificate verification/revoke/supersede lifecycle.
9. **Subscription and review-quota operations:** provider integration,
   lifecycle handling, quota allocation/reconciliation, and operational audit.
10. **Later:** AI assistance, review queue automation, community/events, and
    mobile experiences.

Each implementation step requires its own approved PRD scope, versioned
migration, RLS/grant design, tests, security review, and remote-push review.

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
