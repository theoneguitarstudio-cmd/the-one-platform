# Product Decisions

This is the canonical Product Decision Log for The One 2.0. Every decision
below has status **ACCEPTED**. Changes require an explicit superseding decision;
implementation convenience does not change an accepted decision.

## PD-001 — Platform Membership

**Status: ACCEPTED**

Free, Plus, and Pro are The One platform-level memberships. They are not owned
by an individual Teacher. The product is **The One Plus**, not **Teacher A
Plus**.

## PD-002 — Core Roadmap Access

**Status: ACCEPTED**

The One Guitar Roadmap 2.0 is the core learning system. Plus and Pro users may
access Core Roadmap content according to Content Access Policy. A Learning Node
may contain resources authored by multiple Teachers or Creators. Content
authorship does not determine access authority.

## PD-003 — Creator Premium Products

**Status: ACCEPTED**

Creator or Teacher premium courses outside the Core Roadmap may be separate
Products, including a Fingerstyle Masterclass, Jazz Course, Blues Course, or
Arrangement Course. They may use one-time purchase or future recurring billing.
Plus or Pro membership does not automatically grant every Creator Premium
Product.

## PD-004 — Content / Product Separation

**Status: ACCEPTED**

Preserve these boundaries:

`Content != Product != Commerce != Payment != Entitlement != Achievement`

`Content Author != Access Authority != Revenue Owner`

## PD-005 — Creator Revenue Attribution

**Status: ACCEPTED**

Platform membership revenue must not be divided equally by Teacher count. The
future model is:

`Subscription Revenue → Net Revenue → configurable revenue pools → qualified creator attribution → settlement`

Creator attribution should use an attribution ledger and auditable history. Do
not hard-code pool percentages or formulas, and do not implement view-count-only
revenue sharing. Detailed creator settlement belongs to a future Finance
domain.

## PD-006 — Pro Human Service

**Status: ACCEPTED**

Pro is a platform-level membership. Its human services may include Teacher
Review, Feedback, Verification, Coaching, and practice adjustment. Reviewer
assignment may depend on Teacher capability, stage capability, Student
relationship, specialization, availability, and routing policy. Pro does not
belong to a specific Teacher.

## PD-007 — Content Revenue vs Service Revenue

**Status: ACCEPTED**

Keep these Teacher compensation categories separate:

- one-on-one lesson earnings;
- Core content creator attribution;
- Pro review compensation;
- assessment compensation;
- Creator course revenue;
- mentor revenue.

Do not combine them into one generic Teacher revenue formula.

## PD-008 — Review Quota

**Status: ACCEPTED**

Review quota remains configurable. Do not hard-code monthly quantity, rollover,
resubmission charge, free revision count, or overage pricing. Future
implementation should support allocation plus ledger/history.

## PD-009 — Revenue Formula TBD

**Status: ACCEPTED**

Creator pool percentages, qualified attribution weights, review compensation,
assessment compensation, and platform share remain commercial configuration or
TBD. Do not hard-code them during Epic 7 or Epic 8 unless separately approved.
