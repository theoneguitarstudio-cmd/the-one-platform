-- P1-4C: checkout leases, paid/fulfilled conversion and participant authority.
-- Test-only time travel changes lease timestamps as postgres; application roles
-- must use RPCs. Existing P1-4 audit contracts remain untouched.
-- C1 and conversion-vs-expiry concurrency additionally require two real local
-- sessions; the sequential assertions here are not concurrency evidence.
begin;
select no_plan();
create temporary table hold_ids(name text primary key,id uuid);
grant select,insert on hold_ids to authenticated,service_role;
insert into auth.users(id,email) values
('68000000-0000-0000-0000-000000000001','hold-a@example.invalid'),
('68000000-0000-0000-0000-000000000002','hold-b@example.invalid'),
('68000000-0000-0000-0000-000000000003','hold-teacher@example.invalid'),
('68000000-0000-0000-0000-000000000004','hold-admin@example.invalid'),
('68000000-0000-0000-0000-000000000005','hold-other-teacher@example.invalid');
insert into public.user_roles(user_id,role) values
('68000000-0000-0000-0000-000000000003','teacher'),
('68000000-0000-0000-0000-000000000004','admin'),
('68000000-0000-0000-0000-000000000005','teacher');
insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd) values
('68000000-0000-0000-0000-000000000003','hold-teacher','Hold teacher','active',true,array['online']::public.teaching_mode[],500),
('68000000-0000-0000-0000-000000000005','hold-other-teacher','Other hold teacher','active',true,array['online']::public.teaching_mode[],500);
insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode) values
('68000000-0000-0000-0000-000000000011','68000000-0000-0000-0000-000000000001','68000000-0000-0000-0000-000000000003','active','online'),
('68000000-0000-0000-0000-000000000012','68000000-0000-0000-0000-000000000002','68000000-0000-0000-0000-000000000003','active','online'),
('68000000-0000-0000-0000-000000000015','68000000-0000-0000-0000-000000000001','68000000-0000-0000-0000-000000000005','active','online');
insert into public.products(id,product_type,status,public_slug,name,currency,base_price_amount,owner_type,is_public,is_purchasable,published_at)
values('68000000-0000-0000-0000-000000000021','lesson_package','active','hold-fixed','Fixed checkout','TWD',3200,'platform',true,true,now());
insert into public.lesson_package_product_configs(product_id,lesson_count,validity_value,validity_unit,lesson_duration_minutes,booking_mode_eligibility)
values('68000000-0000-0000-0000-000000000021',4,12,'months',50,'fixed');
insert into public.teacher_scheduling_settings(teacher_user_id,timezone,minimum_booking_notice_minutes,booking_horizon_days,slot_interval_minutes)
select id,'Asia/Taipei',0,180,10 from auth.users where id in
('68000000-0000-0000-0000-000000000003','68000000-0000-0000-0000-000000000005');
insert into public.teacher_availability_rules(teacher_user_id,weekday,local_start_time,local_end_time,timezone,effective_from,created_by)
select s.teacher_user_id,d,'00:00','23:59','Asia/Taipei',current_date,s.teacher_user_id
from public.teacher_scheduling_settings s cross join generate_series(0,6) d
where s.teacher_user_id in('68000000-0000-0000-0000-000000000003','68000000-0000-0000-0000-000000000005');

create function pg_temp.claim(p_name text,p_time time,p_timezone text default 'Asia/Taipei',p_other_teacher boolean default false)
returns uuid language sql security invoker as $$
  select public.claim_fixed_checkout_hold(
    case when p_other_teacher then '68000000-0000-0000-0000-000000000005'::uuid else '68000000-0000-0000-0000-000000000003'::uuid end,
    case when p_other_teacher then '68000000-0000-0000-0000-000000000015'::uuid
      when auth.uid()='68000000-0000-0000-0000-000000000001' then '68000000-0000-0000-0000-000000000011'::uuid
      else '68000000-0000-0000-0000-000000000012'::uuid end,
    'hold-fixed',extract(dow from current_date+7)::smallint,p_time,p_timezone,current_date+7,null,'checkout-hold-test-'||p_name);
$$;
create function pg_temp.hold_id(p_name text) returns uuid language sql as $$
  select id from pg_temp.hold_ids where name=p_name;
