# Supabase database workflow

All schema, grants, triggers, and RLS policies are versioned in
`supabase/migrations`. Do not create production-only schema changes in the
Dashboard without a matching migration.

The SQL tests under `supabase/tests/database` are intended for a local or
linked Supabase project with pgTAP available:

```text
supabase db reset
supabase test db
```

No project credentials or database dumps belong in this directory.
