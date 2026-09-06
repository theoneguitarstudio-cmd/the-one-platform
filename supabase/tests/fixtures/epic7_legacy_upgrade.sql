-- Synthetic populated 29-migration baseline. LOCAL isolated database only.
begin;
insert into auth.users(id,email) values
 ('88000000-0000-0000-0000-000000000001','upgrade-student@example.invalid'),
 ('88000000-0000-0000-0000-000000000002','upgrade-teacher@example.invalid');
insert into public.user_roles(user_id,role) values('88000000-0000-0000-0000-000000000002','teacher');
insert into public.teacher_profiles(id,user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd)
values('88000000-0000-0000-0000-000000000003','88000000-0000-0000-0000-000000000002','upgrade-legacy-teacher','Synthetic','active',true,array['onsite']::public.teaching_mode[],500);
insert into public.teacher_stage_capabilities(teacher_profile_id,stage_number,capability_status)
values('88000000-0000-0000-0000-000000000003',3,'certified');
insert into public.student_profiles(user_id,learning_goal,current_stage)
values('88000000-0000-0000-0000-000000000001','Preserve legacy placement',3);
insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode)
values('88000000-0000-0000-0000-000000000004','88000000-0000-0000-0000-000000000001','88000000-0000-0000-0000-000000000002','active','onsite');
insert into public.lessons(id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,starts_at,ends_at,duration_minutes,timezone_anchor,status,location_text)
values('88000000-0000-0000-0000-000000000005','88000000-0000-0000-0000-000000000001','88000000-0000-0000-0000-000000000002','88000000-0000-0000-0000-000000000004','trial','onsite','2020-01-01 00:00Z','2020-01-01 00:50Z',50,'Asia/Taipei','completed','Synthetic classroom');
insert into public.lesson_records(lesson_id,stage_number,student_visible_notes,completed_at,completed_by)
values('88000000-0000-0000-0000-000000000005',3,'Legacy evidence','2020-01-01 00:50Z','88000000-0000-0000-0000-000000000002');
insert into public.assessments(student_user_id,teacher_user_id,lesson_id,primary_stage,recommendation_type,summary)
values('88000000-0000-0000-0000-000000000001','88000000-0000-0000-0000-000000000002','88000000-0000-0000-0000-000000000005',3,'hybrid','Legacy Trial assessment');
create table private.epic7_upgrade_snapshot(table_name text primary key,rows jsonb not null);
do $$ declare t text; begin
 foreach t in array array['learning_map_stages','teacher_stage_capabilities','student_profiles','lesson_records','assessments','lessons','teacher_profiles','student_teacher_relationships','products','orders','entitlements','lesson_credit_ledger','bookings'] loop
 execute format('insert into private.epic7_upgrade_snapshot select %L,coalesce(jsonb_agg(to_jsonb(x) order by to_jsonb(x)::text),''[]''::jsonb) from public.%I x',t,t);
 end loop;
end; $$;
commit;
