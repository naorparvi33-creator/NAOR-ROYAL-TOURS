(function(){
const site = document.getElementById('site');
site.classList.add('js');
const WA = (window.NRT_CONFIG && window.NRT_CONFIG.whatsapp) || '972536233816';
const waLink = t => `https://wa.me/${WA}?text=${encodeURIComponent(t)}`;
const hasG = typeof gsap !== 'undefined';
let reduce = matchMedia('(prefers-reduced-motion: reduce)').matches || !hasG;
document.querySelectorAll('[data-wa]').forEach(a => a.href = waLink(a.dataset.wa));
const store = {get(k){try{return localStorage.getItem(k)}catch(e){return null}}, set(k,v){try{localStorage.setItem(k,v)}catch(e){}}};

/* ---------------- Data ---------------- */
const CITY = {ATH:'אתונה',RHO:'רודוס',FCO:'רומא',LCA:'לרנקה',PRG:'פראג',BUD:'בודפשט',DXB:'דובאי',LHR:'לונדון',BER:'ברלין',JFK:'ניו יורק'};
const COLORS = {
  caramel:{name:'קרמל', body:'#b07a45', band:'#2a1d13', g:['#7a4a2a','#2b1a10','#0b0806']},
  cream:{name:'בז׳ שמנת', body:'#e2d0b0', band:'#7a5531', g:['#6e5434','#291e12','#0c0906']},
  black:{name:'שחור', body:'#15110e', band:'#c9a066', g:['#8a6430','#2c2012','#090705']},
  white:{name:'לבן', body:'#f7f4ef', band:'#b07a45', g:['#4d4037','#1d1814','#070605']}
};
const TYPES = {
  couple:{label:'חופשה זוגית.', line:'שקיעות, מלון בוטיק ונוף לים. טיסות, מלון וכשרות בהודעה אחת.', msg:'היי נאור, אשמח לתכנן חופשה זוגית', color:'caramel', scene:'ATH', dests:['ATH','RHO','FCO','LCA','PRG','BUD','DXB']},
  family:{label:'חופשה משפחתית.', line:'מלון נוח לכולם, טיולים וחוויות לכל הגילאים. אתם נהנים, אני מסדר.', msg:'היי נאור, אשמח לתכנן חופשה משפחתית', color:'cream', scene:'PRG', dests:['PRG','BUD','LCA','RHO','BER','ATH','LHR']},
  kosher:{label:'חופשה כשרה.', line:'אוכל כשר, שבת ובית חב״ד ליד המלון. מתוכנן מראש, בלי הפתעות.', msg:'היי נאור, אשמח לתכנן חופשה כשרה', color:'black', scene:'FCO', dests:['FCO','LHR','JFK','PRG','BUD','ATH','DXB']},
  flight:{label:'טיסה + מלון.', line:'שעות טיסה נוחות ומלון במיקום הנכון. מהיר, פשוט ומסודר.', msg:'היי נאור, אני מחפש טיסה ומלון', color:'white', scene:'DXB', dests:['DXB','BER','LHR','LCA','RHO','FCO','JFK']}
};
const DEST = [
  {code:'ATH', name:'יוון', time:'כ־2 ש׳ טיסה', color:'cream', line:'איים, שקיעות ואוכל טוב. שעתיים מהבית.'},
  {code:'PRG', name:'פראג', time:'כ־4 ש׳ טיסה', color:'caramel', line:'עיר מאגדה, גשרים ושווקים. מושלמת לזוגות ולמשפחות.'},
  {code:'BUD', name:'בודפשט', time:'כ־3.5 ש׳ טיסה', color:'black', line:'מרחצאות חמים, הדנובה ואורות בלילה.'},
  {code:'RHO', name:'רודוס', time:'כ־1.5 ש׳ טיסה', color:'white', line:'ים טורקיז, עיר עתיקה ומלונות על החוף.'},
  {code:'DXB', name:'דובאי', time:'כ־3 ש׳ טיסה', color:'caramel', line:'יוקרה, שופינג ומדבר. שמש כל השנה.'},
  {code:'LHR', name:'לונדון', time:'כ־5.5 ש׳ טיסה', color:'black', line:'מחזות זמר, שופינג ופארקים ירוקים.'},
  {code:'BER', name:'ברלין', time:'כ־4.5 ש׳ טיסה', color:'white', line:'תרבות, היסטוריה ואוכל מצוין.'},
  {code:'LCA', name:'קפריסין', time:'כ־1 ש׳ טיסה', color:'cream', line:'חוף, שקט ושעת טיסה. בטן־גב במיטבו.'},
  {code:'FCO', name:'איטליה', time:'כ־3.5 ש׳ טיסה', color:'black', line:'העיר הנצחית, אתרים ברגל ואוכל כשר מתוכנן מראש.'},
  {code:'JFK', name:'ארצות הברית', time:'כ־12 ש׳ טיסה', color:'caramel', line:'העיר שלא ישנה. שופינג, מופעים וקהילות כשרות.'}
];
const ORDER = ['couple','family','kosher','flight'];
let currentType = 'couple';

/* ---------------- Build content ---------------- */
const tickHTML = DEST.map(d => `<span>TLV <svg><use href="#i-plane"/></svg> ${d.code} <em>${CITY[d.code]}</em></span>`).join('');
document.getElementById('ticker').innerHTML = tickHTML + tickHTML;

const arrowSvg = '<svg aria-hidden="true"><use href="#i-arrow"/></svg>';
const PHOTO = {ATH:'photo-1580502304784-8985b7eb7260', PRG:'photo-1600623471616-8c1966c91ff6', BUD:'photo-1761249747656-d0dadc498220', RHO:'photo-1527108097555-a5c5e36f3dd0', DXB:'photo-1748626083682-611d0a66cb50', LHR:'photo-1772339014113-29414e7295b3', BER:'photo-1571662728319-d6265ebfcac9', LCA:'photo-1520279088142-543e6893743c', FCO:'photo-1514896856000-91cb6de818e0', JFK:'photo-1499092346589-b9b6be3e94b2'};
// photos are stored inside the site (img/dest), resized to their display size: no outside service needed
const photoUrl = (code, w, h) => `img/dest/${code.toLowerCase()}-${h > w ? 'tall' : 'card'}.webp`;
const photoTag = (code, name, w = 800, h = 500) => PHOTO[code] ? `<img class="photo" data-photo src="${photoUrl(code, w, h)}" alt="${name}" loading="lazy" decoding="async">` : '';
function armPhotos(root){
  root.querySelectorAll('img[data-photo]').forEach(i => {
    i.removeAttribute('data-photo');
    const ok = () => i.classList.add('ok'), bad = () => i.remove();
    if (i.complete){ i.naturalWidth ? ok() : bad(); }
    i.addEventListener('load', ok); i.addEventListener('error', bad);
  });
}
document.getElementById('tickets').innerHTML = DEST.map((d,i) => `
  <div class="ticket rv" style="--i:${i%4}" data-code="${d.code}">
    <button class="t-hit" aria-expanded="false" aria-controls="act-${d.code}"><span class="sr">${d.name}: פתיחת אפשרויות</span></button>
    <span class="tilt">
      <span class="t-img">${ART(d.code)}${photoTag(d.code, d.name)}<span class="code-badge">TLV → ${d.code}</span></span>
      <span class="t-body">
        <span class="t-row"><b>${d.name}</b><span class="t-code">${d.code}</span></span>
        <span class="t-bottom"><span>${d.time}</span><span class="t-swatch"><i style="background:${COLORS[d.color].body}"></i>${COLORS[d.color].name}</span><span class="t-go">לחצו ${arrowSvg}</span></span>
      </span>
    </span><span class="glare"></span>
    <div class="t-actions" id="act-${d.code}" role="group" aria-label="אפשרויות ל${d.name}">
      <a class="t-act wa" href="${waLink('היי נאור, אשמח לסגור חופשה ב' + d.name)}" target="_blank" rel="noopener"><svg aria-hidden="true"><use href="#i-wa"/></svg>לסגור איתי על ${d.name}</a>
      <button class="t-act color" data-code="${d.code}"><i style="background:${COLORS[d.color].body}" aria-hidden="true"></i>צבע מזוודה<span class="sr">: ${COLORS[d.color].name}</span></button>
    </div>
  </div>`).join('') + `
  <a class="ticket other rv" style="--i:2" href="#plan"><span class="tilt"><span class="t-img"><strong>???</strong></span><span class="t-body"><span class="t-row"><b>יעד אחר</b><span class="t-code">ANY</span></span><span class="t-bottom"><span>ספרו לי לאן</span><span class="t-go">לטופס ${arrowSvg}</span></span></span></span><span class="glare"></span></a>
  <a class="ticket other rv" style="--i:3" href="${waLink('היי נאור, יש לי שאלה על חופשה')}" target="_blank" rel="noopener"><span class="tilt"><span class="t-img"><strong>HI!</strong></span><span class="t-body"><span class="t-row"><b>סתם לשאול</b><span class="t-code">24/6</span></span><span class="t-bottom"><span>וואטסאפ</span><span class="t-go">לשיחה ${arrowSvg}</span></span></span></span><span class="glare"></span></a>`;

armPhotos(document.getElementById('tickets'));

const REV = ['img/r1.webp','img/r2.webp','img/r3.webp','img/r4.webp','img/r5.webp'];
const REV_ALT = ['לקוחות מודים לנאור אחרי אישור המלון','לקוחה מודה לנאור על הכול','לקוח מספר שהמלון מושלם ומודה על השירות','לקוח ממליץ על נאור ומודה על הסבלנות','לקוחה מודה על חופשה כשרה שלא עלתה משכורת'];
const rt = document.getElementById('rev-track');
const revHTML = REV.map((s,i) => `<button class="phone" data-src="${i}" aria-label="הגדלת המלצה: ${REV_ALT[i]}"><img src="${s}" alt="${REV_ALT[i]}" decoding="async"></button>`).join('');
rt.innerHTML = revHTML + revHTML.replace(/<button class="phone"/g,'<button class="phone" tabindex="-1" aria-hidden="true"');
const lb = document.getElementById('lightbox'), lbImg = document.getElementById('lb-img');
/* draggable, auto-moving reviews strip */
const vp = rt.parentElement;
let rvx = 0, rvv = 0, rDrag = false, rLast = 0, rMoved = 0, rIdle = 0, rHover = false, rTween = 0;
vp.addEventListener('pointerenter', e => { if (e.pointerType === 'mouse') rHover = true; });
vp.addEventListener('pointerleave', () => { rHover = false; });
vp.addEventListener('pointerdown', e => { rDrag = true; rLast = e.clientX; rMoved = 0; rvv = 0; rTween = 0; vp.classList.add('drag'); });
vp.addEventListener('pointermove', e => { if (!rDrag) return; const dx = e.clientX - rLast; rLast = e.clientX; rvx += dx; rvv = dx; rMoved += Math.abs(dx); if (rMoved > 6 && !vp.hasPointerCapture(e.pointerId)){ try{ vp.setPointerCapture(e.pointerId); }catch(_){} } });
const rEnd = () => { if (!rDrag) return; rDrag = false; rIdle = performance.now() + 1800; vp.classList.remove('drag'); };
vp.addEventListener('pointerup', rEnd); vp.addEventListener('pointercancel', rEnd);
vp.addEventListener('click', e => { if (rMoved > 6){ e.stopPropagation(); e.preventDefault(); } }, true);
const rStep = () => (rt.firstElementChild ? rt.firstElementChild.getBoundingClientRect().width + 26 : 276);
document.getElementById('rev-next').addEventListener('click', () => { rTween = -rStep(); rIdle = performance.now() + 2500; });
document.getElementById('rev-prev').addEventListener('click', () => { rTween = rStep(); rIdle = performance.now() + 2500; });
(function revLoop(){
  const half = rt.scrollWidth / 2;
  if (!rDrag){
    if (rTween){ const d = rTween * .12; rvx += d; rTween -= d; if (Math.abs(rTween) < .5) rTween = 0; }
    rvx += rvv; rvv *= .93; if (Math.abs(rvv) < .05) rvv = 0;
    if (!reduce && !rHover && !rTween && performance.now() > rIdle) rvx -= .55;
  }
  if (half > 0){ while (rvx <= -half) rvx += half; while (rvx > 0) rvx -= half; }
  rt.style.transform = `translate3d(${rvx.toFixed(2)}px,0,0)`;
  requestAnimationFrame(revLoop);
})();
rt.addEventListener('click', e => { const b = e.target.closest('.phone'); if (!b) return; lbImg.src = REV[b.dataset.src]; lbImg.alt = REV_ALT[b.dataset.src]; openDlg(lb); });

/* dialogs */
function openDlg(d){ if (d.showModal) d.showModal(); else d.setAttribute('open',''); }
document.addEventListener('click', e => {
  const o = e.target.closest('[data-dlg]'); if (o){ openDlg(document.getElementById(o.dataset.dlg)); return; }
  const c = e.target.closest('[data-close]'); if (c){ c.closest('dialog').close(); return; }
  if (e.target.tagName === 'DIALOG') e.target.close();
});

/* form: handled by leads.js (validation, lead number, backup, WhatsApp) */

/* headline split */
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
let webgl = typeof THREE !== 'undefined', renderer, scene, camera, rig, spinner, bodyMat, bandMat, tag, shadow;
if (webgl){ try { renderer = new THREE.WebGLRenderer({canvas, antialias:true, alpha:true, powerPreference:'high-performance'}); } catch(e){ webgl = false; } }
const lin = hex => new THREE.Color(hex).convertSRGBToLinear();
function roundedRect(w,h,r){ const s = new THREE.Shape(), x = -w/2, y = -h/2;
  s.moveTo(x+r,y); s.lineTo(x+w-r,y); s.quadraticCurveTo(x+w,y,x+w,y+r); s.lineTo(x+w,y+h-r); s.quadraticCurveTo(x+w,y+h,x+w-r,y+h);
  s.lineTo(x+r,y+h); s.quadraticCurveTo(x,y+h,x,y+h-r); s.lineTo(x,y+r); s.quadraticCurveTo(x,y,x+r,y); return s; }
function slab(w,h,d,r,bevel,mat){ const g = new THREE.ExtrudeGeometry(roundedRect(w,h,r), {depth:d, bevelEnabled:true, bevelThickness:bevel, bevelSize:bevel, bevelSegments:5, curveSegments:18}); g.center(); return new THREE.Mesh(g, mat); }

if (webgl){
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, innerWidth < 900 ? 1.5 : 2));
  renderer.outputEncoding = THREE.sRGBEncoding;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  scene = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(30, 1, .1, 100); camera.position.set(0,0,10);
  const pmrem = new THREE.PMREMGenerator(renderer), env = new THREE.Scene();
  env.add(new THREE.Mesh(new THREE.SphereGeometry(20,32,16), new THREE.MeshBasicMaterial({color:lin('#2a2016'), side:THREE.BackSide})));
  const soft = (c,w,h,x,y,z) => { const m = new THREE.Mesh(new THREE.PlaneGeometry(w,h), new THREE.MeshBasicMaterial({color:c, side:THREE.DoubleSide})); m.position.set(x,y,z); m.lookAt(0,0,0); env.add(m); };
  soft(new THREE.Color(4,3.8,3.5),10,3,0,9,5); soft(new THREE.Color(3,2.2,1.4),4,10,-11,2,3); soft(new THREE.Color(2.6,2.6,2.6),3,9,11,1,-2); soft(new THREE.Color(1.4,1,.6),12,2,0,-9,6);
  scene.environment = pmrem.fromScene(env, .035).texture;
  const key = new THREE.DirectionalLight(0xffffff,1.5); key.position.set(4,6,7); scene.add(key);
  const rim = new THREE.DirectionalLight(0xffc68a,1.4); rim.position.set(-6,3,-5); scene.add(rim);
  scene.add(new THREE.AmbientLight(0xffffff,.22));

  rig = new THREE.Group(); scene.add(rig);
  spinner = new THREE.Group(); rig.add(spinner);
  const bag = new THREE.Group(); bag.position.y = -.28; spinner.add(bag);
  const W = 1.5, H = 2.1, D = .6;
  bodyMat = new THREE.MeshPhysicalMaterial({color:lin(COLORS.caramel.body), roughness:.34, metalness:.05, clearcoat:1, clearcoatRoughness:.14});
  bandMat = new THREE.MeshStandardMaterial({color:lin(COLORS.caramel.band), roughness:.55, metalness:.2});
  const metal = new THREE.MeshStandardMaterial({color:lin('#d9d2c6'), roughness:.22, metalness:1});
  const gold = new THREE.MeshStandardMaterial({color:lin('#e2bd84'), roughness:.25, metalness:1});
  const rubber = new THREE.MeshStandardMaterial({color:lin('#151210'), roughness:.8});
  bag.add(slab(W,H,D,.24,.07,bodyMat));
  const front = D/2 + .07;
  bag.add(slab(W+.035,H+.035,.05,.25,.035,bandMat));
  [-.46,-.16,.16,.46].forEach(x => [1,-1].forEach(side => { const rib = slab(.075,H*.74,.02,.035,.02,bodyMat); rib.position.set(x,0,side*(front+.008)); bag.add(rib); }));
  [[-1,1],[1,1],[-1,-1],[1,-1]].forEach(([sx,sy]) => { const g = new THREE.Mesh(new THREE.SphereGeometry(.13,20,14), bandMat); g.scale.set(1,1,1.9); g.position.set(sx*(W/2-.04), sy*(H/2-.04), 0); bag.add(g); });
  const badge = new THREE.Mesh(new THREE.CylinderGeometry(.11,.11,.025,40), gold); badge.rotation.x = Math.PI/2; badge.position.set(0,H*.36,front+.02); bag.add(badge);
  const top = H/2 + .07;
  const carry = new THREE.Mesh(new THREE.TorusGeometry(.22,.045,14,40,Math.PI), rubber); carry.position.set(0,top,.1); bag.add(carry);
  [-.22,.22].forEach(x => { const f = new THREE.Mesh(new THREE.BoxGeometry(.12,.05,.12), metal); f.position.set(x,top+.01,.1); bag.add(f); });
  [-.42,.42].forEach(x => { const post = new THREE.Mesh(new THREE.CylinderGeometry(.034,.034,.82,18), metal); post.position.set(x,top+.41,-.2); bag.add(post);
    const cap = new THREE.Mesh(new THREE.BoxGeometry(.14,.06,.14), bandMat); cap.position.set(x,top+.02,-.2); bag.add(cap); });
  const grip = new THREE.Mesh(new THREE.CylinderGeometry(.065,.065,1.0,24), rubber); grip.rotation.z = Math.PI/2; grip.position.set(0,top+.84,-.2); bag.add(grip);
  const bottom = -H/2 - .07;
  [[-1,1],[1,1],[-1,-1],[1,-1]].forEach(([sx,sz]) => { const hx = sx*(W/2-.16), hz = sz*(D/2-.06);
    const house = new THREE.Mesh(new THREE.CylinderGeometry(.08,.1,.1,20), bandMat); house.position.set(hx,bottom-.04,hz); bag.add(house);
    [-.045,.045].forEach(o => { const w = new THREE.Mesh(new THREE.CylinderGeometry(.085,.085,.05,24), rubber); w.rotation.z = Math.PI/2; w.position.set(hx+o,bottom-.15,hz); bag.add(w); }); });
  const tc = document.createElement('canvas'); tc.width = 512; tc.height = 300;
  const tex = new THREE.CanvasTexture(tc); tex.encoding = THREE.sRGBEncoding; tex.anisotropy = 4;
  const drawTag = () => { const c = tc.getContext('2d'); c.clearRect(0,0,512,300);
    c.fillStyle = '#f5ebdb'; c.beginPath(); if (c.roundRect) c.roundRect(6,6,500,288,40); else c.rect(6,6,500,288); c.fill();
    c.fillStyle = '#b07a45'; c.fillRect(6,220,500,74);
    c.fillStyle = '#100d0a'; c.font = '700 50px "Bodoni Moda", Georgia, serif'; c.textAlign = 'center'; c.fillText('NAOR ROYAL', 256, 112);
    c.font = '600 30px "IBM Plex Mono", monospace'; c.fillStyle = '#6e6255'; c.fillText('T O U R S', 256, 166);
    c.fillStyle = '#fffcf7'; c.font = '600 34px "IBM Plex Mono", monospace'; c.fillText('TLV  →  WORLD', 256, 270);
    c.fillStyle = '#100d0a'; c.beginPath(); c.arc(56,60,16,0,Math.PI*2); c.fill(); tex.needsUpdate = true; };
  drawTag(); if (document.fonts) document.fonts.ready.then(drawTag);
  tag = new THREE.Group(); tag.position.set(.2,top+.05,.14); bag.add(tag);
  const tagMesh = new THREE.Mesh(new THREE.PlaneGeometry(.5,.29), new THREE.MeshStandardMaterial({map:tex, side:THREE.DoubleSide, roughness:.6, transparent:true}));
  tagMesh.position.set(.18,-.3,.06); tagMesh.rotation.y = -.25; tag.add(tagMesh);
  const string = new THREE.Mesh(new THREE.CylinderGeometry(.008,.008,.24,6), rubber); string.position.set(.05,-.12,.03); string.rotation.z = .55; tag.add(string);
  const sc = document.createElement('canvas'); sc.width = sc.height = 256;
  const sg = sc.getContext('2d'), grd = sg.createRadialGradient(128,128,0,128,128,128);
  grd.addColorStop(0,'rgba(0,0,0,.55)'); grd.addColorStop(1,'rgba(0,0,0,0)'); sg.fillStyle = grd; sg.fillRect(0,0,256,256);
  shadow = new THREE.Mesh(new THREE.PlaneGeometry(2.6,1.1), new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(sc), transparent:true, depthWrite:false}));
  shadow.rotation.x = -Math.PI/2; shadow.position.y = -1.75; rig.add(shadow);
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
    renderer.setSize(W, H, false); camera.aspect = W/H; camera.updateProjectionMatrix();
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

