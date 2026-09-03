begin;

alter table public.lesson_package_product_configs
  add column fixed_renewal_trigger_remaining_lessons integer check(fixed_renewal_trigger_remaining_lessons>=0),
  add column fixed_renewal_deadline_offset_seconds integer check(fixed_renewal_deadline_offset_seconds>=0),
  add column fixed_renewal_hold_seconds integer check(fixed_renewal_hold_seconds>0),
  add column fixed_non_renew_release_offset_seconds integer check(fixed_non_renew_release_offset_seconds>=0);

-- Policy is snapshotted when a cycle first enters its window. Later config
-- edits never rewrite an already-open renewal deadline or lease duration.
alter table public.fixed_entitlement_cycles add constraint fixed_cycles_id_series_unique unique(id,series_id);
alter table public.fixed_entitlement_cycles add constraint fixed_cycles_id_entitlement_unique unique(id,entitlement_id);

create type public.fixed_renewal_state as enum('window_open','renewed','released');
create type public.fixed_renewal_intent as enum('undecided','will_renew','will_not_renew');
create type public.fixed_renewal_hold_status as enum('active','released','converted');

create table public.fixed_cycle_renewals(
  id uuid primary key default gen_random_uuid(),
  series_id uuid not null references public.recurring_lesson_series(id) on delete restrict,
  current_cycle_id uuid not null unique references public.fixed_entitlement_cycles(id) on delete restrict,
  current_entitlement_id uuid not null references public.entitlements(id) on delete restrict,
  student_user_id uuid not null references auth.users(id),teacher_user_id uuid not null references auth.users(id),
  state public.fixed_renewal_state not null default 'window_open',
  renewal_intent public.fixed_renewal_intent not null default 'undecided',
  window_opened_at timestamptz not null default now(),intent_changed_at timestamptz,
  current_cycle_completed_at timestamptz,renewal_deadline_at timestamptz,reminder_due_at timestamptz,
  trigger_remaining_lessons integer not null,deadline_offset_seconds integer not null,
  renewal_hold_seconds integer not null,non_renew_release_offset_seconds integer not null,
  successful_next_cycle_id uuid unique references public.fixed_entitlement_cycles(id),
  successful_order_id uuid references public.orders(id),
  successful_fulfillment_event_id uuid unique references public.order_fulfillment_events(id),
  renewed_at timestamptz,released_at timestamptz,released_by uuid references auth.users(id),release_reason text,
  created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
  foreign key(series_id,student_user_id,teacher_user_id) references public.recurring_lesson_series(id,student_user_id,teacher_user_id),
  foreign key(current_cycle_id,series_id) references public.fixed_entitlement_cycles(id,series_id),
  foreign key(current_cycle_id,current_entitlement_id) references public.fixed_entitlement_cycles(id,entitlement_id),
  check((current_cycle_completed_at is null and renewal_deadline_at is null) or
    (current_cycle_completed_at is not null and renewal_deadline_at>=current_cycle_completed_at)),
  check((state='window_open' and successful_next_cycle_id is null and released_at is null) or
    (state='renewed' and successful_next_cycle_id is not null and renewed_at is not null and released_at is null) or
    (state='released' and successful_next_cycle_id is null and released_at is not null and release_reason is not null))
);
-- Required references make Booking/Lesson/Occurrence cycle links durable.
alter table public.lessons add column fixed_cycle_id uuid references public.fixed_entitlement_cycles(id);
alter table public.bookings add column fixed_cycle_id uuid references public.fixed_entitlement_cycles(id);
alter table public.recurring_lesson_occurrences add column fixed_cycle_id uuid references public.fixed_entitlement_cycles(id);

create table public.fixed_renewal_holds(
 id uuid primary key default gen_random_uuid(),renewal_id uuid not null references public.fixed_cycle_renewals(id),
 order_id uuid not null unique references public.orders(id),student_user_id uuid not null references auth.users(id),
 idempotency_key text not null check(char_length(idempotency_key) between 16 and 140),
 status public.fixed_renewal_hold_status not null default 'active',created_at timestamptz not null,
 expires_at timestamptz not null check(expires_at>created_at),closed_at timestamptz,close_reason text,
 unique(student_user_id,idempotency_key),check((status='active' and closed_at is null) or(status<>'active' and closed_at is not null))
);

