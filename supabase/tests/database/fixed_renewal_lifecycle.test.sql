-- P1-4B real lifecycle coverage. Contract expectations remain unchanged.
begin;
select no_plan();
create temporary table ids(name text primary key,id uuid);
grant select,insert on ids to authenticated,service_role;
insert into auth.users(id,email)values
('69000000-0000-0000-0000-000000000001','renew-a@example.invalid'),
('69000000-0000-0000-0000-000000000002','renew-b@example.invalid'),
('69000000-0000-0000-0000-000000000003','renew-teacher@example.invalid'),
('69000000-0000-0000-0000-000000000004','renew-admin@example.invalid');
insert into public.user_roles(user_id,role)values('69000000-0000-0000-0000-000000000003','teacher'),('69000000-0000-0000-0000-000000000004','admin');
insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd,default_meeting_provider,default_meeting_url)values
('69000000-0000-0000-0000-000000000003','renew-teacher','Renew teacher','active',true,array['online']::public.teaching_mode[],500,'manual_google_meet','https://meet.google.com/abc-defg-hij');
insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode)values
('69000000-0000-0000-0000-000000000011','69000000-0000-0000-0000-000000000001','69000000-0000-0000-0000-000000000003','active','online'),
('69000000-0000-0000-0000-000000000012','69000000-0000-0000-0000-000000000002','69000000-0000-0000-0000-000000000003','active','online');
insert into public.teacher_scheduling_settings(teacher_user_id,timezone,minimum_booking_notice_minutes,booking_horizon_days,slot_interval_minutes)
values('69000000-0000-0000-0000-000000000003','Asia/Taipei',0,180,10);
insert into public.teacher_availability_rules(teacher_user_id,weekday,local_start_time,local_end_time,timezone,effective_from,created_by)
select '69000000-0000-0000-0000-000000000003',d,'00:00','23:59','Asia/Taipei',current_date,'69000000-0000-0000-0000-000000000003' from generate_series(0,6)d;
insert into public.products(id,product_type,status,public_slug,name,currency,base_price_amount,owner_type,is_public,is_purchasable,published_at)values
('69000000-0000-0000-0000-000000000021','lesson_package','active','renew-one','One Fixed','TWD',800,'platform',true,true,now()),
('69000000-0000-0000-0000-000000000022','lesson_package','active','renew-twelve','Twelve Fixed','TWD',8400,'platform',true,true,now()),
('69000000-0000-0000-0000-000000000023','lesson_package','active','renew-flex','Flexible','TWD',900,'platform',true,true,now()),
('69000000-0000-0000-0000-000000000024','lesson_package','active','renew-four','Four Fixed','TWD',3200,'platform',true,true,now());
insert into public.lesson_package_product_configs(product_id,lesson_count,validity_value,validity_unit,lesson_duration_minutes,booking_mode_eligibility)values
('69000000-0000-0000-0000-000000000021',1,12,'months',50,'fixed'),
('69000000-0000-0000-0000-000000000022',12,12,'months',50,'fixed'),
('69000000-0000-0000-0000-000000000023',1,12,'months',50,'flexible'),
('69000000-0000-0000-0000-000000000024',4,12,'months',50,'fixed');
set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000004',true);
select lives_ok($$select public.set_fixed_renewal_policy('69000000-0000-0000-0000-000000000021',1,3600,600,0,'Fixture policy')$$,'Configure non-hardcoded renewal policy');
select lives_ok($$select public.set_fixed_renewal_policy('69000000-0000-0000-0000-000000000024',4,3600,600,0,'Four credit fixture policy')$$,'Configure four-credit trigger');
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.set_fixed_renewal_policy('69000000-0000-0000-0000-000000000021',1,1,1,0,'Student policy')$$,'42501','UNAUTHORIZED_RENEWAL_ACTION','Student cannot set policy');
select lives_ok($$insert into ids values('order-first-a',public.create_checkout_order('renew-four',1,'renew-first-a-order'))$$,'A buys first four-credit package');
select lives_ok($$insert into ids values('order-first-a2',public.create_checkout_order('renew-one',1,'renew-first-a2-order'))$$,'A buys second series package');
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000002',true);
select lives_ok($$insert into ids values('order-first-b',public.create_checkout_order('renew-one',1,'renew-first-b-order'))$$,'B buys reassignment package');
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000004',true);
select lives_ok($$select public.admin_confirm_cash_payment(id,'renew-paid-'||name,'Fixture payment')from ids where name like 'order-first-%'$$,'Pay initial packages');
reset role;
insert into ids select 'event-'||substr(name,7),e.id from ids r join public.order_fulfillment_events e on e.order_id=r.id where name like'order-first-%';
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$select public.process_order_fulfillment_event(id)from ids where name like'event-first-%'$$,'Fulfill initial packages');
reset role;
insert into ids select 'ent-'||substr(name,7),e.id from ids r join public.entitlements e on e.source_order_id=r.id where name like'order-first-%';

