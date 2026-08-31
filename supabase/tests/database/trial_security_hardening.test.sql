begin;

select plan(61);

select ok(
  private.is_safe_trial_meeting_url(
    'manual_google_meet', 'https://meet.google.com/abc-defg-hij'
  ),
  'Google Meet exact hostname is accepted'
);
select ok(
  not private.is_safe_trial_meeting_url(
    'manual_google_meet', 'https://meet.google.com.evil.example/room'
  ),
  'Google Meet suffix spoof is rejected'
);
select ok(
  not private.is_safe_trial_meeting_url(
    'manual_google_meet', 'https://meet.google.com@evil.example/room'
  ),
  'URL userinfo is rejected'
);
select ok(
  not private.is_safe_trial_meeting_url(
    'manual_google_meet', 'https://evil.example/room'
  ),
  'arbitrary HTTPS host is rejected'
);
select ok(
  private.is_safe_trial_meeting_url(
    'manual_zoom', 'https://us02web.zoom.us/j/123456789'
  ),
  'Zoom subdomain with safe boundary is accepted'
);
select ok(
  not private.is_safe_trial_meeting_url(
    'manual_zoom', 'https://zoom.us.evil.example/j/123456789'
  ),
  'Zoom suffix spoof is rejected'
);
select ok(
  not private.is_safe_trial_meeting_url(
    'manual_google_meet', 'https://localhost/room'
  ),
  'localhost is rejected'
);
select ok(
  not private.is_safe_trial_meeting_url(
    'manual_google_meet', 'https://127.0.0.1/room'
  ),
  'loopback IP is rejected'
);
select ok(
  not private.is_safe_trial_meeting_url(
    'manual_zoom', 'https://10.0.0.1/room'
  ),
  'private IP is rejected'
);
select ok(
  not private.is_safe_trial_meeting_url(
    'manual_url', 'https://example.com/room'
  ),
  'manual arbitrary URL is disabled for the MVP'
);
select ok(private.is_valid_iana_timezone('Asia/Taipei'), 'IANA timezone is accepted');
select ok(not private.is_valid_iana_timezone('UTC+8'), 'non-IANA timezone is rejected');

insert into auth.users (id, email) values
  ('40000000-0000-0000-0000-00000000000a', 'hardening-student-a@example.invalid'),
  ('40000000-0000-0000-0000-00000000000b', 'hardening-student-b@example.invalid'),
  ('40000000-0000-0000-0000-00000000000c', 'hardening-teacher-a@example.invalid'),
  ('40000000-0000-0000-0000-00000000000d', 'hardening-teacher-b@example.invalid'),
  ('40000000-0000-0000-0000-00000000000e', 'hardening-admin@example.invalid');

update public.profiles set display_name = case user_id
  when '40000000-0000-0000-0000-00000000000a' then 'Hardening Student A'
  when '40000000-0000-0000-0000-00000000000b' then 'Hardening Student B'
  when '40000000-0000-0000-0000-00000000000c' then 'Hardening Teacher A'
  when '40000000-0000-0000-0000-00000000000d' then 'Hardening Teacher B'
  else 'Hardening Admin' end;

insert into public.user_roles (user_id, role) values
  ('40000000-0000-0000-0000-00000000000c', 'teacher'),
  ('40000000-0000-0000-0000-00000000000d', 'teacher'),
  ('40000000-0000-0000-0000-00000000000e', 'admin');

insert into public.teacher_profiles (
  user_id, public_slug, bio, teaching_status, is_public, teaching_modes,
  trial_price_twd, default_meeting_provider, default_meeting_url
) values
  (
    '40000000-0000-0000-0000-00000000000c', 'hardening-teacher-a', 'A',
    'active', true, array['online']::public.teaching_mode[], 500,
    'manual_google_meet', 'https://meet.google.com/abc-defg-hij'
  ),
  (
    '40000000-0000-0000-0000-00000000000d', 'hardening-teacher-b', 'B',
    'active', true, array['online']::public.teaching_mode[], 500,
    'manual_zoom', 'https://us02web.zoom.us/j/123456789'
  );

