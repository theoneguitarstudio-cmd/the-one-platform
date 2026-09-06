// Explicit node:test local PostgreSQL suite; intentionally outside Vitest discovery.
import assert from 'node:assert/strict';
import test from 'node:test';
import {sql} from './epic7-local-db.mjs';
import {id,admin,teacher,creator,course,map,version,version2,quote,json,setupUsers,setupCourse,structure,content} from './epic7-fixtures.mjs';

test('C content integrity and immutable version contracts (local PostgreSQL)',()=>{
 const stmt = q => quote(q);
 const throws = (q,msg,error='P0001')=>`select throws_ok(${stmt(q)},'${error}',null,${quote(msg)});`;
 let q=`begin;select no_plan();${setupUsers}
 set local role authenticated;select set_config('request.jwt.claim.sub',${quote(admin)},true);${setupCourse}
 ${throws(`select public.learning_freeze_version('${version}',1,'${id(201)}')`,'zero-resource/objective draft cannot freeze')}
 select is(public.learning_put_content('${version}',1,'${id(202)}',${json(content)}),2,'representative content added');
 select is(public.learning_put_content('${version}',1,'${id(202)}',${json(content)}),2,'content retry idempotent');
 ${throws(`select public.learning_put_content('${version}',2,'${id(203)}',${json({prerequisites:[{dependent_node_id:id(40),prerequisite_node_id:id(41)}]})})`,'advisory cycle rejected')}
 ${throws(`select public.learning_put_content('${version}',2,'${id(204)}',${json({capabilities:[{id:id(171),node_id:id(40),code:'async_review',quota:5}]})})`,'capability quota field rejected')}
 ${throws(`select public.learning_put_content('${version}',2,'${id(205)}',${json({resources:[{...content.resources[0],content:'rewritten revision'}]})})`,'resource revision cannot be overwritten')}
 select is(public.learning_freeze_version('${version}',2,'${id(206)}'),3,'complete mixed/text-only nodes freeze');
 select is(public.learning_freeze_version('${version}',2,'${id(206)}'),3,'same freeze retry exact result');
 ${throws(`select public.learning_freeze_version('${version}',3,'${id(207)}')`,'different freeze request cannot mutate frozen version')}
 ${throws(`select public.learning_put_content('${version}',3,'${id(208)}','{}')`,'frozen version rejects content mutation')}
 select public.learning_create_draft('${map}','${version2}');
 select public.learning_put_structure('${version2}',0,'${id(209)}',${json({...structure,nodes:structure.nodes.map(n=>({...n,title:n.title+' V2'}))})});
 select public.learning_put_content('${version2}',1,'${id(210)}',${json(content)});
 select is(public.learning_freeze_version('${version2}',2,'${id(211)}'),3,'V2 frozen without changing V1');
 reset role;
 select is((select title from public.learning_node_versions where publication_id='${version}' and id='${id(40)}'),${quote(structure.nodes[0].title)},'V1 original title retained');
 select is((select count(*) from public.learning_node_resources where publication_id='${version}' and node_id='${id(40)}'),2::bigint,'Node has multiple resources');
 select is((select count(*) from public.learning_author_credits where publication_id='${version}' and resource_revision_id='${id(110)}'),2::bigint,'multiple authors including non-Teacher Creator');
 select is((select count(*) from public.user_roles where user_id='${creator}' and role='teacher'),0::bigint,'Creator attribution did not assign Teacher');
 `;
 const relations=['curriculum_stage_versions','learning_module_versions','learning_node_versions','learning_node_resources','learning_objective_versions','learning_objective_skills','learning_node_prerequisites','learning_author_credits','learning_node_capability_attachments'];
 for(const t of relations){q+=throws(`delete from public.${t} where publication_id='${version}'`,`frozen ${t} cannot delete`);}
 q+=throws(`update public.curriculum_publications set state='draft',frozen_at=null,frozen_by=null where id='${version}'`,'frozen version cannot reopen');
 q+=throws(`update public.learning_resource_versions set content='tampered' where id='${id(110)}'`,'immutable resource body');
 q+=throws(`update public.learning_skills set definition='tampered' where id='${id(140)}'`,'frozen Skill definition stable');
 const tables=['system_courses','learning_maps','curriculum_publications','learning_mutation_receipts','curriculum_stages','learning_modules','learning_nodes','learning_resources','learning_resource_versions','learning_objectives','learning_skills','content_contributors','learning_capabilities',...relations];
 for(const t of tables){q+=`select ok((select relrowsecurity from pg_class where oid='public.${t}'::regclass),'${t} RLS');`;
  for(const role of ['anon','authenticated','service_role'])q+=`select ok(not has_table_privilege('${role}','public.${t}','INSERT,UPDATE,DELETE,TRUNCATE'),'${role} no raw writes ${t}');`;
 }
 for(const actor of [teacher,creator])q+=`set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);${throws(`select public.learning_create_draft('${map}','${id(219)}')`,'Teacher/authorship not construction authority','42501')}reset role;`;
 q+=`select * from finish();rollback;`;
 const output=sql(q);
 assert.doesNotMatch(output,/^not ok|Looks like you failed/m,output);
 console.log(`C: ${(output.match(/^ok /gm)||[]).length} PostgreSQL assertions PASS; Course ${course}`);
});

