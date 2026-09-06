import test from 'node:test';
import assert from 'node:assert/strict';
import {sql} from './epic7-local-db.mjs';
import {setupUsers,admin,superAdmin,course,map,id,structure,json,version,setupCourse,quote} from './epic7-fixtures.mjs';
test('S02/S03/H03/H04/H05/C08: runtime role and construction boundaries',()=>{
 if(!process.env.EPIC7_F_TARGET_MANIFEST)throw Error('Requires this task isolated manifest');
 let q=`begin;select no_plan();${setupUsers}set local role authenticated;select set_config('request.jwt.claim.sub','${admin}',true);${setupCourse}reset role;`;
 for(const role of ['anon','authenticated','service_role']){
 q+=`set local role ${role};`;
 for(const statement of ['select * from public.learning_nodes',"insert into public.learning_nodes(id,course_id,slug) values(gen_random_uuid(),gen_random_uuid(),'forbidden')",'select private.learning_require_admin()'])q+=`select throws_ok(${quote(statement)},'42501',null,'${role} rejects raw/private access');`;
 q+=`select ok(not has_table_privilege('${role}','public.learning_nodes','TRUNCATE'),'${role} TRUNCATE denied without executing it');reset role;`;
 }
 q+=`set local role authenticated;select set_config('request.jwt.claim.sub','${admin}',true);
 select throws_ok(${quote(`select public.learning_put_structure('${version}',1,'${id(200)}','{}')`)},'P0001','learning:idempotency_conflict','H05 construction key binds exact payload');
 select is(public.learning_put_structure('${version}',1,'${id(980)}',${json({...structure,nodes:structure.nodes.map((n,k)=>({...n,position:k===0?2:k===1?1:n.position}))})}),2,'H03 valid sibling reorder succeeds');reset role;
 select is((select position from public.learning_node_versions where publication_id='${version}' and id='${id(40)}'),2,'H03 reordered Node position persisted within transaction');
 set local role authenticated;select set_config('request.jwt.claim.sub','${admin}',true);
 select is(public.learning_put_content('${version}',2,'${id(981)}',${json({capabilities:['submission','async_review','verification','assessment'].map((code,k)=>({id:id(982+k),node_id:id(40),code,description:'Synthetic metadata only'}))})}),3,'C08 all four descriptor codes accepted');reset role;
 select is((select count(*) from public.learning_capabilities),4::bigint,'C08 four descriptors, no workflow authority');
 set local role authenticated;select set_config('request.jwt.claim.sub','${superAdmin}',true);
 select throws_ok(${quote(`select public.learning_create_course('${course}','guitar-roadmap-fixture','Guitar Roadmap fixture','${map}','main')`)},'P0001','learning:idempotency_conflict','H04 different actor cannot reuse creation identity');reset role;`;
 q+=`update public.profiles set account_status='suspended' where user_id='${admin}';set local role authenticated;select set_config('request.jwt.claim.sub','${admin}',true);
 select throws_ok(${quote(`select public.learning_inspect_version('${version}')`)},'42501',null,'inactive Admin rejected');reset role;
 select * from finish();rollback;`;
 const output=sql(q);assert.doesNotMatch(output,/^not ok|Looks like you failed/m,output);assert.match(output,/1\.\.19/);console.log('S02/S03/H03/H04/H05/C08: 19 runtime/privilege assertions PASS');
});