create function public.set_fixed_renewal_policy(p_product_id uuid,p_trigger_remaining integer,p_deadline_seconds integer,
 p_hold_seconds integer,p_non_renew_seconds integer,p_reason text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.current_user_has_role(array['admin','super_admin']::public.app_role[]) then raise exception using errcode='42501',message='UNAUTHORIZED_RENEWAL_ACTION';end if;
 if p_trigger_remaining is null or p_deadline_seconds is null or p_hold_seconds is null or p_non_renew_seconds is null or p_trigger_remaining<0 or p_deadline_seconds<0 or p_hold_seconds<=0 or p_non_renew_seconds<0 or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception using errcode='22023',message='INVALID_RENEWAL_POLICY';end if;
 update public.lesson_package_product_configs set fixed_renewal_trigger_remaining_lessons=p_trigger_remaining,
 fixed_renewal_deadline_offset_seconds=p_deadline_seconds,fixed_renewal_hold_seconds=p_hold_seconds,
 fixed_non_renew_release_offset_seconds=p_non_renew_seconds where product_id=p_product_id;
 if not found then raise exception using errcode='22023',message='INVALID_RENEWAL_PRODUCT';end if;
 insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason) values(auth.uid(),'fixed_renewal.policy_changed','product',p_product_id,
 jsonb_build_object('trigger_remaining_lessons',p_trigger_remaining,'deadline_offset_seconds',p_deadline_seconds,'hold_seconds',p_hold_seconds,'non_renew_release_offset_seconds',p_non_renew_seconds),trim(p_reason));
end;$$;

create function public.open_fixed_cycle_renewal(p_cycle_id uuid,p_reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();c public.fixed_entitlement_cycles%rowtype;s public.recurring_lesson_series%rowtype;e public.entitlements%rowtype;cfg public.lesson_package_product_configs%rowtype;b record;r public.fixed_cycle_renewals%rowtype;
begin
 select * into c from public.fixed_entitlement_cycles where id=p_cycle_id;if not found then raise exception using errcode='P0001',message='FIXED_CYCLE_NOT_FOUND';end if;select * into s from public.recurring_lesson_series where id=c.series_id;
 if auth.role() is distinct from 'service_role' and(caller is null or private.scheduling_actor_role(caller) not in('teacher','admin','super_admin') or not private.scheduling_teacher_authorized(s.teacher_user_id)) then raise exception using errcode='42501',message='UNAUTHORIZED_RENEWAL_ACTION';end if;
 if char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception using errcode='22023',message='INVALID_RENEWAL_REQUEST';end if;
 perform private.lock_lesson_schedule_resources(s.student_user_id,s.teacher_user_id);select * into s from public.recurring_lesson_series where id=c.series_id for update;select * into c from public.fixed_entitlement_cycles where id=p_cycle_id for update;
 select * into r from public.fixed_cycle_renewals where current_cycle_id=c.id;if found then return r.id;end if;
 if s.status<>'active' or exists(select 1 from public.fixed_entitlement_cycles where series_id=s.id and sequence_number>c.sequence_number) then raise exception using errcode='P0001',message='RENEWAL_CYCLE_NOT_CURRENT';end if;
 select * into e from public.entitlements where id=c.entitlement_id;select * into cfg from public.lesson_package_product_configs where product_id=e.product_id;
 if cfg.fixed_renewal_trigger_remaining_lessons is null or cfg.fixed_renewal_deadline_offset_seconds is null or cfg.fixed_renewal_hold_seconds is null or cfg.fixed_non_renew_release_offset_seconds is null then raise exception using errcode='P0001',message='RENEWAL_POLICY_UNAVAILABLE';end if;
 select * into b from private.lesson_credit_balance(e.id);if c.status='active' and b.available+b.reserved>cfg.fixed_renewal_trigger_remaining_lessons then raise exception using errcode='P0001',message='RENEWAL_WINDOW_NOT_OPEN';end if;
 insert into public.fixed_cycle_renewals(series_id,current_cycle_id,current_entitlement_id,student_user_id,teacher_user_id,
 trigger_remaining_lessons,deadline_offset_seconds,renewal_hold_seconds,non_renew_release_offset_seconds,
 current_cycle_completed_at,renewal_deadline_at,reminder_due_at)
 values(s.id,c.id,e.id,s.student_user_id,s.teacher_user_id,cfg.fixed_renewal_trigger_remaining_lessons,cfg.fixed_renewal_deadline_offset_seconds,
 cfg.fixed_renewal_hold_seconds,cfg.fixed_non_renew_release_offset_seconds,c.completed_at,
 case when c.completed_at is null then null else c.completed_at+make_interval(secs=>cfg.fixed_renewal_deadline_offset_seconds) end,now()) returning * into r;
 insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason) values(case when auth.role()='service_role' then null else caller end,'fixed_renewal.window_opened','fixed_cycle_renewal',r.id,to_jsonb(r),trim(p_reason));return r.id;
