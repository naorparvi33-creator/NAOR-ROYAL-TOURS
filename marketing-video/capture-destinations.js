const { chromium, devices } = require('playwright');
(async () => {
  const b = await chromium.launch({args:['--use-gl=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
  const ctx = await b.newContext({ userAgent: devices['iPhone 13'].userAgent, viewport:{width:390,height:844}, deviceScaleFactor:2, hasTouch:true, isMobile:false, locale:'he-IL' });
  const p = await ctx.newPage();
  await p.addInitScript(() => document.addEventListener('DOMContentLoaded', () => { const st = document.createElement('style'); st.textContent = 'html,body{scroll-behavior:auto!important}.hp{left:auto!important;right:0!important;clip-path:inset(50%)!important}'; document.head.appendChild(st); }));
  await p.goto('http://localhost:8765/index.html', {waitUntil:'load'}); await p.waitForTimeout(6000);
  const y0 = await p.evaluate(() => Math.round(document.querySelector('#destinations').getBoundingClientRect().top + scrollY - 40));
  for (let y = y0; y < y0 + 2000; y += 300) { await p.evaluate(y => scrollTo(0, y), y); await p.waitForTimeout(400); }
  await p.evaluate(y => scrollTo(0, y), y0); await p.waitForTimeout(1500);
  await p.screenshot({path:'dest-frame.png'});           // header + buttons in place
  const fixed = await p.evaluate(() => { const out = []; for (const e of document.querySelectorAll('body *')) { const cs = getComputedStyle(e); if (cs.position === 'fixed' && cs.display !== 'none' && cs.visibility !== 'hidden') { const r = e.getBoundingClientRect(); if (r.width > 0 && r.height > 0 && r.bottom > 0 && r.top < 844) { out.push([e.id || e.className, Math.round(r.x), Math.round(r.y), Math.round(r.width), Math.round(r.height)]); e.style.visibility = 'hidden'; } } } return out; });
  console.log(JSON.stringify(fixed));
  await p.waitForTimeout(300);
  await p.screenshot({path:'dest-tall.png', fullPage:true, clip:{x:0, y:y0, width:390, height:844 + 1000}});
  await b.close();
})();
