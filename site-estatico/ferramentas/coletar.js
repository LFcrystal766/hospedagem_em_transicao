// Visita cada página do site (computador e celular) e anota todo arquivo do próprio domínio que ela pede.
// Bloqueia tudo o que é de fora (Stape, GTM, Meta, TikTok, player de vídeo), para não gerar visita falsa no rastreio.
// Uso: node coletar.js <urls.txt> <saida.json>
const { chromium, devices } = require('playwright');
const fs = require('fs');

const ORIGEM = 'crystalnowpp.com.br';
const LIBERADOS = new Set([ORIGEM, 'fonts.googleapis.com', 'fonts.gstatic.com', 'code.jquery.com']);
const [, , arqUrls, arqSaida] = process.argv;
const urls = fs.readFileSync(arqUrls, 'utf8').split('\n').map(s => s.trim()).filter(Boolean);

async function visitar(browser, url, perfil) {
  const ctx = await browser.newContext(perfil === 'celular'
    ? { ...devices['iPhone 13'] }
    : { viewport: { width: 1366, height: 900 } });
  const page = await ctx.newPage();
  const doDominio = new Set();
  const dinamicas = [];
  const bloqueados = new Set();
  const falhas = [];
  await page.route('**/*', route => {
    const u = new URL(route.request().url());
    if (u.protocol === 'data:' || u.protocol === 'blob:') return route.continue();
    if (!LIBERADOS.has(u.hostname)) { bloqueados.add(u.hostname); return route.abort(); }
    return route.continue();
  });
  page.on('request', req => {
    const u = new URL(req.url());
    if (u.hostname !== ORIGEM) return;
    if (req.method() !== 'GET' || /admin-ajax|wp-json|\.php/.test(u.pathname)) dinamicas.push(`${req.method()} ${u.pathname}${u.search}`);
  });
  page.on('response', res => {
    const u = new URL(res.url());
    if (u.hostname !== ORIGEM || res.request().method() !== 'GET') return;
    if (res.status() >= 400) falhas.push(`${res.status()} ${u.pathname}`);
    else doDominio.add(u.origin + u.pathname + u.search);
  });
  let status = 0;
  try {
    const r = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
    status = r ? r.status() : 0;
    // Interação: o LiteSpeed segura parte dos scripts até o primeiro toque, rolagem ou movimento.
    await page.mouse.move(200, 200).catch(() => {});
    await page.keyboard.press('Tab').catch(() => {});
    if (perfil === 'celular') await page.touchscreen.tap(10, 10).catch(() => {});
    const altura = await page.evaluate(() => document.body ? document.body.scrollHeight : 0).catch(() => 0);
    for (let y = 0; y <= altura + 900; y += 700) {
      await page.evaluate(v => window.scrollTo(0, v), y).catch(() => {});
      await page.waitForTimeout(250);
    }
    await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
  } catch (e) {
    falhas.push(`ERRO ${e.message.split('\n')[0]}`);
  }
  await ctx.close();
  return { url, perfil, status, arquivos: [...doDominio], dinamicas, bloqueados: [...bloqueados], falhas };
}

(async () => {
  const browser = await chromium.launch();
  const fila = [];
  for (const u of urls) for (const p of ['computador', 'celular']) fila.push([u, p]);
  const resultados = [];
  let i = 0;
  async function trabalhador() {
    while (i < fila.length) {
      const [u, p] = fila[i++];
      const r = await visitar(browser, u, p);
      resultados.push(r);
      process.stdout.write(`${resultados.length}/${fila.length} ${r.status} ${p} ${u.replace('https://' + ORIGEM, '')}\n`);
    }
  }
  await Promise.all([trabalhador(), trabalhador(), trabalhador(), trabalhador()]);
  await browser.close();
  fs.writeFileSync(arqSaida, JSON.stringify(resultados, null, 1));
})().catch(e => { console.error('ERRO', e); process.exit(1); });
