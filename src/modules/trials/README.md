# Trial module

Owns the Epic 3 Student–Teacher Trial flow: validation, IANA timezone helpers,
participant-minimized DTOs, and re-authorized Server Actions. PostgreSQL owns
atomic payment confirmation, completion, idempotency, participant RLS, and
collision constraints. Meeting URLs must only leave the server through the
authorized Lesson join route.
