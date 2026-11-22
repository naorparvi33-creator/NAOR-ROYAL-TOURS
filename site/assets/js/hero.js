/* NAOR ROYAL TOURS · המסך הראשי: כותרת, כרטיסי העלייה למטוס המרחפים, החלפת סוג חופשה ויעד,
   לולאת האנימציה ואנימציית הפתיחה. את המזוודה עצמה בונה hero-suitcase.js. */
(function(){
const NRT = window.NRT; if (!NRT) return;
const {site, waLink, hasG, fine, CITY, COLORS, TYPES, DEST, ORDER, photoTag, armPhotos} = NRT;
let currentType = 'couple';

/* ---------------- Headline split ---------------- */
const h1 = document.getElementById('h1');
let wi = 0;
(function split(node){
  [...node.childNodes].forEach(n => {
    if (n.nodeType === 3){
      const frag = document.createDocumentFragment();
      n.textContent.split(/(\s+)/).forEach(p => {
        if (!p) return;
        if (/^\s+$/.test(p)){ frag.appendChild(document.createTextNode(' ')); return; }
        const w = document.createElement('span'); w.className = 'w'; const s = document.createElement('span'); s.style.setProperty('--i', wi++); s.textContent = p; w.appendChild(s); frag.appendChild(w);
      });
      n.replaceWith(frag);
    } else if (n.classList && n.classList.contains('glow')){
      const w = document.createElement('span'); w.className = 'w'; const s = document.createElement('span'); s.style.setProperty('--i', wi++);
      n.replaceWith(w); s.appendChild(n); w.appendChild(s);
    }
  });
})(h1);
// line break after "רק" on wide screens
const words = h1.querySelectorAll('.w'); if (words[1]) words[1].after(document.createElement('br'));

/* ---------------- Hero refs ---------------- */
const hero = document.querySelector('.hero');
const slot = document.getElementById('slot');
const canvas = document.getElementById('scene');
const heroLine = document.getElementById('hero-line');
const heroWa = document.getElementById('hero-wa'), heroWaT = document.getElementById('hero-wa-t');
const porthole = document.getElementById('porthole'), phView = document.getElementById('ph-view'), phShade = document.getElementById('ph-shade');
const chip = document.getElementById('bag-chip');
heroWa.href = waLink(TYPES.couple.msg);
phView.innerHTML = ART('SKY');

/* ---------------- Boarding passes ---------------- */
const PASS_DEF = [[-.62,-.38,.6,'bg'],[.66,.24,.55,'bg'],[.1,-.6,.5,'bg'],[-.7,.1,.9,'fg'],[.66,-.3,.84,'fg'],[-.46,.52,.78,'fg'],[.54,.54,.72,'fg']];
const seats = ['12A','03C','21F','07K','14B','02A','18D'];
const passes = PASS_DEF.map((d,i) => {
  const el = document.createElement('div');
  el.className = 'pass' + (d[3] === 'bg' ? ' bg-pass' : '');
  el.innerHTML = `<div class="pass-in"><div class="pass-top"><b>NAOR ROYAL TOURS</b><span>BOARDING</span></div><div class="pass-route"><span>TLV</span><span class="line"></span><svg><use href="#i-plane"/></svg><span class="line"></span><span class="to"></span></div><div class="pass-meta"><span class="seat">SEAT <i>${seats[i]}</i></span><span class="city"></span></div></div>`;
  document.getElementById(d[3] === 'bg' ? 'passes-bg' : 'passes-fg').appendChild(el);
  return {el, ox:d[0], oy:d[1], s:d[2], layer:d[3], x:0, y:0, rx:0, ry:0, scale:d[2], phase:Math.random()*6, tilt:(Math.random()-.5)*16, st:{ix:0,iy:0,sc:0,op:0}, to:el.querySelector('.to'), city:el.querySelector('.city')};
});
const setPass = (p,c) => { p.to.textContent = c; p.city.textContent = CITY[c]; };
passes.forEach((p,i) => setPass(p, TYPES.couple.dests[i]));

/* ---------------- Three.js suitcase ---------------- */
// the 3D suitcase library (600KB) is downloaded only after the page has loaded, so the site
// opens fast; the suitcase then appears with a spin. In the light version it is never downloaded.
let webgl = false, renderer, scene, camera, rig, spinner, bodyMat, bandMat, tag, shadow, heroColor = 'caramel';
const lin = hex => NRT.lin(hex);
let glW = 0, glH = 0;
let build3DQueued = false;
// build the suitcase in a quiet moment, never in the middle of a scroll
function queueHero3D(){
  if (webgl || build3DQueued || typeof THREE === 'undefined') return;
  build3DQueued = true;
  NRT.whenCalm(() => { build3DQueued = false; initHero3D(); });
}
function initHero3D(){
  if (webgl || typeof THREE === 'undefined' || document.documentElement.classList.contains('lite') || !NRT.buildHeroSuitcase) return;
  let parts = null;
  try { parts = NRT.buildHeroSuitcase(canvas, COLORS[heroColor]); } catch(e){ parts = null; }
  if (!parts) return; // no WebGL: the page works without the suitcase
  ({renderer, scene, camera, rig, spinner, bodyMat, bandMat, tag, shadow} = parts);
  webgl = true; layout();
  if (entered && !NRT.reduce && hasG){ entry.s = .001; entry.spin = -Math.PI*2; gsap.to(entry, {s:1, duration:1.4, ease:'back.out(1.4)'}); gsap.to(entry, {spin:0, duration:2.2, ease:'power3.out'}); }
}

/* ---------------- Layout ---------------- */
let anchorScroll = 0, rigBase = {x:0,y:0}, rigScale = 1, slotC = {x:0,y:0,w:300,h:400}, small = false, phBase = {x:0,y:0};
function layout(){
  const hr = hero.getBoundingClientRect(), sr = slot.getBoundingClientRect();
  const W = hr.width, H = hr.height;
  small = W < 900;
  anchorScroll = Math.max(0, Math.round(sr.top + scrollY + sr.height/2 + (small ? 26 : 10) - innerHeight/2));
  slotC = {x:sr.left - hr.left + sr.width/2, y:sr.top - hr.top + sr.height/2, w:sr.width, h:sr.height};
  if (webgl){
    // resizing the canvas clears it and reallocates memory: only when the size really changed
    // (phones fire "resize" every time the address bar slides in or out)
    if (W !== glW || H !== glH){ glW = W; glH = H; renderer.setSize(W, H, false); camera.aspect = W/H; camera.updateProjectionMatrix(); }
    const visH = 2*camera.position.z*Math.tan(THREE.MathUtils.degToRad(camera.fov/2)), visW = visH*camera.aspect;
    rigBase.x = (slotC.x/W - .5)*visW; rigBase.y = -(slotC.y/H - .5)*visH;
    rigScale = (Math.min(sr.height, sr.width*1.5)/H*visH)/3.5;
  }
  const ph = Math.min(sr.height*.86, sr.width*1.15), pw = ph*.7;
  porthole.style.width = pw + 'px'; porthole.style.height = ph + 'px';
  phBase = {x:slotC.x - pw/2, y:slotC.y - ph/2 - sr.height*.02};
  chip.style.left = slotC.x + 'px'; chip.style.top = (slotC.y + sr.height/2 + (small ? 4 : 18)) + 'px';
  const spreadX = small ? Math.min(slotC.w*.5, 175) : slotC.w;
  passes.forEach(p => { p.x = slotC.x + p.ox*spreadX*(small ? 1.25 : 1); p.y = slotC.y + p.oy*slotC.h; p.scale = p.s*(small ? .8 : 1); });
}
layout();
addEventListener('resize', layout);
if ('ResizeObserver' in window) new ResizeObserver(layout).observe(hero);

/* ---------------- Input ---------------- */
const mouse = {x:0,y:0,px:-9999,py:-9999}, cm = {x:0,y:0};
let lastMove = 0;
function onMove(cx,cy){ mouse.x = cx/innerWidth - .5; mouse.y = cy/innerHeight - .5; mouse.px = cx; mouse.py = cy; lastMove = performance.now(); }
addEventListener('pointermove', e => onMove(e.clientX, e.clientY), {passive:true});
addEventListener('touchmove', e => { const t = e.touches[0]; if (t) onMove(t.clientX, t.clientY); }, {passive:true});

/* ---------------- Cursor ---------------- */
const cur = document.getElementById('cursor'), curT = cur.querySelector('span');
let cx = -100, cy = -100;
if (fine){
  addEventListener('pointermove', e => { cur.style.opacity = 1; });
  document.addEventListener('pointerover', e => {
    const tkk = e.target.closest('.t-hit'), ph = e.target.closest('.phone'), l = e.target.closest('a,button,input,select,textarea,label');
    cur.classList.toggle('big', !!(tkk || ph)); cur.classList.toggle('link', !tkk && !ph && !!l);
    curT.textContent = tkk ? 'פתיחה ✈' : ph ? 'הגדלה' : '';
  });
}

/* ---------------- Look switching ---------------- */
const entry = {s: NRT.reduce ? 1 : .001, spin: NRT.reduce ? 0 : -Math.PI*2};
let switchSpin = 0, switching = false, pending = null;
const implodeTarget = p => ({ix: slotC.x - p.x, iy: slotC.y - p.y});
function setChip(code, color, pop){
  document.getElementById('chip-sw').style.background = COLORS[color].body;
  document.getElementById('chip-code').textContent = 'TLV → ' + code;
  document.getElementById('chip-txt').textContent = 'מזוודה בצבע ' + COLORS[color].name;
  if (pop){ chip.classList.remove('pop'); void chip.offsetWidth; chip.classList.add('pop'); }
}
setChip('ATH','caramel',false);

function swapScene(code){
  const fill = () => { phView.innerHTML = ART(code) + photoTag(code, CITY[code] || '', 700, 1000); armPhotos(phView); };
  if (NRT.reduce){ fill(); return; }
  gsap.timeline()
    .to(phShade, {yPercent:0, duration:.45, ease:'power2.in'})
    .add(() => { fill(); gsap.fromTo(phView.children, {scale:1.35}, {scale:1.15, duration:1.6, ease:'power3.out'}); })
    .to(phShade, {yPercent:-101, duration:.75, ease:'power3.out', delay:.3});
}

function transition(look){
  if (switching){ pending = look; return; }
  switching = true;
  const C = COLORS[look.color];
  heroLine.classList.add('swap');
  setTimeout(() => { heroLine.innerHTML = `<b>${look.label}</b> ${look.line}`; heroLine.classList.remove('swap'); }, 350);
  heroWa.href = waLink(look.msg); heroWaT.textContent = look.cta || 'וואטסאפ עכשיו';
  setChip(look.chipCode, look.color, true);
  swapScene(look.scene);
  const swapLook = () => { heroColor = look.color; if (webgl){ bodyMat.color.copy(lin(C.body)); bandMat.color.copy(lin(C.band)); } try { dispatchEvent(new CustomEvent('nrt-color', {detail:{body:C.body, band:C.band}})); } catch(e){} };
  if (NRT.reduce){ hero.style.setProperty('--g1',C.g[0]); hero.style.setProperty('--g2',C.g[1]); hero.style.setProperty('--g3',C.g[2]); swapLook(); passes.forEach((p,i) => setPass(p, look.codes[i % look.codes.length])); finish(); return; }
  gsap.to(hero, {'--g1':C.g[0], '--g2':C.g[1], '--g3':C.g[2], duration:1.5, ease:'power2.inOut'});
  const o = {v:0, b:0};
  gsap.to(o, {v:Math.PI*2, b:12, duration:.6, ease:'power2.in',
    onUpdate:() => { switchSpin = o.v; canvas.style.filter = `blur(${o.b}px)`; },
    onComplete:() => { swapLook();
      gsap.to(o, {v:Math.PI*4, b:0, duration:1.5, ease:'back.out(0.7)',
        onUpdate:() => { switchSpin = o.v; canvas.style.filter = o.b > .2 ? `blur(${o.b}px)` : 'none'; },
        onComplete:() => { switchSpin = 0; canvas.style.filter = 'none'; } }); } });
  let done = 0;
  passes.forEach((p,i) => { const t = implodeTarget(p);
    gsap.timeline()
      .to(p.st, {ix:t.ix, iy:t.iy, sc:.1, op:0, duration:.5, ease:'power2.in', delay:i*.02, onComplete:() => { setPass(p, look.codes[i % look.codes.length]); p.tilt = (Math.random()-.5)*16; }})
      .to(p.st, {duration:.3})
      .to(p.st, {ix:(Math.random()-.5)*60, iy:(Math.random()-.5)*60, sc:1, op:1, duration:.9, ease:'back.out(1.5)', onComplete:() => { if (++done === passes.length) finish(); }}); });
}
function finish(){ switching = false; if (pending){ const p = pending; pending = null; transition(p); } }

function selectType(type){
  if (type === currentType && !pendingDest) return;
  currentType = type; pendingDest = null;
  document.querySelectorAll('.type').forEach(b => b.setAttribute('aria-pressed', b.dataset.type === type));
  const T = TYPES[type];
  transition({label:T.label, line:T.line, msg:T.msg, color:T.color, scene:T.scene, codes:T.dests, chipCode:T.dests[0]});
}
let pendingDest = null;
function selectDest(code){
  const d = DEST.find(x => x.code === code); pendingDest = code;
  document.querySelectorAll('.type').forEach(b => b.setAttribute('aria-pressed','false'));
  transition({label:d.name + '.', line:d.line, msg:`היי נאור, אשמח להצעה לחופשה ב${d.name}`, cta:`הצעה ל${d.name} בוואטסאפ`, color:d.color, scene:code, codes:[code], chipCode:code});
}
document.querySelectorAll('.type').forEach(b => b.addEventListener('click', () => selectType(b.dataset.type)));
const step = dir => selectType(ORDER[(ORDER.indexOf(currentType) + dir + ORDER.length) % ORDER.length]);
document.getElementById('next').addEventListener('click', () => step(1));
document.getElementById('prev').addEventListener('click', () => step(-1));
function goDest(code){
  layout();
  const target = anchorScroll, near = () => Math.abs(scrollY - target) < 40;
  if (near()){ selectDest(code); return; }
  scrollTo({top:target, behavior: NRT.reduce ? 'auto' : 'smooth'});
  const t0 = performance.now();
  (function wait(){ if (near() || performance.now() - t0 > 1600) setTimeout(() => selectDest(code), 120); else requestAnimationFrame(wait); })();
}
NRT.goDest = goDest; // used by the destination tickets (destinations.js)

/* ---------------- Loop ---------------- */
let heroVisible = true;
/* Adaptive quality: if this device cannot keep the hero smooth, lower the 3D resolution step by step,
   and as a last step switch off the live blur effects (class "perf-low"). Strong devices never notice. */
let qPrev = 0, qAvg = 16, qN = 0, qStep = 0;
function watchQuality(now){
  if (!webgl){ qPrev = 0; return; }
  const d = qPrev ? now - qPrev : 0; qPrev = now;
  if (!d || d > 250) return; // first frame, or the tab was in the background
  qAvg = qAvg*.95 + d*.05;
  if (++qN < 120 || qAvg < 36 || qStep >= 3) return; // 36ms = clearly below 30 frames a second
  qStep++; qN = 0; qAvg = 16;
  const pr = renderer.getPixelRatio();
  if (qStep === 1 && pr > 1.5) renderer.setPixelRatio(1.5);
  else if (qStep <= 2 && pr > 1){ qStep = 2; renderer.setPixelRatio(1); }
  else { qStep = 3; site.classList.add('perf-low'); return; }
  glW = glH = 0; layout();
}
new IntersectionObserver(es => { heroVisible = es[es.length - 1].isIntersecting; }, {threshold:0}).observe(hero);
function frame(now){
  requestAnimationFrame(frame);
  if (document.hidden){ qPrev = 0; return; }
  const t = now*.001;
  if (fine){ cx += (mouse.px - cx)*.2; cy += (mouse.py - cy)*.2; cur.style.transform = `translate3d(${cx}px,${cy}px,0)`; }
  if (!heroVisible){ qPrev = 0; return; }
  watchQuality(now);
  if (now - lastMove > 2500){ mouse.x = Math.sin(t*.4)*.25; mouse.y = Math.cos(t*.3)*.12; }
  cm.x += (mouse.x - cm.x)*.05; cm.y += (mouse.y - cm.y)*.05;
  const hr = hero.getBoundingClientRect(), scrollP = Math.min(Math.max((scrollY - anchorScroll)/hr.height, 0), 1);
  const still = NRT.reduce;
  porthole.style.transform = `translate3d(${phBase.x - cm.x*14}px,${phBase.y - cm.y*10 + scrollP*60}px,0) perspective(900px) rotateY(${cm.x*-6}deg) rotateX(${cm.y*5}deg)`;
  if (webgl){
    const bob = still ? 0 : Math.sin(t*1.1)*.07;
    rig.position.set(rigBase.x, rigBase.y + bob*rigScale*3 + scrollP*rigScale*1.2, 0);
    rig.scale.setScalar(rigScale*entry.s);
    spinner.rotation.y = -.35 + cm.x*.9 + entry.spin + switchSpin + (still ? 0 : Math.sin(t*.5)*.12) + scrollP*Math.PI*.8;
    spinner.rotation.x = cm.y*.3 + .05; spinner.rotation.z = -cm.x*.08 + .04;
    tag.rotation.z = Math.sin(t*2.1)*.1 - cm.x*.3;
    shadow.scale.setScalar(1 - bob*1.5); shadow.material.opacity = .9 - bob*2;
    renderer.render(scene, camera);
  }
  passes.forEach((p,i) => {
    const par = p.layer === 'fg' ? 44 : -22;
    const pcx = hr.left + p.x + p.rx + cm.x*par, pcy = hr.top + p.y + p.ry + cm.y*par;
    let trx = 0, trY = 0, boost = 1;
    if (!switching){ const dx = mouse.px - pcx, dy = mouse.py - pcy, dist = Math.hypot(dx,dy) || 1;
      if (dist < 300){ const f = (300 - dist)/300; trx = dx/dist*f*-90; trY = dy/dist*f*-90; boost = 1 + f*3; } }
    p.rx += (trx - p.rx)*.08; p.ry += (trY - p.ry)*.08;
    const dur = [6,7.5,6.8,8,5.5,7,9][i], ph = (t + p.phase)*(Math.PI*2/dur);
    const fy = still ? 0 : Math.sin(ph)*14, fr = still ? 0 : Math.cos(ph)*4*boost;
    const x = p.x + p.rx + cm.x*par + p.st.ix, y = p.y + p.ry + cm.y*par + fy + p.st.iy;
    p.el.style.transform = `translate3d(${x}px,${y}px,0) translate(-50%,-50%) perspective(700px) rotateX(${-cm.y*22}deg) rotateY(${cm.x*28}deg) rotate(${p.tilt + fr}deg) scale(${p.scale*p.st.sc})`;
    p.el.style.opacity = p.st.op*(p.layer === 'bg' ? .7 : 1);
  });
}

/* ---------------- Intro + entry ---------------- */
function enterScene(){
  site.classList.add('ready');
  if (NRT.reduce){ passes.forEach(p => Object.assign(p.st, {ix:0,iy:0,sc:1,op:1})); entry.s = 1; entry.spin = 0; return; }
  passes.forEach(p => Object.assign(p.st, implodeTarget(p), {sc:.1, op:0}));
  gsap.fromTo(porthole, {opacity:0}, {opacity:1, duration:1.4, ease:'power2.out', delay:.05});
  gsap.fromTo(chip, {opacity:0, y:20}, {opacity:1, y:0, duration:.8, ease:'power3.out', delay:1.6});
  gsap.to(entry, {s:1, duration:1.6, ease:'back.out(1.4)', delay:.25});
  gsap.to(entry, {spin:0, duration:2.6, ease:'power3.out', delay:.25});
  gsap.to(passes.map(p => p.st), {ix:0, iy:0, sc:1, op:1, duration:1.1, ease:'back.out(1.6)', delay:1.2, stagger:.08});
}
function intro(done){
  const el = site.querySelector('.intro');
  if (NRT.reduce || typeof gsap === 'undefined'){ if (el) el.remove(); done(); return; }
  if (!el){ done(); return; }
  // the curtain is already on screen with the logo (from index.html): draw the line, then open it
  gsap.timeline({onComplete:() => el.remove()})
    .to(el.querySelector('.bar'), {scaleX:1, duration:.55, ease:'power2.inOut'}, .1)
    .to(el.querySelector('.sub'), {opacity:1, duration:.3}, '-=.25')
    .to(el.querySelector('.mark'), {opacity:0, y:-20, duration:.3, ease:'power2.in'}, '+=.15')
    .add(done, '-=.05')
    .to(el.querySelector('.top'), {yPercent:-100, duration:.8, ease:'expo.inOut'}, '<')
    .to(el.querySelector('.bot'), {yPercent:100, duration:.8, ease:'expo.inOut'}, '<');
}
if (hasG) gsap.set(phShade, {yPercent:-101});
let entered = false;
const enterOnce = () => { if (entered) return; entered = true; try { enterScene(); } catch(e){ site.classList.add('ready'); } };
layout(); requestAnimationFrame(frame);
queueHero3D(); addEventListener('nrt-three', queueHero3D);
try { intro(enterOnce); } catch(e){ enterOnce(); }
// failsafe: never leave the page hidden, even on a slow or blocked network
setTimeout(() => {
  const i = site.querySelector('.intro'); if (i) i.remove();
  if (!entered){ NRT.reduce = true; enterOnce(); }
  site.classList.add('ready');
  passes.forEach(p => { if (p.st.op === 0 && !switching){ Object.assign(p.st, {ix:0, iy:0, sc:1, op:1}); } });
  if (entry.s < .5){ entry.s = 1; entry.spin = 0; }
}, 4500);
addEventListener('load', layout);
})();