/* ---------------- Look switching ---------------- */
const entry = {s: reduce ? 1 : .001, spin: reduce ? 0 : -Math.PI*2};
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
  if (reduce){ fill(); return; }
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
  const swapLook = () => { if (webgl){ bodyMat.color.copy(lin(C.body)); bandMat.color.copy(lin(C.band)); } try { dispatchEvent(new CustomEvent('nrt-color', {detail:{body:C.body, band:C.band}})); } catch(e){} };
  if (reduce){ hero.style.setProperty('--g1',C.g[0]); hero.style.setProperty('--g2',C.g[1]); hero.style.setProperty('--g3',C.g[2]); swapLook(); passes.forEach((p,i) => setPass(p, look.codes[i % look.codes.length])); finish(); return; }
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
const tk = document.getElementById('tickets');
function closeTickets(except){
  tk.querySelectorAll('.ticket.open').forEach(t => { if (t !== except){ t.classList.remove('open'); t.querySelector('.t-hit').setAttribute('aria-expanded','false'); } });
}
tk.addEventListener('click', e => {
  const hit = e.target.closest('.t-hit');
  if (hit){
    const t = hit.closest('.ticket'), open = !t.classList.contains('open');
    closeTickets(t); t.classList.toggle('open', open); hit.setAttribute('aria-expanded', open);
    if (open && e.detail === 0) setTimeout(() => t.querySelector('.t-act').focus(), 60);
    return;
  }
  const c = e.target.closest('.t-act.color');
  if (c){ closeTickets(); goDest(c.dataset.code); return; }
  if (e.target.closest('.t-act.wa')) setTimeout(() => closeTickets(), 400);
});
document.addEventListener('click', e => { if (!e.target.closest('.ticket')) closeTickets(); });
addEventListener('keydown', e => { if (e.key === 'Escape'){ const o = tk.querySelector('.ticket.open'); if (o){ closeTickets(); o.querySelector('.t-hit').focus(); } } });
function goDest(code){
  layout();
  const target = anchorScroll, near = () => Math.abs(scrollY - target) < 40;
  if (near()){ selectDest(code); return; }
  scrollTo({top:target, behavior: reduce ? 'auto' : 'smooth'});
  const t0 = performance.now();
  (function wait(){ if (near() || performance.now() - t0 > 1600) setTimeout(() => selectDest(code), 120); else requestAnimationFrame(wait); })();
}

