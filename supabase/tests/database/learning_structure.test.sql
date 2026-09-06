begin;
select no_plan();
insert into auth.users(id,email) values
 ('87000000-0000-0000-0000-000000000001','learning-admin@example.invalid'),
 ('87000000-0000-0000-0000-000000000002','learning-student@example.invalid');
insert into public.user_roles(user_id,role) values('87000000-0000-0000-0000-000000000001','admin');
select is((select count(*) from public.learning_map_stages),5::bigint,'legacy stage catalog still five');
select is((select count(*) from pg_constraint where contype='f' and confrelid='public.learning_map_stages'::regclass),4::bigint,'all four legacy FKs preserved');
select ok(not has_table_privilege('service_role','public.system_courses','INSERT'),'service role no raw content insert');
select ok(not has_table_privilege('authenticated','public.curriculum_publications','UPDATE'),'authenticated no raw version update');
select ok((select bool_and(relrowsecurity) from pg_class where oid in ('public.system_courses'::regclass,'public.learning_maps'::regclass,'public.curriculum_publications'::regclass)),'RLS in first migration');
set local role authenticated;
select set_config('request.jwt.claim.sub','87000000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.learning_create_course('87000000-0000-0000-0000-000000000010','course-a','Course A','87000000-0000-0000-0000-000000000011','main')$$,'42501',null,'Student cannot construct content');
select set_config('request.jwt.claim.sub','87000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.learning_create_course('87000000-0000-0000-0000-000000000010','course-a','Course A','87000000-0000-0000-0000-000000000011','main')$$,'Admin constructs course/map');
select lives_ok($$select public.learning_create_course('87000000-0000-0000-0000-000000000010','course-a','Course A','87000000-0000-0000-0000-000000000011','main')$$,'create retry idempotent');
select throws_ok($$select public.learning_create_course('87000000-0000-0000-0000-000000000010','course-a','Changed','87000000-0000-0000-0000-000000000011','main')$$,'P0001','learning:idempotency_conflict','identity retry rejects changed payload');
select lives_ok($$select public.learning_create_course('87000000-0000-0000-0000-000000000020','course-b','Course B','87000000-0000-0000-0000-000000000021','main')$$,'second course same schema');
select lives_ok($$select public.learning_create_draft('87000000-0000-0000-0000-000000000011','87000000-0000-0000-0000-000000000012')$$,'draft creation');
select lives_ok($$select public.learning_create_draft('87000000-0000-0000-0000-000000000021','87000000-0000-0000-0000-000000000022')$$,'course B draft');
select throws_ok($$select public.learning_create_draft('87000000-0000-0000-0000-000000000011','87000000-0000-0000-0000-000000000013')$$,'P0001','learning:draft_conflict','one working draft per map');
select is(public.learning_put_structure('87000000-0000-0000-0000-000000000012',0,'87000000-0000-0000-0000-000000000099',
 '{"levels":[{"id":"87000000-0000-0000-0000-000000000031","slug":"level-6","position":6,"title":"Course-local Level"}],"modules":[{"id":"87000000-0000-0000-0000-000000000041","slug":"module","stage_id":"87000000-0000-0000-0000-000000000031","position":1,"title":"Module"}],"nodes":[{"id":"87000000-0000-0000-0000-000000000051","slug":"node","module_id":"87000000-0000-0000-0000-000000000041","position":1,"title":"Node"}]}'::jsonb),1,'hierarchy accepts independent course Level 6 and zero-resource draft');
select throws_ok($$select public.learning_put_structure('87000000-0000-0000-0000-000000000012',0,'87000000-0000-0000-0000-000000000098','{"levels":[],"modules":[],"nodes":[]}')$$,'P0001','learning:revision_conflict','stale revision rejected');
select throws_ok($$select public.learning_put_structure('87000000-0000-0000-0000-000000000022',0,'87000000-0000-0000-0000-000000000097','{"levels":[{"id":"87000000-0000-0000-0000-000000000031","slug":"level-6","position":1,"title":"stolen"}],"modules":[],"nodes":[]}')$$,'P0001','learning:identity_conflict','cross-course stable identity rejected');
select throws_ok($$select public.learning_put_structure('87000000-0000-0000-0000-000000000012',1,'87000000-0000-0000-0000-000000000096','{"levels":[],"modules":[],"nodes":[],"verified":true}')$$,'P0001','learning:invalid_fields','unsupported fields rejected');
reset role;
select is((select revision from public.curriculum_publications where id='87000000-0000-0000-0000-000000000012'),1,'failed mutations leave revision unchanged');
select throws_ok($$update public.learning_nodes set slug='rewritten' where id='87000000-0000-0000-0000-000000000051'$$,'P0001','learning:immutable_identity','identity rewrite rejected even through owner path');
insert into public.learning_maps(id,course_id,slug) values('87000000-0000-0000-0000-000000000023','87000000-0000-0000-0000-000000000020','empty');
select throws_ok($$insert into public.curriculum_publications(course_id,map_id,version_number,course_title,created_by) values('87000000-0000-0000-0000-000000000010','87000000-0000-0000-0000-000000000023',99,'wrong','87000000-0000-0000-0000-000000000001')$$,'23503',null,'composite map/course FK enforced');
select ok(not exists(select 1 from public.learning_node_versions where publication_id='87000000-0000-0000-0000-000000000022'),'no cross-course partial write');
set local role service_role;
select throws_ok($$select public.learning_create_draft('87000000-0000-0000-0000-000000000011','87000000-0000-0000-0000-000000000088')$$,'42501',null,'service cannot impersonate human RPC');
select throws_ok($$truncate public.curriculum_publications cascade$$,'42501',null,'service cannot truncate');
reset role;
select * from finish();
rollback;
