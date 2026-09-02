-- P1-4A: actual fulfilled 4 -> 4 -> 12 packages on one immutable Fixed owner.
-- Existing audit expectations are unchanged. Fixture-only time travel below
-- makes real Booking completion RPCs executable without waiting for weeks.
begin;
select no_plan();
create temporary table cycle_ids(name text primary key,id uuid);
grant select,insert,update on cycle_ids to authenticated,service_role;
insert into auth.users(id,email) values
('67000000-0000-0000-0000-000000000001','cycle-a@example.invalid'),
('67000000-0000-0000-0000-000000000002','cycle-b@example.invalid'),
('67000000-0000-0000-0000-000000000003','cycle-teacher@example.invalid'),
('67000000-0000-0000-0000-000000000004','cycle-admin@example.invalid');
insert into public.user_roles(user_id,role) values
('67000000-0000-0000-0000-000000000003','teacher'),('67000000-0000-0000-0000-000000000004','admin');
insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,
  teaching_modes,trial_price_twd,default_meeting_provider,default_meeting_url) values
('67000000-0000-0000-0000-000000000003','cycle-teacher','Renewal fixture','active',true,
  array['online']::public.teaching_mode[],500,'manual_google_meet','https://meet.google.com/abc-defg-hij');
insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode) values
('67000000-0000-0000-0000-000000000011','67000000-0000-0000-0000-000000000001','67000000-0000-0000-0000-000000000003','active','online'),
('67000000-0000-0000-0000-000000000012','67000000-0000-0000-0000-000000000002','67000000-0000-0000-0000-000000000003','active','online');
insert into public.products(id,product_type,status,public_slug,name,currency,base_price_amount,
  owner_type,is_public,is_purchasable,published_at) values
('67000000-0000-0000-0000-000000000021','lesson_package','active','cycle-four','Four Fixed','TWD',3200,'platform',true,true,now()),
('67000000-0000-0000-0000-000000000022','lesson_package','active','cycle-twelve','Twelve Fixed','TWD',8400,'platform',true,true,now());
insert into public.lesson_package_product_configs(product_id,lesson_count,validity_value,validity_unit,
  lesson_duration_minutes,booking_mode_eligibility) values
('67000000-0000-0000-0000-000000000021',4,12,'months',50,'fixed'),
('67000000-0000-0000-0000-000000000022',12,12,'months',50,'fixed');

insert into auth.users(id,email) values('67000000-0000-0000-0000-000000000005','cycle-other-teacher@example.invalid');
insert into public.user_roles(user_id,role) values('67000000-0000-0000-0000-000000000005','teacher');
insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd)
values('67000000-0000-0000-0000-000000000005','cycle-other-teacher','Other Teacher','active',true,array['online']::public.teaching_mode[],500);
insert into public.products(id,product_type,status,public_slug,name,currency,base_price_amount,owner_type,
  owner_teacher_user_id,is_public,is_purchasable,published_at) values
('67000000-0000-0000-0000-000000000023','lesson_package','active','cycle-both','Both modes','TWD',3200,'platform',null,true,true,now()),
('67000000-0000-0000-0000-000000000024','lesson_package','active','cycle-flex','Flexible only','TWD',3200,'platform',null,true,true,now()),
('67000000-0000-0000-0000-000000000025','lesson_package','active','cycle-other','Other Teacher package','TWD',3200,'teacher','67000000-0000-0000-0000-000000000005',true,true,now());
insert into public.lesson_package_product_configs(product_id,lesson_count,validity_value,validity_unit,lesson_duration_minutes,booking_mode_eligibility) values
('67000000-0000-0000-0000-000000000023',4,12,'months',50,'both'),
('67000000-0000-0000-0000-000000000024',4,12,'months',50,'flexible'),
('67000000-0000-0000-0000-000000000025',4,12,'months',50,'fixed');
set local role authenticated;
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.set_teacher_scheduling_settings('67000000-0000-0000-0000-000000000003','Asia/Taipei',0,180,10,'Cycle fixture')$$,'Configure cycle fixture');
select lives_ok($$insert into cycle_ids values('series',public.create_recurring_lesson_series(
  '67000000-0000-0000-0000-000000000001','67000000-0000-0000-0000-000000000003',
  '67000000-0000-0000-0000-000000000011',null,extract(dow from current_date)::smallint,
  '20:00','Asia/Taipei',50::smallint,current_date,null,'Long term cycle owner'))$$,'Create one long-lived Fixed owner');
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000001',true);
select lives_ok($$insert into cycle_ids select 'order-'||name,public.create_checkout_order(slug,1,'cycle-checkout-'||name)
from (values('four-a','cycle-four'),('four-b','cycle-four'),('twelve','cycle-twelve'),
  ('both','cycle-both'),('flex','cycle-flex'),('other','cycle-other'),('pending','cycle-four'),
  ('revoked','cycle-four'),('cancelled','cycle-four'),('expired','cycle-four'),('exhausted','cycle-four'),
  ('future','cycle-four'),('unpaid','cycle-four')) x(name,slug)$$,'Create real package purchases');
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000002',true);
select lives_ok($$insert into cycle_ids values('order-wrong-student',public.create_checkout_order('cycle-four',1,'cycle-checkout-wrong-student'))$$,'Other student purchase');
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000004',true);
select lives_ok($$select public.admin_confirm_cash_payment(id,'cycle-cash-'||name,'Cash fixture paid') from cycle_ids
  where name like 'order-%' and name<>'order-unpaid'$$,'Confirm paid sources through Admin authority');