set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000003',true);
select lives_ok($$insert into ids values('series-a',public.create_recurring_lesson_series('69000000-0000-0000-0000-000000000001','69000000-0000-0000-0000-000000000003','69000000-0000-0000-0000-000000000011',null,extract(dow from current_date+7)::smallint,'08:00','Asia/Taipei',50::smallint,current_date+7,null,'Renewal series A'))$$,'Create original series');
reset role;set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$insert into ids values('cycle-a',public.attach_fixed_entitlement_cycle((select id from ids where name='series-a'),(select id from ids where name='ent-first-a'),(select id from ids where name='event-first-a'),'First cycle'))$$,'Attach current cycle');
select lives_ok($$insert into ids values('renewal-a',public.open_fixed_cycle_renewal((select id from ids where name='cycle-a'),'Threshold reached'))$$,'R1 open renewal window');
select is(public.open_fixed_cycle_renewal((select id from ids where name='cycle-a'),'Retry open'),(select id from ids where name='renewal-a'),'Window open retry idempotent');
reset role;
select is((select state::text from public.fixed_cycle_renewals where id=(select id from ids where name='renewal-a')),'window_open','R1 state is window_open');
select is((select renewal_deadline_at from public.fixed_cycle_renewals where id=(select id from ids where name='renewal-a')),null,'R11 incomplete cycle has no calendar deadline');
select is((select status::text from public.recurring_lesson_series where id=(select id from ids where name='series-a')),'active','R1 priority retained');
set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.set_fixed_renewal_intent((select id from ids where name='renewal-a'),'will_not_renew','Planning to stop')$$,'R4 student sets non-renew');
select is((select status::text from public.fixed_entitlement_cycles where id=(select id from ids where name='cycle-a')),'active','R4 non-renew preserves current cycle');
reset role;
select is((select status::text from public.recurring_lesson_series where id=(select id from ids where name='series-a')),'active','R4 non-renew does not end series');
set local role authenticated;
select lives_ok($$select public.set_fixed_renewal_intent((select id from ids where name='renewal-a'),'undecided','Changed to undecided')$$,'R2 undecided intent');
select lives_ok($$select public.set_fixed_renewal_intent((select id from ids where name='renewal-a'),'will_renew','Will renew')$$,'R3 will-renew intent');
reset role;
select is((select count(*) from public.audit_logs where action='fixed_renewal.intent_changed' and target_id=(select id from ids where name='renewal-a')),3::bigint,'R18 every intent change audited');
set local role authenticated;
select lives_ok($$insert into ids values('hold-a',public.claim_fixed_renewal_hold((select id from ids where name='renewal-a'),'renew-twelve','renewal-a-hold-key'))$$,'R13 create temporary renewal hold');
select is(public.claim_fixed_renewal_hold((select id from ids where name='renewal-a'),'renew-twelve','renewal-a-hold-key'),(select id from ids where name='hold-a'),'Hold retry idempotent');
select throws_ok($$select public.claim_fixed_renewal_hold((select id from ids where name='renewal-a'),'renew-flex','renewal-flex-key')$$,'P0001','ENTITLEMENT_NOT_ELIGIBLE','R10 flexible-only renewal rejected');
reset role;
select is((select count(*) from public.fixed_entitlement_cycles where series_id=(select id from ids where name='series-a')),1::bigint,'R6 pending order is not renewal');
insert into ids select 'order-renew-a',order_id from public.fixed_renewal_holds where id=(select id from ids where name='hold-a');
set local role authenticated;select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000004',true);
select lives_ok($$select public.admin_confirm_cash_payment((select id from ids where name='order-renew-a'),'renewal-payment-a-01','Renewal paid')$$,'Confirm renewal payment');
reset role;insert into ids select 'event-renew-a',id from public.order_fulfillment_events where order_id=(select id from ids where name='order-renew-a');
select is((select count(*) from public.fixed_entitlement_cycles where series_id=(select id from ids where name='series-a')),1::bigint,'R7 payment alone is not renewal');
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$select public.process_order_fulfillment_event((select id from ids where name='event-renew-a'))$$,'Process renewal fulfillment');
reset role;insert into ids select 'ent-renew-a',id from public.entitlements where source_order_id=(select id from ids where name='order-renew-a');
set local role service_role;select is((public.convert_fixed_renewal((select id from ids where name='renewal-a'),(select id from ids where name='hold-a'),(select id from ids where name='ent-renew-a'),(select id from ids where name='event-renew-a'),'Too early')->>'error'),'RENEWAL_NOT_OPEN','Delayed final lesson prevents early next cycle');
reset role;

