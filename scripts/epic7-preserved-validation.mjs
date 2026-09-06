// Offline verification of one fixed preserved content set. No Git subprocess,
// database adapter, environment fallback, or execution authorization.
import {readFileSync, readdirSync, lstatSync} from 'node:fs';
import {inflateSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

export const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const preserved = 'c61cdb6c757499b875fc9e9f41657f8b2c1a4ef1';
export const candidate = 'd5f98434106797afc65c59953aa3bc61ba26ecb4';
const sha = (b, algorithm = 'sha256') => createHash(algorithm).update(b).digest('hex');
const gitBytes = b => b.includes(0) ? b : Buffer.from(b.toString('utf8').replaceAll('\r\n', '\n'));
const additions = new Set(['scripts/epic7-preserved-validation.mjs', 'scripts/epic7-preserved-validation.test.mjs']);
const directories = ['src', 'public', 'tests', 'scripts', 'supabase/migrations', 'supabase/tests'];
const protectedPath = p => !p.startsWith('docs/') && !p.startsWith('.env');

// Git object hashes bind the old manifest to the preserved commit, rather than
// trusting a freshly generated manifest or a caller-supplied candidate string.
export function snapshot(read = readFileSync) {
  const object = (id, type) => {
    if (!/^[a-f0-9]{40}$/.test(id)) throw Error('Invalid object identity');
    let raw;
    try { raw = inflateSync(read(resolve(root, '.git/objects', id.slice(0, 2), id.slice(2)))); }
    catch {
      try {
        const bundle = JSON.parse(read(resolve(root, 'artifacts/remote-smoke/epic7-preserved-validation/objects.json')));
        raw = inflateSync(Buffer.from(bundle[id], 'base64'));
      } catch { throw Error('Required offline Git object unavailable; no network fallback'); }
    }
    if (sha(raw, 'sha1') !== id) throw Error('Git object hash mismatch');
    const end = raw.indexOf(0), body = raw.subarray(end + 1);
    if (raw.subarray(0, end).toString() !== `${type} ${body.length}`) throw Error('Git object type/size mismatch');
    return body;
  };
  const commit = object(preserved, 'commit').toString();
  if (commit.match(/^parent .+$/gm)?.join('\n') !== `parent ${candidate}`) throw Error('Candidate binding mismatch');
  object(candidate, 'commit');
  const files = new Map();
  const walk = (id, prefix = '') => {
    const data = object(id, 'tree');
    for (let i = 0; i < data.length;) {
      const space = data.indexOf(32, i), zero = data.indexOf(0, space);
      if (space < i || zero < space || zero + 21 > data.length) throw Error('Malformed tree');
      const mode = data.subarray(i, space).toString(), name = data.subarray(space + 1, zero).toString();
      if (!name || name === '.' || name === '..' || /[\\/]/.test(name)) throw Error('Unsafe tree path');
      const oid = data.subarray(zero + 1, zero + 21).toString('hex'), p = prefix + name;
      i = zero + 21;
      if (mode === '40000') walk(oid, p + '/');
      else if (mode === '100644' || mode === '100755') files.set(p, object(oid, 'blob'));
      else throw Error('Unsupported tree mode');
    }
  };
  walk(commit.match(/^tree ([a-f0-9]{40})$/m)[1]);
  return files;
}

export async function verify({read = readFileSync} = {}) {
  const files = snapshot(read);
  const manifestPath = 'docs/EPIC7_F_TOOLING_MANIFEST.json';
  const manifest = JSON.parse(files.get(manifestPath));
  if (manifest.candidate !== candidate) throw Error('Candidate manifest mismatch');
  for (const [p, b] of files) {
    if ((protectedPath(p) || p === manifestPath) && !gitBytes(read(resolve(root, p))).equals(b)) throw Error('Protected content mismatch: ' + p);
  }
  for (const [p, digest] of Object.entries(manifest.files)) if (sha(read(resolve(root, p))) !== digest) throw Error('Historical tool hash mismatch: ' + p);
  for (const [p, digest] of Object.entries(manifest.migrations)) if (sha(read(resolve(root, 'supabase/migrations', p))) !== digest) throw Error('Historical migration hash mismatch: ' + p);
  const inspect = dir => {
    for (const name of readdirSync(resolve(root, dir))) {
      const p = dir + '/' + name, stat = lstatSync(resolve(root, p));
      if (stat.isSymbolicLink()) throw Error('Unexpected symbolic link: ' + p);
      if (stat.isDirectory()) inspect(p);
      else if (!files.has(p) && !additions.has(p)) throw Error('Unreviewed added file: ' + p);
    }
  };
  for (const dir of directories) inspect(dir);
  // Import only after the complete preserved runner bytes have been verified.
  const old = await import('./epic7-readiness.mjs');
  const result = old.validate({head: candidate, read});
  if (result.validation !== 'PASS') throw Error(result.errors.join('; '));
  return {...result, mode: 'Preserved content ValidateOnly', preserved, workingDirectory: root,
    protectedFiles: [...files.keys()].filter(protectedPath).length,
    verifierSHA256: sha(readFileSync(fileURLToPath(import.meta.url))),
    note: 'Content equivalence only; current HEAD is not treated as the historical tested HEAD'};
}

export async function main(args) {
  if (args.length && !(args.length === 1 && args[0] === '--validate-only')) throw Error('Only offline --validate-only; production and caller candidate overrides forbidden');
  return verify();
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).then(r => console.log(JSON.stringify(r, null, 2)))
    .catch(e => { console.error(e.message); process.exitCode = 1; });
}
