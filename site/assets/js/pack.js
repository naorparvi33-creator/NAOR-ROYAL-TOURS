/* NAOR ROYAL TOURS · "מה לארוז": הסצנה עצמה. רשימת הסימון, הקשה להכנסת פריט, המצלמה והאנימציה.
   התוכן נמצא ב-pack-data.js, המזוודה ב-pack-suitcase.js והפריטים ב-pack-items.js. */
(function(){
const sec = document.getElementById('pack'); if (!sec) return;
const stage = document.getElementById('pack-stage'), canvas = document.getElementById('pack-canvas');
const topEl = document.getElementById('pk-top'), bottomEl = document.getElementById('pk-bottom'), listEl = document.getElementById('pk-list');
const capEl = document.getElementById('pk-cap'), stepEl = document.getElementById('pk-step'), tEl = document.getElementById('pk-t'), sEl = document.getElementById('pk-s');
const P = window.NRT_PACK; if (!P) return;
const {ICONS, SEASONS} = P;

const N = 7;
const seasonEl = document.getElementById('pk-season'), shareEl = document.getElementById('pk-share');
// default season by the Israeli calendar: October to March = winter
let season = (() => { const m = new Date().getMonth() + 1; return (m >= 10 || m <= 3) ? 'winter' : 'summer'; })();
let ITEMS = SEASONS[season].items;
const capsFor = () => [
  {t:'המזוודה פתוחה ומחכה.', s:`הקישו על המזוודה, ונארוז יחד את 7 הדברים הכי חשובים ל${SEASONS[season].name}.`},
  ...ITEMS,
  {t:'סוגרים את המזוודה…', s:'רצועות, רוכסן, וזהו.'},
  {t:'ארוז ומוכן.', s:'שמרו את הרשימה, ואת כל השאר אני מסדר.'}
];
let CAPS = capsFor();
const ckSvg = '<span class="pk-ck" aria-hidden="true"><svg viewBox="0 0 12 12"><path d="M2.5 6.3l2.3 2.2L9.5 3.8"/></svg></span>';
let lis = [];
function buildList(){
  listEl.innerHTML = ITEMS.map(i => `<li><span class="pk-ic" aria-hidden="true"><svg viewBox="0 0 24 24">${ICONS[i.key]}</svg></span><span class="pk-nm">${i.t}<small class="pk-tip">${i.s}</small></span>${ckSvg}</li>`).join('');
  lis = [...listEl.children];
  listEl.setAttribute('aria-label', 'מה לארוז ל' + SEASONS[season].name);
  if (shareEl){
    const txt = `רשימת אריזה ל${SEASONS[season].name} (NAOR ROYAL TOURS):\n` + ITEMS.map((it, k) => `${k + 1}. ${it.t}`).join('\n');
    shareEl.href = 'https://wa.me/?text=' + encodeURIComponent(txt);
  }
}
buildList();

/* ---------- caption + checklist (touched only when the stage changes) ---------- */
let capIdx = -1, capTimer = 0, relayout = null;
function setStage(i){
  if (i === capIdx) return; capIdx = i;
  lis.forEach((li, k) => { li.classList.toggle('done', i >= k + 1); li.classList.toggle('active', i === k + 1); });
  const c = CAPS[i]; capEl.classList.add('swap'); clearTimeout(capTimer);
  capTimer = setTimeout(() => {
    stepEl.textContent = i >= 1 && i <= N ? `${String(i).padStart(2, '0')} / 0${N}` : i === 0 ? `0${N} ITEMS · ${season === 'winter' ? 'WINTER' : 'SUMMER'}` : i === N + 1 ? 'CLOSING' : 'READY ✓';
    tEl.textContent = c.t; sEl.textContent = c.s; capEl.classList.remove('swap');
  }, 200);
  const was = sec.classList.contains('done');
  sec.classList.toggle('done', i === N + 2);
  if (relayout && was !== (i === N + 2)) requestAnimationFrame(relayout);
}
let onSeason = null;
function setSeason(s){
  if (!SEASONS[s]) return;
  season = s; ITEMS = SEASONS[s].items; CAPS = capsFor();
  seasonEl.querySelectorAll('[data-season]').forEach(b => b.setAttribute('aria-pressed', b.dataset.season === s));
  const keep = capIdx; buildList(); capIdx = -1; setStage(Math.max(0, keep));
  if (sec.classList.contains('static')) lis.forEach(li => li.classList.add('done'));
  if (onSeason) onSeason(s);
  if (tgt > 0){ goTo(0); snap = true; } // new season: start again from an open, empty suitcase
}
seasonEl.addEventListener('click', e => { const b = e.target.closest('[data-season]'); if (b) setSeason(b.dataset.season); });
seasonEl.querySelectorAll('[data-season]').forEach(b => b.setAttribute('aria-pressed', b.dataset.season === season));
setStage(0);

/* ---------- tap to pack (no scroll-locking) ----------
   Each tap on the suitcase or the button puts the next item in; then the suitcase closes.
   The 3D library arrives in the background after the page loads. Until then, and in the
   light version, the section is a clear static checklist. */
const A0 = .135, STEP = .078, DUR = .085;
let pT = 0, tgt = -1, snap = false;
const nextBtn = document.getElementById('pk-next'), nextT = document.getElementById('pk-next-t'), resetBtn = document.getElementById('pk-reset');
const targetP = k => k <= 0 ? .125 : k > N ? 1 : A0 + (k - 1) * STEP + DUR + .004;
function goTo(k){
  tgt = Math.max(0, Math.min(N + 1, k)); pT = targetP(tgt);
  nextT.textContent = tgt <= 0 ? 'הכניסו את הפריט הראשון' : tgt < N ? `הכניסו פריט ${tgt + 1} מתוך ${N}` : 'סגרו את המזוודה';
}
const live = () => !sec.classList.contains('static');
const advance = () => { if (live() && tgt <= N) goTo(tgt + 1); };
nextBtn.addEventListener('click', advance);
canvas.addEventListener('click', advance);
resetBtn.addEventListener('click', () => { if (live()) goTo(0); });
listEl.addEventListener('click', e => { const li = e.target.closest('li'); if (li && live()) goTo(lis.indexOf(li) + 1); });

const goStatic = () => { sec.classList.add('static'); lis.forEach(li => li.classList.add('done')); };
const isLite = () => document.documentElement.classList.contains('lite');
goStatic();
let armed = false, started = false;
function arm(){
  if (armed || typeof THREE === 'undefined' || isLite()) return; armed = true;
  // switch to 3D only while the visitor is not looking at this section, so nothing jumps under their eyes
  const io = new IntersectionObserver(es => { if (!es[es.length - 1].isIntersecting){ io.disconnect(); go3D(); } });
  io.observe(sec);
}
function go3D(){
  sec.classList.remove('static'); capIdx = -1; setStage(0);
  const near = new IntersectionObserver(es => {
    if (es[es.length - 1].isIntersecting && !started){ started = true; near.disconnect();
      const run = () => { try { init(); } catch(e){ goStatic(); } };
      if ('requestIdleCallback' in window) requestIdleCallback(run, {timeout:1200}); else setTimeout(run, 60); }
  }, {rootMargin:'150% 0px'});
  near.observe(sec);
}
if (!isLite()){ arm(); addEventListener('nrt-three', arm); }

function init(){
let R = null;
try { R = new THREE.WebGLRenderer({canvas, antialias:true, alpha:false, powerPreference:'high-performance'}); } catch(e){ R = null; }
if (!R) throw new Error('no webgl');

/* ---------- helpers ---------- */
const lin = h => new THREE.Color(h).convertSRGBToLinear();
const cl = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const seg = (p, a, b) => cl((p - a) / (b - a));
const eo = t => 1 - Math.pow(1 - t, 3);
const eo5 = t => 1 - Math.pow(1 - t, 5);
const ein = t => t * t * t;
const eio = t => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
const back = (t, c = 1.6) => 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2);
const mix = (a, b, t) => a + (b - a) * t;
const isSmall = () => innerWidth < 900;
const aniso = Math.min(8, (R.capabilities.getMaxAnisotropy && R.capabilities.getMaxAnisotropy()) || 4);
const repaint = [];
function tex(w, h, draw, opts = {}){
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const g = c.getContext('2d');
  const t = new THREE.CanvasTexture(c); t.encoding = THREE.sRGBEncoding; t.anisotropy = aniso;
  if (opts.repeat){ t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(opts.repeat[0], opts.repeat[1]); }
  const paint = () => { g.setTransform(1, 0, 0, 1, 0, 0); g.clearRect(0, 0, w, h); draw(g, w, h); t.needsUpdate = true; };
  paint(); if (opts.text) repaint.push(paint);
  return t;
}
function rr(w, h, r){
  const s = new THREE.Shape(), x = -w / 2, y = -h / 2;
  s.moveTo(x + r, y); s.lineTo(x + w - r, y); s.quadraticCurveTo(x + w, y, x + w, y + r);
  s.lineTo(x + w, y + h - r); s.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  s.lineTo(x + r, y + h); s.quadraticCurveTo(x, y + h, x, y + h - r);
  s.lineTo(x, y + r); s.quadraticCurveTo(x, y, x + r, y);
  return s;
}
function slabGeo(w, d, h, r, bevel = 0, segs = 4){
  const g = new THREE.ExtrudeGeometry(rr(w, d, r), {depth:h, bevelEnabled:bevel > 0, bevelThickness:bevel, bevelSize:bevel, bevelSegments:segs, curveSegments:18});
  g.rotateX(-Math.PI / 2); return g;
}
function shellGeo(w, d, h, t, r, bevel = .014){
  const s = rr(w, d, r); s.holes.push(rr(w - 2 * t, d - 2 * t, Math.max(r - t, .02)));
  const g = new THREE.ExtrudeGeometry(s, {depth:h, bevelEnabled:bevel > 0, bevelThickness:bevel, bevelSize:bevel, bevelSegments:4, curveSegments:20});
  g.rotateX(-Math.PI / 2); return g;
}
const M = (geo, mat) => new THREE.Mesh(geo, mat);
const FONT = {he:'"Heebo","Assistant",Arial,sans-serif', serif:'"Bodoni Moda",Didot,Georgia,serif', mono:'"IBM Plex Mono",Menlo,monospace'};

/* ---------- renderer / scene ---------- */
// full sharpness (up to 2x). The scene is drawn only while something moves, so this costs little
let dpr = Math.min(window.devicePixelRatio || 1, 2); R.setPixelRatio(dpr);
R.outputEncoding = THREE.sRGBEncoding;
R.toneMapping = THREE.ACESFilmicToneMapping;
R.toneMappingExposure = .96;
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(28, 1, .1, 60);

const pmrem = new THREE.PMREMGenerator(R), envScene = new THREE.Scene();
envScene.add(M(new THREE.SphereGeometry(20, 32, 16), new THREE.MeshBasicMaterial({color:lin('#1d1610'), side:THREE.BackSide})));
const soft = (c, w, h, x, y, z) => { const m = M(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({color:c, side:THREE.DoubleSide})); m.position.set(x, y, z); m.lookAt(0, 0, 0); envScene.add(m); };
soft(new THREE.Color(3.6, 3.45, 3.25), 14, 5, 0, 10, 4); soft(new THREE.Color(2.2, 1.7, 1.2), 5, 12, -11, 2, 4);
soft(new THREE.Color(1.7, 1.7, 1.8), 4, 10, 11, 2, -1); soft(new THREE.Color(.7, .55, .4), 14, 2, 0, -9, 7);
scene.environment = pmrem.fromScene(envScene, .04).texture;
const key = new THREE.DirectionalLight(0xfff1df, 1.5); key.position.set(2.5, 6, 4); scene.add(key);
const rim = new THREE.DirectionalLight(0xffc68a, 1.1); rim.position.set(-5, 3, -6); scene.add(rim);
scene.add(new THREE.HemisphereLight(0xfff4e6, 0x2a1a10, .35));

// full-bleed background drawn in WebGL, so scrolling never repaints the page
const bgMat = new THREE.ShaderMaterial({
  uniforms:{uIn:{value:new THREE.Color('#5c3a22')}, uOut:{value:new THREE.Color('#0d0907')}, uC:{value:new THREE.Vector2(.35, .45)}, uAsp:{value:1}, uSeed:{value:0}},
  vertexShader:'varying vec2 vUv; void main(){ vUv = uv; gl_Position = vec4(position.xy, 0., 1.); }',
  fragmentShader:`varying vec2 vUv; uniform vec3 uIn; uniform vec3 uOut; uniform vec2 uC; uniform float uAsp; uniform float uSeed;
    float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233)) + uSeed) * 43758.5453); }
    void main(){
      vec2 d = vUv - uC; d.x *= uAsp;
      float r = length(d) * 1.35;
      vec3 c = mix(uIn, uOut, smoothstep(0., 1., r));
      float bx = vUv.x - uC.x + (vUv.y - 1.) * .32;
      float beam = smoothstep(.2, 0., abs(bx)) * smoothstep(.05, 1., vUv.y) * .22;
      c += beam * (uIn * .9 + vec3(.06, .05, .04));
      c *= 1. - .35 * smoothstep(.5, 1.05, length((vUv - .5) * vec2(uAsp * .8, 1.)));
      c += (h(gl_FragCoord.xy) - .5) / 255.;
      gl_FragColor = vec4(c, 1.);
    }`,
  depthTest:false, depthWrite:false
});
const bg = M(new THREE.PlaneGeometry(2, 2), bgMat); bg.frustumCulled = false; bg.renderOrder = -10; scene.add(bg);

/* ---------- suitcase + items: built in their own files ---------- */
const kit = {tex, lin, M, slabGeo, shellGeo, FONT};
const {bodyMat, bandMat, metal, rubber, leather, goldM, blob, knit, fitParts,
  W, D, Hb, Hl, T, Hc, Y0, TOP_L, TOP_R,
  display, stand, tilt, body, carry, posts, setTele, lidPivot} = P.buildSuitcase(kit, scene);
const {BUILD, META} = P.makeItems({...kit, knit, goldM, metal, rubber});

// 7 places on top of the folded clothes: [x, z, rest rotation]
const CELLS = [[-.72, -.3, .16], [.74, -.32, -.18], [-.22, -.36, .07], [.27, -.38, -.1], [-.62, .27, .14], [.64, .27, -.14], [.02, .24, .05]];
const ISC = 1.15;
const topAt = x => x < -.05 ? TOP_L : x > .05 ? TOP_R : Math.max(TOP_L, TOP_R);
function buildSet(list){
  return list.map((it, i) => {
    const [x, z, r] = CELLS[i], [hh0, fw, fd] = META[it.key], obj = BUILD[it.key](); obj.visible = false; body.add(obj);
    const hh = hh0 * ISC, base = topAt(x), slot = new THREE.Vector3(x, base + hh, z), side = x < 0 ? -1 : 1;
    const sh = blob(fw * ISC * 1.25, fd * ISC * 1.35, 0); sh.rotation.z = r; sh.position.set(x, base + .003, z); body.add(sh);
    const start = new THREE.Vector3(x + side * .55, slot.y + 1.75, z + .5);
    const spin = new THREE.Vector3((i % 2 ? .25 : -.22), side * .45, (i % 3 - 1) * .15);
    const a = A0 + i * STEP;
    return {...it, obj, slot, start, spin, rest:r, a, land:a + DUR, sh};
  });
}
const sets = {summer:buildSet(SEASONS.summer.items), winter:buildSet(SEASONS.winter.items)};
let items = sets[season];

/* ---------- straps + buckles (the last detail before the lid shuts) ---------- */
const straps = [-.2, .27].map(x => {
  const half = (sgn) => { const geo = new THREE.BoxGeometry(.085, .01, (D - 2 * T) / 2); geo.translate(0, 0, -sgn * (D - 2 * T) / 4);
    const m = M(geo, leather); m.position.set(x, .345, sgn * (D / 2 - T)); m.rotation.x = sgn * .08; m.visible = false; body.add(m); return m; };
  const f = half(1), b = half(-1);
  const buckle = M(new THREE.BoxGeometry(.13, .03, .07), goldM); buckle.position.set(x, .352, 0); buckle.visible = false; body.add(buckle);
  return {f, b, buckle};
});

/* ---------- particles ---------- */
const dotTex = tex(64, 64, (g) => { const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32); gr.addColorStop(0, 'rgba(255,244,220,1)'); gr.addColorStop(.35, 'rgba(240,205,150,.75)'); gr.addColorStop(1, 'rgba(240,205,150,0)'); g.fillStyle = gr; g.fillRect(0, 0, 64, 64); });
function burst(n, size, color, parent){
  const geo = new THREE.BufferGeometry(); const pos = new Float32Array(n * 3); geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const dirs = Array.from({length:n}, () => { const a = Math.random() * Math.PI * 2, s = .45 + Math.random() * .65; return [Math.cos(a) * s, .25 + Math.random() * .9, Math.sin(a) * s]; });
  const mat = new THREE.PointsMaterial({map:dotTex, size, color, transparent:true, depthWrite:false, blending:THREE.AdditiveBlending});
  const pts = new THREE.Points(geo, mat); pts.frustumCulled = false; pts.visible = false; parent.add(pts);
  return {set(c, age, reach){
    if (age <= 0 || age >= 1){ pts.visible = false; return; }
    pts.visible = true; const e = eo(age);
    for (let i = 0; i < n; i++){ const d = dirs[i]; pos[i * 3] = c.x + d[0] * reach * e; pos[i * 3 + 1] = c.y + d[1] * reach * e * .6 - age * age * .2; pos[i * 3 + 2] = c.z + d[2] * reach * e; }
    geo.attributes.position.needsUpdate = true; mat.opacity = (1 - age) * .9;
  }};
}
[...sets.summer, ...sets.winter].forEach(it => { it.fx = burst(12, .055, 0xffe2b0, body); });
// switching season: hide the other set at once; the new set follows the scroll position
onSeason = s => {
  const old = items; items = sets[s];
  old.forEach(it => { it.obj.visible = false; it.sh.material.opacity = 0; it.fx.set(it.slot, 0, 0); });
};
const slamFx = burst(46, .08, 0xfff2dc, body), finalFx = burst(70, .085, 0xf3cf8e, scene);
const SLAM_C = new THREE.Vector3(0, Hb, 0), FINAL_C = new THREE.Vector3(0, .2, 0);
const glow = new THREE.Sprite(new THREE.SpriteMaterial({map:dotTex, color:0xffe2b0, transparent:true, depthWrite:false, blending:THREE.AdditiveBlending}));
glow.scale.setScalar(.32); glow.visible = false; body.add(glow);

/* ---------- floor shadow + luggage tag ---------- */
const floorBlob = blob(1, 1, .55); scene.add(floorBlob);
const tag = new THREE.Group(); scene.add(tag);
{
  const leatherTag = M(slabGeo(.3, .46, .018, .05), leather); leatherTag.rotation.x = Math.PI / 2; leatherTag.position.set(0, -.3, 0); tag.add(leatherTag);
  const card = M(new THREE.PlaneGeometry(.22, .3), new THREE.MeshStandardMaterial({roughness:.7, map:tex(256, 350, (g, w, h) => {
    g.fillStyle = '#f6efe2'; g.fillRect(0, 0, w, h); g.fillStyle = '#100d0a'; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.font = `700 30px ${FONT.serif}`; g.fillText('NAOR', w / 2, 90); g.fillText('ROYAL', w / 2, 128); g.font = `600 18px ${FONT.mono}`; g.fillStyle = '#b07a45'; g.fillText('T O U R S', w / 2, 166);
    g.fillStyle = '#100d0a'; g.font = `700 30px ${FONT.he}`; g.fillText('מוכן לטיסה', w / 2, 250); g.strokeStyle = '#b07a45'; g.lineWidth = 3; g.strokeRect(14, 14, w - 28, h - 28);
  }, {text:true})}));
  card.position.set(0, -.33, .02); tag.add(card);
  const loop = M(new THREE.TorusGeometry(.06, .01, 8, 24), metal); loop.position.set(0, -.05, 0); tag.add(loop);
  const strapT = M(new THREE.BoxGeometry(.03, .1, .008), leather); strapT.position.set(0, -.1, 0); tag.add(strapT);
}
tag.visible = false;

/* ---------- color sync with the hero suitcase ---------- */
const colT = {body:lin('#b07a45'), band:lin('#2a1d13')};
addEventListener('nrt-color', e => { if (e.detail){ colT.body = lin(e.detail.body); colT.band = lin(e.detail.band); } });

/* ---------- stage colors for the background (sRGB) ---------- */
const BG_IN = ['#4e3220', '#50331f', '#523420', '#543521', '#563722', '#583822', '#5a3a23', '#5c3b24', '#4a3020', '#6a4c2a'].map(h => new THREE.Color(h));
const BG_OUT = ['#0b0806', '#0b0806', '#0b0806', '#0b0806', '#0b0806', '#0b0806', '#0b0806', '#0b0806', '#0a0705', '#0f0a06'].map(h => new THREE.Color(h));

/* ---------- layout: where the suitcase sits on screen ---------- */
let VW = 1, VH = 1, region = {cx:.5, cy:.5, w:1, h:1};
function layout(){
  const r = stage.getBoundingClientRect();
  const nW = Math.max(1, Math.round(r.width)), nH = Math.max(1, Math.round(r.height));
  // resizing the canvas clears it: only do it when the size really changed (not on every phone address-bar move)
  if (nW !== VW || nH !== VH || R.getPixelRatio() !== layout.dpr){ VW = nW; VH = nH; R.setSize(VW, VH, false); layout.dpr = R.getPixelRatio(); }
  if (isSmall()){
    // phone: the season buttons sit in the text column, right above the suitcase
    seasonEl.classList.remove('float'); seasonEl.style.left = seasonEl.style.top = '';
    const ctaEl = document.getElementById('pk-cta');
    const top = topEl.getBoundingClientRect().bottom - r.top + 8;
    let bot = bottomEl.getBoundingClientRect().top - r.top - 6;
    if (sec.classList.contains('done')) bot = Math.min(bot, ctaEl.getBoundingClientRect().top - r.top - 10);
    region = {cx:VW / 2, cy:(top + bot) / 2, w:VW * .94, h:Math.max(140, bot - top)};
  } else {
    // desktop: the season buttons float centred above the suitcase, which fits in the space below them
    const ui = topEl.parentElement.getBoundingClientRect(), freeW = VW - ui.width, cx = freeW * .53;
    const sTop = Math.max(84, VH * .12);
    seasonEl.classList.add('float');
    seasonEl.style.left = (cx - (ui.left - r.left)) + 'px'; seasonEl.style.top = (sTop - (ui.top - r.top)) + 'px';
    const top = sTop + seasonEl.offsetHeight + 14, bot = VH * .96;
    region = {cx, cy:(top + bot) / 2, w:freeW * .86, h:Math.max(200, bot - top)};
  }
  bgMat.uniforms.uC.value.set(region.cx / VW, 1 - region.cy / VH);
  bgMat.uniforms.uAsp.value = VW / VH;
}
layout(); relayout = layout; addEventListener('resize', layout);
if ('ResizeObserver' in window) new ResizeObserver(layout).observe(stage);
if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => { repaint.forEach(f => f()); layout(); });

