// Disposable source copy: no .env, credentials, Git mutation, install or deployment.
import {mkdirSync,copyFileSync,symlinkSync,writeFileSync,readFileSync} from 'node:fs';
import {execFileSync,spawnSync} from 'node:child_process';
import {resolve,dirname} from 'node:path';
import {randomBytes} from 'node:crypto';
import {root,candidate,hash,validate} from './epic7-readiness.mjs';
import {cleanEnv} from './epic7-readiness-local.mjs';
if(process.argv[2]!=='--isolated-copy'||process.argv.length!==3)throw Error('Requires --isolated-copy');
if(validate().validation!=='PASS')throw Error('Candidate mismatch');
const output=resolve(root,'artifacts/remote-smoke/epic7-f-build-'+randomBytes(8).toString('hex'));
const work=resolve(output,'source');mkdirSync(work,{recursive:true});
const files=execFileSync('git',['ls-files','-z'],{cwd:root,encoding:'utf8'}).split('\0').filter(Boolean);
for(const f of files){if(f.split('/').some(x=>x.startsWith('.env'))||f.startsWith('artifacts/'))continue;const target=resolve(work,f);mkdirSync(dirname(target),{recursive:true});copyFileSync(resolve(root,f),target);}
symlinkSync(resolve(root,'node_modules'),resolve(work,'node_modules'),'junction');
const pnpm=resolve(root,'artifacts/remote-smoke/epic7-f-pnpm-10.34.5/package/bin/pnpm.cjs');
const env={...cleanEnv(),CI:'1',NEXT_TELEMETRY_DISABLED:'1',NEXT_PUBLIC_SUPABASE_URL:'https://synthetic.invalid',NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'synthetic-test-publishable-key-not-a-credential',SUPABASE_SERVICE_ROLE_KEY:'synthetic-test-service-role-not-a-credential',NEXT_PUBLIC_SITE_URL:'https://synthetic.invalid',PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS:'false'};
const version=execFileSync(process.execPath,[pnpm,'--version'],{env,encoding:'utf8',cwd:work}).trim();if(version!=='10.34.5')throw Error('Pinned pnpm mismatch');
const results=[];
for(const [name,args]of [['application-tests',['run','test']],['lint',['run','lint']],['typegen',['exec','next','typegen']],['typecheck',['run','typecheck']],['turbopack',['exec','next','build']],['webpack',['exec','next','build','--webpack']]]){
 const r=spawnSync(process.execPath,[pnpm,...args],{cwd:work,env,encoding:'utf8',timeout:240000,maxBuffer:16*1024*1024});
 const log=(r.stdout??'')+'\n'+(r.stderr??'');writeFileSync(resolve(output,name+'.log'),log);
 results.push({name,command:'pnpm '+args.join(' '),exit:r.status,error:r.error?.code,signal:r.signal,sha256:hash(log)});
 console.log(JSON.stringify(results.at(-1)));
}
// Next may generate types only inside disposable source. Candidate files stay intact.
const manifest={candidate,uncommittedToolSHA256:hash(readFileSync(new URL(import.meta.url))),node:process.version,nodeExecutable:process.execPath,pnpm:version,next:JSON.parse(readFileSync(resolve(work,'node_modules/next/package.json'))).version,sourceEnvironmentFiles:false,credentials:'synthetic invalid placeholders only',network:'public Google Fonts may be requested; no valid production credentials or production DB endpoint supplied',sourceFiles:files.filter(f=>!f.split('/').some(x=>x.startsWith('.env'))&&!f.startsWith('artifacts/')).map(f=>({file:f,sha256:hash(readFileSync(resolve(root,f)))})),results};
writeFileSync(resolve(output,'result.json'),JSON.stringify(manifest,null,2));console.log(output);
if(results.some(r=>r.exit!==0))process.exitCode=1;
