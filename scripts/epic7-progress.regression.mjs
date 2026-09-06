// Explicit node:test local PostgreSQL suite; intentionally outside Vitest discovery.
import assert from 'node:assert/strict';
import test from 'node:test';
import {sql} from './epic7-local-db.mjs';
import {id,admin,studentA,studentB,teacher,creator,superAdmin,course,map,version,version2,quote,json,setupUsers,setupCourse,structure,content} from './epic7-fixtures.mjs';

// Owner-only fixture replacement inside a rolled-back transaction. Never a migration,
// JWT override, app configuration, production policy row or runtime allow-all flag.
const fixturePolicy=`create or replace function private.learning_course_use_authorized(p_actor uuid,p_course uuid,p_version uuid,p_node uuid)
returns boolean language sql stable set search_path='' as $$ select p_actor in ('${studentA}'::uuid,'${studentB}'::uuid) and p_course='${course}'::uuid; $$;`;
const as=actor=>`reset role;set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);`;
const write=(node,expected,key,patch,v=version)=>`select public.learning_set_activity('${v}','${id(node)}',${expected},'${id(key)}',${json(patch)})`;
const denied=(q,label,code='42501')=>`select throws_ok(${quote(q)},'${code}',null,${quote(label)});`;

test('D personal activity, deny-only authority and minimal inspection (PostgreSQL)',()=>{
 let q=`begin;select no_plan();${setupUsers}${as(admin)}${setupCourse}
 select public.learning_put_content('${version}',1,'${id(801)}',${json(content)});
 select public.learning_freeze_version('${version}',2,'${id(802)}');
 select ok(public.learning_inspect_version('${version}')::text not like '%provider_ref%','inspection omits private locator');
 select ok(public.learning_inspect_version('${version}')::text not like '%auth_user_id%','inspection omits contributor Auth link');
 select is(jsonb_array_length(public.learning_inspect_version('${version}')->'nodes'),4,'internal inspection shows representative hierarchy');
 ${as(superAdmin)}select ok(public.learning_inspect_version('${version}') is not null,'Super Admin inspection allowed');
 ${as(studentA)}${denied(write(40,0,803,{opened:true}),'missing Epic8 policy fails closed')}
 select set_config('request.jwt.claim.eligible','true',true);
 ${denied(write(40,0,804,{self_completed:true}),'caller eligibility claim is not authority')}
 ${denied(`select public.learning_get_own_activity('${version}','${id(40)}')`,'unjoined/recommended course has no personal projection')}
 reset role;select is((select count(*) from public.learning_self_activity),0::bigint,'denied use creates no personal map');
 ${fixturePolicy}${as(studentA)}
 select is(public.learning_get_own_activity('${version}','${id(40)}'),null::jsonb,'joined fixture with no activity remains null');
 select is((${write(41,0,805,{self_completed:true}).replace('select ','')}),1,'advisory prerequisite does not block explicit Self Complete');
 select is(public.learning_get_own_activity('${version}','${id(41)}')->'opened_at','null'::jsonb,'Self Complete needs no video event');
 select is((${write(40,0,806,{opened:true,resume_resource_id:id(120)}).replace('select ','')}),1,'open and scoped resume recorded');
 select is(public.learning_get_own_activity('${version}','${id(40)}')->'self_completed','false'::jsonb,'opening never auto-completes');
 select is((${write(40,1,807,{self_completed:true}).replace('select ','')}),2,'explicit Self Complete');
 select is((${write(40,2,808,{self_completed:false,needs_revisit:true,resume_resource_id:null}).replace('select ','')}),3,'correction/revisit and clearing resume');
 select is((${write(40,1,807,{self_completed:true}).replace('select ','')}),2,'old exact retry returns original result');
 select is(public.learning_get_own_activity('${version}','${id(40)}')->'self_completed','false'::jsonb,'old retry cannot undo newer correction');
 ${denied(write(40,1,809,{self_completed:true}),'stale request rejected','P0001')}
 ${denied(write(40,3,807,{opened:true}),'same key different payload denied','P0001')}
 ${denied(write(41,1,807,{self_completed:true}),'same key different Node denied','P0001')}
 ${denied(write(40,3,810,{resume_resource_id:id(121)}),'resume cannot point to another Node','P0001')}
 ${denied(write(40,3,811,{self_completed:true,subject_id:studentB}),'forged subject rejected','P0001')}
 `;
 for(const patch of [{verified:true},{assessment_passed:true},{stage_completed:true},{certificate:true},{self_completed:null},{self_completed:'true'},{opened:false},{}, {membership_tier:'pro'}]){
  q+=denied(write(40,3,812,patch),`invalid/formal patch ${JSON.stringify(patch)} denied`,'P0001');
 }
 q+=`${as(studentB)}select is(public.learning_get_own_activity('${version}','${id(40)}'),null::jsonb,'other Student cannot read A activity');
 select is((${write(40,0,807,{opened:true}).replace('select ','')}),1,'other Student same request key is independent');
 ${as(studentA)}select is((public.learning_get_own_activity('${version}','${id(40)}')->>'revision')::integer,3,'B did not overwrite A');
 ${as(admin)}select public.learning_create_draft('${map}','${version2}');
 select public.learning_put_structure('${version2}',0,'${id(820)}',${json(structure)});
 ${as(studentA)}${denied(write(40,0,821,{opened:true},version2),'draft progress forbidden even in eligible fixture')}
 ${as(admin)}select public.learning_put_content('${version2}',1,'${id(822)}',${json(content)});select public.learning_freeze_version('${version2}',2,'${id(823)}');
 ${as(studentA)}select is(public.learning_get_own_activity('${version2}','${id(40)}'),null::jsonb,'V2 never inherits V1 progress');
 select is((${write(40,0,824,{self_completed:true},version2).replace('select ','')}),1,'new V2 activity starts independently');
 select is((public.learning_get_own_activity('${version}','${id(40)}')->>'revision')::integer,3,'V1 historical progress retained');
 select public.learning_set_activity('${version}','${id(40)}',3,'${id(825)}','{"self_completed":true}');
 select public.learning_set_activity('${version}','${id(42)}',0,'${id(826)}','{"self_completed":true}');
 select public.learning_set_activity('${version}','${id(43)}',0,'${id(827)}','{"self_completed":true}');
 reset role;select is((select count(*) from public.learning_self_activity where subject_id='${studentA}' and publication_id='${version}' and self_completed),4::bigint,'all Nodes self-completed');
 select is((select count(*) from public.assessments where student_user_id='${studentA}'),0::bigint,'all self-complete creates no formal assessment');
 select is((select current_stage from public.student_profiles where user_id='${studentA}'),null::smallint,'no legacy placement conversion');
 update public.system_courses set archived=true where id='${course}';
 ${as(studentA)}${denied(write(40,4,828,{opened:true}),'archive denies new use')}
 reset role;update public.system_courses set archived=false,withdrawn=true where id='${course}';
 ${as(studentA)}${denied(`select public.learning_get_own_activity('${version}','${id(40)}')`,'withdrawal denies use projection')}
 reset role;select is((select count(*) from public.learning_self_activity where subject_id='${studentA}' and publication_id='${version}'),4::bigint,'availability loss retains activity history');
 update public.system_courses set withdrawn=false where id='${course}';
 delete from public.user_roles where user_id='${studentA}' and role='student';
 ${as(studentA)}${denied(write(40,4,829,{opened:true}),'removed Student role is rechecked')}
 reset role;insert into public.user_roles(user_id,role) values('${studentA}','student');
 update public.profiles set account_status='suspended' where user_id='${studentA}';
 ${as(studentA)}${denied(write(40,4,831,{opened:true}),'suspended Student cannot mutate')}
 reset role;update public.profiles set account_status='active' where user_id='${studentA}';
 update public.profiles set account_status='disabled' where user_id='${admin}';
 ${as(admin)}${denied(`select public.learning_inspect_version('${version}')`,'inactive Admin denied inspection')}
 reset role;update public.profiles set account_status='active' where user_id='${admin}';
 delete from public.user_roles where user_id='${admin}' and role='admin';
 ${as(admin)}${denied(`select public.learning_create_draft('${map}','${id(832)}')`,'removed Admin role denied mutation')}
 reset role;
 `;
 for(const actor of [teacher,creator,studentB])q+=`${as(actor)}${denied(`select public.learning_inspect_version('${version}')`,'unprivileged inspection rejected')}`;
 for(const actor of [teacher,creator])q+=`${as(actor)}${denied(write(40,0,830,{self_completed:true}),'Teacher/Creator attribution cannot write learner activity')}`;
 q+=`${as(studentB)}${denied(`update public.learning_self_activity set self_completed=false where subject_id='${studentA}'`,'raw cross-Student update denied')}
 ${denied(`select * from public.learning_self_activity`,'raw cross-Student reads denied')}`;
 q+='reset role;';
 for(const t of ['learning_self_activity','learning_activity_requests']){
  q+=`select ok((select relrowsecurity from pg_class where oid='public.${t}'::regclass),'${t} RLS enabled');`;
  for(const role of ['anon','authenticated','service_role'])q+=`select ok(not has_table_privilege('${role}','public.${t}','SELECT,INSERT,UPDATE,DELETE,TRUNCATE'),'${role} denied raw activity access');`;
 }
 for(const fn of ['learning_course_use_authorized(uuid,uuid,uuid,uuid)','learning_require_use(uuid,uuid)','learning_request(uuid,integer,uuid,text,jsonb)','learning_finish_request(uuid,uuid,text,jsonb)']){
  for(const role of ['anon','authenticated','service_role'])q+=`select ok(not has_function_privilege('${role}','private.${fn}','EXECUTE'),'${role} cannot invoke private ${fn}');`;
 }
 q+=`select * from finish();rollback;`;
 const output=sql(q);assert.doesNotMatch(output,/^not ok|Looks like you failed/m,output);
 assert.equal(sql(`select private.learning_course_use_authorized('${studentA}','${course}','${version}','${id(40)}')`).trim(),'f','fixture policy rolled back to shipped false');
 console.log(`D: ${(output.match(/^ok /gm)||[]).length} PostgreSQL assertions PASS; production boundary remains false`);
});