reset role;
insert into cycle_ids select 'event-'||r.name,e.id from cycle_ids r join public.order_fulfillment_events e on e.order_id=r.id where r.name like 'order-%';
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$select public.process_order_fulfillment_event(id) from cycle_ids where name like 'event-%'$$,'Fulfill existing paid outbox events');
reset role;
insert into cycle_ids select 'ent-'||r.name,e.id from cycle_ids r join public.entitlements e on e.source_order_id=r.id where r.name like 'order-%';
create temporary table source_packages as
select substr(r.name,11) name,e.id entitlement_id,e.source_fulfillment_event_id event_id
from cycle_ids r join public.entitlements e on e.id=r.id where r.name like 'ent-order-%';
grant select on source_packages to authenticated,service_role;
create temporary table original_series as select * from public.recurring_lesson_series where id=(select id from cycle_ids where name='series');
create temporary table credit_before_attach as select count(*) n from public.lesson_credit_ledger;

create function pg_temp.attach_package(package_name text) returns uuid language sql security invoker as $$
  select public.attach_fixed_entitlement_cycle((select id from pg_temp.cycle_ids where name='series'),
    entitlement_id,event_id,'Paid package attachment') from pg_temp.source_packages where name=package_name;
$$;
-- Called only as database owner to advance TEST fixture lesson instants. Actual
-- completion below still executes authenticated Booking/Credit domain RPCs.
create function pg_temp.past_lessons(package_name text) returns void language plpgsql security invoker as $$
declare row record; ordinal integer:=0; age_days integer;
begin
  age_days:=case package_name when 'four-a' then 10 when 'four-b' then 20 else 30 end;
  for row in select b.id,b.lesson_id from public.bookings b join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
    where r.entitlement_id=(select entitlement_id from pg_temp.source_packages where name=package_name) order by b.id
  loop
    ordinal:=ordinal+1;
    update public.lessons set starts_at=now()-make_interval(days=>age_days)-ordinal*interval '1 hour',
      ends_at=now()-make_interval(days=>age_days)-ordinal*interval '1 hour'+interval '50 minutes' where id=row.lesson_id;
    update public.bookings b set starts_at=l.starts_at,ends_at=l.ends_at from public.lessons l where b.id=row.id and l.id=b.lesson_id;
    update public.recurring_lesson_occurrences o set starts_at=l.starts_at,ends_at=l.ends_at from public.lessons l where o.booking_id=row.id and l.id=o.lesson_id;
  end loop;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000001',true);
