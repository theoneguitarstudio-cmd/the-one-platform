/** Offline comparison only. Reads immutable source/native images and writes derived artifacts.
 * No browser, server, network, screenshot replacement, tolerance, or PASS classification.
 */
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { readFile, writeFile, mkdir, readdir, access } from 'node:fs/promises';
import { resolve, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const option = (name, fallback) => { const at = process.argv.indexOf(name); return at < 0 ? fallback : process.argv[at + 1]; };
const handoff = resolve(option('--handoff', 'C:/Users/win/Downloads/the-one-complete-frontend-v1-6/the-one-codex-handoff-v1-6'));
const artifacts = resolve(option('--artifacts', resolve(root, 'artifacts/ux-prototype')));
const outDir = resolve(artifacts, 'comparisons');
const require = createRequire(import.meta.url);
let sharp;
for (const folder of (await readdir(resolve(root, 'node_modules/.pnpm'))).filter(name => name.startsWith('sharp@'))) {
  try { sharp = require(resolve(root, 'node_modules/.pnpm', folder, 'node_modules/sharp')); break; } catch { /* Try another installed copy only. */ }
}
if (!sharp) throw new Error('An installed usable sharp package is required; this script never installs packages.');

const manifestPath = resolve(handoff, 'screenshots/SCENE_MANIFEST.json');
const manifestBytes = await readFile(manifestPath);
const manifest = JSON.parse(manifestBytes);
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const scenes = [
  ['home-desktop', 'homepage-desktop.png', 'public-home-desktop.png'],
  ['home-mobile', 'homepage-mobile.png', 'public-home-mobile.png'],
  ['teacher-cards-desktop', 'homepage-teachers-desktop.png', 'public-teachers-desktop.png'],
  ['teacher-cards-mobile', 'homepage-teachers-mobile.png', 'public-teachers-mobile.png'],
  ['student-today-desktop', 'student-today-dark.png', 'student-today-desktop.png'],
  ['student-today-mobile', 'student-today-mobile.png', 'student-today-mobile.png'],
  ['player-desktop', 'lesson-locked-desktop.png', 'lesson-desktop.png'],
  ['player-desktop-free', 'lesson-locked-desktop.png', 'lesson-free-desktop.png'],
  ['player-mobile', 'lesson-locked-mobile.png', 'lesson-mobile.png'],
  ['teacher-reviews-desktop', 'teacher-reviews-dark.png', 'teacher-reviews-desktop.png'],
  ['teacher-reviews-mobile', 'teacher-reviews-mobile.png', 'teacher-reviews-mobile.png'],
  ['finance-desktop', 'admin-finance-dark.png', 'admin-finance-desktop-native.png'],
  ['finance-mobile', 'admin-finance-mobile.png', 'admin-finance-mobile-native.png'],
];
// Small built-in bitmap captions avoid font discovery/cache writes outside the artifacts folder.
const glyphs = Object.fromEntries(Object.entries({
  A:'01110/10001/10001/11111/10001/10001/10001', B:'11110/10001/10001/11110/10001/10001/11110', C:'01111/10000/10000/10000/10000/10000/01111', D:'11110/10001/10001/10001/10001/10001/11110', E:'11111/10000/10000/11110/10000/10000/11111', F:'11111/10000/10000/11110/10000/10000/10000',
  G:'01111/10000/10000/10111/10001/10001/01111', H:'10001/10001/10001/11111/10001/10001/10001', I:'111/010/010/010/010/010/111', J:'00111/00010/00010/00010/10010/10010/01100', K:'10001/10010/10100/11000/10100/10010/10001', L:'10000/10000/10000/10000/10000/10000/11111',
  M:'10001/11011/10101/10101/10001/10001/10001', N:'10001/11001/10101/10011/10001/10001/10001', O:'01110/10001/10001/10001/10001/10001/01110', P:'11110/10001/10001/11110/10000/10000/10000', Q:'01110/10001/10001/10001/10101/10010/01101', R:'11110/10001/10001/11110/10100/10010/10001',
  S:'01111/10000/10000/01110/00001/00001/11110', T:'11111/00100/00100/00100/00100/00100/00100', U:'10001/10001/10001/10001/10001/10001/01110', V:'10001/10001/10001/10001/10001/01010/00100', W:'10001/10001/10001/10101/10101/11011/10001', X:'10001/10001/01010/00100/01010/10001/10001', Y:'10001/10001/01010/00100/00100/00100/00100', Z:'11111/00001/00010/00100/01000/10000/11111',
  0:'01110/10001/10011/10101/11001/10001/01110', 1:'010/110/010/010/010/010/111', 2:'01110/10001/00001/00010/00100/01000/11111', 3:'11110/00001/00001/01110/00001/00001/11110', 4:'00010/00110/01010/10010/11111/00010/00010', 5:'11111/10000/10000/11110/00001/00001/11110', 6:'01110/10000/10000/11110/10001/10001/01110', 7:'11111/00001/00010/00100/01000/01000/01000', 8:'01110/10001/10001/01110/10001/10001/01110', 9:'01110/10001/10001/01111/00001/00001/01110',
  ':':'0/1/0/0/1/0/0', ',':'0/0/0/0/0/1/1', '(':'01/10/10/10/10/10/01', ')':'10/01/01/01/01/01/10', ' ':'000/000/000/000/000/000/000',
}).map(([key, pattern]) => [key, pattern.split('/')]));
async function label(width, text) {
  const pixels = Buffer.alloc(width * 44 * 3, 23), scale = width < 500 ? 1 : 2;
  let cursor = 12;
  for (const letter of text.toUpperCase()) {
    const glyph = glyphs[letter] ?? glyphs[' '];
    if (cursor + glyph[0].length * scale >= width - 8) break;
    glyph.forEach((row, y) => [...row].forEach((bit, x) => {
      if (bit !== '1') return;
      for (let yy = 0; yy < scale; yy++) for (let xx = 0; xx < scale; xx++) {
        const at = ((15 + y * scale + yy) * width + cursor + x * scale + xx) * 3;
        pixels.fill(240, at, at + 3);
      }
    }));
    cursor += (glyph[0].length + 1) * scale;
  }
  return sharp(pixels, { raw: { width, height: 44, channels: 3 } }).png().toBuffer();
}
async function paired(left, right, leftMeta, rightMeta, destination, labels) {
  const gap = 12, width = leftMeta.width + gap + rightMeta.width;
  const height = Math.max(leftMeta.height, rightMeta.height) + 44;
  await sharp({ create: { width, height, channels: 3, background: '#888888' } }).composite([
    { input: await label(leftMeta.width, labels[0]), top: 0, left: 0 },
    { input: await label(rightMeta.width, labels[1]), top: 0, left: leftMeta.width + gap },
    { input: left, top: 44, left: 0 }, { input: right, top: 44, left: leftMeta.width + gap },
  ]).png().toFile(destination);
}
await mkdir(outDir, { recursive: true });
const results = [], pending = [];
for (const [name, goldenName, nativeName] of scenes) {
  const scene = manifest.find(item => basename(item.file) === goldenName);
  if (!scene) throw new Error(`Scene manifest entry missing: ${goldenName}`);
  const sourcePath = resolve(handoff, scene.file), nativePath = resolve(artifacts, nativeName);
  try { await access(nativePath); } catch { pending.push({ name, nativeName, reason: 'Native screenshot not yet captured' }); continue; }
  const source = await readFile(sourcePath), native = await readFile(nativePath);
  const sourceHash = sha(source), nativeHash = sha(native);
  if (sourceHash !== scene.sha256) throw new Error(`Golden source hash differs from immutable manifest: ${goldenName}`);
  const a = await sharp(source).metadata(), b = await sharp(native).metadata();
  if (a.width !== scene.viewport.width || a.height !== scene.viewport.height) throw new Error(`Golden dimensions differ from scene manifest: ${goldenName}`);
  const sourceTop = Math.round(scene.geometry['#app']?.y ?? 0);
  if (sourceTop < 0 || sourceTop >= a.height) throw new Error(`Invalid manifest reviewbar offset: ${name}`);
  const width = Math.min(a.width, b.width), height = Math.min(a.height - sourceTop, b.height);
  const sourceRect = { left: 0, top: sourceTop, width, height }, nativeRect = { left: 0, top: 0, width, height };
  const alignedSource = await sharp(source).extract(sourceRect).removeAlpha().png().toBuffer();
  const alignedNative = await sharp(native).extract(nativeRect).removeAlpha().png().toBuffer();
  await paired(source, native, a, b, resolve(outDir, `${name}-side-by-side.png`), ['Golden source (unchanged)', 'Native screenshot (unchanged)']);
  await paired(alignedSource, alignedNative, { width, height }, { width, height }, resolve(outDir, `${name}-aligned.png`), [`Golden: remove manifest top ${sourceTop}px`, `Native: common ${width} x ${height}, no resize`]);
  const pixelsA = await sharp(alignedSource).toColourspace('srgb').raw().toBuffer();
  const pixelsB = await sharp(alignedNative).toColourspace('srgb').raw().toBuffer();
  if (pixelsA.length !== width * height * 3 || pixelsB.length !== pixelsA.length) throw new Error(`Unexpected RGB buffer length: ${name}`);
  const diff = Buffer.alloc(pixelsA.length);
  let changedPixels = 0, sumAbs = 0, sumSquares = 0;
  for (let at = 0; at < pixelsA.length; at += 3) {
    let changed = false;
    for (let channel = 0; channel < 3; channel++) {
      const delta = Math.abs(pixelsA[at + channel] - pixelsB[at + channel]);
      diff[at + channel] = delta; sumAbs += delta; sumSquares += delta * delta; changed ||= delta !== 0;
    }
    if (changed) changedPixels++;
  }
  await sharp(diff, { raw: { width, height, channels: 3 } }).png().toFile(resolve(outDir, `${name}-diff.png`));
  const result = { name, sourcePath, nativePath, sourceHash, nativeHash, sourceFormat: a.format, nativeFormat: b.format, sourceViewport: { width: a.width, height: a.height }, nativeViewport: { width: b.width, height: b.height }, manifestAppY: scene.geometry['#app']?.y ?? 0, sourceRect, nativeRect, changedPixels, totalPixels: width * height, changedPixelPercent: changedPixels / (width * height) * 100, meanAbsoluteRGB: sumAbs / pixelsA.length, rootMeanSquareRGB: Math.sqrt(sumSquares / pixelsA.length), manifestGeometry: scene.geometry };
  results.push(result);
  // Re-read inputs: comparison must never alter supplied golden or captured native bytes.
  if (sha(await readFile(sourcePath)) !== sourceHash || sha(await readFile(nativePath)) !== nativeHash) throw new Error(`Input changed while comparing: ${name}`);
}
if (sha(await readFile(manifestPath)) !== sha(manifestBytes)) throw new Error('Scene manifest changed while comparing.');
const report = { createdAt: new Date().toISOString(), renderer: `sharp ${sharp.versions.sharp}`, alignment: 'Only source #app.y reviewbar offset from immutable SCENE_MANIFEST; common upper-left overlap; no resize, mask, tolerance or PASS threshold', results, pending };
try { report.nativePublicGeometry = JSON.parse(await readFile(resolve(artifacts, 'public-final-geometry.json'), 'utf8')); } catch { /* Geometry is optional evidence; never infer missing browser measurements. */ }
try { report.rootPublicGeometry = JSON.parse(await readFile(resolve(artifacts, 'root-public-geometry.json'), 'utf8')); } catch { /* The root browser may not have captured final scene measurements yet. */ }
await writeFile(resolve(outDir, 'comparison.json'), JSON.stringify(report, null, 2) + '\n');
const rows = results.map(r => `| ${r.name} | ${r.sourceViewport.width}×${r.sourceViewport.height} / ${r.nativeViewport.width}×${r.nativeViewport.height} (${r.nativeFormat}) | ${r.manifestAppY} | ${r.sourceRect.width}×${r.sourceRect.height} | ${r.changedPixelPercent.toFixed(2)}% | ${r.meanAbsoluteRGB.toFixed(3)} | [並排](${r.name}-side-by-side.png) · [去展示列](${r.name}-aligned.png) · [差異](${r.name}-diff.png) |`);
await writeFile(resolve(outDir, 'comparison.md'), `# 原稿與原生截圖對照\n\n生成時間：${report.createdAt}。工具：${report.renderer}。來源：\`${handoff.replaceAll('\\', '/')}\`。\n\n## 計算方式\n\n- 原稿的 SHA-256 逐張對照 SCENE_MANIFEST.json；原稿與原生輸入在處理前後再次雜湊，未修改任何輸入。\n- 並排圖保留兩張完整原始畫面，左原稿、右原生。另提供對齊圖：只依 manifest 的 #app.y 移除來源展示列。公開頁0px，學生桌面36px／手機34px，播放器與老師／管理員38px。沒有為了降低差異而微調對齊。\n- 對齊圖與差異圖使用共同可見範圍，不縮放。原生比來源多出的底部展示空間不參與逐像素比較；完整並排圖仍保留。\n- 差異圖每通道為 abs(source-native)，未增亮、未設容差、未遮罩文字、工具或捲軸。黑色代表完全相同；亮色代表不同。\n- 差異像素比例只要RGB任一通道不同就計入；平均差值範圍0–255。這些數值不是驗收分數，不設閾值宣稱PASS。\n\n## 已知差異與判讀限制\n\n- 尺寸：表中原生尺寸與格式取自輸入影像檔頭，不假定等於CSS viewport或副檔名。尺寸不同時只比較共同可見區，整張輸入仍保留在完整並排圖，沒有縮放。\n- 編碼：部分瀏覽器截圖回傳JPEG位元組，即使檔名為.png仍依實際格式解碼；JPEG壓縮差異也包含在數值中，不轉換輸入或扣除差異。\n- 權益狀態：來源播放器顯示Plus鎖定提示；player-desktop使用目前Pro情境原生圖，player-desktop-free另對照Free鎖定情境。權益標籤差異不是CSS位移；所有差異仍納入。\n- 字型：來源截圖與目前Windows瀏覽器環境的中文字型、字重及反鋸齒可能不同。文字邊緣差異可能擴大逐像素比例，應同時看完整並排圖；此工具不消除字型差異。\n- 捲軸：原生桌面瀏覽器的可見捲軸佔用部分可用寬度，例如390px手機工作台表格容器342px，而來源卡片容器常為352px。捲軸、底部Mock工具與開發環境UI都保留在差異圖。\n- Mock資料：共用時鐘採2026-09-08，讓9/9課次保持未來；來源學生首頁截圖顯示9/12，與整合Demo老師課次不同。額度、姓名、狀態與共用流程字句可能與獨立原稿不同，差異未被遮除。\n- 老師圖卡截圖是捲動到區段的場景；兩次截圖的捲動位置不一定完全相同。manifest保留來源卡片座標，完整頁差異會反映捲動位置；不能將此差異比例直接解讀成卡片尺寸不符。\n- 播放器高度由viewport與獨立捲動區域共同決定，去除來源展示列仍會留下底部定位元素差異；這不代替實際三欄與獨立捲動操作驗證。\n- 所有golden檔與核准HTML/CSS保持原狀；這些只是不具通過判定的派生驗收產物。\n\n## 場景結果\n\n| 場景 | 原稿／原生尺寸 | 原稿展示列px | 逐像素範圍 | 不同像素 | 平均RGB差 | 產物 |\n|---|---|---:|---|---:|---:|---|\n${rows.join('\n')}\n\n${pending.length ? `## 等待截圖\n\n${pending.map(item => `- ${item.name}: 尚缺\`${item.nativeName}\`，未臆造畫面。`).join('\n')}\n` : '所有配置的場景均有截圖。\n'}\n詳細矩形、hash、RMSE與來源geometry保存在[comparison.json](comparison.json)。\n`, 'utf8');
if (report.nativePublicGeometry) await writeFile(resolve(outDir, 'comparison.md'), '\n公開頁最後一次實際DOM測量另見 [public-final-geometry.json](../public-final-geometry.json)，也原樣附在 comparison.json 的 nativePublicGeometry。此資料不拿來移動、縮放或遮罩像素差異圖。\n', { flag: 'a' });
if (report.rootPublicGeometry) await writeFile(resolve(outDir, 'comparison.md'), '\n根工作公開場景的要求viewport、實際client寬、scrollY及卡片DOM矩形見 [root-public-geometry.json](../root-public-geometry.json)，也原樣附在 rootPublicGeometry。DOM可能在同場景不同時點量測，與截圖像素分別保留，不假設最後捲動位置完全一致。公開截圖工具回傳內容clip寬1425／375，而要求viewport為1440／390；圖像不補畫捲軸、不擴展或縮放成要求尺寸。\n', { flag: 'a' });
try { await access(resolve(outDir, 'visual-review.md')); await writeFile(resolve(outDir, 'comparison.md'), '\n主要場景的實際目視判讀另見 [visual-review.md](visual-review.md)，不以像素差異數值取代人工檢查。\n', { flag: 'a' }); } catch { /* Human visual review is optional and cannot be generated from pixel statistics. */ }
console.log(JSON.stringify({ output: outDir, compared: results.length, pending: pending.map(item => item.name) }));
