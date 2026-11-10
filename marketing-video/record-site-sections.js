// Section recorder: virtual clock, instant jump + pre-roll per section, every frame validated (fixed header must sit at the top).
const { chromium, devices } = require('playwright');
const fs = require('fs'); const jpeg = require('jpeg-js');
const FPS = 30, OUT = 'castw', PRE = 0.6, B = 60 / 128;
(async () => {
  fs.mkdirSync(OUT, {recursive:true});
  const b = await chromium.launch({args:['--use-gl=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
  const ctx = await b.newContext({ userAgent: devices['iPhone 13'].userAgent, viewport:{width:390,height:844}, deviceScaleFactor:2, hasTouch:true, isMobile:false, locale:'he-IL', timezoneId:'Asia/Jerusalem' });
  const p = await ctx.newPage();
  await p.clock.install({ time: new Date('2026-11-10T10:30:00+02:00') });
  await p.addInitScript(() => {
    document.addEventListener('DOMContentLoaded', () => { const st = document.createElement('style'); st.textContent = '.hp{left:auto!important;right:0!important;clip-path:inset(50%)!important}'; document.head.appendChild(st); });
    window.__smooth = (y, ms) => { const s = scrollY, d = y - s, t0 = performance.now();
      const e = t => t < .5 ? 4*t*t*t : 1 - Math.pow(-2*t + 2, 3)/2;
      (function f(){ const k = Math.min(1, (performance.now() - t0)/ms); scrollTo(0, Math.round(s + d*e(k))); if (k < 1) requestAnimationFrame(f); })(); };
    window.__y = sel => { const el = document.querySelector(sel); return el.getBoundingClientRect().top + scrollY; };
    window.__type = (sel, txt, ms) => { const el = document.querySelector(sel), t0 = performance.now();
      (function f(){ const k = Math.min(1, (performance.now() - t0)/ms), n = Math.ceil(k*txt.length); if (el.value !== txt.slice(0,n)) { el.value = txt.slice(0,n); el.dispatchEvent(new Event('input',{bubbles:true})); } if (k < 1) requestAnimationFrame(f); })(); };
    document.addEventListener('click', e => { if (e.target.closest && e.target.closest('#send')) e.preventDefault(); });
  });
  await p.goto('http://localhost:8765/index.html', {waitUntil:'load'});
  for (let i = 0; i < 70; i++) await p.clock.runFor(100);
  const ev = (fn, arg) => p.evaluate(fn, arg);
  const packTop = await ev(() => __y('#pack')), packH = await ev(() => document.getElementById('pack').offsetHeight);
  const click = sel => () => ev(s => document.querySelector(s).click(), sel);
  const SECTIONS = [
    {name:'hero', dur:4*B, jump: () => ev(() => scrollTo(0, 0)), acts:[]},
    {name:'types', dur:12*B, jump: () => ev(() => scrollTo(0, Math.round(__y('.types') - 470))), acts:[
      [1*B, click('.type[data-type="family"]')], [5*B, click('.type[data-type="kosher"]')], [9*B, click('.type[data-type="couple"]')]]},
    {name:'pack', dur:16*B, jump: async () => { await ev(y => scrollTo(0, y), packTop); await click('[data-season="summer"]')(); }, acts:[
      [0.2, () => ev(([y,h]) => __smooth(y + h*0.55, 3300), [packTop, packH])],
      [8*B, click('[data-season="winter"]')],
      [8*B + 0.15, () => ev(([y,h]) => __smooth(y + h - 844, 2300), [packTop, packH])]]},
    {name:'dest', dur:6*B, jump: () => ev(() => scrollTo(0, Math.round(__y('#destinations') - 40))), acts:[
      [0.05, () => ev(() => __smooth(scrollY + 900, 2650))]]},
    {name:'form', dur:14*B, jump: () => ev(() => scrollTo(0, Math.round(__y('#plan-form') - 60))), acts:[
      [0.20, () => ev(() => __type('#f-name', 'דנה', 350))],
      [0.65, () => ev(() => __type('#f-dest', 'רודוס', 400))],
      [1.15, () => ev(() => __type('#f-people', '2 מבוגרים + 2 ילדים', 700))],
      [2.00, () => ev(() => __smooth(Math.round(__y('#chips') - 300), 450))],
      [6*B, click('#chip-1')], [7*B, click('#chip-3')], [8*B, click('#chip-5')],
      [8*B + 0.15, () => ev(() => __smooth(Math.round(__y('#send') - 420), 400))],
      [10*B, click('#send')]]},
  ];
  let ref = null, f = 0, retries = 0, bad = 0; const index = [];
  const band = buf => { const im = jpeg.decode(buf, {useTArray:true}); const w = im.width, out = new Float32Array(90*39); let k = 0;
    for (let y = 12; y < 102; y++) for (let x = 0; x < 780; x += 20) { const i = (y*w + x)*4; out[k++] = (im.data[i] + im.data[i+1] + im.data[i+2]) / 3; } return out; };
  const shoot = async () => {
    for (let a = 0; a < 12; a++) {
      if (a) { await p.waitForTimeout(40 + a*30); retries++; }
      const buf = await p.screenshot({type:'jpeg', quality:93});
      const bd = band(buf);
      if (!ref) { ref = bd; return buf; }
      let d = 0; for (let i = 0; i < bd.length; i++) d += Math.abs(bd[i] - ref[i]); d /= bd.length;
      if (d < 10) { ref = bd; return buf; }
      if (a === 11) { bad++; console.log('BAD frame', f, d.toFixed(1)); ref = bd; return buf; }
    }
  };
  for (const s of SECTIONS) {
    await s.jump();
    for (let w = 0; w < 4; w++) { await p.clock.runFor(1); await p.waitForTimeout(60); }
    ref = null;
    const start = f / FPS; const n = Math.round((PRE + s.dur) * FPS); let k = 0;
    const acts = s.acts.map(([t, fn]) => [t + PRE, fn]);
    for (let i = 0; i < n; i++) {
      const t = i / FPS;
      while (k < acts.length && acts[k][0] <= t + 1e-6) { await acts[k][1](); k++; }
      await p.clock.runFor(1000 / FPS);
      fs.writeFileSync(`${OUT}/f${String(f).padStart(5,'0')}.jpg`, await shoot()); f++;
      if (f % 60 === 0) console.log('frame', f, 'retries', retries, 'bad', bad);
    }
    index.push({name:s.name, src:start + PRE, dur:s.dur});
    console.log('section', s.name, 'done at frame', f, 'retries', retries, 'bad', bad);
  }
  fs.writeFileSync(`${OUT}/sections.json`, JSON.stringify(index));
  console.log('OK:', await p.evaluate(() => document.getElementById('form-ok').innerText));
  await b.close();
})();
