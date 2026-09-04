begin;

select plan(29);

create temp table lock_secdef_functions on commit drop as
select
  procedure.oid,
  namespace.nspname || '.' || procedure.proname as function_name,
  pg_catalog.pg_get_function_identity_arguments(procedure.oid) as arguments,
  procedure.prosrc
from pg_catalog.pg_proc as procedure
join pg_catalog.pg_namespace as namespace on namespace.oid=procedure.pronamespace
where namespace.nspname in ('public','private')
  and procedure.prokind='f'
  and procedure.prosecdef;

create temp table lock_discovered_mutators on commit drop as
with recursive
direct_mutator(oid) as (
  select oid
  from lock_secdef_functions
  where prosrc ~* '(insert[[:space:]]+into|update[[:space:]]+(public[.]|auth[.]|[a-z_]+[[:space:]]+set)|delete[[:space:]]+from|execute[[:space:]]+format)'
),
function_call(caller_oid,callee_oid) as (
  select caller.oid,callee.oid
  from lock_secdef_functions as caller
  join lock_secdef_functions as callee on caller.oid<>callee.oid
  where caller.prosrc ~* (
    replace(callee.function_name,'.','[.]') || '[[:space:]]*[(]'
  )
),
mutation_closure(oid) as (
  select oid from direct_mutator
  union
  select function_call.caller_oid
  from function_call
  join mutation_closure on mutation_closure.oid=function_call.callee_oid
)
select function_name,arguments
from lock_secdef_functions
where oid in (select oid from mutation_closure);

create temp table lock_function_inventory(
  function_name text primary key,
  expected_overloads integer not null default 1,
  domain text not null,
  classification text not null check(classification in ('managed','exempt')),
  direct_resources text[] not null default '{}',
  advisory_locks text[] not null default '{}',
  row_locks text[] not null default '{}',
  nested_calls text[] not null default '{}',
  inherited_lock_assumptions text not null,
  expected_order text not null,
  exemption_reason text
) on commit drop;

