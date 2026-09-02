-- P1-4 missing-domain contracts. These are necessary schema prerequisites,
-- NOT complete behavioral acceptance tests for a future implementation. No final
-- production table/field/RPC names are prescribed. The evidence test exercises
-- today's real RPCs; these assertions intentionally fail where storage/authority
-- cannot express the requested lifecycle. Do not skip or invert expectations.
begin;
select no_plan();

-- A cycle needs durable series-to-entitlement identity, beyond an occurrence's
-- reservation or the series' single preferred_entitlement_id pointer.
create temporary view cycle_relations as
select c.oid,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind in('r','p')
  and exists(select 1 from pg_constraint f where f.conrelid=c.oid and f.contype='f'
    and f.confrelid='public.recurring_lesson_series'::regclass)
  and exists(select 1 from pg_constraint f where f.conrelid=c.oid and f.contype='f'
    and f.confrelid='public.entitlements'::regclass);
create temporary view renewal_storage as
select c.oid,c.relname,a.attname from pg_class c join pg_namespace n on n.oid=c.relnamespace
join pg_attribute a on a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
where n.nspname='public' and c.relkind in('r','p')
  and (c.oid='public.recurring_lesson_series'::regclass
    or exists(select 1 from pg_constraint f where f.conrelid=c.oid and f.contype='f'
      and f.confrelid='public.recurring_lesson_series'::regclass))
  and (a.attname~*'renew|intent|cycle_end|deadline' or c.relname~*'renew');
-- An order expires, but cannot represent a hold without any slot identity.
-- Discover checkout-linked storage with teacher/slot/series identity and expiry.
create temporary view hold_relations as
select c.oid,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind in('r','p')
  and exists(select 1 from pg_attribute a where a.attrelid=c.oid and a.attnum>0
    and not a.attisdropped and a.attname~*'expir|deadline')
  and (exists(select 1 from pg_constraint f where f.conrelid=c.oid and f.contype='f'
    and f.confrelid='public.orders'::regclass)
    or exists(select 1 from pg_attribute a where a.attrelid=c.oid and a.attnum>0
      and not a.attisdropped and a.attname~*'checkout|attempt'))
  and (exists(select 1 from pg_constraint f where f.conrelid=c.oid and f.contype='f'
    and f.confrelid='public.recurring_lesson_series'::regclass)
    or exists(select 1 from pg_attribute a where a.attrelid=c.oid and a.attnum>0
      and not a.attisdropped and a.attname~*'slot|weekday|local_start_time'));

select ok(exists(select 1 from cycle_relations),
  '4A/A: same Fixed series must persist sequential 4 -> 4 -> 12 entitlement cycles');
select ok(exists(select 1 from cycle_relations c join pg_constraint k on k.conrelid=c.oid
  where k.contype='u' and exists(select 1 from pg_trigger t where t.tgrelid=c.oid and not t.tgisinternal)),
  '4A/B: cycle identity/history must survive renewal without overwriting prior entitlement');
select ok(exists(select 1 from renewal_storage),
  '4B/R1: renewal window must belong to a current cycle while original owner retains priority');
select ok(exists(select 1 from cycle_relations c join pg_proc p on p.prosrc like '%'||c.relname||'%'
  where p.prosrc like '%order_fulfillment_events%' and p.prosrc like '%entitlements%'),
  '4B/D/R3: successful paid fulfillment must authorize idempotent next-cycle attachment to same series');
select ok(exists(select 1 from renewal_storage where attname~*'intent|non_renew|not_renew|cycle_end'),
  '4B/E/R4: non-renew intent must be representable separately from immediately ending the series');
select ok(exists(select 1 from cycle_relations c join pg_constraint f on f.confrelid=c.oid
  where f.contype='f' and f.conrelid in('public.lessons'::regclass,'public.bookings'::regclass,
    'public.recurring_lesson_occurrences'::regclass)),
  '4B/R5: delayed final lesson must remain associated with incomplete cycle value');
select ok(exists(select 1 from renewal_storage where attname~*'deadline|expir'),
  '4B/F/R6: future priority release requires a recorded renewal deadline and unsuccessful renewal');
select ok(exists(select 1 from pg_attribute a join pg_class c on c.oid=a.attrelid
  join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and a.attnum>0
  and not a.attisdropped and c.relname in('lesson_package_product_configs','order_item_fulfillment_snapshots')
  and a.attname~*'renew|remind|deadline|hold')
  or exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in('public','private') and p.prosrc~*'config_metadata|config_snapshot'
      and p.prosrc~*'renew|remind|deadline|hold_duration'),
  '4B/config: reminder trigger, deadline offset and pending-payment hold policy need implemented configuration');

select ok(exists(select 1 from hold_relations),
  '4C/G/C3: checkout attempt must have expiring candidate-slot hold, not just order expiry');
select ok(exists(select 1 from hold_relations c join pg_constraint k on k.conrelid=c.oid where k.contype='x')
  or exists(select 1 from hold_relations c join pg_proc p on p.prosrc like '%'||c.relname||'%'
    where p.prosrc~*'advisory.*lock|for update'),
  '4C/H/C1-C2: concurrent same-slot claims require atomic authority for exactly one active holder');
select ok(exists(select 1 from hold_relations c join pg_attribute a on a.attrelid=c.oid
  where a.attnum>0 and not a.attisdropped and a.attname~*'status|state'),
  '4C/I/C4: expiring or failed hold must be distinct from permanent Fixed ownership');
select ok(exists(select 1 from hold_relations h join pg_proc p on p.prosrc like '%'||h.relname||'%'
  where p.prosrc like '%recurring_lesson_series%' and p.prosrc like '%entitlements%'),
  '4C/C5: successful payment plus fulfillment must convert hold into series and first cycle');
select ok(exists(select 1 from cycle_relations c join pg_constraint k on k.conrelid=c.oid
  where k.contype='u' and pg_get_constraintdef(k.oid)~*'fulfill|event|order_item'),
  '4C/C6: repeated fulfillment event must not attach duplicate cycle/owner');
select ok(exists(select 1 from hold_relations h join pg_proc p on p.prosrc like '%'||h.relname||'%'
  where p.prosrc~*'expir|deadline' and p.prosrc like '%recurring_lesson_series%'),
  '4B/R7 + 4C/J/C7: delayed payment after expiry must recheck ownership, never displace new legal owner');

-- Scenario contract for the future real two-session hold harness: A/B claim same
-- released slot -> one active hold; loser rejected; expiry -> B allowed; payment
-- failure -> no owner; paid+fulfilled -> one owner/cycle; retry -> no duplicate;
-- A delayed callback after B acquires -> B remains owner. Today no hold claim RPC
-- exists, so racing create_checkout_order is ONLY evidence of an unbound checkout,
-- never evidence that two actual holds/owners were acquired.
select * from finish();
rollback;