select throws_ok(
  $$update public.teacher_profiles
    set default_meeting_url = 'https://evil.example/room'
    where user_id = '40000000-0000-0000-0000-00000000000c'$$,
  '23514', null, 'Teacher meeting constraint rejects an arbitrary HTTPS host'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-00000000000b', true);
select lives_ok(
  $$select public.request_trial_checkout(
      'hardening-teacher-b', 'Stable intent', 'online', null,
      '2099-02-01 10:00+00', 'Asia/Taipei',
      'hardening-shared-idempotency'
    )$$,
  'first checkout intent is created'
);
select is(
  public.request_trial_checkout(
    'hardening-teacher-b', 'Stable intent', 'online', null,
    '2099-02-01 10:00+00', 'Asia/Taipei',
    'hardening-shared-idempotency'
  ),
  public.request_trial_checkout(
    'hardening-teacher-b', 'Stable intent', 'online', null,
    '2099-02-01 10:00+00', 'Asia/Taipei',
    'hardening-shared-idempotency'
  ),
  'same Student and key return the same Order id'
);
select throws_ok(
  $$select public.request_trial_checkout(
      'hardening-teacher-b', 'Second intent', 'online', null,
      '2099-02-02 10:00+00', 'Asia/Taipei',
      'hardening-second-pending-intent'
    )$$,
  '23514', null, 'new key cannot create a duplicate pending pair intent'
);

reset role;
select is(
  (
    select count(*)
    from public.trial_orders
    where student_user_id = '40000000-0000-0000-0000-00000000000b'
      and idempotency_key = 'hardening-shared-idempotency'
  ),
  1::bigint,
  'sequential retry creates no duplicate Order'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-00000000000a', true);
select lives_ok(
  $$select public.request_trial_checkout(
      'hardening-teacher-a', 'Independent Student intent', 'online', null,
      '2099-02-03 10:00+00', 'Asia/Taipei',
      'hardening-shared-idempotency'
    )$$,
  'same opaque key is independently scoped to another Student'
);

reset role;
select is(
  (
    select count(*)
    from public.trial_orders
    where idempotency_key = 'hardening-shared-idempotency'
  ),
  2::bigint,
  'different Students neither collide nor receive each other Order'
);

insert into public.student_teacher_relationships (
  id, student_user_id, teacher_user_id, relationship_status, preferred_mode
) values
  (
    '41000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-00000000000a',
    '40000000-0000-0000-0000-00000000000d', 'trial', 'online'
  ),
  (
    '41000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-00000000000a',
    '40000000-0000-0000-0000-00000000000c', 'trial', 'online'
  ),
  (
    '41000000-0000-0000-0000-000000000003',
    '40000000-0000-0000-0000-00000000000b',
    '40000000-0000-0000-0000-00000000000c', 'trial', 'online'
  );

insert into public.lessons (
  id, student_user_id, teacher_user_id, relationship_id, lesson_type,
  delivery_mode, starts_at, ends_at, duration_minutes, timezone_anchor,
  status, meeting_provider, meeting_url
) values
  (
    '42000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-00000000000a',
    '40000000-0000-0000-0000-00000000000d',
    '41000000-0000-0000-0000-000000000001', 'trial', 'online',
    now() - interval '2 hours', now() - interval '70 minutes', 50,
    'Asia/Taipei', 'completed', 'manual_zoom',
    'https://us02web.zoom.us/j/123456789'
  ),
  (
    '42000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-00000000000a',
    '40000000-0000-0000-0000-00000000000c',
    '41000000-0000-0000-0000-000000000002', 'trial', 'online',
    '2099-03-01 10:00+00', '2099-03-01 10:50+00', 50,
    'Asia/Taipei', 'scheduled', 'manual_google_meet',
    'https://meet.google.com/abc-defg-hij'
  ),
  (
    '42000000-0000-0000-0000-000000000003',
    '40000000-0000-0000-0000-00000000000b',
    '40000000-0000-0000-0000-00000000000c',
    '41000000-0000-0000-0000-000000000003', 'trial', 'online',
    '2099-04-01 10:00+00', '2099-04-01 10:50+00', 50,
    'Asia/Taipei', 'scheduled', 'manual_google_meet',
    'https://meet.google.com/abc-defg-hij'
  );

select throws_ok(
  $$insert into public.assessments (
      student_user_id, teacher_user_id, lesson_id, recommendation_type, summary
    ) values (
      '40000000-0000-0000-0000-00000000000b',
      '40000000-0000-0000-0000-00000000000d',
      '42000000-0000-0000-0000-000000000001', 'one_to_one', 'Mismatch'
    )$$,
  '23503', null, 'assessment with mismatched Student is rejected'
);
select throws_ok(
  $$insert into public.assessments (
      student_user_id, teacher_user_id, lesson_id, recommendation_type, summary
    ) values (
      '40000000-0000-0000-0000-00000000000a',
      '40000000-0000-0000-0000-00000000000c',
      '42000000-0000-0000-0000-000000000001', 'one_to_one', 'Mismatch'
    )$$,
  '23503', null, 'assessment with mismatched Teacher is rejected'
);
select lives_ok(
  $$insert into public.assessments (
      student_user_id, teacher_user_id, lesson_id, recommendation_type, summary
    ) values (
      '40000000-0000-0000-0000-00000000000a',
      '40000000-0000-0000-0000-00000000000d',
      '42000000-0000-0000-0000-000000000001', 'one_to_one', 'Correct'
    )$$,
  'assessment with correct Lesson participants is accepted'
);
select throws_ok(
  $$insert into public.lesson_records (
      lesson_id, completed_at, completed_by
    ) values (
      '42000000-0000-0000-0000-000000000001', now(),
      '40000000-0000-0000-0000-00000000000c'
    )$$,
  '23503', null, 'lesson record completed_by must be the assigned Teacher'
);
select lives_ok(
  $$insert into public.lesson_records (
      lesson_id, completed_at, completed_by
    ) values (
      '42000000-0000-0000-0000-000000000001', now(),
      '40000000-0000-0000-0000-00000000000d'
    )$$,
  'assigned Teacher can be the lesson record completer'
);

select ok(
  not has_column_privilege('authenticated', 'public.lessons', 'student_user_id', 'SELECT'),
  'authenticated cannot select Lesson Student auth UUID'
);
select ok(
  not has_column_privilege('authenticated', 'public.lessons', 'trial_order_id', 'SELECT'),
  'authenticated cannot select Lesson order identifier'
);
select ok(
  not has_column_privilege('authenticated', 'public.assessments', 'student_user_id', 'SELECT'),
  'authenticated cannot select Assessment Student auth UUID'
);
select ok(
  has_column_privilege('authenticated', 'public.assessments', 'summary', 'SELECT'),
  'authenticated participant retains Assessment summary access'
);
select ok(
  not has_column_privilege(
    'authenticated', 'public.student_teacher_relationships',
    'teacher_user_id', 'SELECT'
  ),
  'authenticated cannot select counterpart UUID from Relationships'
);
select ok(
  not has_column_privilege('authenticated', 'public.trial_orders', 'teacher_user_id', 'SELECT'),
  'authenticated cannot select Teacher auth UUID from Trial Orders'
);
select ok(
  not has_column_privilege('authenticated', 'public.lesson_records', 'completed_by', 'SELECT'),
  'authenticated cannot select technical Lesson Record completer UUID'
);

select is(
  (
    select pg_catalog.pg_get_userbyid(proowner)
    from pg_catalog.pg_proc
    where oid = 'public.confirm_trial_payment(uuid,timestamptz)'::regprocedure
  ),
  'postgres',
  'payment confirmation is owned by postgres'
);
select is(
  (
    select pg_catalog.pg_get_userbyid(proowner)
    from pg_catalog.pg_proc
    where oid = 'public.complete_trial_lesson(uuid,smallint,text,text,text,text,text,public.recommendation_type,text)'::regprocedure
  ),
  'postgres',
  'trial completion is owned by postgres'
);
select ok(
  not has_function_privilege(
    'anon', 'public.confirm_trial_payment(uuid,timestamptz)', 'EXECUTE'
  ),
  'anonymous cannot execute payment confirmation'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.request_trial_checkout(text,text,public.teaching_mode,text,timestamptz,text,text)',
    'EXECUTE'
  ),
  'anonymous cannot execute checkout request'
);
select ok(
  has_function_privilege(
    'authenticated', 'public.confirm_trial_payment(uuid,timestamptz)', 'EXECUTE'
  ),
  'authenticated receives only the RPC execute capability guarded inside the function'
);

insert into public.trial_orders (
  id, idempotency_key, student_user_id, teacher_user_id, delivery_mode,
  proposed_starts_at, timezone, price_twd
) values (
  '43000000-0000-0000-0000-000000000001',
  'hardening-admin-check-0001',
  '40000000-0000-0000-0000-00000000000a',
  '40000000-0000-0000-0000-00000000000c',
  'online', '2099-05-01 10:00+00', 'Asia/Taipei', 500
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-00000000000a', true);
select throws_ok(
  $$select public.confirm_trial_payment(
      '43000000-0000-0000-0000-000000000001', null
    )$$,
  '42501', null, 'non Admin cannot call payment confirmation RPC'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-00000000000c', true);
select throws_ok(
  $$select public.complete_trial_lesson(
      '42000000-0000-0000-0000-000000000003'::uuid,
      1::smallint, 'Visible', 'Private', 'Performance', 'Next', 'Homework',
      'one_to_one'::public.recommendation_type, 'Assessment'
    )$$,
  '23514', null, 'assigned Teacher cannot complete a Trial before starts_at'
);

reset role;
select is(
  (select status from public.lessons where id = '42000000-0000-0000-0000-000000000003'),
  'scheduled'::public.lesson_status,
  'early completion leaves the Lesson scheduled'
);
select is(
  (select count(*) from public.lesson_records where lesson_id = '42000000-0000-0000-0000-000000000003'),
  0::bigint,
  'early completion creates no partial Lesson Record'
);

update public.student_teacher_relationships
set relationship_status = 'active'
where id = '41000000-0000-0000-0000-000000000003';

set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-00000000000b', true);
select throws_ok(
  $$select public.request_trial_checkout(
      'hardening-teacher-a', 'Active relationship', 'online', null,
      '2099-06-01 10:00+00', 'Asia/Taipei', 'hardening-active-relationship'
    )$$,
  '23514', null, 'active relationship rejects a new Trial request'
);

reset role;
update public.student_teacher_relationships
set relationship_status = 'paused'
where id = '41000000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-00000000000b', true);
select throws_ok(
  $$select public.request_trial_checkout(
      'hardening-teacher-a', 'Paused relationship', 'online', null,
      '2099-06-02 10:00+00', 'Asia/Taipei', 'hardening-paused-relationship'
    )$$,
  '23514', null, 'paused relationship rejects a new Trial request'
);

reset role;
update public.student_teacher_relationships
set relationship_status = 'awaiting_conversion'
where id = '41000000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-00000000000b', true);
select throws_ok(
  $$select public.request_trial_checkout(
      'hardening-teacher-a', 'Awaiting relationship', 'online', null,
      '2099-06-03 10:00+00', 'Asia/Taipei', 'hardening-awaiting-relationship'
    )$$,
  '23514', null, 'awaiting_conversion relationship rejects a new Trial request'
);

reset role;
update public.lessons set
  starts_at = now() - interval '60 minutes',
  ends_at = now() - interval '10 minutes'
where id = '42000000-0000-0000-0000-000000000003';
update public.student_teacher_relationships
set relationship_status = 'active'
where id = '41000000-0000-0000-0000-000000000003';

set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-00000000000c', true);
select throws_ok(
  $$select public.complete_trial_lesson(
      '42000000-0000-0000-0000-000000000003'::uuid,
      1::smallint, 'Visible', 'Private', 'Performance', 'Next', 'Homework',
      'one_to_one'::public.recommendation_type, 'Assessment'
    )$$,
  '23514', null, 'completion requires its Relationship to be trial'
);

reset role;
select is(
  (select status from public.lessons where id = '42000000-0000-0000-0000-000000000003'),
  'scheduled'::public.lesson_status,
  'failed relationship transition rolls the Lesson status back'
);
select is(
  (select count(*) from public.lesson_records where lesson_id = '42000000-0000-0000-0000-000000000003'),
  0::bigint,
  'failed relationship transition leaves no partial records'
);

update public.student_teacher_relationships
set relationship_status = 'trial'
where id = '41000000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-00000000000c', true);
select lives_ok(
  $$select public.complete_trial_lesson(
      '42000000-0000-0000-0000-000000000003'::uuid,
      1::smallint, 'Visible', 'Private', 'Performance', 'Next', 'Homework',
      'one_to_one'::public.recommendation_type, 'Assessment'
    )$$,
  'started Trial with a trial Relationship completes successfully'
);