with inventory(function_name) as (
  select unnest(array[
    'private.attach_fixed_entitlement_cycle_core',
    'private.attach_fixed_entitlement_cycle_without_renewal_core',
    'private.bind_lesson_credit_reservation_booking_core',
    'private.cancel_makeup_lesson_booking_core',
    'private.cancel_ordinary_lesson_booking_authority',
    'private.claim_entitlement_revoke_operation',
    'private.complete_entitlement_revoke_operation',
    'private.complete_makeup_lesson_booking_core',
    'private.complete_ordinary_lesson_booking_authority',
    'private.confirm_payment_locked',
    'private.consume_lesson_credit_core',
    'private.convert_lesson_credit_reservation_to_makeup_core',
    'private.create_makeup_right_core',
    'private.ensure_recurring_occurrences',
    'private.expire_unbound_makeup_right_authority',
    'private.fixed_cycle_completion_renewal',
    'private.fulfill_order_paid_event',
    'private.handle_new_auth_user',
    'private.link_attached_cycle_bookings',
    'private.link_booking_fixed_cycle',
    'private.reconcile_bookings_on_entitlement_revoke',
    'private.reconcile_fixed_cycles_on_entitlement_revoke',
    'private.record_makeup_booking_operation',
    'private.record_makeup_right_operation',
    'private.release_fixed_renewal_locked',
    'private.release_lesson_credit_core',
    'private.reschedule_makeup_lesson_booking_core',
    'private.reschedule_ordinary_lesson_booking_authority',
    'private.reserve_lesson_credit_core',
    'private.restore_unbound_makeup_right_authority',
    'private.revoke_unbound_makeup_right_authority',
    'private.snapshot_order_item_fulfillment',
    'private.sync_product_public_catalog_row',
    'private.sync_product_public_catalog_trigger',
    'private.sync_teacher_products_trigger',
    'private.sync_teacher_public_profile',
    'private.sync_teacher_public_profile_from_account',
    'private.sync_teacher_public_profile_trigger',
    'public.admin_adjust_lesson_credits',
    'public.admin_cancel_order',
    'public.admin_cancel_trial_lesson',
    'public.admin_confirm_cash_payment',
    'public.admin_confirm_payment',
    'public.admin_expire_order',
    'public.admin_reject_payment_submission',
    'public.admin_reschedule_trial_lesson',
    'public.admin_retry_order_fulfillment_event',
    'public.admin_revoke_entitlement',
    'public.admin_set_lesson_package_product_config',
    'public.admin_set_product_status',
    'public.archive_own_product',
    'public.attach_fixed_entitlement_cycle',
    'public.cancel_lesson_booking',
    'public.cancel_own_order',
    'public.claim_fixed_checkout_hold',
    'public.claim_fixed_renewal_hold',
    'public.complete_fixed_entitlement_cycle',
    'public.complete_lesson_booking',
    'public.complete_trial_lesson',
    'public.confirm_trial_payment',
    'public.consume_lesson_credit',
    'public.consume_makeup_right',
    'public.convert_fixed_checkout_hold',
    'public.convert_fixed_renewal',
    'public.create_checkout_order',
    'public.create_lesson_booking',
    'public.create_makeup_lesson_booking',
    'public.create_own_draft_product',
    'public.create_recurring_lesson_series',
    'public.create_teacher_availability_exception',
    'public.create_teacher_availability_rule',
    'public.expire_makeup_right',
    'public.extend_lesson_package_entitlement',
    'public.materialize_recurring_lesson_occurrence',
    'public.open_fixed_cycle_renewal',
    'public.process_order_fulfillment_event',
    'public.refresh_recurring_series_occurrences',
    'public.release_expired_fixed_renewal',
    'public.release_fixed_checkout_hold',
    'public.release_fixed_renewal_hold',
    'public.release_lesson_credit',
    'public.request_own_product_publication',
    'public.request_trial_checkout',
    'public.reschedule_lesson_booking',
    'public.reserve_lesson_credit',
    'public.reserve_makeup_right',
    'public.restore_makeup_right',
    'public.revoke_makeup_right',
    'public.set_fixed_checkout_hold_policy',
    'public.set_fixed_renewal_intent',
    'public.set_fixed_renewal_policy',
    'public.set_makeup_right_policy',
    'public.set_recurring_lesson_series_exception',
    'public.set_recurring_lesson_series_status',
    'public.set_recurring_lesson_series_status_without_renewal',
    'public.set_teacher_scheduling_settings',
    'public.submit_bank_transfer',
    'public.update_own_draft_product',
    'public.update_own_teacher_meeting_defaults',
    'public.update_own_teacher_profile'
  ]::text[])
),
classified as (
  select
    function_name,
    case
      when function_name ~ '(payment|order|checkout)' then 'Commerce'
      when function_name ~ 'fulfill|snapshot_order_item' then 'Fulfillment'
      when function_name ~ 'revoke_entitlement|entitlement_revoke|reconcile_' then 'Entitlement Revoke'
      when function_name ~ 'makeup' then 'Makeup'
      when function_name ~ 'renewal' then 'Fixed Renewal'
      when function_name ~ 'fixed_entitlement_cycle|fixed_cycle' then 'Fixed Cycle'
      when function_name ~ 'lesson_credit|entitlement' then 'Lesson Credit'
      when function_name ~ '(booking|recurring|availability|scheduling)' then 'Scheduling'
      when function_name ~ 'trial' then 'Trial'
      else 'Identity / Catalog'
    end as domain,
    function_name=any(array[
      'private.handle_new_auth_user',
      'private.record_makeup_booking_operation',
      'private.record_makeup_right_operation',
      'private.snapshot_order_item_fulfillment',
      'private.sync_product_public_catalog_row',
      'private.sync_product_public_catalog_trigger',
      'private.sync_teacher_products_trigger',
      'private.sync_teacher_public_profile',
      'private.sync_teacher_public_profile_from_account',
      'private.sync_teacher_public_profile_trigger',
      'public.admin_set_lesson_package_product_config',
      'public.admin_set_product_status',
      'public.archive_own_product',
      'public.create_own_draft_product',
      'public.request_own_product_publication',
      'public.set_fixed_checkout_hold_policy',
      'public.set_fixed_renewal_policy',
      'public.set_makeup_right_policy',
      'public.update_own_draft_product',
      'public.update_own_teacher_meeting_defaults',
      'public.update_own_teacher_profile'
    ]::text[]) as exempt
  from inventory
)
insert into lock_function_inventory(
  function_name,domain,classification,inherited_lock_assumptions,
  expected_order,exemption_reason
)
select
  function_name,domain,
  case when exempt then 'exempt' else 'managed' end,
  case when exempt
    then 'No cross-domain row-lock chain; trigger/sink inherits its caller transaction.'
    else 'Caller-held locks are declared by the nested call contract when applicable.'
  end,
  case when exempt
    then 'NO_CROSS_DOMAIN_LOCK_EDGE'
    else 'MANAGED_BY_BRANCH_DAG_OR_REGISTERED_NESTED_CALL'
  end,
  case when exempt
    then 'Single-aggregate/catalog mutation or append-only projection/audit sink; it does not acquire a second domain lock resource.'
  end
from classified;

create temp table lock_critical_contract(
  function_name text primary key references lock_function_inventory(function_name),
  direct_resources text[] not null,
  advisory_locks text[] not null,
  row_locks text[] not null,
  nested_calls text[] not null,
  inherited_lock_assumptions text not null,
  expected_order text not null
) on commit drop;