set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.set_recurring_lesson_series_exception((select id from ids where name='series-a'),current_date+7,'reschedule',
 (current_date+14+'09:00'::time) at time zone 'Asia/Taipei',(current_date+14+'09:50'::time) at time zone 'Asia/Taipei',false,'Delayed final lesson')$$,'R11 legally delay final occurrence');
select lives_ok($$insert into ids values('booking-a',public.materialize_recurring_lesson_occurrence((select id from ids where name='series-a'),current_date+7,(select id from ids where name='ent-first-a'),'renewal-materialize-a'))$$,'Materialize delayed final lesson');
select lives_ok($$insert into ids select 'booking-extra-'||n,public.materialize_recurring_lesson_occurrence((select id from ids where name='series-a'),current_date+7*n,(select id from ids where name='ent-first-a'),'renewal-materialize-extra-'||n)from generate_series(2,4)n$$,'Materialize remaining three package lessons');
reset role;
with instants as(select id,now()-interval'2 days'-row_number()over(order by id)*interval'2 hours' starts from public.lessons where fixed_cycle_id=(select id from ids where name='cycle-a'))
update public.lessons l set starts_at=i.starts,ends_at=i.starts+interval'50 minutes'from instants i where l.id=i.id;
update public.bookings b set starts_at=l.starts_at,ends_at=l.ends_at from public.lessons l where b.lesson_id=l.id and b.fixed_cycle_id=(select id from ids where name='cycle-a');
update public.recurring_lesson_occurrences o set starts_at=l.starts_at,ends_at=l.ends_at from public.lessons l where o.lesson_id=l.id and o.fixed_cycle_id=(select id from ids where name='cycle-a');
set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.complete_lesson_booking(id,'Actual package lesson completed','','','','')from ids where name like'booking-extra-%'$$,'Complete first three actual lessons');
select throws_ok($$select public.complete_fixed_entitlement_cycle((select id from ids where name='cycle-a'),'Delayed lesson unfinished')$$,'P0001','FIXED_CYCLE_VALUE_INCOMPLETE','Last delayed lesson still protects incomplete cycle');
select lives_ok($$select public.complete_lesson_booking((select id from ids where name='booking-a'),'Actual delayed lesson completed','','','','')$$,'Complete actual delayed final lesson');
select lives_ok($$select public.complete_fixed_entitlement_cycle((select id from ids where name='cycle-a'),'All value completed')$$,'Complete cycle through 4A authority');
reset role;
select ok((select renewal_deadline_at>current_cycle_completed_at from public.fixed_cycle_renewals where id=(select id from ids where name='renewal-a')),'Deadline derives from actual completion');
create temporary table credit_before_renewal as select md5(string_agg(to_jsonb(l)::text,''order by id)) snapshot from public.lesson_credit_ledger l;
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select is(public.convert_fixed_renewal((select id from ids where name='renewal-a'),(select id from ids where name='hold-a'),(select id from ids where name='ent-renew-a'),(select id from ids where name='event-renew-a'),'Fulfilled renewal')->>'status','renewed','R8 fulfilled renewal succeeds');
select is(public.convert_fixed_renewal((select id from ids where name='renewal-a'),(select id from ids where name='hold-a'),(select id from ids where name='ent-renew-a'),(select id from ids where name='event-renew-a'),'Retry renewal')->>'status','renewed','R15 conversion retry');
reset role;
select is((select count(*) from public.fixed_entitlement_cycles where series_id=(select id from ids where name='series-a')),2::bigint,'Exactly one next cycle');
select is((select md5(string_agg(to_jsonb(l)::text,''order by id))from public.lesson_credit_ledger l),(select snapshot from credit_before_renewal),'Renewal conversion leaves full credit ledger unchanged');
select is((select sequence_number from public.fixed_entitlement_cycles where id=(select successful_next_cycle_id from public.fixed_cycle_renewals where id=(select id from ids where name='renewal-a'))),2,'Next sequence is 2');
select is((select product_id from public.entitlements where id=(select id from ids where name='ent-renew-a')),'69000000-0000-0000-0000-000000000022'::uuid,'R9 4 -> 12 compatible renewal attached');
select is((select count(*) from public.audit_logs where action='fixed_renewal.renewed' and target_id=(select id from ids where name='renewal-a')),1::bigint,'Retry has one renewal audit');

