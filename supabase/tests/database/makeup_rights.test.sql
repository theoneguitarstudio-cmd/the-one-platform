begin;
select no_plan();

create temporary table makeup_ids(name text primary key,id uuid);
grant select,insert,update on pg_temp.makeup_ids to authenticated;

insert into auth.users(id,email) values
  ('68000000-0000-0000-0000-000000000001','makeup-student-a@example.invalid'),
  ('68000000-0000-0000-0000-000000000002','makeup-student-b@example.invalid'),
  ('68000000-0000-0000-0000-000000000003','makeup-teacher-a@example.invalid'),
  ('68000000-0000-0000-0000-000000000004','makeup-teacher-b@example.invalid'),
  ('68000000-0000-0000-0000-000000000005','makeup-admin@example.invalid');
update public.profiles set display_name='Makeup lifecycle fixture'
where user_id::text like '68000000-%';
insert into public.user_roles(user_id,role) values
  ('68000000-0000-0000-0000-000000000003','teacher'),
  ('68000000-0000-0000-0000-000000000004','teacher'),
  ('68000000-0000-0000-0000-000000000005','admin');
insert into public.teacher_profiles(
  user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd,
  default_meeting_provider,default_meeting_url
) values
  ('68000000-0000-0000-0000-000000000003','makeup-lifecycle-a','Fixture A','active',true,
    array['online']::public.teaching_mode[],500,'manual_google_meet','https://meet.google.com/abc-defg-hij'),
  ('68000000-0000-0000-0000-000000000004','makeup-lifecycle-b','Fixture B','active',true,
    array['online']::public.teaching_mode[],500,'manual_zoom','https://zoom.us/j/123456789');
insert into public.student_teacher_relationships(
  id,student_user_id,teacher_user_id,relationship_status,preferred_mode
) values
  ('68000000-0000-0000-0000-000000000010','68000000-0000-0000-0000-000000000001','68000000-0000-0000-0000-000000000003','active','online'),
  ('68000000-0000-0000-0000-000000000011','68000000-0000-0000-0000-000000000002','68000000-0000-0000-0000-000000000004','active','online');

insert into public.entitlements(
  id,beneficiary_user_id,teacher_scope_user_id,entitlement_type,status,starts_at,expires_at,
  product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes
) values
  ('68000000-0000-0000-0000-000000000020','68000000-0000-0000-0000-000000000001','68000000-0000-0000-0000-000000000003',
    'lesson_package','expired',now()-interval '60 days',now()-interval '1 day','Expired origin package','flexible',50),
  ('68000000-0000-0000-0000-000000000021','68000000-0000-0000-0000-000000000002','68000000-0000-0000-0000-000000000004',
    'lesson_package','active',now()-interval '1 day',now()+interval '30 days','Other package','flexible',50);

