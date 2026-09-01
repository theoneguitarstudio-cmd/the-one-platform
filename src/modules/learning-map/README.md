# Learning Map Module

## Status

Architecture boundary only. This module has no production LMS implementation,
database table, migration, or client API yet.

## Future responsibility

The module will own the platform curriculum hierarchy:

`learning_maps → stages → modules → learning_nodes → resources → practice requirements`.

It will model provider-neutral resources and versioned learning standards. A
Learning Node will express objective, prerequisites, ordered placement,
resources, practice requirements, verification method, pass criteria, and
standard version. The existing `learning_map_stages` catalog remains the
canonical Stage 1–5 base; later work must integrate it deliberately rather than
replace it silently.

## Boundary rules

- Do not put membership/plan checks, payment logic, or UI-only authorization in
  this module. Future premium access is decided by a server-side Entitlement
  boundary.
- Do not couple Nodes to YouTube or VdoCipher. Resource providers are an
  adapter concern; VdoCipher tokens are server-issued only after entitlement
  authorization, while YouTube may remain free.
- Progress, submissions, reviews, human verification, assessment, and
  certificates are neighboring domains. `VERIFIED` is a human-authorized
  outcome, not a video-view event.
- Teachers act through stage-scoped capabilities and review assignment; the
  map belongs to the platform, not a single Teacher.
- AI may later assist but cannot issue a formal verification, assessment, or
  certificate decision.