reset role;
select is(
  (select status from public.lessons where id = '42000000-0000-0000-0000-000000000003'),
  'completed'::public.lesson_status,
  'successful completion marks the Lesson completed'
);
select is(
  (
    select relationship_status
    from public.student_teacher_relationships
    where id = '41000000-0000-0000-0000-000000000003'
  ),
  'awaiting_conversion'::public.student_teacher_relationship_status,
  'successful completion advances trial to awaiting_conversion'
);

select throws_ok(
  $$insert into public.lessons (
      student_user_id, teacher_user_id, relationship_id, lesson_type,
      delivery_mode, starts_at, ends_at, duration_minutes, timezone_anchor,
      status, meeting_provider, meeting_url
    ) values (
      '40000000-0000-0000-0000-00000000000a',
      '40000000-0000-0000-0000-00000000000c',
      '41000000-0000-0000-0000-000000000002', 'trial', 'online',
      '2099-03-01 10:10+00', '2099-03-01 11:00+00', 50,
      'Asia/Taipei', 'scheduled', 'manual_google_meet',
      'https://meet.google.com/abc-defg-hij'
    )$$,
  '23P01', null, 'scheduled Lesson blocks an overlapping interval'
);

update public.lessons set status = 'completed'
where id = '42000000-0000-0000-0000-000000000002';
select lives_ok(
  $$insert into public.lessons (
      id, student_user_id, teacher_user_id, relationship_id, lesson_type,
      delivery_mode, starts_at, ends_at, duration_minutes, timezone_anchor,
      status, meeting_provider, meeting_url
    ) values (
      '42000000-0000-0000-0000-000000000004',
      '40000000-0000-0000-0000-00000000000a',
      '40000000-0000-0000-0000-00000000000c',
      '41000000-0000-0000-0000-000000000002', 'trial', 'online',
      '2099-03-01 10:00+00', '2099-03-01 10:50+00', 50,
      'Asia/Taipei', 'scheduled', 'manual_google_meet',
      'https://meet.google.com/abc-defg-hij'
    )$$,
  'completed Lesson does not block a replacement interval'
);