insert into public.lessons(
  id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
  starts_at,ends_at,duration_minutes,timezone_anchor,status,meeting_provider,meeting_url
) select
  ('68000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
  case when n=9 then '68000000-0000-0000-0000-000000000002'::uuid else '68000000-0000-0000-0000-000000000001'::uuid end,
  case when n=9 then '68000000-0000-0000-0000-000000000004'::uuid else '68000000-0000-0000-0000-000000000003'::uuid end,
  case when n=9 then '68000000-0000-0000-0000-000000000011'::uuid else '68000000-0000-0000-0000-000000000010'::uuid end,
  'flexible','online',now()-interval '20 days'+n*interval '1 hour',
  now()-interval '20 days'+n*interval '1 hour'+interval '50 minutes',50,'Asia/Taipei','teacher_cancelled',
  case when n=9 then 'manual_zoom'::public.meeting_provider else 'manual_google_meet'::public.meeting_provider end,
  case when n=9 then 'https://zoom.us/j/123456789' else 'https://meet.google.com/abc-defg-hij' end
from generate_series(1,9) n;

insert into public.lesson_credit_reservations(
  id,entitlement_id,beneficiary_user_id,reservation_key,lesson_id,booking_reference,
  status,released_at
) select
  ('68000000-0000-0000-0001-'||lpad(n::text,12,'0'))::uuid,
  case when n=9 then '68000000-0000-0000-0000-000000000021'::uuid else '68000000-0000-0000-0000-000000000020'::uuid end,
  case when n=9 then '68000000-0000-0000-0000-000000000002'::uuid else '68000000-0000-0000-0000-000000000001'::uuid end,
  'p15b-origin-reservation-'||n,
  ('68000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
  'p15b-origin-booking-'||n,'released',now()
from generate_series(1,9) n;

select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000003',true);
insert into makeup_ids values('main',private.create_makeup_right_core(
  '68000000-0000-0000-0000-000000000001','68000000-0000-0000-0000-000000000001',
  '68000000-0000-0000-0000-000000000003',null,now()+interval '10 days','teacher_cancellation',
  'p15b-create-main-0001','Teacher cancellation compensation','68000000-0000-0000-0000-000000000003',
  '68000000-0000-0000-0000-000000000020','68000000-0000-0000-0001-000000000001'));
insert into makeup_ids values('main-retry',private.create_makeup_right_core(
  '68000000-0000-0000-0000-000000000001','68000000-0000-0000-0000-000000000001',
  '68000000-0000-0000-0000-000000000003',null,(select valid_until from public.makeup_rights where id=(select id from makeup_ids where name='main')),
  'teacher_cancellation','p15b-create-main-0001','Teacher cancellation compensation','68000000-0000-0000-0000-000000000003',
  '68000000-0000-0000-0000-000000000020','68000000-0000-0000-0001-000000000001'));
select is((select id from makeup_ids where name='main-retry'),(select id from makeup_ids where name='main'),
  'B1-B2 create retry returns the same Makeup Right');
select is((select count(*) from public.makeup_rights where origin_lesson_id='68000000-0000-0000-0000-000000000001'),1::bigint,
  'B2 source identity creates no duplicate Right');
select is((select current_teacher_user_id=origin_teacher_user_id from public.makeup_rights where id=(select id from makeup_ids where name='main')),true,
  'Current Teacher scope initially defaults to origin Teacher');
select throws_ok($$update public.makeup_rights set origin_lesson_id='68000000-0000-0000-0000-000000000002'
  where id=(select id from makeup_ids where name='main')$$,'55000','MAKEUP_RIGHT_IDENTITY_IMMUTABLE',
  'B3 origin traceability cannot be silently overwritten');
select throws_ok($$update public.makeup_rights set current_teacher_user_id='68000000-0000-0000-0000-000000000004'
  where id=(select id from makeup_ids where name='main')$$,'55000','MAKEUP_RIGHT_IDENTITY_IMMUTABLE',
  'Teacher scope transfer requires a future controlled operation');
select ok((select e.expires_at<now() and m.valid_until>now() from public.makeup_rights m
  join public.entitlements e on e.id=m.origin_entitlement_id where m.id=(select id from makeup_ids where name='main')),
  'B4 Makeup validity is independent from expired origin entitlement');

set local role authenticated;
select lives_ok($$select public.reserve_makeup_right((select id from makeup_ids where name='main'),
  '68000000-0000-0000-0000-000000000001','68000000-0000-0000-0000-000000000003',
  'p15b-reserve-main-001','Reserve valid Makeup Right')$$,'B5 Student reserves own valid Right');
select lives_ok($$select public.reserve_makeup_right((select id from makeup_ids where name='main'),
  '68000000-0000-0000-0000-000000000001','68000000-0000-0000-0000-000000000003',
  'p15b-reserve-main-001','Reserve valid Makeup Right')$$,'Reserve retry is stable');
reset role;
select is((select status from public.makeup_rights where id=(select id from makeup_ids where name='main')),
  'reserved'::public.makeup_right_status,'B5 available transitions to reserved');
select is((select count(*) from public.makeup_right_operations where makeup_right_id=(select id from makeup_ids where name='main') and operation_type='reserve'),1::bigint,
  'Reserve retry creates one operation and one value reservation');

set local role authenticated;
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000005',true);
select lives_ok($$select public.consume_makeup_right((select id from makeup_ids where name='main'),
  'p15b-consume-main-001','Admin consumes unbound reserved Makeup Right')$$,'B6 Admin consumes unbound reserved Right');
select lives_ok($$select public.consume_makeup_right((select id from makeup_ids where name='main'),
  'p15b-consume-main-001','Admin consumes unbound reserved Makeup Right')$$,'Consume retry is stable');
reset role;
select is((select status from public.makeup_rights where id=(select id from makeup_ids where name='main')),
  'used'::public.makeup_right_status,'B6 reserved transitions to used');
select is((select count(*) from public.makeup_right_operations where makeup_right_id=(select id from makeup_ids where name='main') and operation_type='consume'),1::bigint,
  'Consume retry cannot duplicate use');

select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000003',true);
insert into makeup_ids values('restore',private.create_makeup_right_core(
  '68000000-0000-0000-0000-000000000001','68000000-0000-0000-0000-000000000002',
  '68000000-0000-0000-0000-000000000003',null,now()+interval '10 days','teacher_cancellation',
  'p15b-create-restore-01','Restore lifecycle fixture','68000000-0000-0000-0000-000000000003',
  '68000000-0000-0000-0000-000000000020','68000000-0000-0000-0001-000000000002'));
set local role authenticated;
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.reserve_makeup_right((select id from makeup_ids where name='restore'),
  '68000000-0000-0000-0000-000000000001','68000000-0000-0000-0000-000000000003',
  'p15b-reserve-restore-1','Reserve restore fixture')$$,'Reserve restore fixture');
select lives_ok($$select public.restore_makeup_right((select id from makeup_ids where name='restore'),
  'p15b-restore-right-001','Timely generic restore')$$,'B7 reserved Right restores');
select lives_ok($$select public.restore_makeup_right((select id from makeup_ids where name='restore'),
  'p15b-restore-right-001','Timely generic restore')$$,'Restore retry is stable');
reset role;
select is((select status from public.makeup_rights where id=(select id from makeup_ids where name='restore')),
  'available'::public.makeup_right_status,'B7 restore returns the same Right to available');

insert into public.makeup_rights(
  id,student_user_id,origin_lesson_id,origin_teacher_user_id,current_teacher_user_id,
  origin_entitlement_id,origin_reservation_id,source,source_operation_key,status,
  valid_until,reason,created_by,created_at,reserved_at,reserved_by
) values(
  '68000000-0000-0000-0002-000000000003','68000000-0000-0000-0000-000000000001',
  '68000000-0000-0000-0000-000000000003','68000000-0000-0000-0000-000000000003',
  '68000000-0000-0000-0000-000000000003','68000000-0000-0000-0000-000000000020',
  '68000000-0000-0000-0001-000000000003','teacher_cancellation','p15b-create-expired-01',
  'available',now()-interval '1 day','Expired authority fixture','68000000-0000-0000-0000-000000000003',now()-interval '2 days',null,null),
  ('68000000-0000-0000-0002-000000000004','68000000-0000-0000-0000-000000000001',
  '68000000-0000-0000-0000-000000000004','68000000-0000-0000-0000-000000000003',
  '68000000-0000-0000-0000-000000000003','68000000-0000-0000-0000-000000000020',
  '68000000-0000-0000-0001-000000000004','teacher_cancellation','p15b-create-expired-02',
  'reserved',now()-interval '1 day','Expired consume fixture','68000000-0000-0000-0000-000000000003',now()-interval '2 days',
  now()-interval '2 days','68000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.reserve_makeup_right('68000000-0000-0000-0002-000000000003',
  '68000000-0000-0000-0000-000000000001','68000000-0000-0000-0000-000000000003',
  'p15b-expired-reserve-1','Reject expired reserve')$$,'P0001','MAKEUP_RIGHT_EXPIRED','B8 expired Right cannot reserve');
