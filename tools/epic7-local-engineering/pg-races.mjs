import assert from 'node:assert/strict';
import {mkdirSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {open,record} from './pg-local.mjs';
import {compileCase} from './compile.mjs';
import {observe,asActor,executeSteps} from './pg-cases.mjs';
import {reconcileCommitted} from './observe.mjs';
import {candidate} from './schema.mjs';
const pause=ms=>new Promise(r=>setTimeout(r,ms));
export async function race(file,id,dir){
 const plan=compileCase(id),start=new Date().toISOString();record(dir,id+'-plan',plan);
 const setup=await open(file),first=await open(file),second=await open(file),watch=await open(file);
 let before,after,confirmation,result,stop=null,events=[],committed=false;
 const rpc=q=>({text:'select public.'+q.rpc+'('+q.args.map((_,i)=>'$'+(i+1)+'::'+(['uuid','integer','uuid','jsonb'][i])).join(',')+') as value',values:q.args});
 try{
  before=await observe(file,plan,setup.identity.pid,false);
  await setup.raw('begin');events=await executeSteps(setup,plan);await setup.raw('commit');committed=true;await setup.close();
  await first.raw('begin');await asActor(first,plan,'admin');
  const winner=await first.query(rpc(plan.races.first));assert.equal(winner[0].value,3);
  await second.raw('begin');await asActor(second,plan,'admin');
  const waiting=second.query(rpc(plan.races.second)).then(rows=>({rows}),e=>({code:e.code,message:e.message}));
  let blocked=false;
  for(let i=0;i<20;i++){const rows=await watch.query({text:'select $1::int=any(pg_blocking_pids($2::int)) as blocked',values:[first.identity.pid,second.identity.pid]});if(rows[0].blocked){blocked=true;break;}await pause(20);}
  assert.ok(blocked,'LOCK_BARRIER_NOT_OBSERVED');events.push({barrier:'PG_BLOCKING_PIDS',writer:first.identity.pid,waiter:second.identity.pid});
  await first.raw('commit');const loser=await waiting;
  if(id==='R02'){assert.deepEqual(loser.rows,winner);await second.raw('commit');}
  else{assert.equal(loser.message,plan.races.expected[1]);await second.raw('rollback');}
  await first.close();await second.close();await watch.close();
  after=await observe(file,plan,setup.identity.pid,true);confirmation=await observe(file,plan,setup.identity.pid,true);
  result=reconcileCommitted(plan,before,after,confirmation,setup.identity.pid);assert.equal(result.status,'PASS',JSON.stringify(result.stop));
 }catch(e){stop={reason:e.code??e.message};}
 finally{for(const s of [setup,first,second,watch])try{await s.close();}catch{stop??={reason:'CLOSE_FAILED'};}}
 if(!after&&before){try{after=await observe(file,plan,setup.identity.pid,true);confirmation=await observe(file,plan,setup.identity.pid,true);result=reconcileCommitted(plan,before,after,confirmation,setup.identity.pid);}catch{stop??={reason:'OBSERVER_FAILED'};}}
 record(dir,id,{runId:plan.runId,candidate,caseId:id,fixtureManifestHash:plan.planHash,start,end:new Date().toISOString(),identity:first.identity,result:stop?'FAIL':'PASS',stop,committed,events,before,after,confirmation,residue:result,retention:'OWNED_ISOLATED_CONTAINER_ONLY; NO_DELETE',remote:'NOT RUN'});
 console.log(JSON.stringify({caseId:id,result:stop?'FAIL':'PASS',stop}));if(stop)throw Error('RACE_STOP');
}
if(process.argv[2]==='--races'){const dir='artifacts/remote-smoke/epic7-pg-races-'+randomUUID();mkdirSync(dir,{recursive:true});console.log(dir);for(const id of process.argv.slice(4))await race(process.argv[3],id,dir);}
