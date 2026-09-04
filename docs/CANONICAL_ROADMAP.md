# Canonical Roadmap

Status: **APPROVED PRODUCT/ENGINEERING ROADMAP**

This file owns the approved Epic 7+ numbering and scope boundaries. Each Epic
still requires its own approved implementation scope, security review, tests,
and deployment gates. This roadmap does not authorize implementation or make
future/post-launch scope a current blocker.

## Epic 7 — Learning Map Core

Core scope:

- a generic System Course architecture that supports multiple courses;
- Learning Map, Stage or Level, Module, Node, and Resource within a System
  Course;
- Learning Objective, Prerequisite, and Skill Mapping;
- content ownership and authorship;
- standard versioning;
- basic learning-progress foundation.

Canonical hierarchy:

`System Course → Curriculum / Learning Map → Stage / Level → Module → Node → Resource`

The One Guitar Roadmap 2.0 is the first flagship implementation. Epic 7 must
not hard-code the architecture to one guitar curriculum.

## Epic 8 — Membership & Content Access

Core scope:

- Free, Plus, and Pro platform membership;
- membership plan and subscription lifecycle;
- Membership Catalog and approved System Course inclusion;
- Content Access Policy;
- subscription-to-entitlement mapping;
- training, recorded-course, and premium-resource entitlement;
- course-level capability policy for Plus access, Pro review, verification,
  assessment, and certificate eligibility.

Membership access authority is:

`Membership Plan + Membership Inclusion / Access Policy + Entitlement`

It does not derive from Teacher or Creator identity. Membership is not itself a
System Course, and not every Creator Product is Membership-included.

Preserve the boundary:

`Product Type != Billing Model != Entitlement`

## Epic 9 — Learning Workspace & Practice

Core scope:

- Today, Learning Map, Practice, and Practice Plans;
- Resources, PDF, Audio, and Backing Tracks;
- Progress, Homework, and upcoming private lessons.

Primary UX question: **“What should I do today?”**

## Epic 10 — Submission / Coaching / Verification

Core scope:

- Assignment, Evidence, and Submission;
- Teacher Review, Feedback, Revision, and Resubmission;
- Verified Progress;
- Rubric and rubric versions;
- review-quota foundation;
- AI pre-screen.

AI must not make formal `VERIFIED` decisions.

## Epic 11 — Assessment / Achievement / Certificate

Core scope:

- Stage Assessment and Assessment Version;
- Attempt, Evaluator, and Pass Criteria;
- Stage Completion;
- Achievement and Certificate.

## Epic 12 — Private Lesson / Teacher Workspace

Student scope:

- upcoming lesson, join, and reschedule;
- homework, Lesson Record, and Teacher Feedback;
- Learning Map connection.

Teacher scope:

- Today, Schedule, Students, and Student Roadmap;
- Homework, Review Queue, Package, Progress, and Notes.

## Epic 13 — Admin / Creator / Operations / Production Launch

Core scope:

- Admin workspace and Creator content;
- Draft → Review → Publish;
- Teacher capabilities;
- notifications and LINE;
- payment operations;
- monitoring and E2E;
- production hardening and launch readiness.

## Future / post-launch

The following numbering is not frozen:

- Finance / Earnings / Payout;
- Community / Showcase;
- AI Personalization;
- Cloud Classroom;
- Marketplace;
- Other Instruments;
- PWA / Native App.

Do not promote these scopes into current Epic blockers.
