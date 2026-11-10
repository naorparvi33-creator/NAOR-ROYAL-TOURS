// Deterministic recorder: fake clock, one screenshot per 1/30 s of virtual time.
const { chromium, devices } = require('playwright');
const fs = require('fs');
const FPS = 30, OUT = 'castv';
(async () => {
  fs.mkdirSync(OUT, {recursive:true});
  const b = await chromium.launch({args:['--use-gl=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
  const ctx = await b.newContext({ userAgent: devices['iPhone 13'].userAgent, viewport:{width:390,height:844}, deviceScaleFactor:2, hasTouch:true, isMobile:false, locale:'he-IL', timezoneId:'Asia/Jerusalem' });
  const p = await ctx.newPage();
  await p.clock.install({ time: new Date('2026-11-10T10:30:00+02:00') });
  await p.addInitScript(() => {
    window.__smooth = (y, ms) => { const s = scrollY, d = y - s, t0 = performance.now();
      const e = t => t < .5 ? 4*t*t*t : 1 - Math.pow(-2*t + 2, 3)/2;
      (function f(){ const k = Math.min(1, (performance.now() - t0)/ms); scrollTo(0, s + d*e(k)); if (k < 1) requestAnimationFrame(f); })(); };
    window.__y = sel => { const el = document.querySelector(sel); return el.getBoundingClientRect().top + scrollY; };
    window.__type = (sel, txt, ms) => { const el = document.querySelector(sel), t0 = performance.now();
      (function f(){ const k = Math.min(1, (performance.now() - t0)/ms), n = Math.ceil(k*txt.length); if (el.value !== txt.slice(0,n)) { el.value = txt.slice(0,n); el.dispatchEvent(new Event('input',{bubbles:true})); } if (k < 1) requestAnimationFrame(f); })(); };
    document.addEventListener('DOMContentLoaded', () => { const st = document.createElement('style'); st.textContent = '.hp{left:auto!important;right:0!important;clip-path:inset(50%)!important}'; document.head.appendChild(st); });
    document.addEventListener('click', e => { if (e.target.closest && e.target.closest('#send')) e.preventDefault(); });
  });
  await p.goto('http://localhost:8765/index.html', {waitUntil:'load'});
  for (let i = 0; i < 70; i++) await p.clock.runFor(100);   // intro finishes
  await p.evaluate(() => scrollTo(0, 0));
  console.log('sw', await p.evaluate(() => [document.documentElement.scrollWidth, scrollX]));
  const packTop = await p.evaluate(() => __y('#pack')), packH = await p.evaluate(() => document.getElementById('pack').offsetHeight);
  const ev = (fn, arg) => p.evaluate(fn, arg);
  const S = [
    [0.90, () => ev(() => __smooth(__y('.types') - 470, 800))],
    [1.88, () => ev(() => document.querySelector('.type[data-type="family"]').click())],
    [3.75, () => ev(() => document.querySelector('.type[data-type="kosher"]').click())],
    [5.63, () => ev(() => document.querySelector('.type[data-type="couple"]').click())],
    [7.50, () => ev(y => __smooth(y, 600), packTop)],
    [8.20, () => ev(() => document.querySelector('[data-season="summer"]').click())],
    [8.40, () => ev(([y,h]) => __smooth(y + h*0.55, 2800), [packTop, packH])],
    [11.25, () => ev(() => document.querySelector('[data-season="winter"]').click())],
    [11.40, () => ev(([y,h]) => __smooth(y + h - 844, 2000), [packTop, packH])],
    [13.60, () => ev(() => __smooth(__y('#destinations') - 40, 700))],
    [14.40, () => ev(() => __smooth(scrollY + 760, 1300))],
    [15.94, () => ev(() => __smooth(__y('#plan-form') - 60, 800))],
    [16.90, () => ev(() => __type('#f-name', 'דנה', 350))],
    [17.35, () => ev(() => __type('#f-dest', 'רודוס', 400))],
    [17.85, () => ev(() => __type('#f-people', '2 מבוגרים + 2 ילדים', 700))],
    [18.75, () => ev(() => __smooth(__y('#chips') - 300, 500))],
    [19.22, () => ev(() => document.getElementById('chip-1').click())],
    [19.69, () => ev(() => document.getElementById('chip-3').click())],
    [20.16, () => ev(() => document.getElementById('chip-5').click())],
    [20.30, () => ev(() => __smooth(__y('#send') - 420, 450))],
    [21.09, () => ev(() => document.getElementById('send').click())],
  ];
  const N = Math.round(22.6 * FPS); let k = 0;
  for (let f = 0; f < N; f++) {
    const t = f / FPS;
    while (k < S.length && S[k][0] <= t + 1e-6) { await S[k][1](); k++; }
    await p.clock.runFor(1000 / FPS);
    if (f % 30 === 0) console.log('x', await p.evaluate(() => scrollX));
    await p.screenshot({ path: `${OUT}/f${String(f).padStart(5,'0')}.jpg`, type:'jpeg', quality:92 });
    if (f % 60 === 0) console.log('frame', f, '/', N);
  }
  console.log('OK:', await p.evaluate(() => document.getElementById('form-ok').innerText));
  await b.close();
})();
