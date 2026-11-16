// Abre cada página no original e na cópia (servida aqui, como o Cloudflare Pages serviria) e compara.
// Uso: node comparar.js <pasta_copia> <todas.txt> <pasta_saida>
// - Tudo de fora é bloqueado nos dois lados (nada de visita falsa no rastreio); só se anota o que a página tentou chamar.
// - Na cópia, qualquer pedido ao crystalnowpp.com.br também é bloqueado e anotado: seria um arquivo que não veio.
const { chromium, devices } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const [, , PASTA, ARQ_URLS, SAIDA] = process.argv;
const ORIGEM = 'crystalnowpp.com.br';
const TIPOS = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'application/javascript', '.json': 'application/json',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.gif': 'image/gif', '.svg': 'image/svg+xml',
  '.woff': 'font/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf', '.xml': 'application/xml', '.txt': 'text/plain', '.mp4': 'video/mp4' };
fs.mkdirSync(SAIDA, { recursive: true });

const raiz = path.resolve(PASTA);
const servidor = http.createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  let f = path.resolve(raiz, '.' + p);
  if (!f.startsWith(raiz)) { res.writeHead(403); return res.end(); }
  if (fs.existsSync(f) && fs.statSync(f).isDirectory()) f = path.join(f, 'index.html');
  if (!fs.existsSync(f)) { res.writeHead(404, { 'content-type': 'text/html' }); return res.end(fs.readFileSync(path.join(raiz, '404.html'))); }
  res.writeHead(200, { 'content-type': TIPOS[path.extname(f).toLowerCase()] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
});

async function abrir(browser, url, perfil, ehCopia, foto) {
  const ctx = await browser.newContext(perfil === 'celular' ? { ...devices['iPhone 13'] } : { viewport: { width: 1366, height: 900 } });
  const page = await ctx.newPage();
  const externos = new Set(), faltando = new Set(), vazou = new Set();
  await page.route('**/*', route => {
    const u = new URL(route.request().url());
    if (u.protocol === 'data:' || u.protocol === 'blob:') return route.continue();
    if (ehCopia && u.hostname === '127.0.0.1') return route.continue();
    if (!ehCopia && u.hostname === ORIGEM) return route.continue();
    if (['fonts.googleapis.com', 'fonts.gstatic.com', 'code.jquery.com'].includes(u.hostname)) return route.continue();
    if (u.hostname === ORIGEM) vazou.add(u.pathname); else externos.add(u.hostname);
    return route.abort();
  });
  page.on('response', r => { const u = new URL(r.url()); if (ehCopia && u.hostname === '127.0.0.1' && r.status() >= 400) faltando.add(u.pathname); });
  let status = 0;
  try {
    const r = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
    status = r ? r.status() : 0;
    await page.mouse.move(200, 200).catch(() => {});
    if (perfil === 'celular') await page.touchscreen.tap(10, 10).catch(() => {});
    const h = await page.evaluate(() => document.body ? document.body.scrollHeight : 0).catch(() => 0);
    for (let y = 0; y <= h + 900; y += 700) { await page.evaluate(v => window.scrollTo(0, v), y).catch(() => {}); await page.waitForTimeout(150); }
    await page.evaluate(() => window.scrollTo(0, 0)).catch(() => {});
    await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
    await page.waitForTimeout(800);
    if (foto) await page.screenshot({ path: foto, timeout: 30000 }).catch(() => {});
  } catch (e) { faltando.add('ERRO ' + e.message.split('\n')[0]); }
  await ctx.close();
  return { status, externos: [...externos].sort(), faltando: [...faltando].sort(), vazou: [...vazou].sort() };
}

(async () => {
  await new Promise(r => servidor.listen(0, '127.0.0.1', r));
  const porta = servidor.address().port;
  const urls = fs.readFileSync(ARQ_URLS, 'utf8').split('\n').map(s => s.trim()).filter(Boolean);
  const browser = await chromium.launch();
  const fila = [];
  for (const u of urls) for (const p of ['computador', 'celular']) fila.push([u, p]);
  const res = [];
  let i = 0;
  async function trab() {
    while (i < fila.length) {
      const [u, perfil] = fila[i++];
      const caminho = new URL(u).pathname;
      const nome = (caminho.replace(/\//g, '_') || '_') + '-' + perfil;
      const orig = await abrir(browser, u, perfil, false, path.join(SAIDA, nome + '-original.png'));
      const copia = await abrir(browser, `http://127.0.0.1:${porta}${caminho}`, perfil, true, path.join(SAIDA, nome + '-copia.png'));
      const r = { caminho, perfil, nome, orig, copia,
        mesmosExternos: JSON.stringify(orig.externos) === JSON.stringify(copia.externos) };
      res.push(r);
      process.stdout.write(`${res.length}/${fila.length} ${perfil} ${caminho} externos=${r.mesmosExternos ? 'iguais' : 'DIFERENTES'} faltando=${copia.faltando.length} vazou=${copia.vazou.length}\n`);
    }
  }
  await Promise.all([trab(), trab(), trab()]);
  await browser.close();
  servidor.close();
  fs.writeFileSync(path.join(SAIDA, 'comparacao.json'), JSON.stringify(res, null, 1));
})().catch(e => { console.error('ERRO', e); process.exit(1); });