/* ---------------- Ticket tilt ---------------- */
document.getElementById('tickets').addEventListener('pointermove', e => {
  const t = e.target.closest('.ticket'); if (!t || reduce) return;
  const r = t.getBoundingClientRect(), x = (e.clientX - r.left)/r.width, y = (e.clientY - r.top)/r.height;
  t.style.setProperty('--ry', ((x - .5)*14).toFixed(2) + 'deg'); t.style.setProperty('--rx', ((.5 - y)*12).toFixed(2) + 'deg');
  t.style.setProperty('--mx', (x*100).toFixed(1) + '%'); t.style.setProperty('--my', (y*100).toFixed(1) + '%');
});
document.getElementById('tickets').addEventListener('pointerout', e => { const t = e.target.closest('.ticket'); if (t && !t.contains(e.relatedTarget)){ t.style.setProperty('--rx','0deg'); t.style.setProperty('--ry','0deg'); } });

/* ---------------- Magnetic buttons + cursor ---------------- */
const fine = matchMedia('(pointer:fine)').matches;
if (fine){
  document.querySelectorAll('.mag').forEach(b => {
    b.addEventListener('pointermove', e => { if (reduce) return; const r = b.getBoundingClientRect(); b.style.transform = `translate(${(e.clientX - r.left - r.width/2)*.22}px,${(e.clientY - r.top - r.height/2)*.3}px)`; });
    b.addEventListener('pointerleave', () => { b.style.transition = 'transform .6s cubic-bezier(.34,1.56,.64,1)'; b.style.transform = ''; setTimeout(() => b.style.transition = '', 600); });
  });
}
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

