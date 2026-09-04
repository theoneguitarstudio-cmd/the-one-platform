begin;
select no_plan();

create temporary table transfer_cases(
  name text primary key,entitlement_id uuid,lesson_id uuid,reservation_id uuid,booking_id uuid
);
grant select on pg_temp.transfer_cases to authenticated;
insert into transfer_cases values
  ('teacher','71000000-0000-0000-0000-000000000020','71000000-0000-0000-0000-000000000030','71000000-0000-0000-0001-000000000040','71000000-0000-0000-0000-000000000050'),
  ('expired','71000000-0000-0000-0000-000000000021','71000000-0000-0000-0000-000000000031','71000000-0000-0000-0001-000000000041','71000000-0000-0000-0000-000000000051'),
  ('student','71000000-0000-0000-0000-000000000022','71000000-0000-0000-0000-000000000032','71000000-0000-0000-0001-000000000042','71000000-0000-0000-0000-000000000052'),
  ('admin-teacher','71000000-0000-0000-0000-000000000023','71000000-0000-0000-0000-000000000033','71000000-0000-0000-0001-000000000043','71000000-0000-0000-0000-000000000053'),
  ('admin-generic','71000000-0000-0000-0000-000000000024','71000000-0000-0000-0000-000000000034','71000000-0000-0000-0001-000000000044','71000000-0000-0000-0000-000000000054'),
  ('failure','71000000-0000-0000-0000-000000000025','71000000-0000-0000-0000-000000000035','71000000-0000-0000-0001-000000000045','71000000-0000-0000-0000-000000000055');

insert into auth.users(id,email) values
  ('71000000-0000-0000-0000-000000000001','transfer-student@example.invalid'),
  ('71000000-0000-0000-0000-000000000002','transfer-teacher@example.invalid'),
  ('71000000-0000-0000-0000-000000000003','transfer-admin@example.invalid');
update public.profiles set display_name='Teacher cancellation transfer fixture'
where user_id::text like '71000000-%';
insert into public.user_roles(user_id,role) values
  ('71000000-0000-0000-0000-000000000002','teacher'),
  ('71000000-0000-0000-0000-000000000003','admin');
insert into public.teacher_profiles(
  user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd,
  default_meeting_provider,default_meeting_url
) values(
  '71000000-0000-0000-0000-000000000002','teacher-cancel-transfer','Transfer fixture',
  'active',false,array['online']::public.teaching_mode[],500,
  'manual_google_meet','https://meet.google.com/abc-defg-hij'
);
insert into public.student_teacher_relationships(
  id,student_user_id,teacher_user_id,relationship_status,preferred_mode
) values(
  '71000000-0000-0000-0000-000000000010','71000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000002','active','online'
);

insert into public.entitlements(
  id,beneficiary_user_id,teacher_scope_user_id,entitlement_type,status,starts_at,expires_at,
  product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes
)
select entitlement_id,'71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002',
  'lesson_package',case when name='expired' then 'expired'::public.entitlement_status else 'active'::public.entitlement_status end,
  now()-interval '30 days',case when name='expired' then now()-interval '1 day' else now()+interval '30 days' end,
  'One-credit '||name,'flexible',50 from transfer_cases;
insert into public.lesson_credit_ledger(
  entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code
)
select entitlement_id,'71000000-0000-0000-0000-000000000001','allocation',1,
  'p15a-allocation-'||name,'test_fixture' from transfer_cases;

insert into public.lessons(
  id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
  starts_at,ends_at,duration_minutes,timezone_anchor,status,meeting_provider,meeting_url
)
select lesson_id,'71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002',
  '71000000-0000-0000-0000-000000000010','flexible','online',
  case when name='expired' then now()-interval '2 days' else now()+interval '10 days'+row_number() over()*interval '2 hours' end,
  case when name='expired' then now()-interval '2 days'+interval '50 minutes' else now()+interval '10 days'+row_number() over()*interval '2 hours'+interval '50 minutes' end,
  50,'Asia/Taipei','scheduled','manual_google_meet','https://meet.google.com/abc-defg-hij'
from transfer_cases;
insert into public.lesson_credit_reservations(
  id,entitlement_id,beneficiary_user_id,reservation_key,lesson_id,booking_reference,status
)
select reservation_id,entitlement_id,'71000000-0000-0000-0000-000000000001',
  'p15a-reservation-'||name,lesson_id,booking_id::text,'reserved' from transfer_cases;
insert into public.lesson_credit_ledger(
  entitlement_id,beneficiary_user_id,entry_type,available_delta,reserved_delta,
  reservation_id,lesson_id,operation_key,reason_code
)
select entitlement_id,'71000000-0000-0000-0000-000000000001','reservation',-1,1,
  reservation_id,lesson_id,'p15a-reserve-ledger-'||name,'test_fixture' from transfer_cases;