insert into lock_critical_contract values
  ('private.confirm_payment_locked',array['ORDER','PAYMENT'],array[]::text[],array['ORDER','PAYMENT'],array[]::text[],'Public confirmation wrapper holds no domain row lock.','ORDER -> PAYMENT -> AUDIT/OUTBOX'),
  ('private.fulfill_order_paid_event',array['FULFILLMENT_EVENT','ORDER','ENTITLEMENT','LEDGER'],array[]::text[],array['FULFILLMENT_EVENT','ORDER'],array[]::text[],'Entrypoint holds no row lock; retries converge on the event.','FULFILLMENT_EVENT -> ORDER -> ENTITLEMENT -> LEDGER'),
  ('public.create_lesson_booking',array['REQUEST_IDEMPOTENCY','PARTICIPANT_SCHEDULE','ENTITLEMENT','RESERVATION','BOOKING','LESSON'],array['REQUEST_IDEMPOTENCY','PARTICIPANT_SCHEDULE'],array['ENTITLEMENT'],array['private.reserve_lesson_credit_core','private.bind_lesson_credit_reservation_booking_core'],'No inherited domain lock.','REQUEST_IDEMPOTENCY -> PARTICIPANT_SCHEDULE -> ENTITLEMENT -> RESERVATION -> BOOKING/LESSON'),
  ('public.materialize_recurring_lesson_occurrence',array['PARTICIPANT_SCHEDULE','ENTITLEMENT','FIXED_SERIES','OCCURRENCE','RESERVATION','BOOKING','LESSON'],array['PARTICIPANT_SCHEDULE'],array['ENTITLEMENT','FIXED_SERIES','OCCURRENCE'],array['private.reserve_lesson_credit_core','private.bind_lesson_credit_reservation_booking_core'],'No inherited domain lock.','PARTICIPANT_SCHEDULE -> ENTITLEMENT -> FIXED_SERIES -> OCCURRENCE -> RESERVATION -> BOOKING/LESSON'),
  ('private.attach_fixed_entitlement_cycle_without_renewal_core',array['PARTICIPANT_SCHEDULE','FULFILLMENT_EVENT','ORDER','ENTITLEMENT','FIXED_SERIES'],array['PARTICIPANT_SCHEDULE'],array['FULFILLMENT_EVENT','ORDER','ENTITLEMENT','FIXED_SERIES'],array[]::text[],'Caller may already hold schedule locks; advisory acquisition is transaction-reentrant.','PARTICIPANT_SCHEDULE -> FULFILLMENT_EVENT -> ORDER -> ENTITLEMENT -> FIXED_SERIES'),
  ('public.convert_fixed_checkout_hold',array['PARTICIPANT_SCHEDULE','CHECKOUT_HOLD','FULFILLMENT_EVENT','ORDER','ENTITLEMENT','FIXED_SERIES'],array['PARTICIPANT_SCHEDULE'],array['CHECKOUT_HOLD','FULFILLMENT_EVENT','ORDER','ENTITLEMENT'],array['private.attach_fixed_entitlement_cycle_core'],'No inherited domain lock.','PARTICIPANT_SCHEDULE -> CHECKOUT_HOLD -> FULFILLMENT_EVENT -> ORDER -> ENTITLEMENT -> FIXED_SERIES'),
  ('public.convert_fixed_renewal',array['PARTICIPANT_SCHEDULE','FIXED_RENEWAL','RENEWAL_HOLD','FULFILLMENT_EVENT','ORDER','ENTITLEMENT','FIXED_SERIES'],array['PARTICIPANT_SCHEDULE'],array['FIXED_RENEWAL','RENEWAL_HOLD'],array['private.attach_fixed_entitlement_cycle_without_renewal_core'],'No inherited domain lock.','PARTICIPANT_SCHEDULE -> FIXED_RENEWAL -> RENEWAL_HOLD -> FULFILLMENT_EVENT -> ORDER -> ENTITLEMENT -> FIXED_SERIES'),
  ('public.create_makeup_lesson_booking',array['REQUEST_IDEMPOTENCY','MAKEUP_RIGHT','PARTICIPANT_SCHEDULE','BOOKING','LESSON'],array['REQUEST_IDEMPOTENCY','PARTICIPANT_SCHEDULE'],array['MAKEUP_RIGHT'],array['private.record_makeup_booking_operation'],'No inherited domain lock.','REQUEST_IDEMPOTENCY -> MAKEUP_RIGHT -> PARTICIPANT_SCHEDULE -> BOOKING/LESSON'),
  ('private.cancel_makeup_lesson_booking_core',array['MAKEUP_RIGHT','PARTICIPANT_SCHEDULE','BOOKING','LESSON'],array['PARTICIPANT_SCHEDULE'],array['MAKEUP_RIGHT','BOOKING','LESSON'],array['private.record_makeup_booking_operation'],'Wrapper holds no domain row lock.','MAKEUP_RIGHT -> PARTICIPANT_SCHEDULE -> BOOKING -> LESSON'),
  ('private.cancel_ordinary_lesson_booking_authority',array['PARTICIPANT_SCHEDULE','ENTITLEMENT','RESERVATION','BOOKING','OCCURRENCE','LESSON'],array['PARTICIPANT_SCHEDULE'],array['ENTITLEMENT','RESERVATION','BOOKING','OCCURRENCE','LESSON'],array['private.release_lesson_credit_core','private.consume_lesson_credit_core','private.convert_lesson_credit_reservation_to_makeup_core'],'Wrapper holds no domain row lock.','PARTICIPANT_SCHEDULE -> ENTITLEMENT -> RESERVATION -> BOOKING -> OCCURRENCE -> LESSON'),
  ('private.reschedule_makeup_lesson_booking_core',array['MAKEUP_RIGHT','PARTICIPANT_SCHEDULE','BOOKING','LESSON'],array['PARTICIPANT_SCHEDULE'],array['MAKEUP_RIGHT','BOOKING','LESSON'],array[]::text[],'Wrapper holds no domain row lock.','MAKEUP_RIGHT -> PARTICIPANT_SCHEDULE -> BOOKING -> LESSON'),
  ('private.reschedule_ordinary_lesson_booking_authority',array['PARTICIPANT_SCHEDULE','ENTITLEMENT','RESERVATION','BOOKING','OCCURRENCE','LESSON'],array['PARTICIPANT_SCHEDULE'],array['ENTITLEMENT','RESERVATION','BOOKING','OCCURRENCE','LESSON'],array[]::text[],'Wrapper holds no domain row lock.','PARTICIPANT_SCHEDULE -> ENTITLEMENT -> RESERVATION -> BOOKING -> OCCURRENCE -> LESSON'),
  ('private.complete_makeup_lesson_booking_core',array['MAKEUP_RIGHT','PARTICIPANT_SCHEDULE','BOOKING','LESSON'],array['PARTICIPANT_SCHEDULE'],array['MAKEUP_RIGHT','BOOKING','LESSON'],array['private.record_makeup_booking_operation'],'Wrapper holds no domain row lock.','MAKEUP_RIGHT -> PARTICIPANT_SCHEDULE -> BOOKING -> LESSON'),
  ('private.complete_ordinary_lesson_booking_authority',array['PARTICIPANT_SCHEDULE','ENTITLEMENT','RESERVATION','BOOKING','OCCURRENCE','LESSON'],array['PARTICIPANT_SCHEDULE'],array['ENTITLEMENT','RESERVATION','BOOKING','OCCURRENCE','LESSON'],array['private.consume_lesson_credit_core'],'Wrapper holds no domain row lock.','PARTICIPANT_SCHEDULE -> ENTITLEMENT -> RESERVATION -> BOOKING -> OCCURRENCE -> LESSON'),
  ('public.admin_revoke_entitlement',array['ENTITLEMENT','REVOKE_OPERATION','FIXED_CYCLE','FIXED_SERIES','RESERVATION','BOOKING','LESSON'],array[]::text[],array['ENTITLEMENT'],array['private.claim_entitlement_revoke_operation','private.reconcile_fixed_cycles_on_entitlement_revoke','private.reconcile_bookings_on_entitlement_revoke','private.complete_entitlement_revoke_operation'],'No schedule lock is inherited or acquired: this path never waits for PARTICIPANT_SCHEDULE.','ENTITLEMENT -> REVOKE_OPERATION -> FIXED_CYCLE -> FIXED_SERIES -> RESERVATION -> BOOKING -> LESSON');