-- A separate one-credit cycle exercises non-renew, hold expiry, reassignment,
-- and a payment that genuinely arrives after the new owner already exists.
set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000003',true);
select lives_ok($$insert into ids values('series-stop',public.create_recurring_lesson_series('69000000-0000-0000-0000-000000000001','69000000-0000-0000-0000-000000000003','69000000-0000-0000-0000-000000000011',null,extract(dow from current_date+7)::smallint,'10:00','Asia/Taipei',50::smallint,current_date+7,null,'Non-renew series'))$$,'Create non-renew series');
reset role;set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$insert into ids values('cycle-stop',public.attach_fixed_entitlement_cycle((select id from ids where name='series-stop'),(select id from ids where name='ent-first-a2'),(select id from ids where name='event-first-a2'),'First stop cycle'))$$,'Attach stopping cycle');
select lives_ok($$insert into ids values('renewal-stop',public.open_fixed_cycle_renewal((select id from ids where name='cycle-stop'),'Final value remains'))$$,'Open stopping renewal');
reset role;set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.set_fixed_renewal_intent((select id from ids where name='renewal-stop'),'will_not_renew','Stop after actual completion')$$,'R5 non-renew policy selected');
select lives_ok($$insert into ids values('hold-stop',public.claim_fixed_renewal_hold((select id from ids where name='renewal-stop'),'renew-twelve','renewal-stop-hold-key'))$$,'Create bounded pending renewal hold');
select lives_ok($$insert into ids values('hold-failed',public.claim_fixed_renewal_hold((select id from ids where name='renewal-stop'),'renew-twelve','renewal-failed-hold-key'))$$,'Separate failed payment attempt');
select lives_ok($$select public.release_fixed_renewal_hold((select id from ids where name='hold-failed'),'Payment failed')$$,'Payment failure releases its temporary hold');
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.set_fixed_renewal_intent((select id from ids where name='renewal-stop'),'will_renew','Other student intent')$$,'42501','UNAUTHORIZED_RENEWAL_ACTION','Other student cannot change intent');
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.set_recurring_lesson_series_status((select id from ids where name='series-stop'),'ended','Try bypassing renewal')$$,'P0001','FIXED_RENEWAL_RELEASE_REQUIRED','Generic series end cannot bypass incomplete renewal');
select lives_ok($$insert into ids values('booking-stop',public.materialize_recurring_lesson_occurrence((select id from ids where name='series-stop'),current_date+7,(select id from ids where name='ent-first-a2'),'renewal-materialize-stop'))$$,'Schedule final stopping lesson');
select throws_ok($$select public.complete_fixed_entitlement_cycle((select id from ids where name='cycle-stop'),'Too soon')$$,'P0001','FIXED_CYCLE_VALUE_INCOMPLETE','R11 reserved final lesson prevents completion');
reset role;
select is((select fixed_cycle_id from public.recurring_lesson_occurrences where booking_id=(select id from ids where name='booking-stop')),(select id from ids where name='cycle-stop'),'Occurrence retains authoritative cycle association');
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select is(public.release_expired_fixed_renewal((select id from ids where name='renewal-stop'),'Incomplete cycle check'),false,'Incomplete cycle cannot release');
reset role;
update public.lessons set starts_at=now()-interval'4 hours',ends_at=now()-interval'190 minutes' where fixed_cycle_id=(select id from ids where name='cycle-stop');
update public.bookings b set starts_at=l.starts_at,ends_at=l.ends_at from public.lessons l where b.lesson_id=l.id and b.fixed_cycle_id=(select id from ids where name='cycle-stop');
update public.recurring_lesson_occurrences o set starts_at=l.starts_at,ends_at=l.ends_at from public.lessons l where o.lesson_id=l.id and o.fixed_cycle_id=(select id from ids where name='cycle-stop');
set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.complete_lesson_booking((select id from ids where name='booking-stop'),'Actual final lesson','','','','')$$,'Complete stopping lesson');
select lives_ok($$select public.complete_fixed_entitlement_cycle((select id from ids where name='cycle-stop'),'Final value completed')$$,'Cycle completion anchors non-renew deadline');
reset role;set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select is(public.release_expired_fixed_renewal((select id from ids where name='renewal-stop'),'Still held'),false,'R13 valid pending hold retains priority beyond zero configured grace');
reset role;
-- Fixture-only time travel leaves status active, proving expiry is a predicate.
update public.fixed_renewal_holds set created_at=now()-interval'2 hours',expires_at=now()-interval'1 hour' where id=(select id from ids where name='hold-stop');
set local role service_role;
select is(public.release_expired_fixed_renewal((select id from ids where name='renewal-stop'),'Non-renew deadline expired'),true,'R5/R14 completed non-renew releases after temporary hold expires');
select is(public.release_expired_fixed_renewal((select id from ids where name='renewal-stop'),'Repeat release'),true,'Release retry stable');
reset role;
select is((select release_reason from public.fixed_cycle_renewals where id=(select id from ids where name='renewal-stop')),'non_renew','Release reason is explicit');
select is((select count(*) from public.audit_logs where action='fixed_renewal.released' and target_id=(select id from ids where name='renewal-stop')),1::bigint,'Release retry creates no duplicate audit');
set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000003',true);
select lives_ok($$insert into ids values('series-b',public.create_recurring_lesson_series('69000000-0000-0000-0000-000000000002','69000000-0000-0000-0000-000000000003','69000000-0000-0000-0000-000000000012',null,extract(dow from current_date+7)::smallint,'10:00','Asia/Taipei',50::smallint,current_date+7,null,'B legally reassigned'))$$,'R17 B becomes legal same-slot owner');
reset role;set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$insert into ids values('cycle-b',public.attach_fixed_entitlement_cycle((select id from ids where name='series-b'),(select id from ids where name='ent-first-b'),(select id from ids where name='event-first-b'),'B first cycle'))$$,'B attaches own paid entitlement');
reset role;
insert into ids select 'order-late',order_id from public.fixed_renewal_holds where id=(select id from ids where name='hold-stop');
set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000004',true);
select lives_ok($$select public.admin_confirm_cash_payment((select id from ids where name='order-late'),'renewal-late-payment','Payment arrived after reassignment')$$,'A delayed payment remains legitimate commerce');
reset role;insert into ids select 'event-late',id from public.order_fulfillment_events where order_id=(select id from ids where name='order-late');
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$select public.process_order_fulfillment_event((select id from ids where name='event-late'))$$,'A delayed fulfillment');
reset role;insert into ids select 'ent-late',id from public.entitlements where source_order_id=(select id from ids where name='order-late');
set local role service_role;
select is(public.convert_fixed_renewal((select id from ids where name='renewal-stop'),(select id from ids where name='hold-stop'),(select id from ids where name='ent-late'),(select id from ids where name='event-late'),'Late after reassignment')->>'status','rejected','R16 A delayed renewal cannot reclaim');
select throws_ok($$select public.attach_fixed_entitlement_cycle((select id from ids where name='series-stop'),(select id from ids where name='ent-late'),(select id from ids where name='event-late'),'Generic attach bypass')$$,'P0001','FIXED_RENEWAL_OPERATION_REQUIRED','Generic attachment cannot bypass release');
reset role;
select is((select status::text from public.recurring_lesson_series where id=(select id from ids where name='series-b')),'active','R17 B remains owner');
select is((select count(*) from public.fixed_entitlement_cycles where entitlement_id=(select id from ids where name='ent-late')),0::bigint,'A gains no cycle after release');
select is((select count(*) from public.entitlements where id=(select id from ids where name='ent-late')),1::bigint,'A paid entitlement is not deleted');