insert into public.bookings(
  id,student_user_id,teacher_user_id,relationship_id,source,status,starts_at,ends_at,
  timezone_anchor,lesson_id,credit_reservation_id,created_by,idempotency_key
)
select c.booking_id,l.student_user_id,l.teacher_user_id,l.relationship_id,'flexible','confirmed',
  l.starts_at,l.ends_at,l.timezone_anchor,l.id,c.reservation_id,l.student_user_id,
  'p15a-booking-'||c.name from transfer_cases c join public.lessons l on l.id=c.lesson_id;
update public.lesson_credit_reservations r set booking_id=c.booking_id
from transfer_cases c where r.id=c.reservation_id;

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.set_makeup_right_policy(
  'teacher_cancellation',1209600,'Fourteen-day Teacher cancellation policy')$$,
  'Admin configures a fourteen-day Makeup policy');
reset role;

select is((select available from private.lesson_credit_balance((select entitlement_id from transfer_cases where name='teacher'))),0,
  'Teacher case begins with zero available ordinary credit');
select is((select reserved from private.lesson_credit_balance((select entitlement_id from transfer_cases where name='teacher'))),1,
  'Teacher case begins with one reserved ordinary credit');
set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.cancel_lesson_booking(
  (select booking_id from transfer_cases where name='teacher'),'unchanged','Teacher cancellation transfer')$$,
  'A1 Teacher cancellation succeeds');
select lives_ok($$select public.cancel_lesson_booking(
  (select booking_id from transfer_cases where name='teacher'),'unchanged','Teacher cancellation retry')$$,
  'A13 Teacher cancellation retry is stable');
reset role;
select is((select available from private.lesson_credit_balance((select entitlement_id from transfer_cases where name='teacher'))),0,
  'A2 ordinary available credit is not restored');
select is((select reserved from private.lesson_credit_balance((select entitlement_id from transfer_cases where name='teacher'))),0,
  'A3 ordinary reserved balance is removed');
select is((select consumed from private.lesson_credit_balance((select entitlement_id from transfer_cases where name='teacher'))),0,
  'A4 ordinary consumed balance remains unchanged');
select is((select status from public.bookings where id=(select booking_id from transfer_cases where name='teacher')),
  'cancelled'::public.booking_status,'A5 Booking is cancelled');
select is((select status from public.lessons where id=(select lesson_id from transfer_cases where name='teacher')),
  'teacher_cancelled'::public.lesson_status,'A6 Lesson is teacher_cancelled');
select is((select count(*) from public.makeup_rights m join transfer_cases c on c.lesson_id=m.origin_lesson_id
  where c.name='teacher' and m.origin_teacher_user_id='71000000-0000-0000-0000-000000000002'
    and m.origin_entitlement_id=c.entitlement_id and m.origin_reservation_id=c.reservation_id
    and m.status='available'),1::bigint,'A1/A7-A9 exactly one traceable Makeup Right exists');
select ok((select m.valid_until between m.created_at+interval '13 days 23 hours 59 minutes'
  and m.created_at+interval '14 days 1 minute' from public.makeup_rights m
  join transfer_cases c on c.lesson_id=m.origin_lesson_id where c.name='teacher'),
  'A10 valid_until snapshots configured policy');
select is((select count(*) from public.makeup_rights m join transfer_cases c on c.lesson_id=m.origin_lesson_id
  where c.name='teacher'),1::bigint,'A13 retry creates no duplicate Makeup Right');
select is((select count(*) from public.lesson_credit_ledger l join transfer_cases c on c.reservation_id=l.reservation_id
  where c.name='teacher' and l.reason_code='teacher_cancellation_makeup_transfer'),1::bigint,
  'A13 retry creates no duplicate ledger mutation');
select is((select status from public.entitlements where id=(select entitlement_id from transfer_cases where name='teacher')),
  'exhausted'::public.entitlement_status,'A12 final ordinary credit does not reopen entitlement');
select ok((select converted_makeup_right_id is not null from public.lesson_credit_reservations
  where id=(select reservation_id from transfer_cases where name='teacher')),
  'A3 reservation has terminal conversion linkage');
select throws_ok($$select private.consume_lesson_credit_core(
  (select reservation_id from transfer_cases where name='teacher'),
  (select lesson_id from transfer_cases where name='teacher'),'test',
  '71000000-0000-0000-0000-000000000002')$$,'P0001','CREDIT_ALREADY_RELEASED',
  'Converted reservation cannot be ordinarily consumed');