end;$$;

create function public.set_fixed_renewal_intent(p_renewal_id uuid,p_intent public.fixed_renewal_intent,p_reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare r public.fixed_cycle_renewals%rowtype;c public.fixed_entitlement_cycles%rowtype;caller uuid:=auth.uid();
begin select * into r from public.fixed_cycle_renewals where id=p_renewal_id;
 if not found or caller is null or not private.current_user_is_active() or caller<>r.student_user_id then raise exception using errcode='42501',message='UNAUTHORIZED_RENEWAL_ACTION';end if;
 if r.state<>'window_open' or(r.renewal_deadline_at is not null and clock_timestamp()>r.renewal_deadline_at)or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception using errcode='P0001',message='RENEWAL_NOT_OPEN';end if;
 perform private.lock_lesson_schedule_resources(r.student_user_id,r.teacher_user_id);select * into r from public.fixed_cycle_renewals where id=p_renewal_id for update;select * into c from public.fixed_entitlement_cycles where id=r.current_cycle_id;
 if r.state<>'window_open' or p_intent is null or(r.renewal_deadline_at is not null and clock_timestamp()>r.renewal_deadline_at)then raise exception using errcode='P0001',message='RENEWAL_NOT_OPEN';end if;
 if r.renewal_intent=p_intent then return r.id;end if;
 update public.fixed_cycle_renewals set renewal_intent=p_intent,intent_changed_at=now(),updated_at=now(),renewal_deadline_at=case when c.completed_at is null then null else c.completed_at+make_interval(secs=>case when p_intent='will_not_renew' then r.non_renew_release_offset_seconds else r.deadline_offset_seconds end)end where id=r.id returning * into r;
 insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason) values(caller,'fixed_renewal.intent_changed','fixed_cycle_renewal',r.id,to_jsonb(r),trim(p_reason));return r.id;end;$$;

create function private.link_booking_fixed_cycle() returns trigger language plpgsql security definer set search_path='' as $$
declare cid uuid;
begin select c.id into cid from public.lesson_credit_reservations x join public.fixed_entitlement_cycles c on c.entitlement_id=x.entitlement_id where x.id=new.credit_reservation_id and c.series_id=new.recurring_series_id and new.source='fixed';
 if cid is not null then update public.bookings set fixed_cycle_id=cid where id=new.id;update public.lessons set fixed_cycle_id=cid where id=new.lesson_id;update public.recurring_lesson_occurrences set fixed_cycle_id=cid where booking_id=new.id;end if;return new;end;$$;
create trigger booking_link_fixed_cycle after insert on public.bookings for each row execute function private.link_booking_fixed_cycle();
create function private.link_occurrence_fixed_cycle() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.booking_id is not null then select fixed_cycle_id into new.fixed_cycle_id from public.bookings where id=new.booking_id;end if;
 return new;
end;$$;
create trigger occurrence_link_fixed_cycle before update of booking_id on public.recurring_lesson_occurrences for each row execute function private.link_occurrence_fixed_cycle();

-- Existing bookings may predate 4A attachment. Resolve their identity through
-- the existing reservation entitlement and SAME series, never a preferred hint.
update public.bookings b set fixed_cycle_id=c.id from public.lesson_credit_reservations r
 join public.fixed_entitlement_cycles c on c.entitlement_id=r.entitlement_id
 where b.credit_reservation_id=r.id and b.recurring_series_id=c.series_id and b.source='fixed';
update public.lessons l set fixed_cycle_id=b.fixed_cycle_id from public.bookings b where b.lesson_id=l.id and b.fixed_cycle_id is not null;
update public.recurring_lesson_occurrences o set fixed_cycle_id=b.fixed_cycle_id from public.bookings b where b.id=o.booking_id and b.fixed_cycle_id is not null;
create function private.link_attached_cycle_bookings() returns trigger language plpgsql security definer set search_path='' as $$
begin
 update public.bookings b set fixed_cycle_id=new.id from public.lesson_credit_reservations r where b.credit_reservation_id=r.id and r.entitlement_id=new.entitlement_id and b.recurring_series_id=new.series_id and b.source='fixed';
 update public.lessons l set fixed_cycle_id=new.id from public.bookings b where b.lesson_id=l.id and b.fixed_cycle_id=new.id;
 update public.recurring_lesson_occurrences o set fixed_cycle_id=new.id from public.bookings b where b.id=o.booking_id and b.fixed_cycle_id=new.id;
 return new;