select throws_ok($$select pg_temp.attach_package('four-a')$$,'42501','UNAUTHORIZED_FIXED_CYCLE_ACTION','Student cannot attach own cycles');
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000005',true);
select throws_ok($$select pg_temp.attach_package('four-a')$$,'42501','UNAUTHORIZED_FIXED_CYCLE_ACTION','Unrelated Teacher cannot attach');
reset role;
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$insert into cycle_ids values('cycle-1',pg_temp.attach_package('four-a'))$$,'Service fulfillment integration attaches first 4-credit cycle');
select is(pg_temp.attach_package('four-a'),(select id from cycle_ids where name='cycle-1'),'Same fulfillment/entitlement retry returns same cycle');
reset role;
select is((select count(*) from public.lesson_credit_ledger),(select n from credit_before_attach),'Attachment writes no allocation or other credit entry');
select is((select count(*) from public.fixed_entitlement_cycles),1::bigint,'Retry leaves exactly one cycle');
select is((select count(*) from public.audit_logs where action='fixed_cycle.attached'),1::bigint,'Retry leaves exactly one attach audit');
select is((select attachment_actor_role from public.fixed_entitlement_cycles),'service_role','Service source identity is audited');

-- BEGIN 4 -> 4 -> 12 SEQUENTIAL EXECUTION

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000003',true);

select throws_ok($$select public.complete_fixed_entitlement_cycle((select id from cycle_ids where name='cycle-1'),'Too early completion')$$,
  'P0001','FIXED_CYCLE_VALUE_INCOMPLETE','Cycle 1: calendar alone cannot complete unspent value');
select lives_ok($$insert into cycle_ids select 'booking-1-'||n,public.materialize_recurring_lesson_occurrence(
  (select id from cycle_ids where name='series'),current_date+7*(0+n),
  (select entitlement_id from source_packages where name='four-a'),'fixed-cycle-materialization-1-'||n)
  from generate_series(1,4) n$$,'Cycle 1: explicit entitlement materializes 4 lessons');
reset role;
select pg_temp.past_lessons('four-a');
set local role authenticated;
select lives_ok($$select public.complete_lesson_booking(id,'Completed fixture','','','','') from cycle_ids
  where name like 'booking-1-%' and name<>'booking-1-4'$$,'Cycle 1: complete first 3 through Booking/Credit authority');
select throws_ok($$select public.complete_fixed_entitlement_cycle((select id from cycle_ids where name='cycle-1'),'Last lesson still unfinished')$$,
  'P0001','FIXED_CYCLE_VALUE_INCOMPLETE','Cycle 1: unfinished last lesson retains incomplete state');
select lives_ok($$select public.complete_lesson_booking(id,'Final actual lesson','','','','') from cycle_ids where name='booking-1-4'$$,
  'Cycle 1: complete final actual lesson');
select is(public.complete_fixed_entitlement_cycle((select id from cycle_ids where name='cycle-1'),'All actual lesson value completed'),
  (select id from cycle_ids where name='cycle-1'),'Cycle 1: completion boundary succeeds');
select is(public.complete_fixed_entitlement_cycle((select id from cycle_ids where name='cycle-1'),'Completion retry'),
  (select id from cycle_ids where name='cycle-1'),'Cycle 1: completion retry is idempotent');
select is(pg_temp.attach_package('four-a'),(select id from cycle_ids where name='cycle-1'),'Cycle 1: attach retry after exhaustion preserves completed history');
reset role;
select is((select consumed from private.lesson_credit_balance((select entitlement_id from source_packages where name='four-a'))),4,
  'Cycle 1: Epic5 records exactly 4 consumed lesson values');
select is((select status::text from public.fixed_entitlement_cycles where id=(select id from cycle_ids where name='cycle-1')),'completed',
  'Cycle 1: completed state persisted');
create temporary table first_cycle_history as select to_jsonb(c) snapshot from public.fixed_entitlement_cycles c;

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000003',true);
select lives_ok($$insert into cycle_ids values('cycle-2',pg_temp.attach_package('four-b'))$$,'Attach cycle 2 to the same owner');
select throws_ok($$select public.complete_fixed_entitlement_cycle((select id from cycle_ids where name='cycle-2'),'Too early completion')$$,
  'P0001','FIXED_CYCLE_VALUE_INCOMPLETE','Cycle 2: calendar alone cannot complete unspent value');
select lives_ok($$insert into cycle_ids select 'booking-2-'||n,public.materialize_recurring_lesson_occurrence(
  (select id from cycle_ids where name='series'),current_date+7*(4+n),
  (select entitlement_id from source_packages where name='four-b'),'fixed-cycle-materialization-2-'||n)
  from generate_series(1,4) n$$,'Cycle 2: explicit entitlement materializes 4 lessons');