update lock_function_inventory as inventory
set direct_resources=critical.direct_resources,
    advisory_locks=critical.advisory_locks,
    row_locks=critical.row_locks,
    nested_calls=critical.nested_calls,
    inherited_lock_assumptions=critical.inherited_lock_assumptions,
    expected_order=critical.expected_order
from lock_critical_contract as critical
where critical.function_name=inventory.function_name;

create temp table lock_nested_call(
  caller text not null references lock_function_inventory(function_name),
  callee text not null references lock_function_inventory(function_name),
  caller_held_locks text[] not null,
  callee_acquired_locks text[] not null,
  reverse_edge_assessment text not null,
  primary key(caller,callee)
) on commit drop;

insert into lock_nested_call values
  ('public.admin_confirm_payment','private.confirm_payment_locked',array[]::text[],array['ORDER','PAYMENT'],'No reverse edge: the wrapper owns no row lock.'),
  ('public.admin_confirm_cash_payment','private.confirm_payment_locked',array[]::text[],array['ORDER','PAYMENT'],'No reverse edge: the wrapper owns no row lock.'),
  ('public.process_order_fulfillment_event','private.fulfill_order_paid_event',array[]::text[],array['FULFILLMENT_EVENT','ORDER'],'No reverse edge: the wrapper owns no row lock.'),
  ('public.admin_retry_order_fulfillment_event','private.fulfill_order_paid_event',array[]::text[],array['FULFILLMENT_EVENT','ORDER'],'No reverse edge: retry metadata is written after fulfillment.'),
  ('public.attach_fixed_entitlement_cycle','private.attach_fixed_entitlement_cycle_core',array[]::text[],array['PARTICIPANT_SCHEDULE','FULFILLMENT_EVENT','ORDER','ENTITLEMENT','FIXED_SERIES'],'No reverse edge: public wrapper owns no row lock.'),
  ('private.attach_fixed_entitlement_cycle_core','private.attach_fixed_entitlement_cycle_without_renewal_core',array['PARTICIPANT_SCHEDULE'],array['FULFILLMENT_EVENT','ORDER','ENTITLEMENT','FIXED_SERIES'],'Schedule advisory reacquisition is transaction-reentrant.'),
  ('public.convert_fixed_checkout_hold','private.attach_fixed_entitlement_cycle_core',array['PARTICIPANT_SCHEDULE','CHECKOUT_HOLD','FULFILLMENT_EVENT','ORDER','ENTITLEMENT'],array['PARTICIPANT_SCHEDULE','FULFILLMENT_EVENT','ORDER','ENTITLEMENT','FIXED_SERIES'],'Nested locks are reentrant or later in the same branch.'),
  ('public.convert_fixed_renewal','private.attach_fixed_entitlement_cycle_without_renewal_core',array['PARTICIPANT_SCHEDULE','FIXED_RENEWAL','RENEWAL_HOLD'],array['PARTICIPANT_SCHEDULE','FULFILLMENT_EVENT','ORDER','ENTITLEMENT','FIXED_SERIES'],'Fulfillment never acquires schedule/renewal locks, so event contention has no return edge.'),
  ('public.create_lesson_booking','private.reserve_lesson_credit_core',array['PARTICIPANT_SCHEDULE','ENTITLEMENT'],array['ENTITLEMENT','RESERVATION'],'Entitlement reacquisition is row-lock reentrant.'),
  ('public.materialize_recurring_lesson_occurrence','private.reserve_lesson_credit_core',array['PARTICIPANT_SCHEDULE','ENTITLEMENT','FIXED_SERIES','OCCURRENCE'],array['ENTITLEMENT','RESERVATION'],'Entitlement reacquisition is row-lock reentrant.'),
  ('public.cancel_lesson_booking','private.cancel_ordinary_lesson_booking_authority',array[]::text[],array['PARTICIPANT_SCHEDULE','ENTITLEMENT','RESERVATION','BOOKING','OCCURRENCE','LESSON'],'Dispatch wrapper reads source without retaining a row lock.'),
  ('public.cancel_lesson_booking','private.cancel_makeup_lesson_booking_core',array[]::text[],array['MAKEUP_RIGHT','PARTICIPANT_SCHEDULE','BOOKING','LESSON'],'Dispatch wrapper reads source without retaining a row lock.'),
  ('private.cancel_ordinary_lesson_booking_authority','private.convert_lesson_credit_reservation_to_makeup_core',array['PARTICIPANT_SCHEDULE','ENTITLEMENT','RESERVATION','BOOKING','OCCURRENCE','LESSON'],array['ENTITLEMENT','RESERVATION','LESSON'],'All callee row locks are already held and reentrant; new Makeup Right is an insert, not a row-lock edge.'),
  ('public.reschedule_lesson_booking','private.reschedule_ordinary_lesson_booking_authority',array[]::text[],array['PARTICIPANT_SCHEDULE','ENTITLEMENT','RESERVATION','BOOKING','OCCURRENCE','LESSON'],'Dispatch wrapper retains no row lock.'),
  ('public.reschedule_lesson_booking','private.reschedule_makeup_lesson_booking_core',array[]::text[],array['MAKEUP_RIGHT','PARTICIPANT_SCHEDULE','BOOKING','LESSON'],'Dispatch wrapper retains no row lock.'),
  ('public.complete_lesson_booking','private.complete_ordinary_lesson_booking_authority',array[]::text[],array['PARTICIPANT_SCHEDULE','ENTITLEMENT','RESERVATION','BOOKING','OCCURRENCE','LESSON'],'Dispatch wrapper retains no row lock.'),
  ('public.complete_lesson_booking','private.complete_makeup_lesson_booking_core',array[]::text[],array['MAKEUP_RIGHT','PARTICIPANT_SCHEDULE','BOOKING','LESSON'],'Dispatch wrapper retains no row lock.'),
  ('public.admin_revoke_entitlement','private.claim_entitlement_revoke_operation',array['ENTITLEMENT'],array['REVOKE_OPERATION'],'No other domain flow locks an operation row before Entitlement.'),
  ('public.admin_revoke_entitlement','private.reconcile_fixed_cycles_on_entitlement_revoke',array['ENTITLEMENT','REVOKE_OPERATION'],array['FIXED_CYCLE','FIXED_SERIES'],'Fixed attachment never locks an existing Cycle before Entitlement.'),
  ('public.admin_revoke_entitlement','private.reconcile_bookings_on_entitlement_revoke',array['ENTITLEMENT','REVOKE_OPERATION','FIXED_CYCLE','FIXED_SERIES'],array['RESERVATION','BOOKING','LESSON'],'Booking paths obtain Entitlement before these row locks; revoke never waits for schedule advisory locks.');