set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.cancel_lesson_booking(
  (select booking_id from transfer_cases where name='expired'),'unchanged','Expired entitlement transfer')$$,
  'A11 Teacher cancellation succeeds after entitlement expiry');
reset role;
select is((select status from public.entitlements where id=(select entitlement_id from transfer_cases where name='expired')),
  'expired'::public.entitlement_status,'Expired entitlement is not reopened');
select is((select available from private.lesson_credit_balance((select entitlement_id from transfer_cases where name='expired'))),0,
  'Expired entitlement gets no restored ordinary credit');
select is((select count(*) from public.makeup_rights m join transfer_cases c on c.lesson_id=m.origin_lesson_id
  where c.name='expired' and m.status='available'),1::bigint,'Expired origin still creates one Makeup Right');

set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.cancel_lesson_booking(
  (select booking_id from transfer_cases where name='student'),'released','Student timely cancellation')$$,
  'A14 Student cancellation remains unchanged');
reset role;
select is((select available from private.lesson_credit_balance((select entitlement_id from transfer_cases where name='student'))),1,
  'A14 Student cancellation restores ordinary credit');
select is((select count(*) from public.makeup_rights m join transfer_cases c on c.lesson_id=m.origin_lesson_id
  where c.name='student'),0::bigint,'A14 Student cancellation creates no Makeup Right');

set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.cancel_lesson_booking(
  (select booking_id from transfer_cases where name='admin-teacher'),'unchanged',
  'Admin classified Teacher cancellation','teacher_caused')$$,
  'A15 Admin teacher-caused classification uses value transfer');
select lives_ok($$select public.cancel_lesson_booking(
  (select booking_id from transfer_cases where name='admin-generic'),'released',
  'Generic Admin cancellation','future_integration')$$,
  'Generic Admin cancellation retains prior semantics');
reset role;
select is((select count(*) from public.makeup_rights m join transfer_cases c on c.lesson_id=m.origin_lesson_id
  where c.name='admin-teacher'),1::bigint,'A15 Admin teacher-caused creates one Makeup Right');
select is((select status from public.lessons where id=(select lesson_id from transfer_cases where name='admin-teacher')),
  'teacher_cancelled'::public.lesson_status,'Admin teacher-caused classification records Teacher cancellation');
select is((select count(*) from public.makeup_rights m join transfer_cases c on c.lesson_id=m.origin_lesson_id
  where c.name='admin-generic'),0::bigint,'Generic Admin cancellation creates no Makeup Right');
select is((select available from private.lesson_credit_balance((select entitlement_id from transfer_cases where name='admin-generic'))),1,
  'Generic Admin release still restores ordinary credit');

delete from public.makeup_right_policies where source='teacher_cancellation';
set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.cancel_lesson_booking(
  (select booking_id from transfer_cases where name='failure'),'unchanged','Missing policy rollback')$$,
  'P0001','MAKEUP_POLICY_MISSING','A24 Makeup creation prerequisite failure aborts cancellation');
reset role;
select is((select status from public.bookings where id=(select booking_id from transfer_cases where name='failure')),
  'confirmed'::public.booking_status,'A24 failed transfer leaves Booking unchanged');
select is((select status from public.lessons where id=(select lesson_id from transfer_cases where name='failure')),
  'scheduled'::public.lesson_status,'A24 failed transfer leaves Lesson unchanged');
select is((select status from public.lesson_credit_reservations where id=(select reservation_id from transfer_cases where name='failure')),
  'reserved'::public.lesson_credit_reservation_status,'A24 failed transfer leaves reservation unchanged');
select is((select reserved from private.lesson_credit_balance((select entitlement_id from transfer_cases where name='failure'))),1,
  'A24 failed transfer leaves ordinary reserved balance unchanged');
select is((select count(*) from public.makeup_rights m join transfer_cases c on c.lesson_id=m.origin_lesson_id
  where c.name='failure'),0::bigint,'A24 failed transfer creates no partial Makeup Right');

select is(has_function_privilege('authenticated',
  'private.create_makeup_right_core(uuid,uuid,uuid,uuid,timestamptz,public.makeup_right_source,text,text,uuid,uuid,uuid)',
  'EXECUTE'),false,'Private Makeup creation core remains inaccessible');
select is(has_function_privilege('authenticated',
  'private.convert_lesson_credit_reservation_to_makeup_core(uuid,uuid,uuid,uuid,text,integer)',
  'EXECUTE'),false,'Private value-transfer core is inaccessible');
select is(has_function_privilege('authenticated',
  'public.cancel_lesson_booking(uuid,public.booking_credit_outcome,text,text)','EXECUTE'),true,
  'Authenticated cancellation RPC ACL remains available');

select * from finish();
rollback;