reset role;
select pg_temp.past_lessons('four-b');
set local role authenticated;
select lives_ok($$select public.complete_lesson_booking(id,'Completed fixture','','','','') from cycle_ids
  where name like 'booking-2-%' and name<>'booking-2-4'$$,'Cycle 2: complete first 3 through Booking/Credit authority');
select throws_ok($$select public.complete_fixed_entitlement_cycle((select id from cycle_ids where name='cycle-2'),'Last lesson still unfinished')$$,
  'P0001','FIXED_CYCLE_VALUE_INCOMPLETE','Cycle 2: unfinished last lesson retains incomplete state');
select lives_ok($$select public.complete_lesson_booking(id,'Final actual lesson','','','','') from cycle_ids where name='booking-2-4'$$,
  'Cycle 2: complete final actual lesson');
select is(public.complete_fixed_entitlement_cycle((select id from cycle_ids where name='cycle-2'),'All actual lesson value completed'),
  (select id from cycle_ids where name='cycle-2'),'Cycle 2: completion boundary succeeds');
select is(public.complete_fixed_entitlement_cycle((select id from cycle_ids where name='cycle-2'),'Completion retry'),
  (select id from cycle_ids where name='cycle-2'),'Cycle 2: completion retry is idempotent');
select is(pg_temp.attach_package('four-b'),(select id from cycle_ids where name='cycle-2'),'Cycle 2: attach retry after exhaustion preserves completed history');
reset role;
select is((select consumed from private.lesson_credit_balance((select entitlement_id from source_packages where name='four-b'))),4,
  'Cycle 2: Epic5 records exactly 4 consumed lesson values');
select is((select status::text from public.fixed_entitlement_cycles where id=(select id from cycle_ids where name='cycle-2')),'completed',
  'Cycle 2: completed state persisted');


set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000003',true);
select lives_ok($$insert into cycle_ids values('cycle-3',pg_temp.attach_package('twelve'))$$,'Attach cycle 3 to the same owner');
select throws_ok($$select public.complete_fixed_entitlement_cycle((select id from cycle_ids where name='cycle-3'),'Too early completion')$$,
  'P0001','FIXED_CYCLE_VALUE_INCOMPLETE','Cycle 3: calendar alone cannot complete unspent value');
select lives_ok($$insert into cycle_ids select 'booking-3-'||n,public.materialize_recurring_lesson_occurrence(
  (select id from cycle_ids where name='series'),current_date+7*(8+n),
  (select entitlement_id from source_packages where name='twelve'),'fixed-cycle-materialization-3-'||n)
  from generate_series(1,12) n$$,'Cycle 3: explicit entitlement materializes 12 lessons');
reset role;
select pg_temp.past_lessons('twelve');
set local role authenticated;
select lives_ok($$select public.complete_lesson_booking(id,'Completed fixture','','','','') from cycle_ids
  where name like 'booking-3-%' and name<>'booking-3-12'$$,'Cycle 3: complete first 11 through Booking/Credit authority');
select throws_ok($$select public.complete_fixed_entitlement_cycle((select id from cycle_ids where name='cycle-3'),'Last lesson still unfinished')$$,
  'P0001','FIXED_CYCLE_VALUE_INCOMPLETE','Cycle 3: unfinished last lesson retains incomplete state');
select lives_ok($$select public.complete_lesson_booking(id,'Final actual lesson','','','','') from cycle_ids where name='booking-3-12'$$,
  'Cycle 3: complete final actual lesson');
select is(public.complete_fixed_entitlement_cycle((select id from cycle_ids where name='cycle-3'),'All actual lesson value completed'),
  (select id from cycle_ids where name='cycle-3'),'Cycle 3: completion boundary succeeds');
select is(public.complete_fixed_entitlement_cycle((select id from cycle_ids where name='cycle-3'),'Completion retry'),
  (select id from cycle_ids where name='cycle-3'),'Cycle 3: completion retry is idempotent');
select is(pg_temp.attach_package('twelve'),(select id from cycle_ids where name='cycle-3'),'Cycle 3: attach retry after exhaustion preserves completed history');
reset role;
select is((select consumed from private.lesson_credit_balance((select entitlement_id from source_packages where name='twelve'))),12,
  'Cycle 3: Epic5 records exactly 12 consumed lesson values');