select throws_ok($$select public.consume_makeup_right('68000000-0000-0000-0002-000000000004',
  'p15b-expired-consume-1','Reject expired consume')$$,'42501','UNAUTHORIZED_MAKEUP_ACTION',
  'Student cannot consume even a reserved Right');
select lives_ok($$select public.expire_makeup_right('68000000-0000-0000-0002-000000000003',
  'p15b-expire-right-001','Materialize deterministic expiry')$$,'Explicit expiry materializes status');
reset role;
select is((select status from public.makeup_rights where id='68000000-0000-0000-0002-000000000003'),
  'expired'::public.makeup_right_status,'Expired Right reaches terminal expired status');
set local role authenticated;
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000005',true);
select throws_ok($$select public.consume_makeup_right('68000000-0000-0000-0002-000000000004',
  'p15b-expired-consume-2','Reject expired use')$$,'P0001','MAKEUP_RIGHT_EXPIRED','B9 expired reserved Right cannot be used');
reset role;

select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000003',true);
insert into makeup_ids values('revoke',private.create_makeup_right_core(
  '68000000-0000-0000-0000-000000000001','68000000-0000-0000-0000-000000000005',
  '68000000-0000-0000-0000-000000000003',null,now()+interval '10 days','teacher_cancellation',
  'p15b-create-revoke-001','Revoke lifecycle fixture','68000000-0000-0000-0000-000000000003',
  '68000000-0000-0000-0000-000000000020','68000000-0000-0000-0001-000000000005'));
