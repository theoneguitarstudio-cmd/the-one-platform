import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';

const reference = 'C:/Users/win/Downloads/the-one-complete-frontend-v1-6/the-one-codex-handoff-v1-6';
const manifest = JSON.parse(readFileSync(resolve(reference, 'BASELINE_MANIFEST.json'), 'utf8'));
const files = manifest.files.map(entry => {
  const bytes = readFileSync(resolve(reference, entry.file));
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  return { file: entry.file, bytes: bytes.length, sha256, matches: sha256 === entry.sha256 && bytes.length === entry.bytes };
});
const git = args => execFileSync('git', args, {encoding:'utf8'}).trim();
const canonical = ['CURRENT_WORK','PROJECT_STATUS','CANONICAL_ROADMAP','PRODUCT_DECISIONS'].map(name=>({file:`docs/${name}.md`,sha256:createHash('sha256').update(readFileSync(`docs/${name}.md`)).digest('hex')}));
const report = {reference,branch:git(['branch','--show-current']),head:git(['rev-parse','HEAD']),main:git(['rev-parse','main']),files,canonical};
mkdirSync('artifacts/ux-prototype', {recursive:true});
writeFileSync('artifacts/ux-prototype/baseline.json',JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
if(files.some(file=>!file.matches)) process.exitCode=1;
