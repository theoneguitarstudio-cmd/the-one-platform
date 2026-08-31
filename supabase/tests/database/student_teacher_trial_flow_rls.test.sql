begin;

select plan(33);

insert into auth.users (id, email) values
  ('30000000-0000-0000-0000-00000000000a', 'epic3-student-a@example.invalid'),
  ('30000000-0000-0000-0000-00000000000b', 'epic3-student-b@example.invalid'),
  ('30000000-0000-0000-0000-00000000000c', 'epic3-teacher-a@example.invalid'),
  ('30000000-0000-0000-0000-00000000000d', 'epic3-teacher-b@example.invalid'),
  ('30000000-0000-0000-0000-00000000000e', 'epic3-admin@example.invalid');

update public.profiles set display_name = case user_id
  when '30000000-0000-0000-0000-00000000000a' then 'Student A'
  when '30000000-0000-0000-0000-00000000000b' then 'Student B'
  when '30000000-0000-0000-0000-00000000000c' then 'Teacher A'
  when '30000000-0000-0000-0000-00000000000d' then 'Teacher B'
  else 'Trial Admin' end;

insert into public.user_roles (user_id, role) values
  ('30000000-0000-0000-0000-00000000000c', 'teacher'),
  ('30000000-0000-0000-0000-00000000000d', 'teacher'),
  ('30000000-0000-0000-0000-00000000000e', 'admin');

insert into public.teacher_profiles (
  user_id, public_slug, bio, teaching_status, is_public, teaching_modes,
  trial_price_twd, default_meeting_provider, default_meeting_url
) values
  (
    '30000000-0000-0000-0000-00000000000c', 'epic3-teacher-a', 'A',
    'active', true, array['online']::public.teaching_mode[], 500,
    'manual_google_meet', 'https://meet.google.com/aaa-bbbb-ccc'
  ),
  (
    '30000000-0000-0000-0000-00000000000d', 'epic3-teacher-b', 'B',
    'active', true, array['online']::public.teaching_mode[], 500,
    'manual_zoom', 'https://us02web.zoom.us/j/123456789'
  );

insert into public.student_profiles (user_id, learning_goal, onboarding_status)
values ('30000000-0000-0000-0000-00000000000b', 'Private goal B', 'complete');

set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000a', true);