select ok((select relrowsecurity from pg_class where oid='public.fixed_cycle_renewals'::regclass),'Renewal RLS on');
select ok((select relrowsecurity from pg_class where oid='public.fixed_renewal_holds'::regclass),'Renewal hold RLS on');
select ok(not has_table_privilege(r,t,p),r||' no raw '||p||' on '||t)from(values('anon'),('authenticated'),('service_role'))r(r)cross join(values('public.fixed_cycle_renewals'),('public.fixed_renewal_holds'))t(t)cross join(values('INSERT'),('UPDATE'),('DELETE'))p(p);
select ok(not has_function_privilege(r,p.oid,'EXECUTE'),r||' no private '||p.proname)from pg_proc p cross join(values('anon'),('authenticated'),('service_role'))r(r)where p.pronamespace='private'::regnamespace and p.proname in('release_fixed_renewal_locked','attach_fixed_entitlement_cycle_without_renewal_core');
select ok(not has_function_privilege(r,s,'EXECUTE'),r||' no private helper '||s)
from(values('anon'),('authenticated'),('service_role'))roles(r)cross join(values
 ('private.link_booking_fixed_cycle()'),('private.link_occurrence_fixed_cycle()'),('private.link_attached_cycle_bookings()'),
 ('private.stamp_managed_cycle_completion()'),('private.fixed_cycle_completion_renewal()'),
 ('public.set_recurring_lesson_series_status_without_renewal(uuid,public.recurring_series_status,text)'))helpers(s);
