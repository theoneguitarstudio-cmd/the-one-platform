begin;

create or replace function private.attach_fixed_entitlement_cycle_without_renewal_core(
  p_series_id uuid,p_entitlement_id uuid,p_fulfillment_event_id uuid,p_reason text,
  p_actor uuid,p_actor_role text
) returns uuid language plpgsql security definer set search_path='' as $$
declare s public.recurring_lesson_series%rowtype; e public.entitlements%rowtype;
  evt public.order_fulfillment_events%rowtype; ord public.orders%rowtype;
  existing public.fixed_entitlement_cycles%rowtype; result_id uuid; next_sequence integer;
begin
  if char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_FIXED_CYCLE_REQUEST';
  end if;
  select * into s from public.recurring_lesson_series where id=p_series_id;
  if not found then raise exception using errcode='P0001',message='RECURRING_SERIES_INACTIVE'; end if;
  perform private.lock_lesson_schedule_resources(s.student_user_id,s.teacher_user_id);
  -- Fulfillment takes event -> order. It never takes schedule locks. Preserve
  -- that ordering before taking Entitlement -> Series -> Cycle locks here.
  select * into evt from public.order_fulfillment_events where id=p_fulfillment_event_id for share;
  if not found or evt.event_type<>'order.paid' or evt.status<>'processed' then
    raise exception using errcode='P0001',message='FIXED_CYCLE_FULFILLMENT_REQUIRED';
  end if;
  select * into ord from public.orders where id=evt.order_id for share;
  if not found or ord.status<>'paid' or ord.payment_status<>'paid' then
    raise exception using errcode='P0001',message='FIXED_CYCLE_FULFILLMENT_REQUIRED';
  end if;
  select * into e from public.entitlements where id=p_entitlement_id for update;
  if not found or e.source_fulfillment_event_id is distinct from evt.id
    or e.source_order_id is distinct from ord.id or e.beneficiary_user_id is distinct from ord.buyer_user_id
    or not exists(select 1 from public.order_items i join public.order_item_fulfillment_snapshots snap on snap.order_item_id=i.id
      where i.id=e.source_order_item_id and i.order_id=ord.id and i.product_id=e.product_id
        and snap.entitlement_type='lesson_package') then
    raise exception using errcode='P0001',message='FIXED_CYCLE_SOURCE_MISMATCH';
  end if;
  select * into s from public.recurring_lesson_series where id=p_series_id for update;
  select * into existing from public.fixed_entitlement_cycles where entitlement_id=e.id;
  if found then
    if existing.series_id<>s.id or existing.source_fulfillment_event_id<>evt.id then
      raise exception using errcode='P0001',message='FIXED_ENTITLEMENT_ALREADY_ATTACHED';
    end if;
    -- A retry returns the historical identity even after credits are exhausted,
    -- cycle completion, or series end. It does not reactivate anything.
    return existing.id;
  end if;
  if s.status<>'active' or not private.scheduling_relationship_is_active(s.relationship_id,s.student_user_id,s.teacher_user_id)
    or not exists(select 1 from public.profiles where user_id=s.student_user_id and account_status='active')
    or not exists(select 1 from public.teacher_profiles t join public.profiles p on p.user_id=t.user_id
      where t.user_id=s.teacher_user_id and t.teaching_status='active' and p.account_status='active')
    or not exists(select 1 from public.user_roles where user_id=s.teacher_user_id and role='teacher') then
    raise exception using errcode='P0001',message='RECURRING_SERIES_INACTIVE';
  end if;
  if not private.scheduling_entitlement_eligible(e.id,s.student_user_id,s.teacher_user_id,'fixed') then
    raise exception using errcode='P0001',message='ENTITLEMENT_NOT_ELIGIBLE';
  end if;

  -- The shared P1-7 authority reads the immutable Entitlement snapshot. Run it
  -- after both value rows are locked and before sequence allocation or writes.
  perform private.validate_lesson_duration_compatibility(e.id,s.duration_minutes);

  -- The held series row serializes MAX+1, including different entitlements.
  select coalesce(max(sequence_number),0)+1 into next_sequence from public.fixed_entitlement_cycles where series_id=s.id;
  insert into public.fixed_entitlement_cycles(series_id,entitlement_id,student_user_id,teacher_user_id,sequence_number,
    source_fulfillment_event_id,source_order_item_id,attached_by,attachment_actor_role,attachment_reason)
  values(s.id,e.id,s.student_user_id,s.teacher_user_id,next_sequence,evt.id,e.source_order_item_id,p_actor,p_actor_role,trim(p_reason)) returning id into result_id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
  values(p_actor,'fixed_cycle.attached','fixed_entitlement_cycle',result_id,jsonb_build_object(
    'series_id',s.id,'entitlement_id',e.id,'cycle_id',result_id,'sequence_number',next_sequence,
    'source_fulfillment_event_id',evt.id,'source_order_item_id',e.source_order_item_id,'actor_role',p_actor_role),trim(p_reason));
  return result_id;
end;
$$;

alter function private.attach_fixed_entitlement_cycle_without_renewal_core(
  uuid,uuid,uuid,text,uuid,text
) owner to postgres;
revoke all on function private.attach_fixed_entitlement_cycle_without_renewal_core(
  uuid,uuid,uuid,text,uuid,text
) from public,anon,authenticated,service_role;

commit;
