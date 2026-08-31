# Teachers Module

Owns Teacher private editing, Admin-only teacher management, public discovery
queries, Specialty and Learning Map catalog handling, and Teacher-specific
validation.

Public pages consume only the `teacher_public_profiles` projection through
`public-discovery.ts`. Do not read `profiles` or `teacher_profiles` in a
public route or public API.
