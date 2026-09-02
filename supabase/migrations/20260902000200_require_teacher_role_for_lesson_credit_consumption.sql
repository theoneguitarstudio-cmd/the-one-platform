begin;

-- Revalidate the current Teacher role at the public authorization boundary.
-- CREATE OR REPLACE preserves the existing owner and EXECUTE grants.
create or replace function public.consume_lesson_credit(p_reservation_id uuid,p_lesson_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); beneficiary_id uuid; reservation_lesson_id uuid;
begin
  if caller is null or not private.current_user_is_active() then
    raise exception using errcode='42501',message='Not authorized';
  end if;
  select reservation.beneficiary_user_id,reservation.lesson_id
    into beneficiary_id,reservation_lesson_id
  from public.lesson_credit_reservations reservation where reservation.id=p_reservation_id;
  if not found then raise exception using errcode='P0001',message='CREDIT_RESERVATION_NOT_FOUND'; end if;
  if reservation_lesson_id is distinct from p_lesson_id then
    raise exception using errcode='P0001',message='CREDIT_RESERVATION_PAYLOAD_MISMATCH';
  end if;
  if not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
    and (
      not private.current_user_has_role(array['teacher'::public.app_role])
      or not exists(
        select 1 from public.lessons lesson
        join public.teacher_profiles teacher on teacher.user_id=lesson.teacher_user_id
        where lesson.id=p_lesson_id and lesson.teacher_user_id=caller
          and lesson.student_user_id=beneficiary_id and lesson.status='completed'
          and teacher.teaching_status='active'
      )
    ) then raise exception using errcode='42501',message='Not authorized'; end if;
  return private.consume_lesson_credit_core(p_reservation_id,p_lesson_id,
    'lesson_completed',caller);
end; $$;

commit;
