# MASTER PRD

## Architecture Follow-up — Core 1-on-1 service and configurable review quota

### Two primary product lines

The One 2.0 has two independent, mutually reinforcing core services: **1-on-1
personalized guitar teaching** and **platform Membership providing eligible
access to a catalog of System Courses and learning capabilities**. Membership
does not reduce one-on-one's strategic importance. Free is
traffic/trust/learning entry; Plus is structured self-study; Pro adds Teacher
review and verified learning. **1-on-1 Fixed** is stable recurring personalized
teaching, and **1-on-1 Flexible** is flexible high-value personalized teaching.
Both are core revenue services, and every Free, Plus, or Pro Student may
independently purchase one-on-one access.

LMS/review can recommend a lesson for a blockage; an authorized Teacher can
help during a lesson and direct a learner back to LMS practice/submission. The
services are not hard-bound, and lesson participation does not grant access to
all private learning evidence or feedback.

### Configurable review quota and lesson modes

Review quota is Product/Business Configuration, never a platform constant. The
architecture supports allocation, reservation, consumption, adjustment,
expiry/reset, audit/history, additional-review purchase, and configurable
resubmission policy. It deliberately sets no monthly/period count, reset cycle,
free-resubmission count, re-submission consumption rule, pack size, or price.

Fixed/Recurring and Flexible Booking are distinct. Fixed is an ongoing weekly
local-time priority reservation, with each occurrence a separate credit-
consuming Lesson. Flexible is a one-time eligible availability selection with
its own Lesson. Flexible may currently be commercially positioned NT$100 above
Fixed per lesson, but this is business direction only: Commerce/Product pricing
owns the amount and Scheduling must never hard-code the difference.

## Architecture Update — Learning Verification LMS & Membership

**Status:** planning only; Epic 7 product approvals are incorporated in
[Epic 7 Scope Definition](EPIC7_SCOPE_DEFINITION.md). Implementation remains
**NOT STARTED / NOT AUTHORIZED**. This synchronization creates no code,
migration, schema, remote database change, or production LMS behavior.

### Product direction

The One 樂玩吉他 2.0 combines free content, structured training, human Teacher
review, and verified progress: **YouTube teaches how; The One confirms that the
learner can do it.** The future learning flow is:

`system_course → learning_map → stage/level → module → learning_node → resource → practice → evidence → verification`.

The One Guitar Roadmap 2.0 is the flagship guitar System Course, not the
Membership itself or the platform's only possible System Course. Membership
may include multiple approved System Courses through plan, inclusion/access
policy, and Entitlement.

The existing five-stage `learning_map_stages` classification is retained:
(1) 0 to 1 basic accompaniment, (2) technique and accompaniment refinement,
(3) theory and fretboard, (4) transcription and transformation, and
(5) arrangement and composition. These are legacy Teacher/Trial references,
not the identities of new System Course Levels. New Stage/Level structures
are course-scoped; the flagship uses Level 1–6 and preserves the six outcomes
in [Guitar Roadmap principles](guitar-roadmap/README.md). Other System Courses
may use different structures/names. Integration is additive; any legacy
relationship requires explicit mapping/policy, never identity equality.

A Learning Node is the smallest structured unit. It will have title, objective,
prerequisites, stage/module/order, resources, practice requirements,
verification method, pass criteria, and learning-standard version. Viewing is
activity, not proof of demonstrated skill.

Epic 7 initial content is a representative production-like vertical slice
covering the hierarchy, multiple Modules/Nodes, multi-Resource Nodes,
objectives, Skill Mapping, prerequisites, ordering and versioning. A complete
representative Level plus a next-Level sample can test cross-Level structure;
full formal Level 1–6 content entry is not a closure blocker.

A Node is not one video. It may have variable teaching/practice videos,
how-to-learn/practice guidance, PDFs, audio, backing tracks or self-check
instructions, plus optional future submission/review/verification/assessment
capabilities. No fixed resource count or mandatory identical fields apply.
Learning prerequisites are advisory: Students may skip ahead when the target
content's own access policy permits. Prerequisite is neither Content Access,
Entitlement, Verification nor Assessment.

### Product ladder (proposed)

| Tier | Intended value |
| --- | --- |
| Free | Basic map, selected free resources, personal progress. |
| Plus | Full structured self-study, premium resources/tools, practice plans. |
| Pro | Plus plus human review, verified progress, assessment/certification eligibility, and finite review quota. |

Free, Plus, and Pro are membership tiers, **not** Auth roles. A Teacher may
also be a Student. One-on-one lessons remain independent lesson
entitlements/credits.

These are product directions, not a fixed resource-to-tier matrix. Epic 8
owns access through Membership Plan + Membership Inclusion / Access Policy +
Entitlement. The flagship may offer main free learning content across Nodes;
other resources/capabilities remain independently configurable, including
standalone grants. Epic 7 supplies stable IDs and attachment points, not
PDF = Plus, Review = Pro, or provider-based access rules.