select is(
  (select count(*) from public.student_profiles where user_id = '30000000-0000-0000-0000-00000000000b'),
  0::bigint,
  'Student A cannot read Student B profile'
);

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select * from public.student_teacher_relationships$$,
  '42501', null, 'anonymous cannot read trial relationships'
);
select throws_ok(
  $$select * from public.lessons$$,
  '42501', null, 'anonymous cannot read lessons'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000a', true);
select lives_ok(
  $$select public.request_trial_checkout(
    'epic3-teacher-a', 'Learn rhythm', 'online', null,
    '2099-01-10 10:00:00+00', 'Asia/Taipei', 'epic3-student-a-order-0001'
  )$$,
  'student can create a pending trial checkout'
);
select is(
  (select count(*) from public.trial_orders where payment_status = 'pending'),
  1::bigint,
  'trial request remains pending before server confirmation'
);

reset role;
set local role anon;
select throws_ok(
  $$select public.confirm_trial_payment(
    (select id from public.trial_orders where idempotency_key = 'epic3-student-a-order-0001'),
    null
  )$$,
  '42501', null, 'anonymous cannot confirm trial payment'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000e', true);
select lives_ok(
  $$select public.confirm_trial_payment(
    (select id from public.trial_orders where idempotency_key = 'epic3-student-a-order-0001'),
    null
  )$$,
  'Admin can confirm placeholder payment'
);

reset role;
select is(
  (select count(*) from public.student_teacher_relationships where relationship_status = 'trial'),
  1::bigint,
  'payment confirmation creates one trial relationship'
);
select is(
  (select count(*) from public.lessons where status = 'scheduled' and duration_minutes = 50),
  1::bigint,
  'payment confirmation creates one scheduled 50-minute trial'
);
select ok(
  (select ends_at - starts_at = interval '50 minutes' from public.lessons limit 1),
  'trial interval is exactly 50 minutes'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000e', true);
select lives_ok(
  $$select public.confirm_trial_payment(
    (select id from public.trial_orders where idempotency_key = 'epic3-student-a-order-0001'), null
  )$$,
  'payment confirmation is idempotent'
);
reset role;
select is((select count(*) from public.lessons), 1::bigint, 'repeat confirmation creates no duplicate lesson');

set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000d', true);
select is((select count(*) from public.lessons), 0::bigint, 'Teacher B cannot read Teacher A trial');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000c', true);
select is((select count(*) from public.get_own_teacher_trials()), 1::bigint, 'Teacher A can read only own minimal trial workflow');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000a', true);
select is((select count(*) from public.lessons where meeting_url is not null), 1::bigint, 'online trial student participant can read meeting reference');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000b', true);
select is((select count(*) from public.lessons where meeting_url is not null), 0::bigint, 'non-participant cannot read meeting reference');
select lives_ok(
  $$select public.request_trial_checkout(
    'epic3-teacher-a', 'Student B goal', 'online', null,
    '2099-01-10 10:00:00+00', 'Asia/Taipei', 'epic3-student-b-order-0001'
  )$$,
  'second student can request the same teacher time while payment is pending'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000e', true);
select throws_ok(
  $$select public.confirm_trial_payment(
    (select id from public.trial_orders where idempotency_key = 'epic3-student-b-order-0001'), null
  )$$,
  '23P01', null, 'database exclusion constraint rejects teacher collision'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000a', true);
select lives_ok(
  $$select public.request_trial_checkout(
    'epic3-teacher-b', 'Second teacher request', 'online', null,
    '2099-01-10 10:00:00+00', 'Asia/Taipei', 'epic3-student-a-order-0002'
  )$$,
  'student can request another teacher while payment is pending'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000e', true);
select throws_ok(
  $$select public.confirm_trial_payment(
    (select id from public.trial_orders where idempotency_key = 'epic3-student-a-order-0002'), null
  )$$,
  '23P01', null, 'database exclusion constraint rejects student collision'
);

reset role;
select throws_ok(
  $$insert into public.lessons (
    student_user_id, teacher_user_id, relationship_id, lesson_type,
    delivery_mode, starts_at, ends_at, duration_minutes, timezone_anchor,
    status, meeting_provider, meeting_url
  ) values (
    '30000000-0000-0000-0000-00000000000a',
    '30000000-0000-0000-0000-00000000000c',
    (select id from public.student_teacher_relationships limit 1),
    'trial', 'online', '2099-02-01 10:00+00', '2099-02-01 10:40+00',
    50, 'Asia/Taipei', 'scheduled', 'manual_google_meet',
    'https://meet.google.com/invalid-interval'
  )$$,
  '23514', null, 'invalid lesson interval is rejected'
);

update public.lessons set
  starts_at = now() - interval '60 minutes',
  ends_at = now() - interval '10 minutes'
where status = 'scheduled';

set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000d', true);
select throws_ok(
  $$select public.complete_trial_lesson(
    (select id from public.lessons limit 1), 1, 'Visible', 'Private',
    'Performance', 'Next', 'Homework', 'one_to_one', 'Assessment'
  )$$,
  '42501', null, 'only the assigned Teacher can complete a trial'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000c', true);
select lives_ok(
  $$select public.complete_trial_lesson(
    (select id from public.lessons limit 1), 1, 'Visible', 'Private',
    'Performance', 'Next', 'Homework', 'one_to_one', 'Assessment'
  )$$,
  'assigned Teacher can atomically complete a trial'
);

reset role;
select is((select status from public.lessons limit 1), 'completed'::public.lesson_status, 'trial lesson becomes completed');
select is(
  (select relationship_status from public.student_teacher_relationships limit 1),
  'awaiting_conversion'::public.student_teacher_relationship_status,
  'relationship advances from trial to awaiting_conversion'
);
select is((select count(*) from public.assessments), 1::bigint, 'Teacher trial assessment is created');
select is((select count(*) from public.lesson_records), 1::bigint, 'lesson record is created');

set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000a', true);
select is((select student_visible_notes from public.lesson_records limit 1), 'Visible', 'Student can read student-visible notes');
select throws_ok(
  $$select private_teacher_notes from public.lesson_records$$,
  '42501', null, 'Student cannot read private Teacher notes'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-00000000000c', true);
select lives_ok(
  $$select public.complete_trial_lesson(
    (select id from public.lessons limit 1), 1, 'Visible', 'Private',
    'Performance', 'Next', 'Homework', 'one_to_one', 'Assessment'
  )$$,
  'repeat trial completion is idempotent'
);

reset role;
select is(
  (select count(*) from public.lesson_records) + (select count(*) from public.assessments),
  2::bigint,
  'repeat completion does not duplicate record or assessment'
);
select hasnt_table('public', 'credit_ledger', 'trial completion does not create or consume credit');
select hasnt_table('public', 'teacher_earnings', 'trial completion does not create Teacher earnings');

select * from finish();
rollback;