// fit the suitcase into the region. The bounds are measured ONCE for the two poses
// (lying with the lid open, standing with the handle out) and blended, so the camera
// never "breathes" while the lid or handle moves.
const box = new THREE.Box3(), bc = new THREE.Vector3(), corner = new THREE.Vector3();
const boxLie = new THREE.Box3(), boxStand = new THREE.Box3();
const vx = new THREE.Vector3(), vy = new THREE.Vector3(), vz = new THREE.Vector3(), UP = new THREE.Vector3(0, 1, 0);
function measurePose(target, sv){
  const save = [lidPivot.rotation.x, tilt.rotation.x, stand.rotation.z, display.rotation.y, display.position.y, posts[0].scale.y];
  lidPivot.rotation.x = sv ? 0 : -TH; tilt.rotation.x = Math.PI / 2 * sv; stand.rotation.z = Math.PI / 2 * sv;
  setTele(sv ? .65 : .05); display.rotation.y = mix(-.32, -.55, sv); display.position.y = 0; display.updateMatrixWorld(true);
  target.makeEmpty(); fitParts.forEach(o => target.expandByObject(o));
  [lidPivot.rotation.x, tilt.rotation.x, stand.rotation.z, display.rotation.y, display.position.y] = save; setTele(save[5]);
  display.updateMatrixWorld(true);
}
let posesReady = false;
function frameCamera(dirv, pad, s){
  if (!posesReady){ measurePose(boxLie, 0); measurePose(boxStand, 1); posesReady = true; }
  const dx = region.cx - VW / 2, dy = region.cy - VH / 2;
  const fullW = VW + 2 * Math.abs(dx), fullH = VH + 2 * Math.abs(dy);
  camera.aspect = fullW / fullH;
  camera.setViewOffset(fullW, fullH, fullW / 2 - region.cx, fullH / 2 - region.cy, VW, VH);
  box.min.lerpVectors(boxLie.min, boxStand.min, s); box.max.lerpVectors(boxLie.max, boxStand.max, s); box.getCenter(bc);
  vz.copy(dirv).normalize(); vx.crossVectors(UP, vz).normalize(); vy.crossVectors(vz, vx);
  const tan = Math.tan(THREE.MathUtils.degToRad(camera.fov / 2));
  const kh = tan * region.h / fullH / pad, kw = tan * region.w / fullH / pad;
  let dist = 1;
  for (let i = 0; i < 8; i++){
    corner.set(i & 1 ? box.max.x : box.min.x, i & 2 ? box.max.y : box.min.y, i & 4 ? box.max.z : box.min.z).sub(bc);
    const px = corner.dot(vx), py = corner.dot(vy), pz = corner.dot(vz);
    dist = Math.max(dist, pz + Math.abs(py) / kh, pz + Math.abs(px) / kw);
  }
  // ease the framing so nothing on screen ever jitters
  if (!camInit){ camLook.copy(bc); camDist = dist; camInit = true; }
  const kf = 1 - Math.exp(-fitDt * 4);
  camLook.lerp(bc, kf); camDist += (dist - camDist) * kf;
  camera.position.copy(camLook).addScaledVector(vz, camDist);
  camera.lookAt(camLook);
}
const camLook = new THREE.Vector3(); let camDist = 1, camInit = false, fitDt = .016;

