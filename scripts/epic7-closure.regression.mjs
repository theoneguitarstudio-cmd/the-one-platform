import assert from 'node:assert/strict';
import test from 'node:test';
import {sql} from './epic7-local-db.mjs';
import {id,admin,version,quote,json,setupUsers,setupCourse,content,structure} from './epic7-fixtures.mjs';
const start=`begin;select no_plan();${setupUsers}set local role authenticated;select set_config('request.jwt.claim.sub','${admin}',true);${setupCourse}`;
function check(q,label){const output=sql(q+'select * from finish();rollback;');assert.doesNotMatch(output,/^not ok|Looks like you failed/m,output);console.log(`${label}: ${(output.match(/^ok /gm)||[]).length} PostgreSQL assertions PASS`);}

test('ordered draft constraints reject duplicate positions and graph self edges atomically',()=>{
 check(`${start}
 select throws_ok(${quote(`select public.learning_put_structure('${version}',1,'${id(960)}',${json({levels:[],modules:[],nodes:[{...structure.nodes[0],id:id(961),slug:'duplicate-position'}]})})`)},'P0001','learning:invalid_structure','duplicate sibling position rejected');
 select throws_ok(${quote(`select public.learning_put_content('${version}',1,'${id(962)}',${json({prerequisites:[{dependent_node_id:id(40),prerequisite_node_id:id(40)}]})})`)},'P0001',null,'graph self-edge rejected');
 reset role;select is((select count(*) from public.learning_nodes where id='${id(961)}'),0::bigint,'invalid placement leaves no identity row');
 select is((select revision from public.curriculum_publications where id='${version}'),1,'invalid mutations leave revision unchanged');`,'Draft integrity');
});

test('every frozen relation rejects INSERT UPDATE DELETE, including privileged owner paths',()=>{
 let q=`${start}select public.learning_put_content('${version}',1,'${id(950)}',${json(content)});select public.learning_freeze_version('${version}',2,'${id(951)}');reset role;`;
 for(const t of ['curriculum_stage_versions','learning_module_versions','learning_node_versions','learning_node_resources','learning_objective_versions','learning_objective_skills','learning_node_prerequisites','learning_author_credits','learning_node_capability_attachments']){
  for(const mutation of [`insert into public.${t} select * from public.${t} where publication_id='${version}'`,`update public.${t} set publication_id=publication_id where publication_id='${version}'`,`delete from public.${t} where publication_id='${version}'`]){
   q+=`select throws_ok(${quote(mutation)},'P0001','learning:immutable_version',${quote(t+' frozen mutation rejected')});`;
  }
 }
 check(q,'Frozen mutation matrix');
});
for(const [label,partial] of [['Objective without Resource',{objectives:content.objectives}],['Resource without Objective',{...content,objectives:[],mappings:[]}]] ){
 test(label+' cannot freeze',()=>check(`${start}select public.learning_put_content('${version}',1,'${id(952)}',${json(partial)});
 select throws_ok(${quote(`select public.learning_freeze_version('${version}',2,'${id(953)}')`)},'P0001','learning:incomplete_curriculum',${quote(label+' is incomplete')});`,'Independent completeness'));
}
test('freeze independently detects a corrupted graph and rolls back its receipt',()=>{
 // Simulate corruption only as owner inside this rolled-back local fixture.
 // Application roles can neither disable triggers nor insert these raw edges.
 check(`${start}select public.learning_put_content('${version}',1,'${id(954)}',${json(content)});reset role;
 alter table public.learning_node_prerequisites disable trigger learning_prerequisites_dag;
 insert into public.learning_node_prerequisites(publication_id,dependent_node_id,prerequisite_node_id,rationale) values('${version}','${id(40)}','${id(41)}','test-only corruption');
 alter table public.learning_node_prerequisites enable trigger learning_prerequisites_dag;
 set local role authenticated;select set_config('request.jwt.claim.sub','${admin}',true);
 select throws_ok(${quote(`select public.learning_freeze_version('${version}',2,'${id(955)}')`)},'P0001','learning:prerequisite_cycle','freeze validates entire graph');
 reset role;select is((select revision from public.curriculum_publications where id='${version}'),2,'failed freeze revision rolled back');
 select is((select count(*) from public.learning_mutation_receipts where request_id='${id(955)}'),0::bigint,'failed freeze receipt rolled back');`,'Freeze graph validation');
});
