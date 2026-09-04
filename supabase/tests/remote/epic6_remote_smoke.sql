-- P2-4A Epic6 remote smoke payload.
--
-- This is intentionally one statement. All fixtures and domain mutations live
-- inside an exception-backed subtransaction. The success sentinel rolls that
-- subtransaction back before this statement can commit. A real failure also
-- aborts the statement. The wrapper performs an independent residue query.
--
-- Privileged INSERT/UPDATE statements below are limited to synthetic fixture
-- bootstrap and clock/source corruption needed by negative tests. Production
-- behavior is exercised only through public SECURITY DEFINER domain RPCs.
do $epic6_remote_smoke$
declare
  run_tag text := '__RUN_TAG__';
  current_case text := 'fixture-bootstrap';
  student_a uuid := gen_random_uuid();
  student_b uuid := gen_random_uuid();
  teacher_id uuid := gen_random_uuid();
  admin_id uuid := gen_random_uuid();
  relationship_a uuid := gen_random_uuid();
  relationship_b uuid := gen_random_uuid();
  product_fixed uuid := gen_random_uuid();
  ent_flex_a uuid := gen_random_uuid();
  ent_flex_b uuid := gen_random_uuid();
  ent_makeup uuid := gen_random_uuid();
  ent_revoke uuid := gen_random_uuid();
  ent_stale uuid := gen_random_uuid();
  ent_complete uuid := gen_random_uuid();
  booking_happy uuid;
  booking_cancel uuid;
  booking_makeup_origin uuid;
  booking_makeup uuid;
  booking_revoke uuid;
  booking_stale uuid;
  booking_complete uuid;
  series_80 uuid;
  series_fixed uuid;
  series_cycle uuid;
  series_timezone uuid;
  order_initial uuid;
  event_initial uuid;
  entitlement_initial uuid;
  cycle_initial uuid;
  fixed_booking uuid;
  renewal_id uuid;
  renewal_hold uuid;
  renewal_order uuid;
  renewal_event uuid;
  renewal_entitlement uuid;
  renewal_result jsonb;
  checkout_hold uuid;
  makeup_right uuid;
  renewed_cycle uuid;
  revoke_fixed_order uuid;
  revoke_fixed_event uuid;
  revoke_fixed_entitlement uuid;
  revoke_fixed_series uuid;
  revoke_fixed_cycle uuid;
  before_count bigint;
  after_count bigint;
  original_starts_at timestamptz;
  expected_utc timestamptz;
  error_context text;