create temp table lock_resource(resource text primary key) on commit drop;
insert into lock_resource values
  ('REQUEST_IDEMPOTENCY'),('PARTICIPANT_SCHEDULE'),('ORDER'),('PAYMENT'),
  ('FULFILLMENT_EVENT'),('ENTITLEMENT'),('REVOKE_OPERATION'),('MAKEUP_RIGHT'),
  ('CHECKOUT_HOLD'),('FIXED_RENEWAL'),('RENEWAL_HOLD'),('FIXED_CYCLE'),
  ('FIXED_SERIES'),('RESERVATION'),('BOOKING'),('OCCURRENCE'),('LESSON'),
  ('LEDGER'),('AUDIT');

create temp table lock_edge(
  branch text not null,
  earlier text not null references lock_resource(resource),
  later text not null references lock_resource(resource),
  reason text not null,
  primary key(branch,earlier,later)
) on commit drop;

insert into lock_edge values
  ('payment','ORDER','PAYMENT','Payment confirmation serializes Order before Payment.'),
  ('fulfillment','FULFILLMENT_EVENT','ORDER','Fulfillment owns event identity before reading paid Order.'),
  ('fulfillment','ORDER','ENTITLEMENT','Entitlements are created only after paid Order validation.'),
  ('ordinary','REQUEST_IDEMPOTENCY','PARTICIPANT_SCHEDULE','Booking identity precedes schedule ownership.'),
  ('ordinary','PARTICIPANT_SCHEDULE','ENTITLEMENT','Schedule participants serialize before value source.'),
  ('ordinary','ENTITLEMENT','RESERVATION','Credit authority locks Entitlement before Reservation.'),
  ('ordinary','RESERVATION','BOOKING','Reservation is authoritative before Booking mutation.'),
  ('ordinary','BOOKING','OCCURRENCE','Booking precedes optional occurrence mutation.'),
  ('ordinary','OCCURRENCE','LESSON','Occurrence precedes Lesson where present.'),
  ('ordinary','BOOKING','LESSON','Flexible paths without occurrences lock Booking before Lesson.'),
  ('fixed-attachment','PARTICIPANT_SCHEDULE','FULFILLMENT_EVENT','Attachment serializes slot before fulfilled value source.'),
  ('fixed-attachment','FULFILLMENT_EVENT','ORDER','Attachment validates event before Order.'),
  ('fixed-attachment','ORDER','ENTITLEMENT','Attachment validates Order before Entitlement.'),
  ('fixed-attachment','ENTITLEMENT','FIXED_SERIES','Value is locked before long-lived slot owner.'),
  ('checkout-hold','PARTICIPANT_SCHEDULE','CHECKOUT_HOLD','Claims and conversion lock schedule before Hold row.'),
  ('checkout-hold','CHECKOUT_HOLD','FULFILLMENT_EVENT','Conversion validates held checkout before fulfillment.'),
  ('renewal','PARTICIPANT_SCHEDULE','FIXED_RENEWAL','Renewal serializes slot before lifecycle row.'),
  ('renewal','FIXED_RENEWAL','RENEWAL_HOLD','Renewal row precedes its Hold.'),
  ('renewal','RENEWAL_HOLD','FULFILLMENT_EVENT','Conversion enters fixed attachment after Hold validation.'),
  ('makeup','REQUEST_IDEMPOTENCY','MAKEUP_RIGHT','Booking retry identity precedes existing Right.'),
  ('makeup','MAKEUP_RIGHT','PARTICIPANT_SCHEDULE','Existing Right is locked before the target schedule.'),
  ('makeup','PARTICIPANT_SCHEDULE','BOOKING','Schedule is serialized before Booking mutation.'),
  ('makeup','BOOKING','LESSON','Booking row precedes Lesson row in lifecycle operations.'),
  ('revoke','ENTITLEMENT','REVOKE_OPERATION','Entitlement identity precedes request identity.'),
  ('revoke','REVOKE_OPERATION','FIXED_CYCLE','Operation identity precedes reconciliation.'),
  ('revoke','FIXED_CYCLE','FIXED_SERIES','Cycle is invalidated before preferred pointer clearing.'),
  ('revoke','FIXED_SERIES','RESERVATION','Fixed reconciliation precedes ordinary value reconciliation.'),
  ('revoke','RESERVATION','BOOKING','Reservation rows precede their Bookings.'),
  ('revoke','BOOKING','LESSON','Booking rows precede Lessons.'),
  ('sink','ENTITLEMENT','LEDGER','Credit ledger is an append-only sink.'),
  ('sink','LESSON','LEDGER','Completion writes ledger only after Lesson validation.'),
  ('sink','PAYMENT','AUDIT','Financial audit is written after Payment transition.'),
  ('sink','LEDGER','AUDIT','Audit is a terminal append-only sink.');

