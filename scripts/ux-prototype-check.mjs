// Local checks only: direct installed tools, no package install or remote services.
import { spawn, execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
const mode = process.argv[2];
const commands = {
  test: ['node_modules/vitest/vitest.mjs', 'run', '--exclude', 'scripts/epic7-preserved-validation.test.mjs'],
  'legacy-guard': ['--test', 'scripts/epic7-preserved-validation.test.mjs'],
  lint: ['node_modules/eslint/bin/eslint.js', 'src', 'tests', 'scripts/ux-prototype-*.mjs', 'next.config.ts'],
  typecheck: ['node_modules/typescript/bin/tsc', '--noEmit', '--pretty', 'false'],
  build: ['node_modules/next/dist/bin/next', 'build', '--webpack'],
};
if (!commands[mode]) throw new Error('Use test, legacy-guard, lint, typecheck or build.');
if (execFileSync('git', ['branch', '--show-current'], {encoding:'utf8'}).trim() !== 'preview-test') throw new Error('Checks require preview-test.');
const env = {...process.env, NEXT_TELEMETRY_DISABLED:'1',
  NEXT_PUBLIC_SUPABASE_URL:'http://127.0.0.1:9', NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'local-ux-placeholder-not-a-credential',
  SUPABASE_SERVICE_ROLE_KEY:'local-ux-placeholder-not-a-credential', NEXT_PUBLIC_SITE_URL:'http://127.0.0.1:3100'};
if (mode === 'build') { env.THE_ONE_UX_BUILD_CHECK='1'; env.NODE_ENV='production'; }
const originals = mode === 'build' ? ['tsconfig.json','next-env.d.ts'].map(path=>[path,readFileSync(path)]) : [];
mkdirSync('artifacts/ux-prototype', {recursive:true});
const child = spawn(process.execPath,commands[mode],{env,windowsHide:true});
let log='';
child.stdout.on('data',chunk=>{log+=chunk;process.stdout.write(chunk)});
child.stderr.on('data',chunk=>{log+=chunk;process.stderr.write(chunk)});
child.on('exit',code=>{
  // Next rewrites generated type-path hints for the temporary build directory.
  // Restore the dev server's exact pre-check hints; application files are not touched.
  for(const [path,bytes] of originals) writeFileSync(path,bytes);
  writeFileSync(`artifacts/ux-prototype/${mode}.log`,log+`\nEXIT_CODE=${code}\n`);
  process.exitCode=code??1;
});
child.on('error',error=>{console.error(error);process.exitCode=1});