end;$$;
create trigger fixed_cycle_link_bookings after insert on public.fixed_entitlement_cycles for each row execute function private.link_attached_cycle_bookings();

-- now() is the transaction start, potentially before a hold was claimed. Only
-- managed cycles need a wall-clock completion boundary for deadline admission.
create function private.stamp_managed_cycle_completion() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.status='active' and new.status='completed' and exists(select 1 from public.fixed_cycle_renewals where current_cycle_id=new.id and state='window_open')then new.completed_at:=clock_timestamp();end if;
 return new;
end;$$;
create trigger fixed_cycle_completion_clock before update of status on public.fixed_entitlement_cycles for each row execute function private.stamp_managed_cycle_completion();

create function private.fixed_cycle_completion_renewal() returns trigger language plpgsql security definer set search_path='' as $$
begin if old.status='active' and new.status='completed' then update public.fixed_cycle_renewals set current_cycle_completed_at=new.completed_at,
 renewal_deadline_at=new.completed_at+make_interval(secs=>case when renewal_intent='will_not_renew' then non_renew_release_offset_seconds else deadline_offset_seconds end),updated_at=now() where current_cycle_id=new.id and state='window_open';end if;return new;end;$$;
create trigger fixed_cycle_completion_renewal after update of status on public.fixed_entitlement_cycles for each row execute function private.fixed_cycle_completion_renewal();

create function public.claim_fixed_renewal_hold(p_renewal_id uuid,p_product_slug text,p_idempotency_key text) returns uuid language plpgsql security definer set search_path='' as $$
declare r public.fixed_cycle_renewals%rowtype;h public.fixed_renewal_holds%rowtype;p public.products%rowtype;cfg public.lesson_package_product_configs%rowtype;oid uuid;ts timestamptz;
begin select * into r from public.fixed_cycle_renewals where id=p_renewal_id;
 if not found or auth.uid() is null or auth.uid()<>r.student_user_id or not private.current_user_is_active() then raise exception using errcode='42501',message='UNAUTHORIZED_RENEWAL_ACTION';end if;
 if char_length(coalesce(p_idempotency_key,'')) not between 16 and 140 then raise exception using errcode='22023',message='INVALID_RENEWAL_HOLD_KEY';end if;
 perform private.lock_lesson_schedule_resources(r.student_user_id,r.teacher_user_id);ts:=clock_timestamp();select * into h from public.fixed_renewal_holds where student_user_id=auth.uid() and idempotency_key=p_idempotency_key for update;if found then if h.renewal_id<>r.id or not exists(select 1 from public.order_items i join public.products product on product.id=i.product_id where i.order_id=h.order_id and product.public_slug=p_product_slug)then raise exception using errcode='22023',message='RENEWAL_HOLD_PAYLOAD_MISMATCH';end if;return h.id;end if;
 select * into r from public.fixed_cycle_renewals where id=p_renewal_id for update;if r.state<>'window_open' or(r.renewal_deadline_at is not null and ts>r.renewal_deadline_at) then raise exception using errcode='P0001',message='RENEWAL_NOT_OPEN';end if;
 select * into p from public.products where public_slug=p_product_slug;select * into cfg from public.lesson_package_product_configs where product_id=p.id;
 if not found or cfg.booking_mode_eligibility not in('fixed','both') or(p.owner_type='teacher' and p.owner_teacher_user_id is distinct from r.teacher_user_id) then raise exception using errcode='P0001',message='ENTITLEMENT_NOT_ELIGIBLE';end if;
 oid:=public.create_checkout_order(p_product_slug,1,'fixed-renewal:'||p_idempotency_key);
 if not exists(select 1 from public.orders where id=oid and buyer_user_id=r.student_user_id and status='awaiting_payment' and payment_status='unpaid' and expires_at>clock_timestamp())then raise exception using errcode='P0001',message='RENEWAL_CHECKOUT_UNAVAILABLE';end if;
 insert into public.fixed_renewal_holds(renewal_id,order_id,student_user_id,idempotency_key,created_at,expires_at) values(r.id,oid,r.student_user_id,p_idempotency_key,ts,ts+make_interval(secs=>r.renewal_hold_seconds)) returning id into h.id;
 insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason) values(auth.uid(),'fixed_renewal.hold_created','fixed_renewal_hold',h.id,jsonb_build_object('renewal_id',r.id,'order_id',oid,'expires_at',ts+make_interval(secs=>r.renewal_hold_seconds)),'Renewal checkout');return h.id;end;$$;