$$;
create function pg_temp.convert(p_name text) returns jsonb language sql security invoker as $$
  select public.convert_fixed_checkout_hold(pg_temp.hold_id(p_name),pg_temp.hold_id('ent-'||p_name),
    pg_temp.hold_id('event-'||p_name),'Fulfilled checkout conversion');
$$;

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000001',true);
select throws_ok($$select pg_temp.claim('no-policy','08:00')$$,'22023','HOLD_POLICY_UNAVAILABLE','No implicit business TTL');
select throws_ok($$select public.set_fixed_checkout_hold_policy('68000000-0000-0000-0000-000000000021',1200,'Student override')$$,
  '42501','UNAUTHORIZED_HOLD_ACTION','Student cannot set policy');
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000004',true);
select lives_ok($$select public.set_fixed_checkout_hold_policy('68000000-0000-0000-0000-000000000021',1200,'Fixture TTL configuration')$$,'Admin configures TTL');
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000001',true);
select lives_ok($$insert into hold_ids values('a',pg_temp.claim('a','08:00'))$$,'C4: A claims available slot');
select is(pg_temp.claim('a','08:00'),pg_temp.hold_id('a'),'C2: same checkout retry returns same hold');
select throws_ok($$select pg_temp.claim('a','09:00')$$,'22023','HOLD_PAYLOAD_MISMATCH','Same key different payload rejected');
select is((select expires_at-created_at from public.fixed_checkout_holds where id=pg_temp.hold_id('a')),interval '1200 seconds','TTL is snapshotted from policy');
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000002',true);
select throws_ok($$select pg_temp.claim('b-conflict','08:00')$$,'P0001','FIXED_SLOT_UNAVAILABLE','C4: active A prevents B');
select is((select count(*) from public.fixed_checkout_holds),0::bigint,'RLS hides other student hold identity');
select throws_ok($$select public.release_fixed_checkout_hold(pg_temp.hold_id('a'),'Other student cancel')$$,
  '42501','UNAUTHORIZED_HOLD_ACTION','Other student cannot release');
select lives_ok($$insert into hold_ids values('b-free',pg_temp.claim('b-free','09:00'))$$,'C12: non-overlapping slot allowed');
reset role;
select is((select count(*) from public.orders),2::bigint,'Rejected claims leave no checkout order');
select is((select count(*) from public.recurring_lesson_series),0::bigint,'Unpaid holds create no permanent owner');
select is((select count(*) from public.lessons),0::bigint,'Claims create no future Lessons');
select is((select count(*) from public.entitlements),0::bigint,'Claims allocate no entitlement/credit');
select is((select count(*) from public.audit_logs where action='fixed_checkout_hold.claimed'),2::bigint,'Claim retry has no duplicate audit');

-- Existing scheduling entry points cannot take a live checkout hold.
set local role authenticated;
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.create_recurring_lesson_series('68000000-0000-0000-0000-000000000002',
  '68000000-0000-0000-0000-000000000003','68000000-0000-0000-0000-000000000012',null,
  extract(dow from current_date+7)::smallint,'08:00','Asia/Taipei',50::smallint,current_date+7,null,'Try taking held slot')$$,
  'P0001','RECURRING_SERIES_CONFLICT','Teacher create-series honors checkout hold');
reset role;
select ok(not private.scheduling_slot_clear('68000000-0000-0000-0000-000000000002','68000000-0000-0000-0000-000000000003',
  private.resolve_scheduling_local_datetime(current_date+14,'08:00','Asia/Taipei'),
  private.resolve_scheduling_local_datetime(current_date+14,'08:50','Asia/Taipei')),'Booking target check honors future weekly hold');
select ok(not private.scheduling_instance_slot_clear('68000000-0000-0000-0000-000000000002','68000000-0000-0000-0000-000000000003',
  private.resolve_scheduling_local_datetime(current_date+14,'08:00','Asia/Taipei'),
  private.resolve_scheduling_local_datetime(current_date+14,'08:50','Asia/Taipei')),'Fresh occurrence expansion primitive honors hold');

