import fs from 'node:fs';
const root = 'C:/Users/win/Downloads/the-one-complete-frontend-v1-6/the-one-codex-handoff-v1-6';
const html = fs.readFileSync(`${root}/demo.html`, 'utf8');
let css = ['public-home-v15', 'public-teacher-cards-v16'].map(id => html.match(new RegExp(`<style id="${id}">([\\s\\S]*?)</style>`))[1]).join('\n');
css = css.replace(/\/\*[\s\S]*?\*\//g, '').replace(/overflow:clip/g, 'overflow:visible');
css = css.replace(/([^{}]+)\{/g, (match, selectors) => {
  if (selectors.trim().startsWith('@')) return match;
  return selectors.split(',').map(raw => {
    let selector = raw.trim().replace(/body\.p5-public|\.p5-public/g, '').trim();
    if (!selector) return '.surface';
    return `.surface :global(${selector})`;
  }).join(',') + '{';
});
fs.writeFileSync(new URL('./reference.module.css', import.meta.url), '/* Native scoped reconstruction of the approved public v1.6 CSS. Original references remain unchanged. */\n'+css);
fs.mkdirSync('public/ux-prototype', {recursive:true});
for (const asset of ['guitar.jpg','wide.jpg','lesson.jpg','student.jpg','mobile.png']) fs.copyFileSync(`${root}/assets/${asset}`, `public/ux-prototype/${asset}`);