update public.lessons set status = 'student_cancelled'
where id = '42000000-0000-0000-0000-000000000004';
select lives_ok(
  $$insert into public.lessons (
      id, student_user_id, teacher_user_id, relationship_id, lesson_type,
      delivery_mode, starts_at, ends_at, duration_minutes, timezone_anchor,
      status, meeting_provider, meeting_url
    ) values (
      '42000000-0000-0000-0000-000000000005',
      '40000000-0000-0000-0000-00000000000a',
      '40000000-0000-0000-0000-00000000000c',
      '41000000-0000-0000-0000-000000000002', 'trial', 'online',
      '2099-03-01 10:00+00', '2099-03-01 10:50+00', 50,
      'Asia/Taipei', 'scheduled', 'manual_google_meet',
      'https://meet.google.com/abc-defg-hij'
    )$$,
  'cancelled Lesson does not block a replacement interval'
);

update public.lessons set status = 'rescheduled'
where id = '42000000-0000-0000-0000-000000000005';
select lives_ok(
  $$insert into public.lessons (
      id, student_user_id, teacher_user_id, relationship_id, lesson_type,
      delivery_mode, starts_at, ends_at, duration_minutes, timezone_anchor,
      status, meeting_provider, meeting_url
    ) values (
      '42000000-0000-0000-0000-000000000006',
      '40000000-0000-0000-0000-00000000000a',
      '40000000-0000-0000-0000-00000000000c',
      '41000000-0000-0000-0000-000000000002', 'trial', 'online',
      '2099-03-01 10:00+00', '2099-03-01 10:50+00', 50,
      'Asia/Taipei', 'scheduled', 'manual_google_meet',
      'https://meet.google.com/abc-defg-hij'
    )$$,
  'rescheduled Lesson does not block a replacement interval'
);
select lives_ok(
  $$insert into public.lessons (
      student_user_id, teacher_user_id, relationship_id, lesson_type,
      delivery_mode, starts_at, ends_at, duration_minutes, timezone_anchor,
      status, meeting_provider, meeting_url
    ) values (
      '40000000-0000-0000-0000-00000000000a',
      '40000000-0000-0000-0000-00000000000c',
      '41000000-0000-0000-0000-000000000002', 'trial', 'online',
      '2099-03-01 10:50+00', '2099-03-01 11:40+00', 50,
      'Asia/Taipei', 'scheduled', 'manual_google_meet',
      'https://meet.google.com/abc-defg-hij'
    )$$,
  'adjacent half-open Lesson interval is allowed'
);

