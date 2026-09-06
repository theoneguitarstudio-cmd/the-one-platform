// Offline manifest validation. No database/process/network imports or env-file fallback.
import {readFileSync, existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

export const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
export const candidate='d5f98434106797afc65c59953aa3bc61ba26ecb4';
export const migrations={
 '20260906000100_learning_course_versions.sql':'ea13b605b7d0fc54a237ef2c901c9ccb35f41c0bb9e8e0a58af591c6ac2ac8fb',
 '20260906000200_learning_hierarchy.sql':'20ab7f8114f9d8d1b352275494b8f31f5c6151ab1cb8df8b587dbee8a75e2a55',
 '20260906000300_learning_content_freeze.sql':'9e5c2253bbcafce4661ab5ae6f5017866a07a320fe02b206b32c91785db1c2f8',
 '20260906000400_learning_self_activity.sql':'64d9d2eeed9f049f1e129552c1261457ed70404ba70e57cb02e57456ec555af0',
 '20260906000500_learning_freeze_graph_validation.sql':'89c671af5ba816029f4d2de8a6e8a6c222e8de69589d6dd70026b117d965d103',
};
export const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
export function readHead(read=readFileSync){
 const h=read(resolve(root,'.git/HEAD'),'utf8').trim();
 if(!h.startsWith('ref: ')) return h;
 const ref=h.slice(5);if(!/^refs\/heads\/[\w/-]+$/.test(ref)||ref.includes('..'))throw Error('Invalid Git ref');
 try{return read(resolve(root,'.git',ref),'utf8').trim();}catch{
  return read(resolve(root,'.git/packed-refs'),'utf8').split('\n').find(x=>x.endsWith(' '+ref))?.split(' ')[0];
 }
}
export function validate({head=readHead(), read=readFileSync, exists=existsSync}={}){
 const errors=[];if(head!==candidate)errors.push('Candidate HEAD mismatch');
 for(const [file,digest]of Object.entries(migrations))if(hash(read(resolve(root,'supabase/migrations',file)))!==digest)errors.push('Migration hash mismatch: '+file);
 const cases=JSON.parse(read(resolve(root,'scripts/epic7-readiness-cases.json'),'utf8'));
 const plan=read(resolve(root,'docs/EPIC7_REMOTE_SMOKE_PLAN.md'),'utf8');
 const ids=[...plan.matchAll(/^\| ([SCHGVPRL]\d{2}) \|/gm)].map(m=>m[1]);
 if(cases.length!==37||new Set(ids).size!==37||JSON.stringify(cases.map(c=>c.id))!==JSON.stringify(ids))errors.push('37-case coverage mismatch');
 for(const c of cases){for(const k of ['id','purpose','prerequisite','role','localSource','remoteMethod','retention','approval','sideEffects'])if(!c[k])errors.push(c.id+' missing '+k);
  if(!exists(resolve(root,c.localSource)))errors.push(c.id+' evidence source absent');
  if(c.remoteStatus!=='REMOTE NOT RUN'||c.approvedDeferral!==false)errors.push(c.id+' unauthorized status promotion');
 }
 return {mode:'ValidateOnly',validation:errors.length?'FAIL':'PASS',candidate,cases:cases.length,errors,executionAllowed:false,authorization:'NOT AUTHORIZED',databaseConnections:0,sql:0,network:0};
}
export async function main(args,adapters={}){
 if(args.length===0||JSON.stringify(args)===JSON.stringify(['--validate-only']))return validate(adapters.validation);
 if(args[0]==='--production')throw Error('Production execution unavailable: target/SHA/hash/recovery/case/retention/operator gates require separate reviewed authorization; no production adapter exists');
 if(args.length!==2||args[0]!=='--local-manifest')throw Error('Only --validate-only or --local-manifest FILE; --yes/remote URLs are not accepted');
 const report=validate(adapters.validation);if(report.validation!=='PASS')throw Error(report.errors.join('; '));
 const local=adapters.loadLocal?await adapters.loadLocal():await import('./epic7-readiness-local.mjs');
 return local.runLocal(args[1]);
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 main(process.argv.slice(2)).then(r=>{console.log(JSON.stringify(r,null,2));if(r.validation==='FAIL')process.exitCode=1;}).catch(e=>{console.error(e.message);process.exitCode=1;});
}