-- Cross-timezone: Taipei 08:00 = UTC 00:00. Same local strings are not identity.
set local role authenticated;
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000002',true);
select throws_ok($$select pg_temp.claim('utc-conflict','00:00','UTC')$$,'P0001','FIXED_SLOT_UNAVAILABLE','C13: different wall time, same UTC conflicts');
select lives_ok($$insert into hold_ids values('utc-free',pg_temp.claim('utc-free','08:00','UTC'))$$,'C14: same wall time, different UTC allowed');
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000001',true);
select throws_ok($$select pg_temp.claim('student-conflict','08:00','Asia/Taipei',true)$$,'P0001','FIXED_SLOT_UNAVAILABLE','Student overlap across different teachers rejected');
select lives_ok($$insert into hold_ids values('dst-a',pg_temp.claim('dst-a','09:00','America/New_York'))$$,'DST region hold is represented in its own timezone');
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000002',true);
select throws_ok($$select pg_temp.claim('dst-b',case when
  (((current_date+7)::timestamp+interval '9 hours') at time zone 'America/New_York' at time zone 'UTC')::time='13:00'::time
  then '14:00'::time else '13:00'::time end,'UTC')$$,'P0001','FIXED_SLOT_UNAVAILABLE',
  'Weekly authority rejects overlap in the other DST season even if the first instances do not overlap');
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.release_fixed_checkout_hold(pg_temp.hold_id('dst-a'),'DST test finished')$$,'Release DST fixture');

-- Release and effective expiry need no cron. Only postgres advances fixtures.
select lives_ok($$select public.release_fixed_checkout_hold(pg_temp.hold_id('a'),'Checkout abandoned')$$,'C6: own checkout release');
select is(public.release_fixed_checkout_hold(pg_temp.hold_id('a'),'Retry cancellation'),pg_temp.hold_id('a'),'Release retry stable');
select is(pg_temp.claim('a','08:00'),pg_temp.hold_id('a'),'Terminal claim retry does not resurrect lease');
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000002',true);
select lives_ok($$insert into hold_ids values('after-release',pg_temp.claim('after-release','08:00'))$$,'C6: B takes released slot');
reset role;
update public.fixed_checkout_holds set created_at=clock_timestamp()-interval '2 hours',expires_at=clock_timestamp()-interval '1 hour'
where id=pg_temp.hold_id('after-release');
select is((select status::text from public.fixed_checkout_holds where id=pg_temp.hold_id('after-release')),'active','Expiry fixture keeps stored active status');
set local role authenticated;
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000001',true);
select lives_ok($$insert into hold_ids values('after-expiry',pg_temp.claim('after-expiry','08:00'))$$,'C5: expired active row immediately stops blocking');
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000002',true);
select is(pg_temp.claim('after-release','08:00'),pg_temp.hold_id('after-release'),'Expired claim retry returns old identity without extending expiry');
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.claim_fixed_checkout_hold('68000000-0000-0000-0000-000000000003',
  '68000000-0000-0000-0000-000000000012','hold-fixed',extract(dow from current_date+7)::smallint,
  '18:00','Asia/Taipei',current_date+7,null,'checkout-wrong-relationship')$$,'42501','UNAUTHORIZED_HOLD_ACTION','Student cannot claim another relationship');
select throws_ok($$select pg_temp.claim('overnight','23:30')$$,'22023','INVALID_HOLD_SLOT','Unsupported overnight slot rejected');
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000004',true);
select lives_ok($$select public.set_fixed_checkout_hold_policy('68000000-0000-0000-0000-000000000021',2400,'New fixture TTL')$$,'Change policy');
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000001',true);
select lives_ok($$insert into hold_ids values('config-new',pg_temp.claim('config-new','10:00'))$$,'New claim after policy change');
select is((select expires_at-created_at from public.fixed_checkout_holds where id=pg_temp.hold_id('config-new')),interval '2400 seconds','New claim uses new TTL');
select is((select expires_at-created_at from public.fixed_checkout_holds where id=pg_temp.hold_id('after-expiry')),interval '1200 seconds','Existing lease does not change');
select lives_ok($$insert into hold_ids values('payment-fail',pg_temp.claim('payment-fail','11:00'))$$,'Create checkout for payment failure');
reset role;
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$select public.release_fixed_checkout_hold(pg_temp.hold_id('payment-fail'),'Payment failed')$$,'C7: payment worker releases failed checkout');
select is(pg_temp.convert('payment-fail')->>'error','HOLD_NOT_ACTIVE','Released payment failure cannot convert');
select is(pg_temp.convert('config-new')->>'error','HOLD_FULFILLMENT_REQUIRED','Unpaid/unfulfilled hold cannot convert');
reset role;
select is((select count(*) from public.recurring_lesson_series),0::bigint,'Rejected conversions leave no owner');
select is((select count(*) from public.fixed_entitlement_cycles),0::bigint,'Rejected conversions leave no cycle');
select is((select count(*) from public.audit_logs where action='fixed_checkout_hold.conversion_failed'),2::bigint,'Conversion failure audit survives rejection');

