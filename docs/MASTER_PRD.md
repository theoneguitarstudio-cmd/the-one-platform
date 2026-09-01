# MASTER PRD

## Architecture Follow-up — Core 1-on-1 service and configurable review quota

### Two primary product lines

The One 2.0 has two independent, mutually reinforcing core services: **1-on-1
personalized guitar teaching** and **LMS / Training / Learning Verification
membership**. LMS does not reduce one-on-one's strategic importance. Free is
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

**Status:** Architecture proposal only. This update creates no Epic 5 code,
migration, schema, remote database change, or production LMS behavior.

### Product direction

The One 樂玩吉他 2.0 combines free content, structured training, human Teacher
review, and verified progress: **YouTube teaches how; The One confirms that the
learner can do it.** The future learning flow is:

`learning_maps → stages → modules → learning_nodes → resources → practice → evidence → verification`.

The canonical five stages are: (1) 0 to 1 basic accompaniment, (2) technique
and accompaniment refinement, (3) theory and fretboard, (4) transcription and
transformation, and (5) arrangement and composition.

A Learning Node is the smallest structured unit. It will have title, objective,
prerequisites, stage/module/order, resources, practice requirements,
verification method, pass criteria, and learning-standard version. Viewing is
activity, not proof of demonstrated skill.

### Product ladder (proposed)

| Tier | Intended value |
| --- | --- |
| Free | Basic map, selected free resources, personal progress. |
| Plus | Full structured self-study, premium resources/tools, practice plans. |
| Pro | Plus plus human review, verified progress, assessment/certification eligibility, and finite review quota. |

Free, Plus, and Pro are membership tiers, **not** Auth roles. A Teacher may
also be a Student. One-on-one lessons remain independent lesson
entitlements/credits.

### Durable learner outcome

Proposed node states are `VIEWED`, `PRACTICED`, `SUBMITTED`, `UNDER_REVIEW`,
`REVISION_REQUIRED`, and `VERIFIED`. Only verified work can complete a stage or
qualify a learner for assessment/certification. Membership expiry or
cancellation removes future access according to entitlement policy but must not
erase submissions, feedback, verified nodes, completions, certificates, or
audit history.

### Pending formal-product decisions

Plan prices/capability detail; review quota, renewal, rollover and resubmission
policy; assessment/certificate policy; reviewer SLA/assignment; content
licensing/downloads; and membership grace/refund rules remain for the formal
PRD.

## Architecture Follow-up — Core 1-on-1 service and configurable review quota

### Two primary product lines

The One 2.0 has two independent, mutually reinforcing core services:

1. **1-on-1 personalized guitar teaching**; and
2. **LMS / Training / Learning Verification membership**.

LMS membership does not reduce the strategic importance of one-on-one teaching.
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
without a live gateway. Course packages, credits, subscriptions, refunds,
invoices, earnings, and LMS entitlement remain future PRD work.