select is((select status::text from public.fixed_entitlement_cycles where id=(select id from cycle_ids where name='cycle-3')),'completed',
  'Cycle 3: completed state persisted');

select is((select array_agg(sequence_number order by sequence_number) from public.fixed_entitlement_cycles),array[1,2,3],'Sequences are 1 / 2 / 3');
select is((select count(distinct series_id) from public.fixed_entitlement_cycles),1::bigint,'All three cycles share the same series');
select is((select count(distinct entitlement_id) from public.fixed_entitlement_cycles),3::bigint,'All three cycles retain different entitlements');
select is((select to_jsonb(c) from public.fixed_entitlement_cycles c where sequence_number=1),(select snapshot from first_cycle_history),'Old completed cycle was not overwritten by later attachments');
select is((select to_jsonb(s) from public.recurring_lesson_series s where id=(select id from cycle_ids where name='series')),
  (select to_jsonb(s) from original_series s),'Entire series identity, owner, base rule and compatibility hint unchanged');
select ok(not private.scheduling_slot_clear('67000000-0000-0000-0000-000000000002','67000000-0000-0000-0000-000000000003',
  private.resolve_scheduling_local_datetime(current_date+175,'20:00','Asia/Taipei'),
  private.resolve_scheduling_local_datetime(current_date+175,'20:00','Asia/Taipei')+interval '50 minutes'),'Future Fixed priority remains owned after all three completions');
select is((select count(*) from public.audit_logs where action='fixed_cycle.attached'),3::bigint,'One attachment audit per cycle');
select is((select count(*) from public.audit_logs where action='fixed_cycle.completed'),3::bigint,'One completion audit per cycle');
select throws_ok($$update public.fixed_entitlement_cycles set entitlement_id=gen_random_uuid() where sequence_number=1$$,
  '55000','FIXED_CYCLE_HISTORY_IMMUTABLE','Even owner SQL cannot silently overwrite cycle entitlement history');
select throws_ok($$delete from public.fixed_entitlement_cycles where sequence_number=1$$,
  '55000','FIXED_CYCLE_HISTORY_IMMUTABLE','Cycle history cannot be deleted');

-- State fixtures change only lifecycle fields as local database owner. Entitlement
-- source/beneficiary/config identity remains the real fulfilled purchase snapshot.
update public.entitlements e set status=x.state::public.entitlement_status,
  revoked_at=case when x.state='revoked' then now() end,
  revoked_by=case when x.state='revoked' then '67000000-0000-0000-0000-000000000004'::uuid end,
  revoked_reason=case when x.state='revoked' then 'Local guard fixture' end
from (values('pending'),('revoked'),('cancelled'),('exhausted')) x(state)
where e.id=(select entitlement_id from source_packages where name=x.state);
update public.entitlements set starts_at=now()-interval '2 days',expires_at=now()-interval '1 hour'
  where id=(select entitlement_id from source_packages where name='expired');
update public.entitlements set starts_at=now()+interval '1 day'
  where id=(select entitlement_id from source_packages where name='future');
set local role authenticated;
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000003',true);
select throws_ok(format('select pg_temp.attach_package(%L)',name),'P0001','ENTITLEMENT_NOT_ELIGIBLE',
  name||' entitlement cannot become a new Fixed cycle')
from (values('wrong-student'),('other'),('flex'),('pending'),('revoked'),('cancelled'),('expired'),('exhausted'),('future')) x(name);
select throws_ok($$select public.attach_fixed_entitlement_cycle((select id from cycle_ids where name='series'),
  (select entitlement_id from source_packages where name='both'),gen_random_uuid(),'No paid fulfillment')$$,
  'P0001','FIXED_CYCLE_FULFILLMENT_REQUIRED','Unpaid/nonexistent fulfillment cannot authorize attachment');
select throws_ok($$select public.attach_fixed_entitlement_cycle((select id from cycle_ids where name='series'),
  (select entitlement_id from source_packages where name='both'),(select event_id from source_packages where name='twelve'),'Wrong fulfillment source')$$,
  'P0001','FIXED_CYCLE_SOURCE_MISMATCH','Entitlement must belong to exact successful fulfillment');
