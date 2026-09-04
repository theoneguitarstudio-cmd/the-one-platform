-- P1-5 evidence for current HEAD. This exercises the real cancellation RPC and
-- records the confirmed gap: Teacher cancellation releases ordinary credit and
-- creates no first-class Makeup Right. It should pass before the future fix and
-- fail once that behavior changes, forcing replacement with acceptance tests.
begin;
select no_plan();

insert into auth.users(id,email) values
  ('67000000-0000-0000-0000-000000000001','makeup-student@example.invalid'),
  ('67000000-0000-0000-0000-000000000002','makeup-teacher@example.invalid');

update public.profiles set display_name=case user_id
  when '67000000-0000-0000-0000-000000000001' then 'Makeup Student'
  else 'Makeup Teacher' end
where user_id::text like '67000000-%';

insert into public.user_roles(user_id,role) values
  ('67000000-0000-0000-0000-000000000002','teacher');
insert into public.teacher_profiles(
  user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd,
  default_meeting_provider,default_meeting_url
) values (
  '67000000-0000-0000-0000-000000000002','makeup-audit-teacher','Audit fixture',
  'active',true,array['online']::public.teaching_mode[],500,
  'manual_google_meet','https://meet.google.com/abc-defg-hij'
);
insert into public.student_teacher_relationships(
  id,student_user_id,teacher_user_id,relationship_status,preferred_mode
) values (
  '67000000-0000-0000-0000-000000000010',
  '67000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000002','active','online'
);
insert into public.entitlements(
  id,beneficiary_user_id,teacher_scope_user_id,entitlement_type,status,starts_at,expires_at,
  product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes
) values (
  '67000000-0000-0000-0000-000000000020',
  '67000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000002',
  'lesson_package','active',now()-interval '1 day',now()+interval '1 month',
  'One ordinary lesson','flexible',50
);
insert into public.lesson_credit_ledger(
  entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code
) values (
  '67000000-0000-0000-0000-000000000020',
  '67000000-0000-0000-0000-000000000001',
  'allocation',1,'p15-makeup-audit-allocation','test_fixture'
);
insert into public.lessons(
  id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
  starts_at,ends_at,duration_minutes,timezone_anchor,status,meeting_provider,meeting_url
) values (
  '67000000-0000-0000-0000-000000000030',
  '67000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000002',
  '67000000-0000-0000-0000-000000000010','flexible','online',
  now()+interval '7 days',now()+interval '7 days 50 minutes',50,'Asia/Taipei','scheduled',
  'manual_google_meet','https://meet.google.com/abc-defg-hij'
);
insert into public.lesson_credit_reservations(
  id,entitlement_id,beneficiary_user_id,reservation_key,lesson_id,booking_reference,status
) values (
  '67000000-0000-0000-0000-000000000040',
  '67000000-0000-0000-0000-000000000020',
  '67000000-0000-0000-0000-000000000001',
  'p15-makeup-audit-reservation',
  '67000000-0000-0000-0000-000000000030',
  '67000000-0000-0000-0000-000000000050','reserved'
);
insert into public.lesson_credit_ledger(
  entitlement_id,beneficiary_user_id,entry_type,available_delta,reserved_delta,
  reservation_id,lesson_id,operation_key,reason_code
) values (
  '67000000-0000-0000-0000-000000000020',
  '67000000-0000-0000-0000-000000000001','reservation',-1,1,
  '67000000-0000-0000-0000-000000000040',
  '67000000-0000-0000-0000-000000000030',
  'p15-makeup-audit-reserve-ledger','test_fixture'
);
insert into public.bookings(
  id,student_user_id,teacher_user_id,relationship_id,source,status,starts_at,ends_at,
  timezone_anchor,lesson_id,credit_reservation_id,created_by,idempotency_key
) values (
  '67000000-0000-0000-0000-000000000050',
  '67000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000002',
  '67000000-0000-0000-0000-000000000010','flexible','confirmed',
  now()+interval '7 days',now()+interval '7 days 50 minutes','Asia/Taipei',
  '67000000-0000-0000-0000-000000000030',
  '67000000-0000-0000-0000-000000000040',
  '67000000-0000-0000-0000-000000000001','p15-makeup-audit-booking'
);
update public.lesson_credit_reservations
set booking_id='67000000-0000-0000-0000-000000000050'
where id='67000000-0000-0000-0000-000000000040';

select is((select available from private.lesson_credit_balance('67000000-0000-0000-0000-000000000020')),0::integer,
  'Precondition: the single ordinary value is unavailable while reserved');
select is((select reserved from private.lesson_credit_balance('67000000-0000-0000-0000-000000000020')),1::integer,
  'Precondition: one ordinary value is reserved');
select is((select consumed from private.lesson_credit_balance('67000000-0000-0000-0000-000000000020')),0::integer,
  'Precondition: no ordinary value is consumed');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','67000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.cancel_lesson_booking(
  '67000000-0000-0000-0000-000000000050','released','Teacher caused cancellation')$$,
  'Current Teacher cancellation RPC succeeds');
select lives_ok($$select public.cancel_lesson_booking(
  '67000000-0000-0000-0000-000000000050','released','Teacher caused cancellation retry')$$,
  'Repeated Teacher cancellation returns idempotently');
reset role;

select is((select available from private.lesson_credit_balance('67000000-0000-0000-0000-000000000020')),1::integer,
  'Confirmed gap: Teacher cancellation restores one ordinary available credit');
select is((select reserved from private.lesson_credit_balance('67000000-0000-0000-0000-000000000020')),0::integer,
  'Teacher cancellation releases the ordinary reservation');
select is((select consumed from private.lesson_credit_balance('67000000-0000-0000-0000-000000000020')),0::integer,
  'Teacher cancellation does not consume ordinary credit');
select is((select status from public.lesson_credit_reservations
  where id='67000000-0000-0000-0000-000000000040'),
  'released'::public.lesson_credit_reservation_status,
  'Reservation reaches released state');
select is((select status from public.lessons
  where id='67000000-0000-0000-0000-000000000030'),
  'teacher_cancelled'::public.lesson_status,
  'Actor identity only distinguishes Teacher cancellation at Lesson status');
select is((select cancellation_credit_outcome from public.bookings
  where id='67000000-0000-0000-0000-000000000050'),
  'released'::public.booking_credit_outcome,
  'Booking records released ordinary credit');
select is((select count(*) from public.lesson_credit_ledger
  where reservation_id='67000000-0000-0000-0000-000000000040' and entry_type='release'),
  1::bigint,'Retry creates exactly one ordinary release ledger entry');
select is((select count(*) from public.audit_logs
  where target_id='67000000-0000-0000-0000-000000000050'
    and action='booking.cancelled' and actor_user_id='67000000-0000-0000-0000-000000000002'),
  1::bigint,'Teacher cancellation has one actor-aware booking audit event');
select is((select count(*) from public.makeup_rights
  where origin_lesson_id='67000000-0000-0000-0000-000000000030'),0::bigint,
  'Confirmed P1-5A gap: Teacher cancellation still creates no Makeup Right');

select * from finish();
rollback;