create function public.release_fixed_renewal_hold(p_hold_id uuid,p_reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare h public.fixed_renewal_holds%rowtype;r public.fixed_cycle_renewals%rowtype;caller uuid:=auth.uid();
begin select * into h from public.fixed_renewal_holds where id=p_hold_id;if not found then raise exception using errcode='P0001',message='RENEWAL_HOLD_NOT_FOUND';end if;select * into r from public.fixed_cycle_renewals where id=h.renewal_id;
 if auth.role() is distinct from 'service_role' and(caller is null or not private.current_user_is_active()or(caller<>h.student_user_id and not private.current_user_has_role(array['admin','super_admin']::public.app_role[]))) then raise exception using errcode='42501',message='UNAUTHORIZED_RENEWAL_ACTION';end if;
 if char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception using errcode='22023',message='INVALID_RENEWAL_REQUEST';end if;
 perform private.lock_lesson_schedule_resources(r.student_user_id,r.teacher_user_id);update public.fixed_renewal_holds set status='released',closed_at=clock_timestamp(),close_reason=trim(p_reason) where id=h.id and status='active';
 if found then insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason) values(case when auth.role()='service_role'then null else caller end,'fixed_renewal.hold_released','fixed_renewal_hold',h.id,jsonb_build_object('renewal_id',r.id),trim(p_reason));end if;return h.id;end;$$;

create function private.release_fixed_renewal_locked(p_renewal_id uuid,p_actor uuid,p_reason text) returns boolean language plpgsql security definer set search_path='' as $$
declare r public.fixed_cycle_renewals%rowtype;s public.recurring_lesson_series%rowtype;
begin select * into r from public.fixed_cycle_renewals where id=p_renewal_id for update;if r.state<>'window_open' then return r.state='released';end if;
 if r.current_cycle_completed_at is null or r.renewal_deadline_at is null or clock_timestamp()<=r.renewal_deadline_at or exists(select 1 from public.fixed_renewal_holds where renewal_id=r.id and status='active' and expires_at>clock_timestamp() and created_at<=r.renewal_deadline_at) then return false;end if;
 select * into s from public.recurring_lesson_series where id=r.series_id for update;
 if exists(select 1 from public.fixed_entitlement_cycles where series_id=s.id and status<>'completed')then return false;end if;
 update public.fixed_cycle_renewals set state='released',released_at=clock_timestamp(),released_by=p_actor,release_reason=case when renewal_intent='will_not_renew'then 'non_renew' else 'renewal_expired'end,updated_at=now() where id=r.id;
 update public.recurring_lesson_series set status='ended',ended_at=clock_timestamp(),effective_until=greatest(effective_from,least(coalesce(effective_until,current_date),current_date)),lifecycle_reason=case when r.renewal_intent='will_not_renew'then 'non_renew' else 'renewal_expired'end,updated_at=now() where id=s.id and status in('active','paused');
 update public.recurring_lesson_occurrences set status='released',updated_at=now() where series_id=s.id and status in('planned','credit_required');
 insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason) values(p_actor,'fixed_renewal.released','fixed_cycle_renewal',r.id,jsonb_build_object('series_id',s.id,'deadline',r.renewal_deadline_at),trim(p_reason));return true;end;$$;

create function public.release_expired_fixed_renewal(p_renewal_id uuid,p_reason text) returns boolean language plpgsql security definer set search_path='' as $$
declare r public.fixed_cycle_renewals%rowtype;caller uuid:=auth.uid();
begin select * into r from public.fixed_cycle_renewals where id=p_renewal_id;if not found then raise exception using errcode='P0001',message='RENEWAL_NOT_FOUND';end if;
 if auth.role() is distinct from 'service_role' and(caller is null or not private.current_user_has_role(array['admin','super_admin']::public.app_role[])) then raise exception using errcode='42501',message='UNAUTHORIZED_RENEWAL_ACTION';end if;
 if char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception using errcode='22023',message='INVALID_RENEWAL_REQUEST';end if;
 perform private.lock_lesson_schedule_resources(r.student_user_id,r.teacher_user_id);return private.release_fixed_renewal_locked(r.id,case when auth.role()='service_role'then null else caller end,p_reason);end;$$;

