-- P1-5 target contracts for the currently missing Makeup Right domain.
-- These assertions intentionally fail until production implements the domain.
-- They are schema/authority prerequisites, not a prescribed final naming scheme.
begin;
select no_plan();

create temporary view makeup_relations as
select c.oid,c.relname
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind in('r','p')
  and c.relname~*'makeup';

create temporary view makeup_columns as
select r.oid,r.relname,a.attname,format_type(a.atttypid,a.atttypmod) as data_type
from makeup_relations r
join pg_attribute a on a.attrelid=r.oid and a.attnum>0 and not a.attisdropped;

create temporary view makeup_functions as
select p.oid,p.proname,p.prosrc
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname in('public','private')
  and (p.proname~*'makeup' or p.prosrc~*'makeup');

select ok(exists(select 1 from makeup_relations),
  'M1: Teacher cancellation value transfers into one first-class Makeup Right');
select ok(exists(select 1 from makeup_functions
  where prosrc~*'teacher_cancel' and prosrc~*'makeup'
    and prosrc!~*'release_lesson_credit_core'),
  'M2: Teacher cancellation converts value without restoring ordinary credit');
select ok(exists(select 1 from makeup_relations r
  join pg_constraint f on f.conrelid=r.oid and f.contype='f'
  where f.confrelid='public.lessons'::regclass),
  'M3: Makeup Right is traceable to its origin Lesson');
select ok(exists(select 1 from makeup_columns where attname~*'origin_teacher')
  and exists(select 1 from makeup_columns where attname~*'reason|source')
  and exists(select 1 from makeup_columns where attname~*'actor|created_by'),
  'M3: origin Teacher, reason/source, and actor identity are durable');
select ok(exists(select 1 from makeup_columns where attname='valid_until'),
  'M4: Makeup Right has its own valid_until independent of entitlement expiry');
select ok(exists(select 1 from makeup_columns where attname~*'current_teacher|teacher_scope'),
  'M4: current Teacher scope is distinct from origin Teacher history');
select ok(exists(select 1 from makeup_functions
  where proname~*'book' and proname!~*'cancel|complet|reschedul'
    and prosrc~*'makeup'
    and prosrc!~*'reserve_lesson_credit_core'),
  'M5: Makeup booking reserves a Makeup Right, not ordinary entitlement credit');
select ok(exists(select 1 from makeup_functions
  where proname~*'complet' and prosrc~*'makeup'
    and prosrc!~*'consume_lesson_credit_core'),
  'M6: Makeup completion consumes the Makeup Right, not ordinary credit');
select ok(exists(select 1 from makeup_functions
  where proname~*'cancel.*makeup|makeup.*cancel'
    and prosrc~*'restor|available'),
  'M7: timely Makeup cancellation restores the same right');
select ok(exists(select 1 from makeup_relations r
  join pg_constraint k on k.conrelid=r.oid and k.contype='u'
  where pg_get_constraintdef(k.oid)~*'lesson|origin'),
  'M8: origin identity prevents retry from creating duplicate Makeup Rights');
select ok(exists(select 1 from makeup_functions
  where prosrc~*'for update|advisory' and prosrc~*'cancel' and prosrc~*'makeup'),
  'M9-M10: cancellation/completion races serialize on authoritative value state');
select ok(exists(select 1 from makeup_columns where attname='status')
  and exists(select 1 from makeup_functions where prosrc~*'available' and prosrc~*'reserved'
    and prosrc~*'used' and prosrc~*'expired'),
  'Lifecycle supports available -> reserved -> used plus expiry/revocation');
select ok(exists(select 1 from makeup_relations r
  where (select relrowsecurity from pg_class where oid=r.oid))
  and not exists(select 1 from makeup_relations r
    where has_table_privilege('authenticated',r.oid,'INSERT,UPDATE,DELETE')),
  'Makeup storage has RLS and no authenticated raw-write authority');
select ok(exists(select 1 from makeup_functions
  where prosrc~*'audit_logs' and prosrc~*'before_snapshot' and prosrc~*'after_snapshot'),
  'Create/reserve/restore/use/transfer mutations are actor-aware and audited');

select * from finish();
rollback;
