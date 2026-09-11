// Read-only source extraction. Native React components use these scoped approved tokens.
import fs from 'node:fs';
import postcss from '../node_modules/.pnpm/postcss@8.5.26/node_modules/postcss/lib/postcss.js';
const source = 'C:/Users/win/Downloads/the-one-complete-frontend-v1-6/the-one-codex-handoff-v1-6/demo.html';
const html = fs.readFileSync(source, 'utf8');
const styles = [...html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].slice(0, 3);
const css = postcss.parse(styles.map(match => match[1]).join('\n'));
css.walkRules(rule => {
  if (rule.parent.type === 'atrule' && /keyframes$/.test(rule.parent.name)) return;
  rule.selectors = rule.selectors.map(selector => {
    const rooted = selector.replace(/:root|(?<![\w.-])\b(?:html|body)\b(?![\w-])/g, '.ux-workspace');
    return rooted.startsWith('.ux-workspace') ? rooted : `.ux-workspace ${rooted}`;
  });
});
const fixes = `
.ux-workspace{--review-h:0px;height:100dvh;font:14px var(--font);background:var(--bg);color:var(--text)}
.ux-workspace .app{height:100dvh}.ux-workspace a{text-decoration:none}
.ux-workspace .sidebar{min-height:0;overflow-y:auto}.ux-workspace .tabs{width:100%}
.ux-workspace :where(input,select,textarea){max-width:100%;min-width:0}
.ux-workspace .v4-table{table-layout:auto}.ux-workspace .v4-scroll{min-width:0}
.ux-workspace .mobile-header{flex-shrink:0}
.ux-workspace dialog{margin:auto;max-height:88dvh;max-width:min(760px,calc(100vw - 28px));overflow:auto}
.ux-workspace dialog::backdrop{background:#000a}
.ux-workspace fieldset{min-width:0}.ux-workspace .v4-grid>*{min-width:0}
.ux-workspace .x-confirm-details{margin:22px 0;white-space:pre-wrap;overflow-wrap:anywhere}
.ux-workspace .x-bottom-actions{display:flex;gap:10px;justify-content:flex-end;flex-wrap:wrap;margin-top:24px}
.ux-workspace :where(h1,h2,h3,p,td,th,button){overflow-wrap:anywhere}
.ux-workspace .ux-audit-json{white-space:pre-wrap;overflow-wrap:anywhere;font-size:11px;background:var(--surface2);padding:16px}
@media(max-width:700px){.ux-workspace .page-header{flex-wrap:wrap}.ux-workspace .header-tools{display:flex;flex-wrap:wrap;min-width:0}.ux-workspace .header-tools>.icon-button{display:none}}
`;
fs.writeFileSync('src/components/ux-prototype/workspace/workspace.css', '/* Approved demo workspace styles, scoped; source remains byte-identical. */\n' + css.toString() + fixes);