/* ---------------- Reveal + progress + header ---------------- */
const io = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting){ e.target.classList.add('in'); io.unobserve(e.target); } }), {threshold:.12, rootMargin:'0px 0px -6% 0px'});
document.querySelectorAll('.rv,#qs').forEach(el => io.observe(el));
const progress = document.getElementById('progress'), header = document.getElementById('header');
const routePath = document.getElementById('route-path'), routeLen = routePath.getTotalLength();
routePath.style.strokeDasharray = `${routeLen}`; routePath.style.strokeDashoffset = routeLen;
const steps = document.querySelector('.steps-wrap');
const portraitImg = document.getElementById('naor-img');
const portraitFrame = portraitImg.closest('.ph') || portraitImg;
function onScroll(){
  const max = document.documentElement.scrollHeight - innerHeight;
  progress.style.transform = `scaleX(${max > 0 ? scrollY/max : 0})`;
  header.classList.toggle('solid', scrollY > 40);
  const r = steps.getBoundingClientRect(), p = Math.min(Math.max((innerHeight*.85 - r.top)/(innerHeight*.6), 0), 1);
  routePath.style.strokeDashoffset = routeLen*(1 - p);
  // measure the photo's frame (not the moving photo itself) and keep the shift inside the frame
  const pr = portraitFrame.getBoundingClientRect(), pp = Math.max(-1, Math.min(1, (pr.top + pr.height/2 - innerHeight/2)/innerHeight));
  portraitImg.style.transform = reduce ? 'translateY(-7.5%)' : `translateY(${(-7.5 - pp*7.5).toFixed(2)}%)`;
}
addEventListener('scroll', onScroll, {passive:true}); onScroll();
const links = [...document.querySelectorAll('.nav a')], secs = links.map(a => document.querySelector(a.getAttribute('href')));
const navIO = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting){ const i = secs.indexOf(e.target); links.forEach((l,j) => l.classList.toggle('on', i === j)); } }), {rootMargin:'-45% 0px -50% 0px'});
secs.forEach(s => s && navIO.observe(s));

