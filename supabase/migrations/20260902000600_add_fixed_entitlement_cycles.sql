begin;

create type public.fixed_entitlement_cycle_status as enum ('active','completed');
alter table public.recurring_lesson_series add constraint recurring_series_cycle_participants_unique
  unique(id,student_user_id,teacher_user_id);
create table public.fixed_entitlement_cycles (
  id uuid primary key default gen_random_uuid(),
  series_id uuid not null references public.recurring_lesson_series(id) on delete restrict,
  entitlement_id uuid not null unique references public.entitlements(id) on delete restrict,
  student_user_id uuid not null,
  teacher_user_id uuid not null,
  sequence_number integer not null check (sequence_number>0),
  status public.fixed_entitlement_cycle_status not null default 'active',
  source_fulfillment_event_id uuid not null references public.order_fulfillment_events(id) on delete restrict,
  source_order_item_id uuid not null references public.order_items(id) on delete restrict,
  attached_at timestamptz not null default now(),
  attached_by uuid references auth.users(id) on delete restrict,
  attachment_actor_role text not null check (attachment_actor_role in('service_role','teacher','admin','super_admin')),
  attachment_reason text not null check (char_length(trim(attachment_reason)) between 3 and 1000),
  completed_at timestamptz,
  completed_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(series_id,sequence_number),
  unique(source_fulfillment_event_id,source_order_item_id),
  foreign key(series_id,student_user_id,teacher_user_id)
    references public.recurring_lesson_series(id,student_user_id,teacher_user_id) on delete restrict,
  foreign key(entitlement_id,student_user_id)
    references public.entitlements(id,beneficiary_user_id) on delete restrict,
  check ((status='active' and completed_at is null and completed_by is null)
    or (status='completed' and completed_at>=attached_at and completed_by is not null))
);
create index fixed_cycles_student_idx on public.fixed_entitlement_cycles(student_user_id,series_id,sequence_number);
create index fixed_cycles_teacher_idx on public.fixed_entitlement_cycles(teacher_user_id,series_id,sequence_number);
comment on table public.fixed_entitlement_cycles is
  'Append-oriented package attachments to a long-lived Fixed series. Sequence orders attachments; it does not select credits or imply FIFO. Several prepaid attachments may be active. Completion is explicit and value-validated.';

create or replace function private.protect_fixed_cycle_history()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='DELETE' then raise exception using errcode='55000',message='FIXED_CYCLE_HISTORY_IMMUTABLE'; end if;
  if (new.id,new.series_id,new.entitlement_id,new.student_user_id,new.teacher_user_id,new.sequence_number,new.source_fulfillment_event_id,
      new.source_order_item_id,new.attached_at,new.attached_by,new.attachment_actor_role,new.attachment_reason,new.created_at)
    is distinct from
     (old.id,old.series_id,old.entitlement_id,old.student_user_id,old.teacher_user_id,old.sequence_number,old.source_fulfillment_event_id,
      old.source_order_item_id,old.attached_at,old.attached_by,old.attachment_actor_role,old.attachment_reason,old.created_at)
    or old.status='completed' then
    raise exception using errcode='55000',message='FIXED_CYCLE_HISTORY_IMMUTABLE';
  end if;
  if new.status<>'completed' then raise exception using errcode='55000',message='INVALID_FIXED_CYCLE_TRANSITION'; end if;
  return new;
end;
$$;
create trigger fixed_cycle_history_immutable before update or delete on public.fixed_entitlement_cycles
for each row execute function private.protect_fixed_cycle_history();

create or replace function private.attach_fixed_entitlement_cycle_core(
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

create or replace function public.attach_fixed_entitlement_cycle(
  p_series_id uuid,p_entitlement_id uuid,p_fulfillment_event_id uuid,p_reason text
) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); actor_role text; teacher_id uuid;
begin
  if auth.role()='service_role' then actor_role:='service_role'; caller:=null;
  else
    select teacher_user_id into teacher_id from public.recurring_lesson_series where id=p_series_id;
    actor_role:=private.scheduling_actor_role(caller)::text;
    if caller is null or teacher_id is null or actor_role not in('teacher','admin','super_admin')
      or not private.scheduling_teacher_authorized(teacher_id) then
      raise exception using errcode='42501',message='UNAUTHORIZED_FIXED_CYCLE_ACTION';
    end if;
  end if;
  return private.attach_fixed_entitlement_cycle_core(p_series_id,p_entitlement_id,p_fulfillment_event_id,p_reason,caller,actor_role);
end;
$$;