select throws_ok(
  $$insert into public.trial_orders (
      idempotency_key, student_user_id, teacher_user_id, delivery_mode,
      proposed_starts_at, timezone, price_twd
    ) values (
      'hardening-invalid-timezone-order',
      '40000000-0000-0000-0000-00000000000a',
      '40000000-0000-0000-0000-00000000000d',
      'online', '2099-07-01 10:00+00', 'UTC+8', 500
    )$$,
  '23514', null, 'Trial Order DB constraint rejects invalid timezone'
);
select throws_ok(
  $$insert into public.lessons (
      student_user_id, teacher_user_id, relationship_id, lesson_type,
      delivery_mode, starts_at, ends_at, duration_minutes, timezone_anchor,
      status, meeting_provider, meeting_url
    ) values (
      '40000000-0000-0000-0000-00000000000a',
      '40000000-0000-0000-0000-00000000000d',
      '41000000-0000-0000-0000-000000000001', 'trial', 'online',
      '2099-07-01 10:00+00', '2099-07-01 10:50+00', 50,
      'UTC+8', 'scheduled', 'manual_zoom',
      'https://us02web.zoom.us/j/123456789'
    )$$,
  '23514', null, 'Lesson DB constraint rejects invalid timezone anchor'
);

update public.profiles set account_status = 'suspended'
where user_id = '40000000-0000-0000-0000-00000000000c';
set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-00000000000c', true);
select throws_ok(
  $$select public.update_own_teacher_meeting_defaults(
      'manual_google_meet', 'https://meet.google.com/new-room'
    )$$,
  '42501', null, 'suspended Teacher cannot use Trial mutation RPCs'
);

reset role;
update public.profiles set account_status = 'active'
where user_id = '40000000-0000-0000-0000-00000000000c';
delete from public.user_roles
where user_id = '40000000-0000-0000-0000-00000000000c'
  and role = 'teacher';
set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-00000000000c', true);
select throws_ok(
  $$select public.complete_trial_lesson(
      '42000000-0000-0000-0000-000000000003'::uuid,
      1::smallint, 'Visible', 'Private', 'Performance', 'Next', 'Homework',
      'one_to_one'::public.recommendation_type, 'Assessment'
    )$$,
  '42501', null, 'removed Teacher role cannot complete a Trial'
);

select ok(
  not has_function_privilege(
    'anon', 'public.admin_reschedule_trial_lesson(uuid,timestamptz)', 'EXECUTE'
  ),
  'anonymous cannot execute Trial reschedule RPC'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.complete_trial_lesson(uuid,smallint,text,text,text,text,text,public.recommendation_type,text)',
    'EXECUTE'
  ),
  'anonymous cannot execute Trial completion RPC'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.update_own_teacher_meeting_defaults(public.meeting_provider,text)',
    'EXECUTE'
  ),
  'anonymous cannot execute meeting settings RPC'
);

reset role;
select * from finish();
rollback;
