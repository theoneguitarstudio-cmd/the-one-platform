import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {main,validate,candidate} from './epic7-readiness.mjs';
import {validateTarget,validateDatabaseIdentity,image} from './epic7-readiness-local.mjs';
const m={kind:'epic7-f-synthetic-local',candidate,runId:'a'.repeat(32),containerId:'b'.repeat(64),image,database:'epic7_race_20260906'};
const i={Id:m.containerId,Image:image,Name:'/epic7-f-'+m.runId,Config:{Labels:{'theone.epic7-f':m.runId},Entrypoint:['/bin/bash'],Cmd:['-c','sleep infinity']},HostConfig:{NetworkMode:'none',PortBindings:{}},Mounts:[],State:{Running:true}};
test('real offline CLI under socket/process/env-file tripwires',()=>{
 const output=execFileSync(process.execPath,['--import','./scripts/epic7-readiness-offline-tripwire.mjs','scripts/epic7-readiness.mjs','--validate-only'],{encoding:'utf8'});
 assert.equal(JSON.parse(output).validation,'PASS');
});
test('ValidateOnly and default never load local adapter or execute side effects',async()=>{
 let loads=0;const calls=[];const adapter={loadLocal(){loads++;throw Error('MUST NOT LOAD')},validation:{read(p,...args){calls.push(String(p));assert(!/\.env/.test(String(p)));return readFileSync(p,...args)}}};
 for(const args of [[],['--validate-only']]){const r=await main(args,adapter);assert.equal(r.validation,'PASS');assert.equal(r.executionAllowed,false);assert.equal(r.databaseConnections+r.network+r.sql,0);}
 assert.equal(loads,0);assert(calls.length>0);
});
for(const args of [['--yes'],['--local'],['--linked'],['--db-url','postgres://localhost/x'],['--validate-only','--yes'],['--production'],['--production','--yes']])test('fail closed '+args.join(' '),async()=>{let loads=0;await assert.rejects(main(args,{loadLocal(){loads++;}}));assert.equal(loads,0);});
test('hash mismatch and HEAD mismatch do not execute',()=>{
 assert.equal(validate({head:'0'.repeat(40)}).validation,'FAIL');
 assert.equal(validate({read(p,...a){return String(p).endsWith('.sql')?Buffer.from('tamper'):readFileSync(p,...a)}}).validation,'FAIL');
});
test('missing source evidence and truncated/altered case manifest fail',()=>{
 assert.equal(validate({exists:()=>false}).validation,'FAIL');
 assert.equal(validate({read(p,...a){if(String(p).endsWith('cases.json'))return '[]';return readFileSync(p,...a)}}).validation,'FAIL');
});
test('only exact attested isolated target accepted',()=>assert.deepEqual(validateTarget(m,i),m));
test('actual DB marker and data directory must match, not merely localhost',()=>{
 validateDatabaseIdentity(m,`postgres:${m.runId}:/tmp/epic7-f-data`);
 for(const value of ['localhost','postgres:wrong:/tmp/epic7-f-data',`postgres:${m.runId}:/var/lib/postgresql/data`,`production:${m.runId}:/tmp/epic7-f-data`])assert.throws(()=>validateDatabaseIdentity(m,value));
});
for(const [name,change]of Object.entries({remoteHost:x=>x.HostConfig.NetworkMode='host',bridge:x=>x.HostConfig.NetworkMode='bridge',tunnel:x=>x.HostConfig.PortBindings={'5432/tcp':[{}]},bindMount:x=>x.Mounts=[{Type:'bind'}],wrongId:x=>x.Id='c'.repeat(64),wrongImage:x=>x.Image='other',wrongLabel:x=>x.Config.Labels={},existingName:x=>x.Name='/supabase_db_the-one-platform',stopped:x=>x.State.Running=false,unexpectedProcess:x=>x.Config.Cmd=['postgres']}))test('reject target '+name,()=>{const copy=structuredClone(i);change(copy);assert.throws(()=>validateTarget(m,copy));});
for(const field of ['kind','candidate','runId','containerId','image','database'])test('reject forged manifest '+field,()=>assert.throws(()=>validateTarget({...m,[field]:'production'},i)));