reset role;
update public.order_fulfillment_events set status='pending' where id=(select event_id from source_packages where name='both');
set local role authenticated;
select throws_ok($$select pg_temp.attach_package('both')$$,'P0001','FIXED_CYCLE_FULFILLMENT_REQUIRED','Paid but not processed fulfillment cannot attach');
reset role;
update public.order_fulfillment_events set status='processed' where id=(select event_id from source_packages where name='both');
set local role authenticated;
select lives_ok($$insert into cycle_ids values('cycle-both',pg_temp.attach_package('both'))$$,'Both-mode package is Fixed compatible');
select lives_ok($$insert into cycle_ids values('other-series',public.create_recurring_lesson_series(
  '67000000-0000-0000-0000-000000000001','67000000-0000-0000-0000-000000000003',
  '67000000-0000-0000-0000-000000000011',null,extract(dow from current_date)::smallint,
  '21:00','Asia/Taipei',50::smallint,current_date,null,'Separate nonoverlapping series'))$$,'Create other series for attachment exclusivity control');
select throws_ok($$select public.attach_fixed_entitlement_cycle((select id from cycle_ids where name='other-series'),
  (select entitlement_id from source_packages where name='both'),(select event_id from source_packages where name='both'),'Duplicate entitlement on another series')$$,
  'P0001','FIXED_ENTITLEMENT_ALREADY_ATTACHED','One entitlement cannot belong to two series/cycles');
reset role;
select is((select count(*) from public.fixed_entitlement_cycles),4::bigint,'Rejected attachments create no extra cycles or sequence holes');

-- Catalog AND real role controls; private/internal metadata is not a browser DTO.
select ok((select relrowsecurity from pg_class where oid='public.fixed_entitlement_cycles'::regclass),'Cycles RLS enabled');
select ok(not has_table_privilege(r,'public.fixed_entitlement_cycles',p),r||' has no raw '||p)
  from unnest(array['anon','authenticated','service_role']) r cross join unnest(array['INSERT','UPDATE','DELETE']) p;
select ok(not has_any_column_privilege(r,'public.fixed_entitlement_cycles',p),r||' has no column '||p)
  from unnest(array['anon','authenticated','service_role']) r cross join unnest(array['INSERT','UPDATE']) p;
select ok(not has_function_privilege(r,'private.attach_fixed_entitlement_cycle_core(uuid,uuid,uuid,text,uuid,text)','EXECUTE'),
  r||' cannot bypass public authorization via private core') from unnest(array['anon','authenticated','service_role']) r;
set local role authenticated;
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000001',true);
select is((select count(id) from public.fixed_entitlement_cycles),4::bigint,'Student reads own safe cycle history');
select throws_ok($$select source_fulfillment_event_id from public.fixed_entitlement_cycles$$,'42501',null,'Student cannot read internal fulfillment metadata');
select throws_ok($$update public.fixed_entitlement_cycles set status='completed'$$,'42501',null,'Authenticated raw update denied');
select throws_ok($$delete from public.fixed_entitlement_cycles$$,'42501',null,'Authenticated raw delete denied');
select throws_ok($$select public.complete_fixed_entitlement_cycle((select id from cycle_ids where name='cycle-both'),'Student attempts completion')$$,
  '42501','UNAUTHORIZED_FIXED_CYCLE_ACTION','Student completion denied');
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000002',true);
select is((select count(id) from public.fixed_entitlement_cycles),0::bigint,'Other Student sees no cycles');
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000003',true);
select is((select count(id) from public.fixed_entitlement_cycles),4::bigint,'Assigned Teacher reads cycles');
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000005',true);
select is((select count(id) from public.fixed_entitlement_cycles),0::bigint,'Unrelated Teacher sees no cycles');
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000004',true);
select is((select count(id) from public.fixed_entitlement_cycles),4::bigint,'Admin reads cycles');
select is(pg_temp.attach_package('both'),(select id from cycle_ids where name='cycle-both'),'Admin can idempotently attach verified source');
reset role;
set local role service_role;
select throws_ok($$update public.fixed_entitlement_cycles set status='completed'$$,'42501',null,'Service role raw mutation denied');
select throws_ok($$select public.complete_fixed_entitlement_cycle(gen_random_uuid(),'Service completion denied')$$,'42501',null,'Service does not receive human completion RPC');
reset role;
select * from finish();
rollback;
