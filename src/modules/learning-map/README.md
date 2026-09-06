# Learning Map Module

## Status

Architecture boundary only. This module has no production LMS implementation,
database table, migration, or client API yet.
The four product approvals are incorporated in
[Epic 7 Scope Definition](../../../docs/EPIC7_SCOPE_DEFINITION.md).
Epic 7 implementation is **NOT STARTED / NOT AUTHORIZED**.

## Future responsibility

The module will own the platform curriculum hierarchy:

`System Course → Curriculum / Learning Map → Stage / Level → Module → Node → Resource`.

It will model provider-neutral resources and versioned learning standards. A
Learning Node will express objective, prerequisites, ordered placement,
resources, practice requirements, verification method, pass criteria, and
standard version. The existing `learning_map_stages` catalog remains the
legacy Stage 1–5 Teacher/Trial base with all references preserved. New Levels
are course-scoped: Guitar Roadmap uses Level 1–6, while other courses can use
different structures. Integration is additive; any relationship needs explicit
mapping/policy, not 1:1 identity equality or automatic capability transfer.

Nodes have variable Resource sets and optional future capability attachment
points, not one video or fixed horizontal fields. Initial content is a
representative production-like vertical slice, not full Level 1–6 entry.
Version foundations and minimal internal/Admin inspection do not include a
production publishing system or Creator workflow (Epic 13).

## Boundary rules

- Do not put membership/plan checks, payment logic, or UI-only authorization in
  this module. Future premium access is decided by a server-side Entitlement
  boundary.
- Do not couple Nodes to YouTube or VdoCipher. Resource providers are an
  adapter concern; VdoCipher tokens are server-issued only after entitlement
  authorization. Free resources follow policy, not provider identity.
- Prerequisites are advisory. Resource/capability access belongs to Epic 8's
  Plan + Inclusion/Access Policy + Entitlement boundary, with no tier-by-type
  or authorship shortcut. Content supports a capability; Epic 8 authorizes the
  Student; Epic 10 executes submission/review and Epic 11 assessment.
- Progress is a neighboring domain with an Epic 7 personal Self Complete
  foundation. It is not VERIFIED, mastery, formal Stage completion, assessment
  pass or certificate. Viewing does not auto-complete. Evidence/review and
  formal outcomes remain Epic 10/11, never raw Student or Teacher writes.
- Epic 9 owns Student Workspace/personal map UI after formal course joining/
  eligibility. Recommendation is not enrollment and suggested start is not
  certification. Unjoined Courses get no personal 0%/Level progress. Diagnosis/
  recommendation workflows remain future interface notes, not Epic 7 blockers.
- Teachers act through stage-scoped capabilities and review assignment; the
  map belongs to the platform, not a single Teacher. Legacy assignments do not
  authorize new-course Levels. Authorship grants no access or revenue authority.
- AI may later assist but cannot issue a formal verification, assessment, or
  certificate decision.