begin
  begin
    -- Synthetic fixture bootstrap. Every identifier is unique to this run and
    -- the surrounding subtransaction guarantees no durable fixture state.
    insert into auth.users(id,email) values
      (student_a,run_tag||'-student-a@example.invalid'),
      (student_b,run_tag||'-student-b@example.invalid'),
      (teacher_id,run_tag||'-teacher@example.invalid'),
      (admin_id,run_tag||'-admin@example.invalid');

    insert into public.user_roles(user_id,role) values
      (student_a,'student'),(student_b,'student'),
      (teacher_id,'teacher'),(admin_id,'admin')
    on conflict do nothing;

    insert into public.teacher_profiles(
      user_id,public_slug,bio,teaching_status,is_public,teaching_modes,
      trial_price_twd,default_meeting_provider,default_meeting_url
    ) values(
      teacher_id,run_tag||'-teacher','Synthetic Epic6 remote smoke Teacher',
      'active',true,array['online']::public.teaching_mode[],500,
      'manual_google_meet','https://meet.google.com/epic-six-smoke'
    );

    insert into public.student_teacher_relationships(
      id,student_user_id,teacher_user_id,relationship_status,preferred_mode
    ) values
      (relationship_a,student_a,teacher_id,'active','online'),
      (relationship_b,student_b,teacher_id,'active','online');

    insert into public.teacher_scheduling_settings(
      teacher_user_id,timezone,minimum_booking_notice_minutes,
      booking_horizon_days,slot_interval_minutes
    ) values(teacher_id,'UTC',0,120,10);

    insert into public.teacher_availability_rules(
      teacher_user_id,weekday,local_start_time,local_end_time,timezone,
      effective_from,effective_until,is_active,created_by
    )
    select teacher_id,d::smallint,'00:00','23:59','UTC',current_date,
      current_date+120,true,teacher_id
    from generate_series(0,6) d;

    insert into public.products(
      id,product_type,status,public_slug,name,currency,base_price_amount,
      owner_type,is_public,is_purchasable,published_at
    ) values(
      product_fixed,'lesson_package','active',run_tag||'-fixed-one',
      run_tag||' Fixed 50','TWD',800,'platform',true,true,now()
    );
    insert into public.lesson_package_product_configs(
      product_id,lesson_count,validity_value,validity_unit,
      lesson_duration_minutes,booking_mode_eligibility
    ) values(product_fixed,1,12,'months',50,'fixed');

    insert into public.entitlements(
      id,beneficiary_user_id,teacher_scope_user_id,entitlement_type,status,
      starts_at,expires_at,product_name_snapshot,booking_mode_eligibility,
      lesson_duration_minutes
    ) values
      (ent_flex_a,student_a,teacher_id,'lesson_package','active',now()-interval '1 day',now()+interval '1 year',run_tag||' Flex A','both',50),
      (ent_flex_b,student_b,teacher_id,'lesson_package','active',now()-interval '1 day',now()+interval '1 year',run_tag||' Flex B','flexible',50),
      (ent_makeup,student_a,teacher_id,'lesson_package','active',now()-interval '1 day',now()+interval '1 year',run_tag||' Makeup Origin','flexible',50),
      (ent_revoke,student_a,teacher_id,'lesson_package','active',now()-interval '1 day',now()+interval '1 year',run_tag||' Revoke','flexible',50),
      (ent_stale,student_a,teacher_id,'lesson_package','active',now()-interval '1 day',now()+interval '1 year',run_tag||' Stale Reschedule','flexible',50),
      (ent_complete,student_a,teacher_id,'lesson_package','active',now()-interval '1 day',now()+interval '1 year',run_tag||' Stale Completion','flexible',50);

    insert into public.lesson_credit_ledger(
      entitlement_id,beneficiary_user_id,entry_type,available_delta,
      operation_key,reason_code
    ) values
      (ent_flex_a,student_a,'allocation',8,run_tag||'-flex-a-allocation','remote_smoke_fixture'),
      (ent_flex_b,student_b,'allocation',4,run_tag||'-flex-b-allocation','remote_smoke_fixture'),
      (ent_makeup,student_a,'allocation',1,run_tag||'-makeup-allocation','remote_smoke_fixture'),
      (ent_revoke,student_a,'allocation',1,run_tag||'-revoke-allocation','remote_smoke_fixture'),
      (ent_stale,student_a,'allocation',1,run_tag||'-stale-reschedule-allocation','remote_smoke_fixture'),
      (ent_complete,student_a,'allocation',1,run_tag||'-stale-completion-allocation','remote_smoke_fixture');

    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',admin_id::text,true);
    perform public.set_makeup_right_policy('teacher_cancellation',1209600,run_tag||' Makeup policy');
    perform public.set_fixed_checkout_hold_policy(product_fixed,600,run_tag||' Checkout Hold policy');
    perform public.set_fixed_renewal_policy(product_fixed,1,3600,600,0,run_tag||' Renewal policy');
    execute 'reset role';

    current_case := 'E6-RS-001';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',student_a::text,true);
    booking_happy := public.create_lesson_booking(
      student_a,teacher_id,relationship_a,ent_flex_a,
      (current_date+14)::timestamp+time '10:00','UTC',
      run_tag||'-happy-booking',run_tag||' happy booking'
    );
    perform public.reschedule_lesson_booking(
      booking_happy,(current_date+15)::timestamp+time '10:00','UTC',
      run_tag||' happy reschedule'
    );
    execute 'reset role';
    update public.lessons set starts_at=now()-interval '2 hours',ends_at=now()-interval '70 minutes'
      where id=(select lesson_id from public.bookings where id=booking_happy);
    update public.bookings set starts_at=now()-interval '2 hours',ends_at=now()-interval '70 minutes'
      where id=booking_happy;
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',teacher_id::text,true);
    perform public.complete_lesson_booking(booking_happy,'Smoke visible','','Smoke summary','Smoke goal','Smoke homework');
    execute 'reset role';
    if not exists(
      select 1 from public.bookings b
      join public.lessons l on l.id=b.lesson_id
      join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
      where b.id=booking_happy and b.status='completed' and l.status='completed'
        and r.status='consumed' and r.entitlement_id=ent_flex_a
    ) then raise exception 'E6-RS-001 flexible lifecycle incomplete'; end if;
    raise notice 'E6-RS-001 PASS';

    current_case := 'E6-RS-002';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',student_a::text,true);
    booking_cancel := public.create_lesson_booking(
      student_a,teacher_id,relationship_a,ent_flex_a,
      (current_date+14)::timestamp+time '12:00','UTC',
      run_tag||'-explicit-source',run_tag||' explicit source'
    );
    begin
      perform public.create_lesson_booking(
        student_a,teacher_id,relationship_a,ent_flex_b,
        (current_date+14)::timestamp+time '13:00','UTC',
        run_tag||'-wrong-source',run_tag||' wrong source'
      );
      raise exception using errcode='P6001',message='E6-RS-002 wrong entitlement source accepted';
    exception when sqlstate 'P0001' then
      if sqlerrm <> 'ENTITLEMENT_NOT_ELIGIBLE' then raise; end if;
    end;
    perform public.cancel_lesson_booking(booking_cancel,'released',run_tag||' ordinary cancellation');
    execute 'reset role';
    if not exists(
      select 1 from public.bookings b join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
      where b.id=booking_cancel and b.status='cancelled' and r.status='released' and r.entitlement_id=ent_flex_a
    ) then raise exception 'E6-RS-002 explicit source/cancellation state invalid'; end if;
    raise notice 'E6-RS-002 PASS';

    current_case := 'E6-RS-003';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',teacher_id::text,true);
    series_80 := public.create_recurring_lesson_series(
      student_a,teacher_id,relationship_a,null,
      extract(dow from current_date+16)::smallint,'09:00','UTC',80::smallint,
      current_date+16,current_date+16,run_tag||' duration mismatch series'
    );
    begin
      perform public.materialize_recurring_lesson_occurrence(
        series_80,current_date+16,ent_flex_a,run_tag||'-duration-mismatch'
      );
      raise exception using errcode='P6002',message='E6-RS-003 duration mismatch accepted';
    exception when sqlstate 'P0001' then
      if sqlerrm <> 'LESSON_DURATION_MISMATCH' then raise; end if;
    end;
    execute 'reset role';
    if exists(select 1 from public.bookings where recurring_series_id=series_80) then
      raise exception 'E6-RS-003 mismatch created a booking';
    end if;
    raise notice 'E6-RS-003 PASS';

    current_case := 'E6-RS-004';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',teacher_id::text,true);
    series_fixed := public.create_recurring_lesson_series(
      student_a,teacher_id,relationship_a,null,
      extract(dow from current_date+21)::smallint,'11:00','UTC',50::smallint,
      current_date+21,current_date+35,run_tag||' fixed priority series'
    );
    perform set_config('request.jwt.claim.sub',student_b::text,true);
    begin
      perform public.create_lesson_booking(
        student_b,teacher_id,relationship_b,ent_flex_b,
        (current_date+21)::timestamp+time '11:00','UTC',
        run_tag||'-priority-takeover',run_tag||' priority takeover'
      );
      raise exception using errcode='P6003',message='E6-RS-004 Fixed priority takeover accepted';
    exception when sqlstate 'P0001' then
      if sqlerrm <> 'SLOT_NOT_AVAILABLE' then raise; end if;
    end;
    execute 'reset role';
    if not exists(select 1 from public.recurring_lesson_series where id=series_fixed and status='active') then
      raise exception 'E6-RS-004 Fixed priority owner was not retained';
    end if;
    raise notice 'E6-RS-004 PASS';

    current_case := 'E6-RS-005';
    select count(*) into before_count from public.recurring_lesson_occurrences where series_id=series_fixed;
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',teacher_id::text,true);
    perform public.refresh_recurring_series_occurrences(series_fixed,current_date+35);
    perform public.refresh_recurring_series_occurrences(series_fixed,current_date+35);
    execute 'reset role';
    select count(*) into after_count from public.recurring_lesson_occurrences where series_id=series_fixed;
    if before_count <> after_count or after_count <> 3 then
      raise exception 'E6-RS-005 refresh not idempotent: before %, after %',before_count,after_count;
    end if;
    raise notice 'E6-RS-005 PASS';

    current_case := 'E6-RS-006';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',teacher_id::text,true);
    perform public.set_teacher_scheduling_settings(
      teacher_id,'America/New_York',0,120,10,run_tag||' timezone control'
    );
    series_timezone := public.create_recurring_lesson_series(
      student_a,teacher_id,relationship_a,null,
      extract(dow from current_date+22)::smallint,'07:00','America/New_York',50::smallint,
      current_date+22,current_date+22,run_tag||' timezone series'
    );
    perform public.refresh_recurring_series_occurrences(series_timezone,current_date+22);
    perform public.set_teacher_scheduling_settings(
      teacher_id,'UTC',0,120,10,run_tag||' restore UTC settings'
    );
    execute 'reset role';
    expected_utc := private.resolve_scheduling_local_datetime(current_date+22,'07:00','America/New_York');
    if not exists(
      select 1 from public.recurring_lesson_occurrences
      where series_id=series_timezone and occurrence_date=current_date+22 and starts_at=expected_utc
    ) then raise exception 'E6-RS-006 IANA local wall time resolved incorrectly'; end if;
    raise notice 'E6-RS-006 PASS';

    current_case := 'E6-RS-007';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',student_a::text,true);
    order_initial := public.create_checkout_order(
      run_tag||'-fixed-one',1,run_tag||'-initial-fixed-order'
    );
    perform set_config('request.jwt.claim.sub',admin_id::text,true);
    perform public.admin_confirm_cash_payment(order_initial,run_tag||'-initial-cash',run_tag||' initial fixed payment');
    execute 'reset role';
    select id into event_initial from public.order_fulfillment_events where order_id=order_initial;
    execute 'set local role service_role';
    perform set_config('request.jwt.claim.role','service_role',true);
    perform public.process_order_fulfillment_event(event_initial);
    execute 'reset role';
    select id into entitlement_initial from public.entitlements where source_order_id=order_initial;
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',teacher_id::text,true);
    series_cycle := public.create_recurring_lesson_series(
      student_a,teacher_id,relationship_a,entitlement_initial,
      extract(dow from current_date+31)::smallint,'09:00','UTC',50::smallint,
      current_date+31,current_date+31,run_tag||' cycle series'
    );
    execute 'reset role';
    execute 'set local role service_role';
    perform set_config('request.jwt.claim.role','service_role',true);
    cycle_initial := public.attach_fixed_entitlement_cycle(
      series_cycle,entitlement_initial,event_initial,run_tag||' initial cycle'
    );
    execute 'reset role';
    if not exists(
      select 1 from public.fixed_entitlement_cycles c
      join public.recurring_lesson_series s on s.id=c.series_id
      where c.id=cycle_initial and c.status='active'
        and c.entitlement_id=entitlement_initial and s.preferred_entitlement_id=entitlement_initial
    ) then raise exception 'E6-RS-007 cycle/preferred entitlement attachment invalid: %',(
      select jsonb_build_object(
        'cycle_status',c.status,'cycle_entitlement',c.entitlement_id,
        'preferred_entitlement',s.preferred_entitlement_id,'series_status',s.status
      ) from public.fixed_entitlement_cycles c
      join public.recurring_lesson_series s on s.id=c.series_id where c.id=cycle_initial
    ); end if;
    raise notice 'E6-RS-007 PASS';

    current_case := 'E6-RS-008';
    if not exists(select 1 from public.profiles where user_id=student_a and account_status='active')
      or not exists(select 1 from public.user_roles where user_id=student_a and role='student')
      or not exists(select 1 from public.user_roles where user_id=teacher_id and role='teacher')
      or not exists(select 1 from public.teacher_profiles where user_id=teacher_id and teaching_status='active')
      or not exists(select 1 from public.student_teacher_relationships where id=relationship_a and relationship_status='active') then
      raise exception 'E6-RS-008 fixture authority prerequisites missing';
    end if;
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',student_a::text,true);
    if auth.uid() is distinct from student_a or auth.role() is distinct from 'authenticated' then
      raise exception 'E6-RS-008 JWT context invalid: uid %, role %',auth.uid(),auth.role();
    end if;
    current_case := 'E6-RS-008-first-claim';
    begin
      checkout_hold := public.claim_fixed_checkout_hold(
        teacher_id,relationship_a,run_tag||'-fixed-one',
        extract(dow from current_date+30)::smallint,'15:00','UTC',
        current_date+30,current_date+30,run_tag||'-checkout-hold-a'
      );
    exception when others then
      get stacked diagnostics error_context = pg_exception_context;
      execute 'reset role';
      raise exception 'E6-RS-008 first claim % (%): %',sqlerrm,error_context,(
        select jsonb_build_object(
          'student_profile',exists(select 1 from public.profiles where user_id=student_a and account_status='active'),
          'student_role',exists(select 1 from public.user_roles where user_id=student_a and role='student'),
          'teacher_profile',exists(select 1 from public.teacher_profiles where user_id=teacher_id and teaching_status='active'),
          'teacher_role',exists(select 1 from public.user_roles where user_id=teacher_id and role='teacher'),
          'teacher_account',exists(select 1 from public.profiles where user_id=teacher_id and account_status='active'),
          'relationship',exists(select 1 from public.student_teacher_relationships where id=relationship_a and student_user_id=student_a and teacher_user_id=teacher_id and relationship_status='active'),
          'teacher_helper',private.teacher_owner_is_active(teacher_id),
          'relationship_helper',private.scheduling_relationship_is_active(relationship_a,student_a,teacher_id)
        )
      );
    end;
    perform set_config('request.jwt.claim.sub',student_b::text,true);
    current_case := 'E6-RS-008-conflicting-claim';
    begin
      perform public.claim_fixed_checkout_hold(
        teacher_id,relationship_b,run_tag||'-fixed-one',
        extract(dow from current_date+30)::smallint,'15:00','UTC',
        current_date+30,current_date+30,run_tag||'-checkout-hold-b'
      );
      raise exception using errcode='P6004',message='E6-RS-008 duplicate effective holder accepted';
    exception when sqlstate 'P0001' then
      if sqlerrm <> 'FIXED_SLOT_UNAVAILABLE' then raise; end if;
    end;
    execute 'reset role';
    current_case := 'E6-RS-008-holder-assertion';
    if (select count(*) from public.fixed_checkout_holds where status='active' and id=checkout_hold) <> 1 then
      raise exception 'E6-RS-008 effective holder count invalid';
    end if;
    execute 'set local role service_role';
    perform set_config('request.jwt.claim.role','service_role',true);
    current_case := 'E6-RS-008-release';
    perform public.release_fixed_checkout_hold(checkout_hold,run_tag||' hold cleanup');
    execute 'reset role';
    if exists(select 1 from public.fixed_checkout_holds where id=checkout_hold and status='active') then
      raise exception 'E6-RS-008 active hold remained after release';
    end if;
    raise notice 'E6-RS-008 PASS';

    current_case := 'E6-RS-009';
    execute 'set local role service_role';
    perform set_config('request.jwt.claim.role','service_role',true);
    renewal_id := public.open_fixed_cycle_renewal(cycle_initial,run_tag||' renewal open');
    execute 'reset role';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',teacher_id::text,true);
    fixed_booking := public.materialize_recurring_lesson_occurrence(
      series_cycle,current_date+31,entitlement_initial,run_tag||'-fixed-materialize'
    );
    execute 'reset role';
    update public.lessons set starts_at=now()-interval '2 hours',ends_at=now()-interval '70 minutes'
      where id=(select lesson_id from public.bookings where id=fixed_booking);
    update public.bookings set starts_at=now()-interval '2 hours',ends_at=now()-interval '70 minutes'
      where id=fixed_booking;
    update public.recurring_lesson_occurrences set starts_at=now()-interval '2 hours',ends_at=now()-interval '70 minutes'
      where booking_id=fixed_booking;
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',teacher_id::text,true);
    perform public.complete_lesson_booking(fixed_booking,'Fixed complete','','','','');
    perform public.complete_fixed_entitlement_cycle(cycle_initial,run_tag||' cycle complete');
    perform set_config('request.jwt.claim.sub',student_a::text,true);
    perform public.set_fixed_renewal_intent(renewal_id,'will_renew',run_tag||' will renew');
    renewal_hold := public.claim_fixed_renewal_hold(
      renewal_id,run_tag||'-fixed-one',run_tag||'-renewal-hold'
    );
    execute 'reset role';
    select order_id into renewal_order from public.fixed_renewal_holds where id=renewal_hold;
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',admin_id::text,true);
    perform public.admin_confirm_cash_payment(renewal_order,run_tag||'-renewal-cash',run_tag||' renewal payment');
    execute 'reset role';
    select id into renewal_event from public.order_fulfillment_events where order_id=renewal_order;
    execute 'set local role service_role';
    perform set_config('request.jwt.claim.role','service_role',true);
    perform public.process_order_fulfillment_event(renewal_event);
    execute 'reset role';
    select id into renewal_entitlement from public.entitlements where source_order_id=renewal_order;
    execute 'set local role service_role';
    perform set_config('request.jwt.claim.role','service_role',true);
    renewal_result := public.convert_fixed_renewal(
      renewal_id,renewal_hold,renewal_entitlement,renewal_event,run_tag||' renewal conversion'
    );
    execute 'reset role';
    if renewal_result->>'status' <> 'renewed'
      or (select count(*) from public.fixed_entitlement_cycles where series_id=series_cycle) <> 2
      or not exists(select 1 from public.recurring_lesson_series where id=series_cycle and preferred_entitlement_id=entitlement_initial and status='active') then
      raise exception 'E6-RS-009 renewal did not produce one next cycle while retaining priority: result %, state %',renewal_result,(
        select jsonb_build_object(
          'cycle_count',(select count(*) from public.fixed_entitlement_cycles where series_id=series_cycle),
          'preferred_entitlement',s.preferred_entitlement_id,
          'series_status',s.status,
          'renewal_entitlement',renewal_entitlement
        ) from public.recurring_lesson_series s where s.id=series_cycle
      );
    end if;
    raise notice 'E6-RS-009 PASS';

    current_case := 'E6-RS-010';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',student_a::text,true);
    booking_makeup_origin := public.create_lesson_booking(
      student_a,teacher_id,relationship_a,ent_makeup,
      (current_date+24)::timestamp+time '10:00','UTC',
      run_tag||'-makeup-origin',run_tag||' makeup origin'
    );
    perform set_config('request.jwt.claim.sub',teacher_id::text,true);
    perform public.cancel_lesson_booking(booking_makeup_origin,'unchanged',run_tag||' teacher cancellation');
    perform public.cancel_lesson_booking(booking_makeup_origin,'unchanged',run_tag||' teacher cancellation retry');
    execute 'reset role';
    select id into makeup_right from public.makeup_rights
      where origin_lesson_id=(select lesson_id from public.bookings where id=booking_makeup_origin);
    if makeup_right is null
      or (select count(*) from public.makeup_rights where origin_lesson_id=(select lesson_id from public.bookings where id=booking_makeup_origin)) <> 1
      or not exists(select 1 from public.lesson_credit_reservations where booking_id=booking_makeup_origin and status='released') then
      raise exception 'E6-RS-010 compensation was not exactly one Makeup Right';
    end if;
    raise notice 'E6-RS-010 PASS';

    current_case := 'E6-RS-011';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',student_a::text,true);
    booking_makeup := public.create_makeup_lesson_booking(
      makeup_right,student_a,teacher_id,relationship_a,
      (current_date+12)::timestamp+time '18:00','UTC',
      run_tag||'-makeup-booking',run_tag||' makeup booking'
    );
    execute 'reset role';
    if not exists(
      select 1 from public.bookings b join public.makeup_rights m on m.id=b.makeup_right_id
      where b.id=booking_makeup and b.source='makeup' and b.credit_reservation_id is null
        and m.id=makeup_right and m.status='reserved'
    ) then raise exception 'E6-RS-011 Makeup booking used the wrong value source'; end if;
    raise notice 'E6-RS-011 PASS';

    current_case := 'E6-RS-012';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',student_a::text,true);
    perform public.cancel_lesson_booking(booking_makeup,'released',run_tag||' Makeup timely cancellation');
    booking_makeup := public.create_makeup_lesson_booking(
      makeup_right,student_a,teacher_id,relationship_a,
      (current_date+13)::timestamp+time '18:00','UTC',
      run_tag||'-makeup-rebook',run_tag||' Makeup rebook'
    );
    perform set_config('request.jwt.claim.sub',teacher_id::text,true);
    perform public.cancel_lesson_booking(booking_makeup,'released',run_tag||' Teacher cancels Makeup','teacher_caused');
    execute 'reset role';
    if not exists(select 1 from public.makeup_rights where id=makeup_right and status='available')
      or (select count(*) from public.makeup_rights where origin_lesson_id=(select lesson_id from public.bookings where id=booking_makeup_origin)) <> 1 then
      raise exception 'E6-RS-012 cancellation failed to restore the same Right';
    end if;
    raise notice 'E6-RS-012 PASS';

    current_case := 'E6-RS-013';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',student_a::text,true);
    booking_revoke := public.create_lesson_booking(
      student_a,teacher_id,relationship_a,ent_revoke,
      (current_date+27)::timestamp+time '10:00','UTC',
      run_tag||'-revoke-booking',run_tag||' revoke booking'
    );
    perform set_config('request.jwt.claim.sub',admin_id::text,true);
    perform public.admin_revoke_entitlement(ent_revoke,run_tag||' revoke reconciliation',run_tag||'-revoke-operation');
    execute 'reset role';
    if not exists(
      select 1 from public.bookings b join public.lessons l on l.id=b.lesson_id
      join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
      join public.entitlements e on e.id=r.entitlement_id
      where b.id=booking_revoke and e.status='revoked' and r.status='released'
        and b.status='cancelled' and l.status='admin_cancelled'
    ) then raise exception 'E6-RS-013 revoke left an orphan booking state'; end if;
    raise notice 'E6-RS-013 PASS';

    current_case := 'E6-RS-014';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',student_a::text,true);
    revoke_fixed_order := public.create_checkout_order(
      run_tag||'-fixed-one',1,run_tag||'-revoke-fixed-order'
    );
    perform set_config('request.jwt.claim.sub',admin_id::text,true);
    perform public.admin_confirm_cash_payment(
      revoke_fixed_order,run_tag||'-revoke-fixed-cash',run_tag||' revoke fixed payment'
    );
    execute 'reset role';
    select id into revoke_fixed_event from public.order_fulfillment_events where order_id=revoke_fixed_order;
    execute 'set local role service_role';
    perform set_config('request.jwt.claim.role','service_role',true);
    perform public.process_order_fulfillment_event(revoke_fixed_event);
    execute 'reset role';
    select id into revoke_fixed_entitlement from public.entitlements where source_order_id=revoke_fixed_order;
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',teacher_id::text,true);
    revoke_fixed_series := public.create_recurring_lesson_series(
      student_a,teacher_id,relationship_a,revoke_fixed_entitlement,
      extract(dow from current_date+32)::smallint,'16:00','UTC',50::smallint,
      current_date+32,current_date+32,run_tag||' revoke fixed series'
    );
    execute 'reset role';
    execute 'set local role service_role';
    perform set_config('request.jwt.claim.role','service_role',true);
    revoke_fixed_cycle := public.attach_fixed_entitlement_cycle(
      revoke_fixed_series,revoke_fixed_entitlement,revoke_fixed_event,run_tag||' revoke fixed cycle'
    );
    execute 'reset role';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',admin_id::text,true);
    perform public.admin_revoke_entitlement(
      revoke_fixed_entitlement,run_tag||' fixed revoke reconciliation',run_tag||'-fixed-revoke-operation'
    );
    execute 'reset role';
    if not exists(select 1 from public.fixed_entitlement_cycles where id=revoke_fixed_cycle and status='invalidated')
      or not exists(select 1 from public.recurring_lesson_series where id=revoke_fixed_series and status='active' and preferred_entitlement_id is null) then
      raise exception 'E6-RS-014 revoke did not invalidate cycle while retaining Series priority';
    end if;
    raise notice 'E6-RS-014 PASS';

    current_case := 'E6-RS-015';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',student_a::text,true);
    booking_stale := public.create_lesson_booking(
      student_a,teacher_id,relationship_a,ent_stale,
      (current_date+28)::timestamp+time '10:00','UTC',
      run_tag||'-stale-reschedule',run_tag||' stale reschedule'
    );
    execute 'reset role';
    select starts_at into original_starts_at from public.bookings where id=booking_stale;
    -- Deliberately construct an impossible stale source to prove defense in depth.
    update public.entitlements set status='revoked',revoked_at=now(),revoked_by=admin_id,
      revoked_reason=run_tag||' stale source fixture',updated_at=now() where id=ent_stale;
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',student_a::text,true);
    begin
      perform public.reschedule_lesson_booking(
        booking_stale,(current_date+29)::timestamp+time '12:00','UTC',run_tag||' rejected stale reschedule'
      );
      raise exception using errcode='P6005',message='E6-RS-015 stale source rescheduled';
    exception when sqlstate 'P0001' then
      if sqlerrm <> 'ENTITLEMENT_NOT_ACTIVE' then raise; end if;
    end;
    execute 'reset role';
    if not exists(select 1 from public.bookings where id=booking_stale and starts_at=original_starts_at and status='confirmed') then
      raise exception 'E6-RS-015 rejected reschedule mutated the Booking';
    end if;
    raise notice 'E6-RS-015 PASS';

    current_case := 'E6-RS-016';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',student_a::text,true);
    booking_complete := public.create_lesson_booking(
      student_a,teacher_id,relationship_a,ent_complete,
      (current_date+29)::timestamp+time '14:00','UTC',
      run_tag||'-stale-completion',run_tag||' stale completion'
    );
    execute 'reset role';
    update public.lessons set starts_at=now()-interval '2 hours',ends_at=now()-interval '70 minutes'
      where id=(select lesson_id from public.bookings where id=booking_complete);
    update public.bookings set starts_at=now()-interval '2 hours',ends_at=now()-interval '70 minutes'
      where id=booking_complete;
    update public.lesson_credit_reservations set status='released',released_at=now(),updated_at=now()
      where booking_id=booking_complete;
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.role','authenticated',true);
    perform set_config('request.jwt.claim.sub',teacher_id::text,true);
    begin
      perform public.complete_lesson_booking(booking_complete,'Should fail','','','','');
      raise exception using errcode='P6006',message='E6-RS-016 released source completed';
    exception when sqlstate 'P0001' then
      if sqlerrm <> 'CREDIT_ALREADY_RELEASED' then raise; end if;
    end;
    execute 'reset role';
    if not exists(
      select 1 from public.bookings b join public.lessons l on l.id=b.lesson_id
      where b.id=booking_complete and b.status='confirmed' and l.status='scheduled'
        and not exists(select 1 from public.lesson_records where lesson_id=l.id)
    ) then raise exception 'E6-RS-016 rejected completion created partial state'; end if;
    raise notice 'E6-RS-016 PASS';

    -- Force rollback of every synthetic row, including immutable evidence.
    raise exception using errcode='P6000',message=
      'EPIC6_REMOTE_SMOKE_ROLLBACK E6-RS-001 PASS E6-RS-002 PASS E6-RS-003 PASS E6-RS-004 PASS E6-RS-005 PASS E6-RS-006 PASS E6-RS-007 PASS E6-RS-008 PASS E6-RS-009 PASS E6-RS-010 PASS E6-RS-011 PASS E6-RS-012 PASS E6-RS-013 PASS E6-RS-014 PASS E6-RS-015 PASS E6-RS-016 PASS';
  exception
    when sqlstate 'P6000' then
      raise;
    when others then
      execute 'reset role';
      raise exception using
        errcode=sqlstate,
        message=current_case||': '||sqlerrm,
        detail='Epic6 smoke subtransaction was rolled back; run the independent residue query.';
  end;
end
$epic6_remote_smoke$;
