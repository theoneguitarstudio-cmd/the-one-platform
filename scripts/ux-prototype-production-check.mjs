// Starts only the isolated local build, probes prototype paths, then stops its own process.
import { spawn, execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
if (execFileSync('git', ['branch', '--show-current'], {encoding:'utf8'}).trim() !== 'preview-test') throw new Error('Requires preview-test.');
const env = {...process.env, THE_ONE_UX_BUILD_CHECK:'1', NODE_ENV:'production', NEXT_TELEMETRY_DISABLED:'1',
  NEXT_PUBLIC_SUPABASE_URL:'http://127.0.0.1:9', NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'local-ux-placeholder-not-a-credential',
  SUPABASE_SERVICE_ROLE_KEY:'local-ux-placeholder-not-a-credential'};
// 3101–3200 is reserved by Windows on this host. Keep the probe on loopback.
const probePort = 4101;
const child = spawn(process.execPath, ['node_modules/next/dist/bin/next','start','--hostname','127.0.0.1','--port',String(probePort)], {env,windowsHide:true});
let output=''; let ready;
const started = new Promise((resolve,reject)=>{ready=resolve;child.once('error',reject);child.once('exit',code=>reject(new Error(`Server exited ${code}: ${output.slice(-600)}`)))});
const collect = data=>{output+=data; if(output.includes('Ready in')) ready();};
child.stdout.on('data',collect);child.stderr.on('data',collect);
const timeout=setTimeout(()=>child.kill(),30000);
try {
  await started;
  const probes=[];
  for(const path of ['/ux-prototype','/ux-prototype/teacher','/ux-prototype/admin','/ux-prototype/student']) {
    const response=await fetch(`http://127.0.0.1:${probePort}${path}`);
    probes.push({path,status:response.status,body:await response.text()});
    if(response.status!==404) throw new Error(`Prototype exposed in production: ${path}`);
  }
  const dev=await fetch('http://127.0.0.1:3100/ux-prototype');
  const devResult={status:dev.status,csp:dev.headers.get('content-security-policy'),robots:dev.headers.get('x-robots-tag'),cache:dev.headers.get('cache-control')};
  if(devResult.status!==200||!devResult.csp?.includes("connect-src 'self'")||devResult.robots!=='noindex, nofollow')throw new Error('Development isolation headers missing.');
  const report={production:probes,development:devResult,networkScope:`Only 127.0.0.1:3100 and 127.0.0.1:${probePort} were requested by this check.`};
  writeFileSync('artifacts/ux-prototype/production-isolation.json',JSON.stringify(report,null,2));
  console.log(JSON.stringify(report,null,2));
} finally {clearTimeout(timeout);child.kill();}
