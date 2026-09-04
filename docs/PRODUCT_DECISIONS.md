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

## PD-010 — Membership Is Not a System Course

**Status: ACCEPTED**

Free, Plus, and Pro are subscription and access plans provided by The One 2.0.
Membership is not a System Course. Membership controls eligible access through
plan, inclusion/access policy, and Entitlement.

Free provides free or preview access. Plus provides self-directed access to
eligible Membership System Courses and digital learning capabilities. Pro adds
eligible human services such as Review, Feedback, Verification, Coaching, and
Assessment eligibility; each System Course may support a different subset.

## PD-011 — System Course

**Status: ACCEPTED**

A System Course is a first-class product/content concept: a structured learning
program that may contain learning objectives, a curriculum or Learning Map,
Stages or Levels, Modules, Nodes, Resources, Practice, Progress, Evidence,
Review capability, and Assessment capability. The future domain model must
support multiple System Courses without hard-coding one guitar curriculum.

Examples include The One Guitar Roadmap 2.0, Blues Guitar System, Fingerstyle
Foundation System, Jazz Guitar Roadmap, and future instrument learning systems.

## PD-012 — Guitar Roadmap Is the Flagship System Course

**Status: ACCEPTED**

The One Guitar Roadmap 2.0 is The One's flagship guitar System Course. It is not
the definition of Membership, the entire The One 2.0 platform, or the only
System Course the platform may support.

## PD-013 — Membership Catalog

**Status: ACCEPTED**

A Membership may provide access to multiple approved System Courses through a
Membership Catalog. Access is determined by:

`Membership Plan + Membership Inclusion / Access Policy + Entitlement`

Teacher identity does not determine Membership access. Not every System Course
must support every Plus or Pro capability; future policies decide course-level
Plus access, Pro review, verification, assessment, and certificate eligibility.

## PD-014 — Creator Participation Models

**Status: ACCEPTED**

A Teacher or Creator may contribute a System Course included in Membership,
sell a standalone premium Product, or do both. A Creator's Membership-included
System Course does not make their standalone masterclass part of Membership.
One-on-one lessons and Pro human services remain separate human-service and
compensation categories.

## PD-015 — Membership Creator Attribution

**Status: ACCEPTED**

Membership revenue attribution uses a future configurable model, never an
equal split by Teacher count:

`Membership Revenue → Net Revenue → Configurable Revenue Pools → Qualified Content / Creator Attribution → Settlement`

Future attribution should be traceable to Creator, Content, System Course,
Membership inclusion, and qualified learning contribution. Pool percentages,
Creator weights, review compensation, and platform share remain unapproved
configuration in the future Finance domain. View-count-only attribution is not
an approved model.