test('C cross-course content, prerequisites and shared attribution remain isolated',()=>{
 const bCourse=id(300), bMap=id(301), bVersion=id(302);
 const bStructure={levels:[{id:id(310),slug:'pulse',position:1,title:'Pulse'}],modules:[{id:id(311),slug:'basics',stage_id:id(310),position:1,title:'Basics'}],nodes:[{id:id(312),slug:'exercise',module_id:id(311),position:1,title:'Exercise'}]};
 const bContent={resources:[{id:id(313),slug:'text',revision_id:id(314),kind:'text',title:'Text',content:'Synthetic instruction'}],links:[{id:id(315),node_id:id(312),resource_revision_id:id(314),position:1,purpose:'learn'}],objectives:[{id:id(316),node_id:id(312),objective:'Maintain pulse'}],mappings:[{objective_id:id(316),skill_id:id(140)}],credits:[{id:id(317),contributor_id:id(151),resource_revision_id:id(314),contribution:'author',position:1}]};
 const output=sql(`begin;select no_plan();${setupUsers}set local role authenticated;select set_config('request.jwt.claim.sub','${admin}',true);${setupCourse}
 select public.learning_put_content('${version}',1,'${id(330)}',${json(content)});
 select public.learning_create_course('${bCourse}','other-system','Other System','${bMap}','main');
 select public.learning_create_draft('${bMap}','${bVersion}');
 select public.learning_put_structure('${bVersion}',0,'${id(331)}',${json(bStructure)});
 select throws_ok(${quote(`select public.learning_put_content('${bVersion}',1,'${id(332)}',${json({links:[{id:id(333),node_id:id(312),resource_revision_id:id(110),position:1,purpose:'stolen'}]})})`)},'P0001','learning:invalid_content','cross-course Resource revision denied');
 select throws_ok(${quote(`select public.learning_put_content('${bVersion}',1,'${id(334)}',${json({prerequisites:[{dependent_node_id:id(312),prerequisite_node_id:id(40)}]})})`)},'P0001','learning:invalid_content','cross-course prerequisite denied');
 select is(public.learning_put_content('${bVersion}',1,'${id(335)}',${json(bContent)}),2,'shared Skill/Contributor allowed as metadata only');
 select is(public.learning_freeze_version('${bVersion}',2,'${id(336)}'),3,'different course structure freezes without schema changes');
 reset role;select is((select count(*) from public.learning_node_resources where publication_id='${bVersion}'),1::bigint,'no foreign partial Resource write');
 select * from finish();rollback;`);
 assert.doesNotMatch(output,/^not ok|Looks like you failed/m,output);
 console.log(`C isolation: ${(output.match(/^ok /gm)||[]).length} PostgreSQL assertions PASS`);
});