-- The real commerce payment operation precedes the real Epic5 outbox processor.
insert into hold_ids select 'order-'||r.name,h.order_id from hold_ids r join public.fixed_checkout_holds h on h.id=r.id
where r.name in('after-expiry','config-new','after-release');
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000004',true);
select lives_ok($$select public.admin_confirm_cash_payment(id,'fixed-hold-cash-'||name,'Paid fixture source') from hold_ids where name like 'order-%'$$,'Confirm cash payment using existing Admin authority');
reset role;
insert into hold_ids select 'event-'||substr(r.name,7),e.id from hold_ids r join public.order_fulfillment_events e on e.order_id=r.id where r.name like 'order-%';
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select is(pg_temp.convert('config-new')->>'error','HOLD_FULFILLMENT_REQUIRED','C8: paid but unprocessed cannot become owner');
select lives_ok($$select public.process_order_fulfillment_event(id) from hold_ids where name like 'event-%'$$,'Process real paid fulfillment events');
reset role;
insert into hold_ids select 'ent-'||substr(r.name,7),e.id from hold_ids r join public.entitlements e on e.source_order_id=r.id where r.name like 'order-%';
create temporary table hold_credit_before as select count(*) n from public.lesson_credit_ledger;
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000001',true);
select throws_ok($$select pg_temp.convert('after-expiry')$$,'42501','UNAUTHORIZED_HOLD_ACTION','Student cannot invoke privileged conversion');
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select is(pg_temp.convert('after-expiry')->>'status','converted','C9: paid+fulfilled active hold becomes owner and Cycle 1');
select lives_ok($$insert into hold_ids values('converted-series',(pg_temp.convert('after-expiry')->>'series_id')::uuid)$$,'C10: conversion retry returns same series');
select lives_ok($$select public.process_order_fulfillment_event(pg_temp.hold_id('event-after-expiry'))$$,'C10: repeated fulfillment remains idempotent');
select is((pg_temp.convert('after-expiry')->>'series_id')::uuid,pg_temp.hold_id('converted-series'),'C10: no duplicate owner after fulfillment retry');
reset role;
select is((select count(*) from public.recurring_lesson_series),1::bigint,'Exactly one formal series');
select is((select count(*) from public.fixed_entitlement_cycles),1::bigint,'Exactly one cycle');
select is((select sequence_number from public.fixed_entitlement_cycles),1,'First purchase attaches Cycle 1');
select is((select entitlement_id from public.fixed_entitlement_cycles),pg_temp.hold_id('ent-after-expiry'),'Cycle uses fulfilled entitlement');
select is((select count(*) from public.lesson_credit_ledger),(select n from hold_credit_before),'Conversion writes no credit ledger');
select is((select count(*) from public.lessons),0::bigint,'Conversion creates no speculative future Lessons');
select is((select count(*) from public.audit_logs where action='fixed_checkout_hold.converted'),1::bigint,'Exactly one conversion audit');
select is((select count(*) from public.audit_logs where action='recurring_series.created'),1::bigint,'Exactly one ownership audit');
select ok(private.fixed_checkout_hold_slot_clear('68000000-0000-0000-0000-000000000002','68000000-0000-0000-0000-000000000003',
  private.resolve_scheduling_local_datetime(current_date+14,'08:00','Asia/Taipei'),
  private.resolve_scheduling_local_datetime(current_date+14,'08:50','Asia/Taipei')),'Converted hold itself no longer blocks');
select ok(not private.scheduling_slot_clear('68000000-0000-0000-0000-000000000002','68000000-0000-0000-0000-000000000003',
  private.resolve_scheduling_local_datetime(current_date+14,'08:00','Asia/Taipei'),
  private.resolve_scheduling_local_datetime(current_date+14,'08:50','Asia/Taipei')),'Formal unexpanded owner now has Fixed priority');
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000002',true);
select throws_ok($$select pg_temp.claim('existing-owner','08:00')$$,'P0001','FIXED_SLOT_UNAVAILABLE','C3: existing formal Fixed owner rejects claim');
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select is(pg_temp.convert('after-release')->>'error','HOLD_NOT_ACTIVE','C11: expired prior holder delayed paid fulfillment cannot reclaim');
reset role;
select is((select count(*) from public.recurring_lesson_series),1::bigint,'C11: delayed conversion leaves current owner intact');
select is((select student_user_id from public.recurring_lesson_series),'68000000-0000-0000-0000-000000000001'::uuid,'C11: legitimate new owner unchanged');
select ok(exists(select 1 from public.entitlements where id=pg_temp.hold_id('ent-after-release')),'C11: delayed purchase entitlement remains with commerce');