create function pg_temp.lock_markers_in_order(p_signature text,p_markers text[])
returns boolean language plpgsql as $$
declare definition text; marker text; marker_position integer; last_position integer:=0;
begin
  definition:=lower(regexp_replace(
    pg_catalog.pg_get_functiondef(pg_catalog.to_regprocedure(p_signature)),
    '[[:space:]]+','','g'
  ));
  foreach marker in array p_markers loop
    marker:=lower(regexp_replace(marker,'[[:space:]]+','','g'));
    marker_position:=strpos(definition,marker);
    if marker_position=0 or marker_position<=last_position then return false; end if;
    last_position:=marker_position;
  end loop;
  return true;
end;
$$;

select is((select count(*)::integer from lock_discovered_mutators),100,'100 SECURITY DEFINER mutation-capable functions are discovered');
select is((select count(*)::integer from lock_function_inventory),100,'all discovered mutators have an explicit inventory entry');
select is((select count(*)::integer from lock_discovered_mutators d left join lock_function_inventory i using(function_name) where i.function_name is null),0,'coverage guard has no missing mutating function');
select is((select count(*)::integer from lock_function_inventory i left join lock_discovered_mutators d using(function_name) where d.function_name is null),0,'inventory has no stale function entry');
select is((select count(*)::integer from (select function_name,count(*) actual from lock_discovered_mutators group by function_name) d join lock_function_inventory i using(function_name) where d.actual<>i.expected_overloads),0,'coverage guard detects unexpected overloads');
select ok(not exists(select 1 from lock_function_inventory where classification='exempt' and exemption_reason is null),'every exemption has a reason');
select ok(not exists(select 1 from lock_function_inventory where classification='managed' and expected_order=''),'every managed mutator declares an order contract');
select is((select count(*)::integer from lock_critical_contract),15,'15 critical cross-domain functions have detailed lock manifests');
select ok(not exists(select 1 from lock_nested_call c left join lock_function_inventory caller on caller.function_name=c.caller left join lock_function_inventory callee on callee.function_name=c.callee where caller.function_name is null or callee.function_name is null),'nested call graph references only inventoried functions');
select ok(not exists(select 1 from lock_nested_call c join lock_secdef_functions f on f.function_name=c.caller where strpos(lower(f.prosrc),split_part(c.callee,'.',2)||'(')=0),'nested call graph matches live function source');
select ok(not exists(select 1 from lock_edge where earlier=later),'global lock graph contains no self edge');
select ok(not exists(select 1 from lock_edge e left join lock_resource a on a.resource=e.earlier left join lock_resource b on b.resource=e.later where a.resource is null or b.resource is null),'all graph edges use canonical resources');
select ok(not exists(
  with recursive walk(origin,current,path,cycle) as (
    select earlier,later,array[earlier,later],later=earlier from lock_edge
    union all
    select walk.origin,edge.later,walk.path||edge.later,edge.later=any(walk.path)
    from walk join lock_edge edge on edge.earlier=walk.current
    where not walk.cycle
  ) select 1 from walk where cycle
),'branch-aware global lock graph is acyclic');
select ok(not exists(select 1 from lock_critical_contract where cardinality(direct_resources)=0),'critical manifests declare direct resources');