/* ---------------- Accessibility menu ---------------- */
const aBtn = document.getElementById('a11y-btn'), aPanel = document.getElementById('a11y-panel');
aBtn.addEventListener('click', () => { const open = aPanel.hidden; aPanel.hidden = !open; aBtn.setAttribute('aria-expanded', open); });
const applyA = (cls, on) => { site.classList.toggle(cls, on); if (cls === 'a-still') reduce = on || matchMedia('(prefers-reduced-motion: reduce)').matches; };
aPanel.querySelectorAll('[data-a]').forEach(b => {
  const k = b.dataset.a, saved = store.get('nrt-' + k) === '1';
  if (saved){ b.setAttribute('aria-pressed','true'); applyA(k, true); }
  b.addEventListener('click', () => { const on = b.getAttribute('aria-pressed') !== 'true'; b.setAttribute('aria-pressed', on); applyA(k, on); store.set('nrt-' + k, on ? '1' : '0'); });
});
addEventListener('keydown', e => { if (e.key === 'Escape' && !aPanel.hidden){ aPanel.hidden = true; aBtn.setAttribute('aria-expanded','false'); aBtn.focus(); } });

/* ---------------- Loop ---------------- */
let heroVisible = true;
new IntersectionObserver(es => { heroVisible = es[0].isIntersecting; }, {threshold:0}).observe(hero);
function frame(now){
  requestAnimationFrame(frame);
  if (document.hidden) return;
  const t = now*.001;
  if (fine){ cx += (mouse.px - cx)*.2; cy += (mouse.py - cy)*.2; cur.style.transform = `translate3d(${cx}px,${cy}px,0)`; }
  if (!heroVisible) return;
  if (now - lastMove > 2500){ mouse.x = Math.sin(t*.4)*.25; mouse.y = Math.cos(t*.3)*.12; }
  cm.x += (mouse.x - cm.x)*.05; cm.y += (mouse.y - cm.y)*.05;
  const hr = hero.getBoundingClientRect(), scrollP = Math.min(Math.max((scrollY - anchorScroll)/hr.height, 0), 1);
  const still = reduce;
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
  if (reduce){ passes.forEach(p => Object.assign(p.st, {ix:0,iy:0,sc:1,op:1})); entry.s = 1; entry.spin = 0; return; }
  passes.forEach(p => Object.assign(p.st, implodeTarget(p), {sc:.1, op:0}));
  gsap.fromTo(porthole, {opacity:0}, {opacity:1, duration:1.4, ease:'power2.out', delay:.05});
  gsap.fromTo(chip, {opacity:0, y:20}, {opacity:1, y:0, duration:.8, ease:'power3.out', delay:1.6});
  gsap.to(entry, {s:1, duration:1.6, ease:'back.out(1.4)', delay:.25});
  gsap.to(entry, {spin:0, duration:2.6, ease:'power3.out', delay:.25});
  gsap.to(passes.map(p => p.st), {ix:0, iy:0, sc:1, op:1, duration:1.1, ease:'back.out(1.6)', delay:1.2, stagger:.08});
}
function intro(done){
  if (reduce || typeof gsap === 'undefined'){ done(); return; }
  const el = document.createElement('div'); el.className = 'intro'; el.setAttribute('aria-hidden','true');
  el.innerHTML = `<div class="half top"></div><div class="half bot"></div><div class="mark"><div class="word">${'NAOR ROYAL TOURS'.split('').map(c => `<span>${c === ' ' ? '&nbsp;' : c}</span>`).join('')}</div><div class="bar"></div><div class="sub">TLV → WORLD</div></div>`;
  site.appendChild(el);
  const letters = el.querySelectorAll('.word span');
  gsap.timeline({onComplete:() => el.remove()})
    .to(letters, {y:0, duration:.7, ease:'power4.out', stagger:.035})
    .to(el.querySelector('.bar'), {scaleX:1, duration:.7, ease:'power2.inOut'}, '-=.35')
    .to(el.querySelector('.sub'), {opacity:1, duration:.4}, '-=.3')
    .to(el.querySelector('.mark'), {opacity:0, y:-20, duration:.4, ease:'power2.in'}, '+=.25')
    .add(done, '-=.05')
    .to(el.querySelector('.top'), {yPercent:-100, duration:1, ease:'expo.inOut'}, '<')
    .to(el.querySelector('.bot'), {yPercent:100, duration:1, ease:'expo.inOut'}, '<');
}
if (hasG) gsap.set(phShade, {yPercent:-101});
let entered = false;
const enterOnce = () => { if (entered) return; entered = true; try { enterScene(); } catch(e){ site.classList.add('ready'); } };
layout(); requestAnimationFrame(frame);
try { intro(enterOnce); } catch(e){ enterOnce(); }
// failsafe: never leave the page hidden, even on a slow or blocked network
setTimeout(() => {
  const i = site.querySelector('.intro'); if (i) i.remove();
  if (!entered){ reduce = true; enterOnce(); }
  site.classList.add('ready');
  passes.forEach(p => { if (p.st.op === 0 && !switching){ Object.assign(p.st, {ix:0, iy:0, sc:1, op:1}); } });
  if (entry.s < .5){ entry.s = 1; entry.spin = 0; }
}, 4500);
addEventListener('load', layout);
})();