set local role authenticated;
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000005',true);
select lives_ok($$select public.revoke_makeup_right((select id from makeup_ids where name='revoke'),
  'p15b-revoke-right-001','Admin controlled revocation')$$,'Admin revokes available Right');
reset role;
select is((select status from public.makeup_rights where id=(select id from makeup_ids where name='revoke')),
  'revoked'::public.makeup_right_status,'B10 revoke creates terminal revoked status');
set local role authenticated;
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000005',true);
select throws_ok($$select public.consume_makeup_right((select id from makeup_ids where name='revoke'),
  'p15b-revoked-consume-1','Reject revoked use')$$,'P0001','MAKEUP_RIGHT_NOT_RESERVED',
  'B10 revoked Right cannot be consumed');
reset role;

select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000004',true);
insert into makeup_ids values('other',private.create_makeup_right_core(
  '68000000-0000-0000-0000-000000000002','68000000-0000-0000-0000-000000000009',
  '68000000-0000-0000-0000-000000000004',null,now()+interval '10 days','teacher_cancellation',
  'p15b-create-other-0001','Other Student fixture','68000000-0000-0000-0000-000000000004',
  '68000000-0000-0000-0000-000000000021','68000000-0000-0000-0001-000000000009'));
set local role authenticated;
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000001',true);
select ok((select count(*)>0 from public.makeup_rights),'B11 Student reads own Rights');
select is((select count(*) from public.makeup_rights where student_user_id='68000000-0000-0000-0000-000000000002'),0::bigint,
  'B12 Student cannot read another Student Rights');
select set_config('request.jwt.claim.sub','68000000-0000-0000-0000-000000000003',true);
select ok((select count(*)>0 from public.makeup_rights),'B13 Teacher reads own scope/origin Rights');
select is((select count(*) from public.makeup_rights where current_teacher_user_id='68000000-0000-0000-0000-000000000004'),0::bigint,
  'Teacher cannot read unrelated scope');
reset role;

select is(has_table_privilege('authenticated','public.makeup_rights','INSERT'),false,'B14 authenticated raw INSERT blocked');
select is(has_table_privilege('authenticated','public.makeup_rights','UPDATE'),false,'B14 authenticated raw UPDATE blocked');
select is(has_table_privilege('service_role','public.makeup_rights','INSERT,UPDATE,DELETE'),false,'B14 service_role generic raw mutation blocked');
select is(has_function_privilege('authenticated',
  'private.create_makeup_right_core(uuid,uuid,uuid,uuid,timestamptz,public.makeup_right_source,text,text,uuid,uuid,uuid)','EXECUTE'),false,
  'B15 authenticated cannot execute private create helper');
select is(has_function_privilege('service_role',
  'private.create_makeup_right_core(uuid,uuid,uuid,uuid,timestamptz,public.makeup_right_source,text,text,uuid,uuid,uuid)','EXECUTE'),false,
  'B15 service_role cannot execute private create helper');
select is((select count(distinct o.operation_type) from public.makeup_right_operations o join public.audit_logs a on a.id=o.audit_log_id
  where a.target_type='makeup_right' and a.actor_user_id is not null),
  6::bigint,'B16 every lifecycle mutation has actor-aware append-only audit linkage');
select is((select count(*) from public.lesson_credit_ledger where beneficiary_user_id::text like '68000000-%'),0::bigint,
  'Makeup lifecycle never writes ordinary credit ledger');
select is((select count(*) from public.lesson_credit_reservations where beneficiary_user_id::text like '68000000-%'),9::bigint,
  'Makeup lifecycle does not create or mutate a second ordinary reservation');

select * from finish();
rollback;
