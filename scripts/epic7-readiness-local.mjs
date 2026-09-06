// Explicit local-only adapter. Docker Unix socket inside a newly owned container;
// never a URL/client/tunnel. Existing development databases are not targets.
import {execFileSync,spawn} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {candidate} from './epic7-readiness.mjs';
export const host='npipe:////./pipe/docker_engine';
export const image='sha256:b3bfedb107413abb3b8cb0d0874b0414a1dceb3d55bc0c778de6ad22d1f7dc86';
export function validateDatabaseIdentity(m,value){if(value!==`postgres:${m.runId}:/tmp/epic7-f-data`)throw Error('Database environment marker mismatch');}
export const cleanEnv=()=>Object.fromEntries(Object.entries(process.env).filter(([k])=>['PATH','SYSTEMROOT','WINDIR','TEMP','TMP','COMSPEC','PATHEXT','USERPROFILE','LOCALAPPDATA','APPDATA'].includes(k.toUpperCase())));
export function docker(args,input){return execFileSync('docker',['--host',host,...args],{input,encoding:'utf8',env:cleanEnv(),timeout:args.includes('psql')?600000:60000,maxBuffer:32*1024*1024});}
export function validateTarget(m,i){
 if(m?.kind!=='epic7-f-synthetic-local'||m.candidate!==candidate||!/^[a-f0-9]{32}$/.test(m.runId)||!/^[a-f0-9]{64}$/.test(m.containerId)||m.image!==image||m.database!=='epic7_race_20260906')throw Error('Invalid synthetic target manifest');
 if(i.Id!==m.containerId||i.Image!==image||i.Name!=='/epic7-f-'+m.runId||i.Config?.Labels?.['theone.epic7-f']!==m.runId||i.HostConfig?.NetworkMode!=='none'||Object.keys(i.HostConfig?.PortBindings??{}).length||i.Mounts?.length||!i.State?.Running)throw Error('Container identity/isolation mismatch');
 if(i.Config?.Entrypoint?.join(' ')!=='/bin/bash'||i.Config?.Cmd?.join(' ')!=='-c sleep infinity')throw Error('Unexpected container process');
 return m;
}
export function attest(file){const m=JSON.parse(readFileSync(file,'utf8'));
 // Reject malformed IDs before invoking Docker, so arbitrary target strings never reach it.
 if(!/^[a-f0-9]{64}$/.test(m.containerId??''))throw Error('Invalid target ID');
 return validateTarget(m,JSON.parse(docker(['inspect',m.containerId]))[0]);
}
export function guarded(file){const m=attest(file);
 const sql=(q,db=m.database)=>{
  if(![m.database,'postgres'].includes(db))throw Error('Database outside manifest');attest(file);
  return docker(['exec','-i',m.containerId,'psql','-h','/tmp','-X','-U','postgres','-d',db,'-v','ON_ERROR_STOP=1','-At'],"set statement_timeout='120s';set lock_timeout='10s';"+q).replace(/^SET\r?\nSET\r?\n/,'');
 };
 const identity=()=>validateDatabaseIdentity(m,sql("select current_database()||':'||current_setting('epic7_f.run_id')||':'||current_setting('data_directory')",'postgres').trim());
 identity();
 return {container:m.containerId,database:m.database,sql,session(q){attest(file);identity();return new Promise((resolve,reject)=>{
  const c=spawn('docker',['--host',host,'exec','-i',m.containerId,'psql','-h','/tmp','-X','-U','postgres','-d',m.database,'-v','ON_ERROR_STOP=1','-At'],{env:cleanEnv(),stdio:['pipe','pipe','pipe']});let output='';let timedOut=false;
  const timer=setTimeout(()=>{timedOut=true;c.kill();},30000);c.stdout.on('data',d=>output+=d);c.stderr.on('data',d=>output+=d);c.on('error',e=>{clearTimeout(timer);reject(e);});c.on('close',code=>{clearTimeout(timer);resolve({code:timedOut?124:code,output});});c.stdin.end("set statement_timeout='20s';set lock_timeout='10s';"+q);
 });}};
}
export async function runLocal(file){const a=guarded(file);return {mode:'local identity check',container:a.container,database:a.database,remoteExecution:false};}