-- A series that entered managed renewal cannot use generic attachment or end
-- operations to bypass the renewal deadline authority.
alter function private.attach_fixed_entitlement_cycle_core(uuid,uuid,uuid,text,uuid,text)
 rename to attach_fixed_entitlement_cycle_without_renewal_core;
create function private.attach_fixed_entitlement_cycle_core(p_series_id uuid,p_entitlement_id uuid,p_event_id uuid,p_reason text,p_actor uuid,p_actor_role text)
returns uuid language plpgsql security definer set search_path='' as $$
declare s public.recurring_lesson_series%rowtype;
begin
 select * into s from public.recurring_lesson_series where id=p_series_id;perform private.lock_lesson_schedule_resources(s.student_user_id,s.teacher_user_id);
 if not exists(select 1 from public.fixed_entitlement_cycles where entitlement_id=p_entitlement_id)
   and exists(select 1 from public.fixed_cycle_renewals where series_id=p_series_id) then
   raise exception using errcode='P0001',message='FIXED_RENEWAL_OPERATION_REQUIRED';
 end if;
 return private.attach_fixed_entitlement_cycle_without_renewal_core(p_series_id,p_entitlement_id,p_event_id,p_reason,p_actor,p_actor_role);
end;$$;

alter function public.set_recurring_lesson_series_status(uuid,public.recurring_series_status,text)
 rename to set_recurring_lesson_series_status_without_renewal;
create function public.set_recurring_lesson_series_status(p_series_id uuid,p_status public.recurring_series_status,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare s public.recurring_lesson_series%rowtype;caller uuid:=auth.uid();actor_role public.app_role;
begin
 select * into s from public.recurring_lesson_series where id=p_series_id;actor_role:=private.scheduling_actor_role(caller);
 if not found or caller is null or not private.scheduling_teacher_authorized(s.teacher_user_id) or actor_role not in('teacher','admin','super_admin') then raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';end if;
 perform private.lock_lesson_schedule_resources(s.student_user_id,s.teacher_user_id);
 if p_status='ended' and exists(select 1 from public.fixed_cycle_renewals where series_id=p_series_id and state='window_open') then raise exception using errcode='P0001',message='FIXED_RENEWAL_RELEASE_REQUIRED';end if;
 return public.set_recurring_lesson_series_status_without_renewal(p_series_id,p_status,p_reason);
end;$$;

create function public.convert_fixed_renewal(p_renewal_id uuid,p_hold_id uuid,p_entitlement_id uuid,p_event_id uuid,p_reason text) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.fixed_cycle_renewals%rowtype;h public.fixed_renewal_holds%rowtype;cy uuid;failure text;actor uuid:=auth.uid();ar text;
begin if auth.role()='service_role'then actor:=null;ar:='service_role';elsif private.current_user_has_role(array['admin','super_admin']::public.app_role[])then ar:=private.scheduling_actor_role(actor)::text;else raise exception using errcode='42501',message='UNAUTHORIZED_RENEWAL_ACTION';end if;
 select * into r from public.fixed_cycle_renewals where id=p_renewal_id;perform private.lock_lesson_schedule_resources(r.student_user_id,r.teacher_user_id);select * into r from public.fixed_cycle_renewals where id=p_renewal_id for update;
 if r.state='renewed'then if exists(select 1 from public.fixed_entitlement_cycles where id=r.successful_next_cycle_id and entitlement_id=p_entitlement_id and source_fulfillment_event_id=p_event_id)then return jsonb_build_object('status','renewed','cycle_id',r.successful_next_cycle_id,'series_id',r.series_id);end if;raise exception using errcode='22023',message='RENEWAL_PAYLOAD_MISMATCH';end if;
 begin
  select * into h from public.fixed_renewal_holds where id=p_hold_id and renewal_id=r.id and order_id=(select source_order_id from public.entitlements where id=p_entitlement_id) for update;
  if r.state<>'window_open' or r.current_cycle_completed_at is null or not found or h.status<>'active' or h.created_at>r.renewal_deadline_at
    or(clock_timestamp()>r.renewal_deadline_at and h.expires_at<=clock_timestamp())then raise exception using errcode='P0001',message='RENEWAL_NOT_OPEN';end if;
  cy:=private.attach_fixed_entitlement_cycle_without_renewal_core(r.series_id,p_entitlement_id,p_event_id,p_reason,actor,ar);
  update public.fixed_cycle_renewals set state='renewed',successful_next_cycle_id=cy,successful_order_id=h.order_id,successful_fulfillment_event_id=p_event_id,renewed_at=clock_timestamp(),updated_at=now() where id=r.id;
  update public.fixed_renewal_holds set status='converted',closed_at=clock_timestamp(),close_reason=trim(p_reason) where id=h.id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)values(actor,'fixed_renewal.renewed','fixed_cycle_renewal',r.id,jsonb_build_object('series_id',r.series_id,'next_cycle_id',cy,'fulfillment_event_id',p_event_id),trim(p_reason));return jsonb_build_object('status','renewed','cycle_id',cy,'series_id',r.series_id);
 exception when sqlstate'P0001' or sqlstate'22023' then failure:=sqlerrm;end;
 insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)values(actor,'fixed_renewal.conversion_rejected','fixed_cycle_renewal',r.id,jsonb_build_object('error',failure,'entitlement_id',p_entitlement_id,'fulfillment_event_id',p_event_id),trim(p_reason));return jsonb_build_object('status','rejected','error',failure);