select ok(pg_temp.lock_markers_in_order('private.confirm_payment_locked(uuid,uuid,text,uuid,text)',array['where id = requested_order_id for update','where id = requested_payment_id for update']),'payment locks Order before Payment');
select ok(pg_temp.lock_markers_in_order('private.fulfill_order_paid_event(uuid,uuid)',array['where id=p_event_id for update','where id=evt.order_id for share','insert into public.entitlements','insert into public.lesson_credit_ledger']),'fulfillment locks Event then Order before Entitlement/Ledger writes');
select ok(pg_temp.lock_markers_in_order('public.create_lesson_booking(uuid,uuid,uuid,uuid,timestamptz,text,text,text)',array['pg_advisory_xact_lock','private.lock_lesson_schedule_resources','from public.entitlements where id=p_entitlement_id for update','private.reserve_lesson_credit_core','insert into public.bookings']),'ordinary booking preserves idempotency/schedule/value ordering');
select ok(pg_temp.lock_markers_in_order('public.materialize_recurring_lesson_occurrence(uuid,date,uuid,text)',array['private.lock_lesson_schedule_resources','from public.entitlements where id=p_entitlement_id for update','private.validate_lesson_duration_compatibility','private.reserve_lesson_credit_core','insert into public.bookings']),'fixed materialization preserves schedule/value/materialization ordering');
select ok(pg_temp.lock_markers_in_order('private.attach_fixed_entitlement_cycle_without_renewal_core(uuid,uuid,uuid,text,uuid,text)',array['private.lock_lesson_schedule_resources','from public.order_fulfillment_events where id=p_fulfillment_event_id for share','from public.orders where id=evt.order_id for share','from public.entitlements where id=p_entitlement_id for update','from public.recurring_lesson_series where id=p_series_id for update']),'fixed attachment preserves schedule/event/order/entitlement/series ordering');
select ok(pg_temp.lock_markers_in_order('public.convert_fixed_checkout_hold(uuid,uuid,uuid,text)',array['private.lock_lesson_schedule_resources','from public.fixed_checkout_holds where id=p_hold_id for update','from public.order_fulfillment_events','from public.orders','from public.entitlements','private.attach_fixed_entitlement_cycle_core']),'checkout conversion preserves schedule/hold/fulfillment ordering');
select ok(pg_temp.lock_markers_in_order('public.convert_fixed_renewal(uuid,uuid,uuid,uuid,text)',array['private.lock_lesson_schedule_resources','from public.fixed_cycle_renewals where id=p_renewal_id for update','from public.fixed_renewal_holds','private.attach_fixed_entitlement_cycle_without_renewal_core']),'renewal conversion preserves schedule/renewal/hold/attachment ordering');
select ok(pg_temp.lock_markers_in_order('public.create_makeup_lesson_booking(uuid,uuid,uuid,uuid,timestamptz,text,text,text)',array['pg_advisory_xact_lock','from public.makeup_rights','for update','private.lock_lesson_schedule_resources','insert into public.bookings']),'Makeup booking preserves request/Right/schedule ordering');
select ok(pg_temp.lock_markers_in_order('private.cancel_ordinary_lesson_booking_authority(uuid,public.booking_credit_outcome,text,text)',array['private.lock_lesson_schedule_resources','for update of e','where id=b.credit_reservation_id for update','where id=p_booking_id for update','where booking_id=b.id for update','where id=b.lesson_id for update']),'ordinary cancellation preserves schedule/value/booking/occurrence/lesson ordering');
select ok(pg_temp.lock_markers_in_order('private.cancel_makeup_lesson_booking_core(uuid,public.booking_credit_outcome,text,text)',array['where id=b.makeup_right_id for update','private.lock_lesson_schedule_resources','where id=p_booking_id for update','where id=b.lesson_id for update']),'Makeup cancellation preserves Right/schedule/booking/lesson ordering');
select ok(pg_temp.lock_markers_in_order('private.reschedule_ordinary_lesson_booking_authority(uuid,timestamptz,text,text)',array['private.lock_lesson_schedule_resources','for update of e','where id=b.credit_reservation_id for update','where id=p_booking_id for update','where booking_id=b.id for update','where id=b.lesson_id for update']),'ordinary reschedule preserves canonical row-lock order');
select ok(pg_temp.lock_markers_in_order('private.reschedule_makeup_lesson_booking_core(uuid,timestamptz,text,text)',array['where id=b.makeup_right_id for update','private.lock_lesson_schedule_resources','where id=p_booking_id for update','where id=b.lesson_id for update']),'Makeup reschedule preserves Right/schedule/booking/lesson ordering');
select ok(pg_temp.lock_markers_in_order('private.complete_ordinary_lesson_booking_authority(uuid,text,text,text,text,text)',array['private.lock_lesson_schedule_resources','for update of entitlement','where id=b.credit_reservation_id for update','where id=p_booking_id for update','where booking_id=b.id for update','where id=b.lesson_id for update']),'ordinary completion preserves canonical row-lock order');
select ok(pg_temp.lock_markers_in_order('private.complete_makeup_lesson_booking_core(uuid,text,text,text,text,text)',array['where id=b.makeup_right_id for update','private.lock_lesson_schedule_resources','where id=p_booking_id for update','where id=b.lesson_id for update']),'Makeup completion preserves Right/schedule/booking/lesson ordering');
select ok(pg_temp.lock_markers_in_order('public.admin_revoke_entitlement(uuid,text,text)',array['where id=p_entitlement_id for update','private.claim_entitlement_revoke_operation','private.reconcile_fixed_cycles_on_entitlement_revoke','private.reconcile_bookings_on_entitlement_revoke','update public.entitlements','insert into public.audit_logs']),'Entitlement revoke preserves identity/operation/fixed/booking reconciliation ordering');

select * from finish();
rollback;
