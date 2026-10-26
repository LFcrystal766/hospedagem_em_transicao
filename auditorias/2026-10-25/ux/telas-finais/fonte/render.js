// Renderiza as telas HTML de ./telas em PNG em ./png.
// Uso: NODE_PATH=/opt/node22/lib/node_modules node render.js [prefixo-ou-arquivo ...]
// Cada tela declara o tamanho em <meta name="viewport-mock" content="390x844"> (padrão 390x844).
// Celular sai em escala 2 (nitidez de iPhone); computador em escala 1.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const base = __dirname;
const dirTelas = path.join(base, 'telas');
const dirPng = path.join(base, 'png');
fs.mkdirSync(dirPng, { recursive: true });

const filtros = process.argv.slice(2);
const arquivos = fs.readdirSync(dirTelas)
  .filter((f) => f.endsWith('.html'))
  .filter((f) => filtros.length === 0 || filtros.some((p) => f.startsWith(p.replace(/\.html$/, ''))))
  .sort();

(async () => {
  const browser = await chromium.launch();
  const avisos = [];
  for (const f of arquivos) {
    const html = fs.readFileSync(path.join(dirTelas, f), 'utf8');
    const m = html.match(/<meta\s+name="viewport-mock"\s+content="(\d+)x(\d+)"/);
    const w = m ? Number(m[1]) : 390;
    const h = m ? Number(m[2]) : 844;
    const celular = w < 600;
    const ctx = await browser.newContext({
      viewport: { width: w, height: h },
      deviceScaleFactor: celular ? 2 : 1,
      reducedMotion: 'reduce',
      locale: 'pt-BR',
    });
    const page = await ctx.newPage();
    const erros = [];
    page.on('pageerror', (e) => erros.push(String(e)));
    page.on('requestfailed', (r) => { if (!r.url().startsWith('data:')) erros.push('falhou: ' + r.url()); });
    await page.goto('file://' + path.join(dirTelas, f));
    await page.evaluate(() => document.fonts && document.fonts.ready);
    // Conteúdo que vaza da largura da tela: sinal de layout quebrado.
    const vaza = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1);
    const saida = path.join(dirPng, f.replace(/\.html$/, '.png'));
    await page.screenshot({ path: saida, fullPage: false });
    if (vaza) avisos.push(`${f}: conteúdo mais largo que ${w}px (rolagem lateral)`);
    for (const e of erros) avisos.push(`${f}: ${e}`);
    console.log(`ok ${f} -> png/${path.basename(saida)} (${w}x${h}${celular ? ' @2x' : ''})`);
    await ctx.close();
  }
  await browser.close();
  if (avisos.length) {
    console.log('\nAVISOS:');
    for (const a of avisos) console.log(' - ' + a);
  } else {
    console.log('\nsem avisos');
  }
})();