select is(has_function_privilege(r,s,'EXECUTE'),r='authenticated' or (r='service_role'and svc),r||' RPC ACL '||s)
from(values('anon'),('authenticated'),('service_role'))roles(r)cross join(values
 ('public.set_fixed_renewal_policy(uuid,integer,integer,integer,integer,text)',false),
 ('public.open_fixed_cycle_renewal(uuid,text)',true),
 ('public.set_fixed_renewal_intent(uuid,public.fixed_renewal_intent,text)',false),
 ('public.claim_fixed_renewal_hold(uuid,text,text)',false),
 ('public.release_fixed_renewal_hold(uuid,text)',true),
 ('public.release_expired_fixed_renewal(uuid,text)',true),
 ('public.convert_fixed_renewal(uuid,uuid,uuid,uuid,text)',true))rpc(s,svc);
set local role authenticated;select set_config('request.jwt.claim.role','',true);select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.release_expired_fixed_renewal((select id from ids where name='renewal-stop'),'Missing role claim')$$,'42501','UNAUTHORIZED_RENEWAL_ACTION','Missing JWT role cannot bypass release authorization');
reset role;
select ok(p.prosecdef and p.proconfig=array['search_path=""']::text[],'Pinned renewal definer: '||p.proname)from pg_proc p where p.pronamespace='public'::regnamespace and p.proname like'%fixed%renewal%';
select * from finish();
rollback;