/* ---------- input ---------- */
const mouse = {x:0, y:0}, cm = {x:0, y:0};
addEventListener('pointermove', e => { mouse.x = e.clientX / innerWidth - .5; mouse.y = e.clientY / innerHeight - .5; }, {passive:true});

/* ---------- frame ---------- */
let pC = 0, visible = true, last = performance.now();
// always the latest report: the browser may deliver several at once when it is busy
new IntersectionObserver(es => { visible = es[es.length - 1].isIntersecting; }, {rootMargin:'100px 0px'}).observe(sec);
// the lid opens by itself when the suitcase comes into view
new IntersectionObserver(es => { if (es[es.length - 1].isIntersecting && tgt < 0) goTo(0); }, {threshold:.4}).observe(stage);
const qTmp = new THREE.Quaternion(), dir = new THREE.Vector3(), tmp = new THREE.Vector3(), cIn = BG_IN[0].clone(), cOut = BG_OUT[0].clone();
const TH = 1.86;

function render(now){
  const dt = Math.min(.05, (now - last) / 1000); last = now;
  // move toward the tapped stage: steady, slowing down at the end; unpacking goes faster
  if (snap){ pC = pT; snap = false; }
  const dp = pT - pC;
  if (dp){ const v = Math.min(dp > 0 ? .26 : .8, Math.abs(dp) * 5 + .03); pC += Math.sign(dp) * Math.min(Math.abs(dp), v * dt); }
  const p = pC, t = now * .001;

  let stg = 0; items.forEach((it, i) => { if (p >= it.land - DUR * .25) stg = i + 1; });
  if (p >= .71) stg = N + 1; if (p >= .935) stg = N + 2;
  setStage(stg);
  const k = 1 - Math.exp(-dt * 2.6);
  cIn.lerp(BG_IN[stg], k); cOut.lerp(BG_OUT[stg], k);
  bgMat.uniforms.uIn.value.copy(cIn); bgMat.uniforms.uOut.value.copy(cOut); /* static dither: no per-frame grain flicker */
  const kc = 1 - Math.exp(-dt * 4); bodyMat.color.lerp(colT.body, kc); bandMat.color.lerp(colT.band, kc);

  const open = eo5(seg(p, .015, .12)), close = ein(seg(p, .78, .845));
  lidPivot.rotation.x = -TH * open * (1 - close);

  items.forEach(it => {
    const q = seg(p, it.a, it.land);
    it.obj.visible = q > 0;
    if (q > 0){
      const e = eo(q);
      it.obj.position.set(mix(it.start.x, it.slot.x, e), mix(it.start.y, it.slot.y, eo5(q)), mix(it.start.z, it.slot.z, e));
      it.obj.rotation.set(it.spin.x * (1 - e), it.rest + it.spin.y * (1 - e), it.spin.z * (1 - e));
      const s = mix(.94, 1, eo(Math.min(1, q * 2.5)));
      const sq = 0;
      it.obj.scale.set(ISC * s * (1 + sq * .5), ISC * s * (1 - sq), ISC * s * (1 + sq * .5));
    }
    it.sh.material.opacity = .5 * Math.pow(q, 3);
  });

  const bk = seg(p, .76, .78);
  straps.forEach((st, i) => {
    const a = eo(seg(p, .715 + i * .012, .765 + i * .012));
    st.f.visible = st.b.visible = a > 0; st.f.scale.z = st.b.scale.z = Math.max(.001, a);
    st.buckle.visible = bk > 0; st.buckle.scale.setScalar(bk > 0 ? Math.max(.001, back(bk, 2.2)) : .001);
  });


  const z = seg(p, .85, .9);
  glow.visible = false;
  if (glow.visible){
    const per = 2 * (W + D), d = z * per, hw = W / 2 + .012, hd = D / 2 + .012;
    let x, zz;
    if (d < W){ x = hw - d; zz = hd; } else if (d < W + D){ x = -hw; zz = hd - (d - W); } else if (d < 2 * W + D){ x = -hw + (d - W - D); zz = -hd; } else { x = hw; zz = -hd + (d - 2 * W - D); }
    glow.position.set(x, Hb, zz); glow.material.opacity = Math.sin(Math.PI * z);
  }

  const s = eio(seg(p, .885, .95));
  tilt.rotation.x = Math.PI / 2 * s; stand.rotation.z = Math.PI / 2 * s;
  setTele(.05 + .6 * eo(seg(p, .94, .985)));
  const spin = Math.PI * 2 * eio(seg(p, .9, .985));
  const km = 1 - Math.exp(-dt * 3); cm.x += (mouse.x - cm.x) * km; cm.y += (mouse.y - cm.y) * km;
  display.rotation.y = mix(-.32, -.55, s) + spin + cm.x * .12;
  display.position.y = 0;
  const floorY = mix(-Hc, -W / 2 - .24, s);
  floorBlob.position.set(0, floorY + .003, mix(-.05, 0, s));
  floorBlob.scale.set(mix(3.2, 2.1, s), mix(2.4, 1.3, s), 1);


  const tg = seg(p, .955, .99);
  tag.visible = tg > 0;
  if (tag.visible){
    scene.updateMatrixWorld();
    carry.getWorldPosition(tag.position); body.getWorldQuaternion(qTmp); tmp.set(0, 0, 1).applyQuaternion(qTmp);
    tag.position.addScaledVector(tmp, .2); tag.position.y -= .03;
    tag.rotation.set(0, Math.atan2(camera.position.x - tag.position.x, camera.position.z - tag.position.z), Math.sin(t * 1.9) * .08);
    tag.scale.setScalar(Math.max(.001, back(tg, 2)));
  }

  const elev = mix(.92, .14, s), yaw = cm.x * .05;
  dir.set(Math.sin(yaw) * Math.cos(elev), Math.sin(elev), Math.cos(yaw) * Math.cos(elev));
  fitDt = dt; frameCamera(dir, 1.04, s);

  R.render(scene, camera);
}
// adaptive resolution, but only ONCE and only on a device that is clearly struggling
// (avg frame > 34ms over 90 frames). No repeated resolution jumps while scrolling.
let avg = 16, frames = 0, downgraded = false;
// draw only while something is moving (packing, pointer, colour change, resize); a still picture costs nothing
let awakeUntil = 0, lastW = 0, lastH = 0, lastItems = null;
function loop(now){
  requestAnimationFrame(loop);
  if (!visible || document.hidden){ last = now; loop.prev = 0; return; }
  const moving = Math.abs(pT - pC) > 1e-5 || Math.abs(mouse.x - cm.x) + Math.abs(mouse.y - cm.y) > .002 || tag.visible ||
    Math.abs(bodyMat.color.r - colT.body.r) + Math.abs(bodyMat.color.g - colT.body.g) > .002 || VW !== lastW || VH !== lastH || items !== lastItems;
  lastW = VW; lastH = VH; lastItems = items;
  if (moving) awakeUntil = now + 1200;
  if (now > awakeUntil){ last = now; loop.prev = 0; return; }
  render(now);
  if (loop.prev){ avg = avg * .97 + (now - loop.prev) * .03; frames++; }
  if (!downgraded && frames > 90 && avg > 34 && dpr > 1.25){ downgraded = true; dpr = 1.25; R.setPixelRatio(dpr); layout(); }
  loop.prev = now;
}
render(performance.now()); requestAnimationFrame(loop);
}
})();