end;$$;

alter table public.fixed_cycle_renewals enable row level security;alter table public.fixed_renewal_holds enable row level security;
revoke all on public.fixed_cycle_renewals,public.fixed_renewal_holds from public,anon,authenticated,service_role;
grant select on public.fixed_cycle_renewals,public.fixed_renewal_holds to authenticated;
create policy fixed_renewal_read on public.fixed_cycle_renewals for select to authenticated using(private.current_user_is_active()and(student_user_id=auth.uid()or(teacher_user_id=auth.uid()and private.current_user_has_role(array['teacher']::public.app_role[]))or private.current_user_has_role(array['admin','super_admin']::public.app_role[])));
create policy fixed_renewal_hold_read on public.fixed_renewal_holds for select to authenticated using(private.current_user_is_active()and(student_user_id=auth.uid()or private.current_user_has_role(array['admin','super_admin']::public.app_role[])));

do $$declare f regprocedure;begin for f in select oid::regprocedure from pg_proc where pronamespace in('private'::regnamespace,'public'::regnamespace)and proname in('link_booking_fixed_cycle','link_occurrence_fixed_cycle','fixed_cycle_completion_renewal','release_fixed_renewal_locked','attach_fixed_entitlement_cycle_without_renewal_core','attach_fixed_entitlement_cycle_core','set_recurring_lesson_series_status_without_renewal','set_recurring_lesson_series_status','set_fixed_renewal_policy','open_fixed_cycle_renewal','set_fixed_renewal_intent','claim_fixed_renewal_hold','release_fixed_renewal_hold','release_expired_fixed_renewal','convert_fixed_renewal')loop execute format('alter function %s owner to postgres',f);execute format('revoke all on function %s from public,anon,authenticated,service_role',f);end loop;end$$;
grant execute on function public.set_fixed_renewal_policy(uuid,integer,integer,integer,integer,text),public.open_fixed_cycle_renewal(uuid,text),public.set_fixed_renewal_intent(uuid,public.fixed_renewal_intent,text),public.claim_fixed_renewal_hold(uuid,text,text),public.release_fixed_renewal_hold(uuid,text),public.release_expired_fixed_renewal(uuid,text),public.convert_fixed_renewal(uuid,uuid,uuid,uuid,text) to authenticated;
grant execute on function public.open_fixed_cycle_renewal(uuid,text),public.release_fixed_renewal_hold(uuid,text),public.release_expired_fixed_renewal(uuid,text),public.convert_fixed_renewal(uuid,uuid,uuid,uuid,text) to service_role;
grant execute on function public.set_recurring_lesson_series_status(uuid,public.recurring_series_status,text) to authenticated;
alter function private.stamp_managed_cycle_completion() owner to postgres;
revoke all on function private.stamp_managed_cycle_completion() from public,anon,authenticated,service_role;
alter function private.link_attached_cycle_bookings() owner to postgres;
revoke all on function private.link_attached_cycle_bookings() from public,anon,authenticated,service_role;
commit;