### Durable learner outcome

Students may explicitly record **Self Complete** as personal learning/usage
state. Viewing does not automatically complete a Node. Self Complete is not
Verified, Mastered, Assessment Passed, Certificate Earned or formal Stage/Level
completion, even when every Node is self-completed. Epic 7 provides this basic
progress foundation; it does not implement a production progress UI.

`VIEWED`/`PRACTICED` describe activity; `SUBMITTED`, `UNDER_REVIEW`,
`REVISION_REQUIRED`, and `VERIFIED` belong to later evidence/review workflows,
not one Epic 7 completion enum. Formal Verification belongs to Epic 10;
formal Assessment/Achievement belongs to Epic 11. Only appropriately verified
work can satisfy formal stage/assessment prerequisites. Membership expiry or
cancellation removes future access according to entitlement policy but must not
erase submissions, feedback, verified nodes, completions, certificates, or
audit history.

### Workspace and workflow boundaries

The personal Learning Map appears only after formal course joining/confirmed
use eligibility. An unjoined course must not appear as 0% progress, Level
progress or a personal roadmap. Recommendation is not enrollment; a suggested
starting Level is not completion or formal verification. Epic 8 owns course
access and Epic 9 owns the Student Workspace/personal map.

The future journey is promotion/pain-point guidance → staged diagnosis →
recommended System Course and starting point → recommendation plan → joining
→ personal Learning Map → Practice / Review / Verification / Assessment.
Full diagnosis and recommendation workflows remain future interface/product
notes without a newly assigned Epic or an Epic 7 closure dependency.

Node support for async review is content capability; a Student's eligibility
is Epic 8 policy; upload → Teacher review → Feedback → Revision/Resubmission
→ any Verification is Epic 10 workflow. Epic 7 implements none of that workflow.
Its only planned surface is minimal internal/Admin structure inspection.
Immutable version foundations do not include the Epic 13 Creator CMS,
Draft → Review → Publish or production publishing system.

### Pending formal-product decisions

Plan prices/capability detail; review quota, renewal, rollover and resubmission
policy; assessment/certificate policy; reviewer SLA/assignment; content
licensing/downloads; and membership grace/refund rules remain for the formal
PRD.

## Architecture Follow-up — Core 1-on-1 service and configurable review quota

### Two primary product lines

The One 2.0 has two independent, mutually reinforcing core services:

1. **1-on-1 personalized guitar teaching**; and
2. **platform Membership with a catalog of eligible System Courses and learning
   capabilities**.

Membership and System Course learning do not reduce the strategic importance of
one-on-one teaching.
Free is a traffic/trust/learning entry; Plus is structured self-study; Pro adds
Teacher review and verified learning. **1-on-1 Fixed** is stable recurring
personalized teaching, while **1-on-1 Flexible** is flexible, high-value
personalized teaching. Both are core revenue services. Every Free, Plus, or Pro
Student may independently purchase one-on-one access.

The services may refer learners to one another: LMS/review can recommend a
one-on-one session for a blockage; an authorized Teacher can help a learner in
a lesson and direct them back to LMS practice/submission. They are not hard
bound, and a lesson Teacher does not automatically receive all private learning
evidence or feedback.

### Configurable review quota

Review quota is Product/Business Configuration, never a platform constant. The
architecture supports allocation, reservation, consumption, adjustment,
expiry/reset, audit/history, additional-review purchase, and configurable
resubmission policy. It deliberately sets no monthly/period count, reset cycle,
free-resubmission count, re-submission consumption rule, pack size, or price.

### One-on-one modes

Fixed/Recurring and Flexible Booking are distinct scheduling behaviors:

- **Fixed / Recurring Lesson:** Student and Teacher agree an ongoing weekly
  local-time slot with priority reservation. Each occurrence remains a separate
  Lesson and consumes a Lesson Credit, while the series persists until pause,
  change, or end.
- **Flexible Booking:** a Student selects one available Teacher slot; each
  booking is an independent Lesson and requires sufficient Lesson entitlement
  or Credit.

Flexible lessons may currently be commercially positioned above fixed lessons
by NT$100 per lesson. This is a current business direction only: Commerce /
Product pricing owns the actual amount, and Scheduling must never hard-code a
price difference.

Status: Draft

## Purpose

The authoritative product requirements document for The One 樂玩吉他 2.0.

## Pending formal PRD input

To be completed from the approved formal PRD.

## Epic 4 delivered scope

The implemented Commerce Core covers Product → Order → Order Item → Payment →
`order.paid` outbox. It supports manual bank-transfer review and cash confirmation
without a live gateway. Epic 4 itself does not grant entitlements or credits;
Epic 5 is REMOTE CLOSED and implements Lesson Package fulfillment and
Lesson Credits. Subscriptions, refunds, invoices, earnings, and LMS entitlement
remain future PRD work.
