# MASTER PRD

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
