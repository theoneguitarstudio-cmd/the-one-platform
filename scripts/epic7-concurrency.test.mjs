import assert from 'node:assert/strict';
import test from 'node:test';
import {sql,session,database} from './epic7-local-db.mjs';
import {id,admin,version,map,auth,json,setupUsers,setupCourse,structure,content} from './epic7-fixtures.mjs';

test('real independent PostgreSQL sessions serialize DAG, freeze and edit',async()=>{
 assert.equal(database,'epic7_race_20260906','Concurrency fixtures require the disposable race database');
 sql(setupUsers);sql(auth(admin,setupCourse));
 sql(auth(admin,`select public.learning_put_content('${version}',1,'${id(700)}',${json({...content,prerequisites:[]})})`));
 const edge={prerequisites:[{dependent_node_id:id(41),prerequisite_node_id:id(40)}]};
 const inverse={prerequisites:[{dependent_node_id:id(40),prerequisite_node_id:id(41)}]};
 // Wait until the actual database session holds the version lock, not a guessed delay.
 // Returning the Promise from an async helper would await transaction completion.
 // Store it separately so both sessions overlap after the lock barrier.
 let pending;
 const hold = async(body)=>{
  pending=session(`set application_name='epic7-held';${auth(admin,body+';select pg_sleep(2)')}`);
  for(let n=0;n<100;n++){
   if(sql("select count(*) from pg_stat_activity where application_name='epic7-held' and wait_event='PgSleep'").trim()==='1')return;
   await new Promise(resolve=>setTimeout(resolve,20));
  }
  throw new Error('Session barrier did not arrive');
 };
 await hold(`select public.learning_put_content('${version}',2,'${id(701)}',${json(edge)})`);
 const inverseResult=await session(auth(admin,`select public.learning_put_content('${version}',3,'${id(702)}',${json(inverse)})`));
 assert.equal((await pending).code,0);assert.notEqual(inverseResult.code,0);assert.match(inverseResult.output,/learning:prerequisite_cycle/);
 assert.equal(sql(`select count(*) from public.learning_node_prerequisites where publication_id='${version}'`).trim(),'1');
 await hold(`select public.learning_freeze_version('${version}',3,'${id(703)}')`);
 const retry=await session(auth(admin,`select public.learning_freeze_version('${version}',3,'${id(703)}')`));
 assert.equal((await pending).code,0);assert.equal(retry.code,0,retry.output);
 assert.equal(sql(`select count(*) from public.audit_logs where target_id='${version}' and action='learning.freeze'`).trim(),'1');
 const second=id(710);sql(auth(admin,`select public.learning_create_draft('${map}','${second}');select public.learning_put_structure('${second}',0,'${id(711)}',${json(structure)});select public.learning_put_content('${second}',1,'${id(712)}',${json(content)})`));
 await hold(`select public.learning_freeze_version('${second}',2,'${id(713)}')`);
 const edit=await session(auth(admin,`select public.learning_put_structure('${second}',2,'${id(714)}',${json(structure)})`));
 assert.equal((await pending).code,0);assert.notEqual(edit.code,0);assert.match(edit.output,/learning:immutable_version/);
 console.log('PASS: inverse-edge race; freeze retry exactly once; freeze versus edit; no partial writes');
});