-- Force a late attach rejection to prove the conversion subtransaction rolls
-- back the provisional release/series and leaves only the failure audit.
update public.entitlements set status='revoked',revoked_at=clock_timestamp(),revoked_reason='Late failure fixture'
where id=pg_temp.hold_id('ent-config-new');
set local role service_role;
select is(pg_temp.convert('config-new')->>'error','ENTITLEMENT_NOT_ELIGIBLE','Late Cycle core validation rejects revoked entitlement');
reset role;
select is((select status::text from public.fixed_checkout_holds where id=pg_temp.hold_id('config-new')),'active','Failed attachment restores own live hold');
select is((select count(*) from public.recurring_lesson_series),1::bigint,'Failed attachment rolls back new series');
select is((select count(*) from public.fixed_entitlement_cycles),1::bigint,'Failed attachment rolls back cycle');
select is((select count(*) from public.audit_logs where action='recurring_series.created'),1::bigint,'Failed attachment leaves no ownership audit');
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000004',true);
select lives_ok($$select public.release_fixed_checkout_hold(pg_temp.hold_id('after-release'),'Admin acknowledges expiry')$$,'Admin can finalize effective expiry');
select is((select status::text from public.fixed_checkout_holds where id=pg_temp.hold_id('after-release')),'expired','Release records explicit expired state');
select ok((select count(*) from public.fixed_checkout_holds)>1,'Admin can read all holds');
reset role;

select ok((select relrowsecurity from pg_class where oid='public.fixed_checkout_holds'::regclass),'Hold RLS enabled');
select ok(not has_table_privilege(r,'public.fixed_checkout_holds',p),r||' has no raw '||p)
from (values('anon'),('authenticated'),('service_role')) roles(r) cross join (values('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE')) privileges(p);
select ok(not has_function_privilege(r,p.oid,'EXECUTE'),r||' cannot execute private '||p.proname)
from pg_proc p cross join (values('anon'),('authenticated'),('service_role')) roles(r)
where p.pronamespace='private'::regnamespace and p.proname in(
  'fixed_checkout_hold_slot_clear','scheduling_instance_slot_clear','recurring_ownership_clear','validate_fixed_checkout_slot',
  'scheduling_instance_without_checkout_hold_clear','recurring_series_ownership_clear');
select ok(not has_function_privilege('anon',p.oid,'EXECUTE'),'Anonymous cannot execute '||p.proname)
from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in(
  'claim_fixed_checkout_hold','release_fixed_checkout_hold','convert_fixed_checkout_hold','set_fixed_checkout_hold_policy');
-- Anonymous denial and runtime authorization above do not prove the complete
-- role grant matrix. In particular service_role must not gain claim/config RPCs.
select is(has_function_privilege(r.role_name,f.signature,'EXECUTE'),
  r.role_name='authenticated' or f.service_allowed,r.role_name||' RPC grant: '||f.signature)
from (values('authenticated'),('service_role')) r(role_name)
cross join (values
  ('public.claim_fixed_checkout_hold(uuid,uuid,text,smallint,time,text,date,date,text)',false),
  ('public.set_fixed_checkout_hold_policy(uuid,integer,text)',false),
  ('public.release_fixed_checkout_hold(uuid,text)',true),
  ('public.convert_fixed_checkout_hold(uuid,uuid,uuid,text)',true)
) f(signature,service_allowed);
select ok(p.prosecdef and p.proowner='postgres'::regrole and p.proconfig=array['search_path=""']::text[],'Pinned definer for '||p.proname)
from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in(
  'claim_fixed_checkout_hold','release_fixed_checkout_hold','convert_fixed_checkout_hold','set_fixed_checkout_hold_policy');
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000001',true);
select throws_ok($$update public.fixed_checkout_holds set status='released'$$,'42501',null,'Authenticated raw UPDATE denied in execution');
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select throws_ok($$delete from public.fixed_checkout_holds$$,'42501',null,'Service raw DELETE denied despite RLS bypass');
reset role;
select * from finish();
rollback;
