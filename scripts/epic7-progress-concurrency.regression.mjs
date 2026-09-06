// Explicit node:test disposable-database race suite, not a Vitest unit suite.
import assert from 'node:assert/strict';
import test from 'node:test';
import {sql,session,database} from './epic7-local-db.mjs';
import {id,studentA,course,version,auth} from './epic7-fixtures.mjs';

test('two-session progress revisions and request identity are serialized',async()=>{
 assert.equal(database,'epic7_race_20260906');
 // Committed only in this disposable test database so independent sessions see it.
 const signature='private.learning_course_use_authorized(p_actor uuid,p_course uuid,p_version uuid,p_node uuid)';
 sql(`create or replace function ${signature} returns boolean language sql stable set search_path='' as $$ select p_actor='${studentA}'::uuid and p_course='${course}'::uuid; $$;`);
 let pending;
 const hold=async(body)=>{
  pending=session(`set application_name='epic7-progress-held';${auth(studentA,body+';select pg_sleep(2)')}`);
  for(let i=0;i<100;i++){
   if(sql("select count(*) from pg_stat_activity where application_name='epic7-progress-held' and wait_event='PgSleep'").trim()==='1')return;
   await new Promise(r=>setTimeout(r,20));
  }
  throw new Error('Progress lock barrier not reached');
 };
 const set=(node,revision,key,patch)=>`select public.learning_set_activity('${version}','${id(node)}',${revision},'${id(key)}','${JSON.stringify(patch)}'::jsonb)`;
 try {
  const first=set(40,0,900,{self_completed:true});
  await hold(first);
  const stale=await session(auth(studentA,set(40,0,901,{self_completed:false})));
  assert.equal((await pending).code,0);assert.notEqual(stale.code,0);assert.match(stale.output,/learning:revision_conflict/);
  sql(auth(studentA,set(40,1,902,{self_completed:false})));
  await hold(first);
  const repeat=await session(auth(studentA,first));
  assert.equal((await pending).code,0);assert.equal(repeat.code,0,repeat.output);
  assert.equal(sql(`select revision||':'||self_completed from public.learning_self_activity where subject_id='${studentA}' and publication_id='${version}' and node_id='${id(40)}'`).trim(),'2:false');
  await hold(set(41,0,903,{opened:true}));
  const otherNode=await session(auth(studentA,set(42,0,903,{opened:true})));
  assert.equal((await pending).code,0);assert.notEqual(otherNode.code,0);assert.match(otherNode.output,/learning:idempotency_conflict/);
  assert.equal(sql(`select count(*) from public.learning_self_activity where subject_id='${studentA}' and node_id='${id(42)}'`).trim(),'0');
  console.log('PASS: competing initial writes; exact stale retries preserve correction; cross-Node key race leaves no partial write');
 } finally {
  if(pending)await pending;
  sql(`create or replace function ${signature} returns boolean language sql stable set search_path='' as $$ select false; $$;`);
 }
 assert.equal(sql(`select private.learning_course_use_authorized('${studentA}','${course}','${version}','${id(40)}')`).trim(),'f');
});
