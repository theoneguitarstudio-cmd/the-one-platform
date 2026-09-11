import { spawn, execFileSync } from 'node:child_process';
import { resolve } from 'node:path';

const branch = execFileSync('git',['branch','--show-current'],{encoding:'utf8'}).trim();
if(branch !== 'preview-test') throw new Error('Local UX development requires preview-test. No branch is changed by this script.');
const env = {...process.env, NODE_ENV:'development', NEXT_TELEMETRY_DISABLED:'1',
  THE_ONE_LOCAL_EXPERIENCE:'1',
  NEXT_PUBLIC_SUPABASE_URL:'http://127.0.0.1:9',
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'local-ux-placeholder-not-a-credential',
  SUPABASE_SERVICE_ROLE_KEY:'local-ux-placeholder-not-a-credential',
  NEXT_PUBLIC_SITE_URL:'http://127.0.0.1:3100'};
const child = spawn(process.execPath,[resolve('node_modules/next/dist/bin/next'),'dev','--webpack','--hostname','127.0.0.1','--port','3100'],{env,stdio:'inherit',windowsHide:true});
child.on('exit',code=>{process.exitCode=code??1});
child.on('error',error=>{console.error(error.message);process.exitCode=1});