create or replace function public.complete_fixed_entitlement_cycle(p_cycle_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare c public.fixed_entitlement_cycles%rowtype; s public.recurring_lesson_series%rowtype;
  e public.entitlements%rowtype; balance record; completed_lessons bigint;
  caller uuid:=auth.uid(); actor_role public.app_role;
begin
  select * into c from public.fixed_entitlement_cycles where id=p_cycle_id;
  if not found then raise exception using errcode='P0001',message='FIXED_CYCLE_NOT_FOUND'; end if;
  select * into s from public.recurring_lesson_series where id=c.series_id;
  actor_role:=private.scheduling_actor_role(caller);
  if caller is null or actor_role not in('teacher','admin','super_admin')
    or not private.scheduling_teacher_authorized(s.teacher_user_id) then
    raise exception using errcode='42501',message='UNAUTHORIZED_FIXED_CYCLE_ACTION';
  end if;
  if char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_FIXED_CYCLE_REQUEST';
  end if;
  perform private.lock_lesson_schedule_resources(s.student_user_id,s.teacher_user_id);
  select * into e from public.entitlements where id=c.entitlement_id for update;
  perform 1 from public.recurring_lesson_series where id=s.id for update;
  select * into c from public.fixed_entitlement_cycles where id=p_cycle_id for update;
  if c.status='completed' then return c.id; end if;
  select * into balance from private.lesson_credit_balance(e.id);
  -- Read the sole Epic5 balance authority. Never create or adjust credits here.
  if e.status not in('active','exhausted') or balance.available<>0 or balance.reserved<>0
    or balance.consumed<=0 or balance.total<>balance.consumed then
    raise exception using errcode='P0001',message='FIXED_CYCLE_VALUE_INCOMPLETE';
  end if;
  select count(*) into completed_lessons from public.lesson_credit_reservations r
  join public.bookings b on b.credit_reservation_id=r.id
  join public.lessons l on l.id=b.lesson_id
  where r.entitlement_id=e.id and r.status='consumed' and b.recurring_series_id=s.id
    and b.status='completed' and l.status='completed' and r.lesson_id=l.id;
  -- Cancellation, expiry, revocation or spending value outside this series is
  -- not proof of completed Fixed lessons. Such dispositions need a future
  -- explicit policy; this operation does not infer them from calendar dates.
  if completed_lessons<>balance.consumed then
    raise exception using errcode='P0001',message='FIXED_CYCLE_LESSONS_INCOMPLETE';
  end if;
  update public.fixed_entitlement_cycles set status='completed',completed_at=now(),completed_by=caller,updated_at=now() where id=c.id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(caller,'fixed_cycle.completed','fixed_entitlement_cycle',c.id,jsonb_build_object('status',c.status),
    jsonb_build_object('status','completed','cycle_id',c.id,'series_id',c.series_id,'entitlement_id',c.entitlement_id,
      'source_fulfillment_event_id',c.source_fulfillment_event_id,'actor_role',actor_role),trim(p_reason));
  return c.id;
end;
$$;

alter table public.fixed_entitlement_cycles enable row level security;
revoke all on table public.fixed_entitlement_cycles from public,anon,authenticated,service_role;
grant select(id,series_id,entitlement_id,student_user_id,teacher_user_id,sequence_number,status,attached_at,completed_at,created_at,updated_at)
  on public.fixed_entitlement_cycles to authenticated;
create policy fixed_cycles_participant_read on public.fixed_entitlement_cycles for select to authenticated using(
  private.current_user_is_active() and (
    private.current_user_has_role(array['admin','super_admin']::public.app_role[])
    or student_user_id=auth.uid() or (teacher_user_id=auth.uid()
      and private.current_user_has_role(array['teacher']::public.app_role[]))
  )
);

alter function private.protect_fixed_cycle_history() owner to postgres;
alter function private.attach_fixed_entitlement_cycle_core(uuid,uuid,uuid,text,uuid,text) owner to postgres;
alter function public.attach_fixed_entitlement_cycle(uuid,uuid,uuid,text) owner to postgres;
alter function public.complete_fixed_entitlement_cycle(uuid,text) owner to postgres;
revoke all on function private.protect_fixed_cycle_history(),
  private.attach_fixed_entitlement_cycle_core(uuid,uuid,uuid,text,uuid,text),
  public.attach_fixed_entitlement_cycle(uuid,uuid,uuid,text),public.complete_fixed_entitlement_cycle(uuid,text)
  from public,anon,authenticated,service_role;
grant execute on function public.attach_fixed_entitlement_cycle(uuid,uuid,uuid,text) to authenticated,service_role;
grant execute on function public.complete_fixed_entitlement_cycle(uuid,text) to authenticated;

-- Keep preferred_entitlement_id as a compatibility hint. No historical pointer
-- is overwritten and materialization still requires an explicit entitlement.
commit;
