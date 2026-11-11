/* ---------------- Packing scene: scroll-driven 3D suitcase ---------------- */
(function(){
const sec = document.getElementById('pack'); if (!sec) return;
const stage = document.getElementById('pack-stage'), canvas = document.getElementById('pack-canvas');
const topEl = document.getElementById('pk-top'), bottomEl = document.getElementById('pk-bottom'), listEl = document.getElementById('pk-list');
const capEl = document.getElementById('pk-cap'), stepEl = document.getElementById('pk-step'), tEl = document.getElementById('pk-t'), sEl = document.getElementById('pk-s');

/* Packing guide: the 7 most important things to pack, per season.
   Based on traveller surveys of the most-forgotten items (toiletries, chargers, sunscreen),
   CDC travel-health guidance (medicine kit, sun protection, heat) and cold-weather
   packing guides (layering, waterproof boots, hat and gloves). */
const ICONS = {
  passport:'<rect x="5.5" y="2.5" width="13" height="19" rx="2"/><circle cx="12" cy="10" r="3.2"/><path d="M8.8 10h6.4M12 6.8c1.3 1.6 1.3 4.8 0 6.4M12 6.8c-1.3 1.6-1.3 4.8 0 6.4M9 17h6"/>',
  sunscreen:'<path d="M9 8h6v12a1.5 1.5 0 0 1-1.5 1.5h-3A1.5 1.5 0 0 1 9 20z"/><path d="M10 8V5h4v3M10.5 3h3M11 13h2M11 16h2"/>',
  hat:'<path d="M2.5 15.5c2.5 2 16.5 2 19 0"/><path d="M6.5 15.5c0-4.5 2.5-8 5.5-8s5.5 3.5 5.5 8"/><path d="M7 13.2h10"/>',
  swim:'<path d="M7 3v3.5c0 2 2 3.5 5 3.5s5-1.5 5-3.5V3"/><path d="M5 12.5h14l-2.5 7.5h-3L12 16l-1.5 4h-3z"/>',
  kit:'<rect x="3" y="8" width="18" height="12" rx="3"/><path d="M8.5 8V6.5a3.5 3.5 0 0 1 7 0V8M12 11.5v5M9.5 14h5"/>',
  charger:'<path d="M9 2.5v4.5M15 2.5v4.5"/><path d="M6.5 7h11v4a5.5 5.5 0 0 1-11 0z"/><path d="M12 16.5v5"/>',
  bottle:'<path d="M10 2.5h4v2.5h-4z"/><path d="M9 5h6l1 3v12a1.8 1.8 0 0 1-1.8 1.8H9.8A1.8 1.8 0 0 1 8 20V8z"/><path d="M8.3 12h7.4"/>',
  coat:'<path d="M8 3l4 3 4-3 4 3v15H4V6z"/><path d="M12 6v15M10 11h.01M10 15h.01"/>',
  layers:'<path d="M12 3 2.5 8 12 13l9.5-5z"/><path d="M2.5 12.3 12 17.3l9.5-5"/><path d="M2.5 16.5 12 21.5l9.5-5"/>',
  beanie:'<path d="M5 15a7 7 0 0 1 14 0"/><rect x="4" y="15" width="16" height="4.5" rx="1.5"/><circle cx="12" cy="5.2" r="1.8"/>',
  boots:'<path d="M6.5 3h6v9.5l6.2 2.8a2 2 0 0 1 1.3 1.9V20H4v-3.5l2.5-2z"/><path d="M4 18h16"/>',
  powerbank:'<rect x="6" y="2.5" width="12" height="19" rx="2.5"/><path d="M12.6 7.5 10 12.3h4l-2.6 4.7"/>'
};
const SEASONS = {
  summer:{
    name:'חופשת קיץ', short:'קיץ',
    items:[
      {key:'passport', t:'דרכון וביטוח נסיעות', s:'בדקו שהדרכון בתוקף לפחות חצי שנה קדימה, ושמרו צילום של הביטוח בטלפון.'},
      {key:'sunscreen', t:'קרם הגנה SPF 30+', s:'אחד הדברים שהכי שוכחים בקיץ. ומחירו ביעד כפול.'},
      {key:'hat', t:'כובע ומשקפי שמש', s:'הגנה מהשמש בשעות הצהריים. במיוחד לילדים.'},
      {key:'swim', t:'בגד ים', s:'שניים לכל אחד, כדי שתמיד יהיה אחד יבש.'},
      {key:'kit', t:'טואלטיקה ותרופות', s:'מברשת שיניים ותרופות קבועות בתיק היד, עם כמה ימים רזרבה.'},
      {key:'charger', t:'מטען ומתאם חשמל', s:'בהרבה יעדים השקע שונה. בלי מתאם, הטלפון נגמר ביום הראשון.'},
      {key:'bottle', t:'בקבוק מים רב־פעמי', s:'בחום שותים הרבה. ממלאים אחרי הבידוק בשדה.'}
    ]
  },
  winter:{
    name:'חופשת חורף', short:'חורף',
    items:[
      {key:'passport', t:'דרכון וביטוח נסיעות', s:'בדקו שהדרכון בתוקף לפחות חצי שנה קדימה. בחורף כדאי ביטוח שמכסה גם שלג וסקי.'},
      {key:'coat', t:'מעיל חם ועמיד למים', s:'השכבה החיצונית. עדיף מעיל אחד טוב משלושה סוודרים.'},
      {key:'layers', t:'ביגוד תרמי', s:'שכבה צמודה לגוף שומרת על חום ויובש. סט לכל יומיים־שלושה.'},
      {key:'beanie', t:'כובע צמר, כפפות וצעיף', s:'הרבה חום בורח מהראש ומהידיים. קטן בתיק, עושה הבדל ענק.'},
      {key:'boots', t:'נעליים אטומות למים', s:'הפריט הכי חשוב בחורף. רגליים רטובות הורסות יום שלם.'},
      {key:'kit', t:'טואלטיקה ותרופות', s:'מברשת שיניים, תרופות קבועות, וגם שפתון וקרם לחות לקור היבש.'},
      {key:'powerbank', t:'מטען וסוללה ניידת', s:'בקור הסוללה של הטלפון נגמרת מהר יותר. סוללה ניידת בתיק היד.'}
    ]
  }
};
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
  const io = new IntersectionObserver(es => { if (!es[0].isIntersecting){ io.disconnect(); go3D(); } });
  io.observe(sec);
}
function go3D(){
  sec.classList.remove('static'); capIdx = -1; setStage(0);
  const near = new IntersectionObserver(es => {
    if (es[0].isIntersecting && !started){ started = true; near.disconnect();
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

/* ---------- materials ---------- */
const grain = tex(256, 256, (g, w, h) => { const d = g.createImageData(w, h); for (let i = 0; i < d.data.length; i += 4){ const v = 118 + Math.random() * 20; d.data[i] = d.data[i + 1] = d.data[i + 2] = v; d.data[i + 3] = 255; } g.putImageData(d, 0, 0); }, {repeat:[5, 5]});
const bodyMat = new THREE.MeshPhysicalMaterial({color:lin('#9c6a3d'), roughness:.46, metalness:.02, clearcoat:.45, clearcoatRoughness:.28, bumpMap:grain, bumpScale:.0025, sheen:0});
const bandMat = new THREE.MeshStandardMaterial({color:lin('#2a1d13'), roughness:.5, metalness:.25});
const metal = new THREE.MeshStandardMaterial({color:lin('#dcd6cc'), roughness:.18, metalness:1});
const rubber = new THREE.MeshStandardMaterial({color:lin('#141110'), roughness:.8});
const leather = new THREE.MeshStandardMaterial({color:lin('#8a5a32'), roughness:.55});
const goldM = new THREE.MeshStandardMaterial({color:lin('#e2bd84'), roughness:.24, metalness:1});
const lining = (w, h) => tex(w, h, (g, W, H) => {
  g.fillStyle = '#ede1cd'; g.fillRect(0, 0, W, H);
  g.strokeStyle = 'rgba(150,110,70,.13)'; g.lineWidth = 2;
  for (let i = -H; i < W + H; i += 46){ g.beginPath(); g.moveTo(i, 0); g.lineTo(i + H, H); g.stroke(); g.beginPath(); g.moveTo(i + H, 0); g.lineTo(i, H); g.stroke(); }
  g.fillStyle = 'rgba(176,122,69,.30)'; g.font = `700 22px ${FONT.serif}`; g.textAlign = 'center'; g.textBaseline = 'middle';
  for (let y = 23, r = 0; y < H; y += 46, r++) for (let x = (r % 2 ? 46 : 23); x < W; x += 92) g.fillText('N', x, y);
  const edge = (x0, y0, x1, y1) => { const gr = g.createLinearGradient(x0, y0, x1, y1); gr.addColorStop(0, 'rgba(70,45,25,.42)'); gr.addColorStop(1, 'rgba(70,45,25,0)'); g.fillStyle = gr; g.fillRect(0, 0, W, H); };
  const e = Math.min(W, H) * .16; edge(0, 0, e, 0); edge(W, 0, W - e, 0); edge(0, 0, 0, e); edge(0, H, 0, H - e);
}, {text:true});
const floorMat = new THREE.MeshStandardMaterial({map:lining(1024, 680), roughness:.9});
const ceilMat = new THREE.MeshStandardMaterial({map:lining(1024, 680), roughness:.9, side:THREE.DoubleSide});
const wallMat = new THREE.MeshStandardMaterial({color:lin('#d9c8ad'), roughness:.92});
const netMat = new THREE.MeshStandardMaterial({map:tex(256, 256, (g, w, h) => {
  g.strokeStyle = 'rgba(120,85,50,.85)'; g.lineWidth = 2.5;
  for (let i = -h; i < w + h; i += 18){ g.beginPath(); g.moveTo(i, 0); g.lineTo(i + h, h); g.stroke(); g.beginPath(); g.moveTo(i + h, 0); g.lineTo(i, h); g.stroke(); }
}, {repeat:[7, 3]}), transparent:true, alphaTest:.04, roughness:.8, side:THREE.DoubleSide});
const shadowTex = tex(128, 128, (g) => { const gr = g.createRadialGradient(64, 64, 0, 64, 64, 64); gr.addColorStop(0, 'rgba(0,0,0,.75)'); gr.addColorStop(.55, 'rgba(0,0,0,.35)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, 128, 128); });
function blob(w, d, opacity){
  const m = M(new THREE.PlaneGeometry(w, d), new THREE.MeshBasicMaterial({map:shadowTex, transparent:true, depthWrite:false, opacity}));
  m.rotation.x = -Math.PI / 2; m.renderOrder = 1; return m;
}

/* ---------- suitcase ---------- */
let fitParts = [];
const W = 2.3, D = 1.55, Hb = .38, Hl = .38, T = .045, RAD = .26, Hc = (Hb + Hl) / 2, Y0 = .046;
const display = new THREE.Group(), stand = new THREE.Group(), tilt = new THREE.Group(), body = new THREE.Group();
scene.add(display); display.add(stand); stand.add(tilt); tilt.add(body); body.position.y = -Hc;

body.add(M(shellGeo(W, D, Hb, T, RAD), bodyMat));
body.add(M(slabGeo(W, D, .04, RAD), bodyMat));
const rimB = M(shellGeo(W + .02, D + .02, .05, T + .01, RAD + .01, .01), bandMat); rimB.position.y = Hb - .05; body.add(rimB);
const floor = M(new THREE.PlaneGeometry(W - 2 * T, D - 2 * T), floorMat); floor.rotation.x = -Math.PI / 2; floor.position.y = Y0; body.add(floor);
const wallB = M(shellGeo(W - 2 * T - .004, D - 2 * T - .004, Hb - .06, .01, RAD - T, 0), wallMat); wallB.position.y = .04; body.add(wallB);
const ribGeo = new THREE.CylinderGeometry(.011, .011, W * .7, 16); ribGeo.rotateZ(Math.PI / 2);
for (let z = -.54; z <= .55; z += .18){ const r = M(ribGeo, bodyMat); r.position.set(-.06, -.002, z); r.scale.y = .6; body.add(r); }
const carry = M(new THREE.TorusGeometry(.19, .036, 14, 40, Math.PI), rubber); carry.rotation.x = Math.PI / 2; carry.position.set(0, Hb * .52, D / 2 + .012); body.add(carry);
function wheels(parent, y, z){
  const house = M(new THREE.CylinderGeometry(.07, .085, .11, 22), bandMat); house.rotation.z = Math.PI / 2; house.position.set(-W / 2 - .045, y, z); parent.add(house);
  [-.042, .042].forEach(o => { const w = M(new THREE.CylinderGeometry(.08, .08, .046, 26), rubber); w.rotation.x = Math.PI / 2; w.position.set(-W / 2 - .16, y, z + o); parent.add(w);
    const hub = M(new THREE.CylinderGeometry(.03, .03, .05, 16), metal); hub.rotation.x = Math.PI / 2; hub.position.copy(w.position); parent.add(hub); });
}
wheels(body, Hb * .5, D / 2 - .24); wheels(body, Hb * .5, -D / 2 + .24);
const tele = new THREE.Group(); tele.position.set(W / 2, Hb * .55, 0); body.add(tele);
const posts = [-.4, .4].map(z => { const p = M(new THREE.CylinderGeometry(.028, .028, 1, 16), metal); p.rotation.z = Math.PI / 2; p.position.z = z; tele.add(p);
  const cap = M(new THREE.BoxGeometry(.04, .09, .11), bandMat); cap.position.set(.018, 0, z); tele.add(cap); return p; });
const grip = M(new THREE.CylinderGeometry(.055, .055, .94, 24), rubber); grip.rotation.x = Math.PI / 2; tele.add(grip);
function setTele(len){ posts.forEach(p => { p.scale.y = len; p.position.x = len / 2; }); grip.position.x = len + .03; }
setTele(.05);
fitParts.push(body.children[0], tele);

// lid
const lidPivot = new THREE.Group(); lidPivot.position.set(0, Hb, -D / 2); body.add(lidPivot);
const lid = new THREE.Group(); lid.position.z = D / 2; lidPivot.add(lid);
fitParts.push(lid);
lid.add(M(shellGeo(W, D, Hl, T, RAD), bodyMat));
const lidTop = M(slabGeo(W, D, .04, RAD), bodyMat); lidTop.position.y = Hl - .04; lid.add(lidTop);
lid.add(M(shellGeo(W + .02, D + .02, .05, T + .01, RAD + .01, .01), bandMat));
const ceil = M(new THREE.PlaneGeometry(W - 2 * T, D - 2 * T), ceilMat); ceil.rotation.x = Math.PI / 2; ceil.position.y = Hl - .042; lid.add(ceil);
const wallL = M(shellGeo(W - 2 * T - .004, D - 2 * T - .004, Hl - .06, .01, RAD - T, 0), wallMat); wallL.position.y = .02; lid.add(wallL);
const net = M(new THREE.PlaneGeometry(W - .3, D * .46), netMat); net.rotation.x = Math.PI / 2; net.position.set(0, Hl - .07, D * .2); lid.add(net);
const zip = M(new THREE.BoxGeometry(W - .3, .012, .028), bandMat); zip.position.set(0, Hl - .074, D * .2 - D * .23); lid.add(zip);
const pull = M(new THREE.BoxGeometry(.05, .01, .09), goldM); pull.position.set(.55, Hl - .08, D * .2 - D * .23 - .03); lid.add(pull);
const label = M(new THREE.PlaneGeometry(.5, .14), new THREE.MeshStandardMaterial({roughness:.7, map:tex(512, 144, (g, w, h) => {
  g.fillStyle = '#100d0a'; g.fillRect(0, 0, w, h); g.strokeStyle = '#b07a45'; g.lineWidth = 4; g.strokeRect(10, 10, w - 20, h - 20);
  g.fillStyle = '#e8c690'; g.font = `700 46px ${FONT.serif}`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('NAOR ROYAL TOURS', w / 2, h / 2 + 2);
}, {text:true})}));
label.rotation.x = Math.PI / 2; label.position.set(0, Hl - .075, D * .2 + D * .23 + .05); lid.add(label);
for (let z = -.54; z <= .55; z += .18){ const r = M(ribGeo, bodyMat); r.position.set(-.06, Hl + .002, z); r.scale.y = .6; lid.add(r); }
const plate = M(new THREE.BoxGeometry(.11, .012, .36), [goldM, goldM, new THREE.MeshStandardMaterial({metalness:.75, roughness:.28, map:tex(128, 420, (g, w, h) => {
  const gr = g.createLinearGradient(0, 0, w, h); gr.addColorStop(0, '#f2d9a8'); gr.addColorStop(.5, '#d3a46e'); gr.addColorStop(1, '#b8844f'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
  g.translate(w / 2, h / 2); g.rotate(Math.PI / 2); g.fillStyle = '#3a2614'; g.font = `700 50px ${FONT.serif}`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('NAOR ROYAL', 0, 2);
}, {text:true})}), goldM, goldM, goldM]);
plate.position.set(W / 2 - .3, Hl + .006, 0); lid.add(plate);
wheels(lid, Hl * .5, D / 2 - .24); wheels(lid, Hl * .5, -D / 2 + .24);

/* ---------- folded clothes ---------- */
const knit = (base, line, step) => tex(256, 256, (g, w, h) => { g.fillStyle = base; g.fillRect(0, 0, w, h); g.strokeStyle = line; g.lineWidth = 3;
  for (let x = 0; x < w; x += step){ g.beginPath(); g.moveTo(x, 0); g.lineTo(x, h); g.stroke(); } }, {repeat:[4, 4]});
const linen = tex(256, 256, (g, w, h) => { g.fillStyle = '#f6f2ea'; g.fillRect(0, 0, w, h); for (let i = 0; i < 3000; i++){ g.fillStyle = `rgba(120,100,70,${Math.random() * .08})`; g.fillRect(Math.random() * w, Math.random() * h, 3, 1); } }, {repeat:[3, 3]});
const stripe = (a, b) => tex(256, 256, (g, w, h) => { g.fillStyle = a; g.fillRect(0, 0, w, h); g.fillStyle = b; for (let y = 0; y < h; y += 64){ g.fillRect(0, y, w, 22); } });
function fold(w, d, h, map, x, y, z, ry){
  const m = M(slabGeo(w, d, h, .08, .022, 4), new THREE.MeshStandardMaterial({map, roughness:.96}));
  m.position.set(x, y, z); m.rotation.y = ry; body.add(m);
  const crease = M(new THREE.BoxGeometry(w * .96, .004, .006), new THREE.MeshBasicMaterial({color:0x000000, transparent:true, opacity:.12})); crease.position.set(x, y + h + .023, z + d * .18); crease.rotation.y = ry; body.add(crease);
}
fold(.98, 1.0, .07, knit('#23324d', 'rgba(0,0,0,.18)', 9), -.55, Y0, -.15, .02);
fold(.92, .95, .06, linen, -.55, Y0 + .092, -.15, -.015);
fold(.97, 1.0, .07, knit('#e9dcc6', 'rgba(120,90,60,.16)', 10), .52, Y0, -.15, -.02);
fold(.88, .92, .05, knit('#b07a45', 'rgba(60,35,15,.2)', 9), .52, Y0 + .092, -.15, .025);
[[-.55, stripe('#f2e8d8', '#b07a45')], [.52, stripe('#f7f4ef', '#23324d')]].forEach(([x, map]) => {
  const m = M(new THREE.CylinderGeometry(.085, .085, .94, 32), new THREE.MeshStandardMaterial({map, roughness:.96})); m.rotation.z = Math.PI / 2; m.position.set(x, Y0 + .085, .53); body.add(m);
  const sw = M(new THREE.CylinderGeometry(.086, .086, .02, 32), new THREE.MeshStandardMaterial({color:lin('#d8c6a8'), roughness:.96})); sw.rotation.z = Math.PI / 2; sw.position.set(x + .3, Y0 + .085, .53); body.add(sw);
});
[[-.55, -.15, 1.1, 1.12], [.52, -.15, 1.1, 1.12], [0, .53, 2.1, .3]].forEach(([x, z, w, d]) => { const b = blob(w, d, .35); b.position.set(x, Y0 + .002, z); body.add(b); });
const TOP_L = Y0 + .092 + .06 + .022, TOP_R = Y0 + .092 + .05 + .022;

/* ---------- items ---------- */
function boxTop(w, h, d, topMap, sideColor, rough = .5, metalness = 0){
  const side = new THREE.MeshStandardMaterial({color:lin(sideColor), roughness:rough, metalness});
  const top = new THREE.MeshStandardMaterial({map:topMap, roughness:rough, metalness});
  return M(new THREE.BoxGeometry(w, h, d), [side, side, top, side, side, side]);
}
const std = (color, rough = .6, metal = 0) => new THREE.MeshStandardMaterial({color:lin(color), roughness:rough, metalness:metal});
function makePassport(){
  const t = tex(512, 720, (g, w, h) => {
    const gr = g.createLinearGradient(0, 0, w, h); gr.addColorStop(0, '#26395f'); gr.addColorStop(1, '#141e35'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
    for (let i = 0; i < 2600; i++){ g.fillStyle = `rgba(255,255,255,${Math.random() * .05})`; g.fillRect(Math.random() * w, Math.random() * h, 2, 2); }
    g.strokeStyle = '#d9b56d'; g.fillStyle = '#d9b56d'; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.font = `700 64px ${FONT.he}`; g.fillText('דרכון', w / 2, 140);
    g.lineWidth = 6; g.beginPath(); g.arc(w / 2, 365, 92, 0, Math.PI * 2); g.stroke();
    g.lineWidth = 4; g.beginPath(); g.ellipse(w / 2, 365, 40, 92, 0, 0, Math.PI * 2); g.stroke();
    [-46, 0, 46].forEach(o => { const hw = Math.sqrt(92 * 92 - o * o); g.beginPath(); g.moveTo(w / 2 - hw, 365 + o); g.lineTo(w / 2 + hw, 365 + o); g.stroke(); });
    g.font = `500 46px ${FONT.serif}`; g.fillText('PASSPORT', w / 2, 560);
    g.lineWidth = 3; g.strokeRect(w / 2 - 34, 616, 68, 46); g.beginPath(); g.arc(w / 2, 639, 12, 0, Math.PI * 2); g.stroke();
  }, {text:true});
  const grp = new THREE.Group();
  grp.add(boxTop(.37, .034, .53, t, '#1a2742', .5));
  const pages = M(new THREE.BoxGeometry(.355, .026, .515), std('#f1ece2', .9)); pages.position.set(.009, -.001, 0); grp.add(pages);
  return grp;
}
function makeGlasses(){
  const grp = new THREE.Group();
  const tort = new THREE.MeshPhysicalMaterial({color:lin('#3b2414'), roughness:.18, clearcoat:1, clearcoatRoughness:.06});
  const lens = new THREE.MeshPhysicalMaterial({color:lin('#2a1a10'), roughness:.03, metalness:.2, clearcoat:1, envMapIntensity:1.8});
  [-1, 1].forEach(s => {
    const l = M(new THREE.CylinderGeometry(.1, .1, .012, 40), lens); l.scale.x = 1.2; l.position.x = s * .135; grp.add(l);
    const f = M(new THREE.TorusGeometry(.1, .016, 12, 48), tort); f.rotation.x = Math.PI / 2; f.scale.x = 1.2; f.position.x = s * .135; grp.add(f);
    const tmp = M(new THREE.BoxGeometry(.42, .016, .02), tort); tmp.position.set(-s * .015, -.006 + s * .009, -.085 - (s > 0 ? .016 : 0)); grp.add(tmp);
  });
  const bridge = M(new THREE.TorusGeometry(.038, .013, 8, 20, Math.PI), tort); bridge.rotation.x = -Math.PI / 2; bridge.position.set(0, .002, .05); grp.add(bridge);
  return grp;
}
function makeSunscreen(){
  const hh = .04, grp = new THREE.Group();
  const label = tex(512, 208, (g, w, h) => {
    const gr = g.createLinearGradient(0, 0, w, 0); gr.addColorStop(0, '#ffd36b'); gr.addColorStop(1, '#ff9f43'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
    g.fillStyle = '#fffaf0'; g.fillRect(0, h * .66, w, h * .34);
    g.fillStyle = '#7a3b10'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.font = `700 84px ${FONT.mono}`; g.fillText('SPF 50', w / 2 - 20, h * .34);
    g.font = `700 34px ${FONT.serif}`; g.fillStyle = '#b07a45'; g.fillText('SUN CARE', w / 2 - 20, h * .84);
  }, {text:true});
  const tube = boxTop(.3, .07, .13, label, '#ffb45a', .35); tube.position.set(-.03, -hh + .035, 0); grp.add(tube);
  const capG = new THREE.CylinderGeometry(.045, .05, .07, 32); capG.rotateZ(Math.PI / 2);
  const cap = M(capG, std('#fffaf0', .3)); cap.position.set(.155, -hh + .045, 0); grp.add(cap);
  return grp;
}
function makeHat(){
  const hh = .065, grp = new THREE.Group();
  const straw = tex(256, 256, (g, w, h) => { g.fillStyle = '#e6cd98'; g.fillRect(0, 0, w, h); g.strokeStyle = 'rgba(140,100,50,.35)'; g.lineWidth = 2;
    for (let y = 0; y < h; y += 8){ g.beginPath(); g.moveTo(0, y); g.lineTo(w, y + 4); g.stroke(); } }, {repeat:[3, 3]});
  const sm = new THREE.MeshStandardMaterial({map:straw, roughness:.9});
  const brim = M(new THREE.CylinderGeometry(.21, .22, .012, 56), sm); brim.position.y = -hh + .006; grp.add(brim);
  const crown = M(new THREE.SphereGeometry(.12, 40, 20, 0, Math.PI * 2, 0, Math.PI / 2), sm); crown.scale.y = .95; crown.position.y = -hh + .012; grp.add(crown);
  const band = M(new THREE.CylinderGeometry(.122, .122, .03, 40, 1, true), new THREE.MeshStandardMaterial({color:lin('#2a1d13'), roughness:.6, side:THREE.DoubleSide})); band.position.y = -hh + .028; grp.add(band);
  const gl = makeGlasses(); gl.scale.setScalar(.6); gl.position.set(0, -hh + .03, .165); gl.rotation.x = -.12; grp.add(gl);
  return grp;
}
function makeSwim(){
  const hh = .03, grp = new THREE.Group();
  const dots = (base, dot) => tex(128, 128, (g, w, h) => { g.fillStyle = base; g.fillRect(0, 0, w, h); g.fillStyle = dot;
    for (let y = 16; y < h; y += 32) for (let x = (y / 32) % 2 ? 32 : 16; x < w; x += 32){ g.beginPath(); g.arc(x, y, 6, 0, Math.PI * 2); g.fill(); } }, {repeat:[6, 6]});
  const a = M(slabGeo(.38, .28, .022, .08, .01), new THREE.MeshStandardMaterial({map:dots('#1f9fb3', '#fff6e6'), roughness:.7})); a.position.y = -hh + .01; grp.add(a);
  const b = M(slabGeo(.28, .13, .02, .05, .008), new THREE.MeshStandardMaterial({map:dots('#f08a5d', '#fff6e6'), roughness:.7})); b.position.set(.03, -hh + .036, -.03); b.rotation.y = .25; grp.add(b);
  return grp;
}
function makeKit(){
  const hh = .07, grp = new THREE.Group();
  const pouch = M(slabGeo(.42, .24, .1, .07, .02), new THREE.MeshStandardMaterial({map:knit('#2f3e5c', 'rgba(0,0,0,.15)', 6), roughness:.85})); pouch.position.y = -hh + .02; grp.add(pouch);
  const zip = M(new THREE.BoxGeometry(.36, .008, .016), std('#1a140f', .5)); zip.position.y = hh - .002; grp.add(zip);
  const pull = M(new THREE.BoxGeometry(.05, .008, .028), goldM); pull.position.set(.16, hh + .002, .02); grp.add(pull);
  const cross = M(new THREE.PlaneGeometry(.08, .08), new THREE.MeshStandardMaterial({roughness:.6, map:tex(128, 128, (g, w, h) => {
    g.fillStyle = '#fbf6ee'; g.fillRect(0, 0, w, h); g.fillStyle = '#c8362e'; g.fillRect(w * .4, h * .18, w * .2, h * .64); g.fillRect(w * .18, h * .4, w * .64, h * .2);
  })}));
  cross.rotation.x = -Math.PI / 2; cross.position.set(-.1, hh + .001, .04); grp.add(cross);
  const brushG = new THREE.CylinderGeometry(.011, .011, .26, 12); brushG.rotateZ(Math.PI / 2);
  const brush = M(brushG, std('#7fc6d6', .3)); brush.position.set(.02, hh + .012, -.07); brush.rotation.y = .1; grp.add(brush);
  const head = M(new THREE.BoxGeometry(.04, .02, .018), std('#ffffff', .8)); head.position.set(.15, hh + .022, -.057); grp.add(head);
  return grp;
}
function makeCharger(){
  const hh = .045, grp = new THREE.Group(), white = new THREE.MeshPhysicalMaterial({color:lin('#f4f2ee'), roughness:.3, clearcoat:.8});
  const plug = M(new THREE.BoxGeometry(.11, .09, .11), white); plug.position.set(-.11, -hh + .045, 0); grp.add(plug);
  [-.025, .025].forEach(z => { const pg = new THREE.CylinderGeometry(.008, .008, .06, 10); pg.rotateZ(Math.PI / 2); const p = M(pg, metal); p.position.set(-.195, -hh + .045, z); grp.add(p); });
  const cable = new THREE.MeshStandardMaterial({color:lin('#f4f2ee'), roughness:.5});
  const c1 = M(new THREE.TorusGeometry(.09, .011, 8, 48), cable); c1.rotation.x = Math.PI / 2; c1.position.set(.08, -hh + .011, .01); grp.add(c1);
  const c2 = M(new THREE.TorusGeometry(.075, .011, 8, 48), cable); c2.rotation.x = Math.PI / 2; c2.position.set(.09, -hh + .033, 0); grp.add(c2);
  const usb = M(new THREE.BoxGeometry(.05, .02, .025), std('#d9d4cc', .3, .5)); usb.position.set(.18, -hh + .012, .07); grp.add(usb);
  return grp;
}
function makeBottle(){
  const hh = .065, grp = new THREE.Group();
  const g = new THREE.CylinderGeometry(.065, .065, .3, 40); g.rotateZ(Math.PI / 2);
  const b = M(g, new THREE.MeshPhysicalMaterial({color:lin('#3e7c87'), roughness:.28, metalness:.55, clearcoat:.6})); b.position.set(-.03, 0, 0); grp.add(b);
  const cg = new THREE.CylinderGeometry(.05, .05, .06, 32); cg.rotateZ(Math.PI / 2);
  const cap = M(cg, std('#1b1714', .5)); cap.position.set(.15, 0, 0); grp.add(cap);
  const rg = new THREE.CylinderGeometry(.067, .067, .02, 40); rg.rotateZ(Math.PI / 2);
  const ring = M(rg, goldM); ring.position.set(-.08, 0, 0); grp.add(ring);
  return grp;
}
function makeCoat(){
  const hh = .06, grp = new THREE.Group();
  const coat = M(slabGeo(.48, .38, .07, .07, .015), new THREE.MeshStandardMaterial({map:knit('#24324a', 'rgba(0,0,0,.2)', 5), roughness:.9})); coat.position.y = -hh + .015; grp.add(coat);
  const collar = M(slabGeo(.46, .1, .02, .04, .006), new THREE.MeshStandardMaterial({map:knit('#8a6a4a', 'rgba(0,0,0,.2)', 4), roughness:.95})); collar.position.set(0, hh - .022, -.13); grp.add(collar);
  [-.12, 0, .12].forEach(x => { const bt = M(new THREE.CylinderGeometry(.018, .018, .01, 20), goldM); bt.position.set(x, hh - .015, .06); grp.add(bt); });
  return grp;
}
function makeLayers(){
  const hh = .035, grp = new THREE.Group();
  const a = M(slabGeo(.42, .32, .024, .06, .008), new THREE.MeshStandardMaterial({map:knit('#e9e3d8', 'rgba(90,70,50,.18)', 5), roughness:.95})); a.position.y = -hh + .008; grp.add(a);
  const b = M(slabGeo(.4, .3, .024, .06, .008), new THREE.MeshStandardMaterial({map:knit('#7a2e2e', 'rgba(0,0,0,.2)', 5), roughness:.95})); b.position.set(.02, -hh + .04, .01); b.rotation.y = -.08; grp.add(b);
  return grp;
}
function makeBeanie(){
  const hh = .1, grp = new THREE.Group(), wool = new THREE.MeshStandardMaterial({map:knit('#b0413e', 'rgba(0,0,0,.2)', 6), roughness:.95});
  const cuff = M(new THREE.CylinderGeometry(.115, .115, .045, 36), new THREE.MeshStandardMaterial({map:knit('#8d2f2d', 'rgba(0,0,0,.25)', 4), roughness:.95})); cuff.position.set(-.12, -hh + .0225, 0); grp.add(cuff);
  const dome = M(new THREE.SphereGeometry(.11, 36, 18, 0, Math.PI * 2, 0, Math.PI / 2), wool); dome.scale.y = 1.1; dome.position.set(-.12, -hh + .045, 0); grp.add(dome);
  const pom = M(new THREE.SphereGeometry(.038, 20, 14), std('#f3ead9', 1)); pom.position.set(-.12, -hh + .045 + .121 + .02, 0); grp.add(pom);
  const glove = new THREE.MeshStandardMaterial({map:knit('#3a3a44', 'rgba(255,255,255,.08)', 5), roughness:.95});
  [[.1, -.02, .2], [.19, .03, -.15]].forEach(([x, z, r], i) => {
    const gl = M(slabGeo(.1, .17, .024, .045, .008), glove); gl.position.set(x, -hh + .008 + i * .028, z); gl.rotation.y = r; grp.add(gl);
    const th = M(slabGeo(.035, .08, .022, .016, .006), glove); th.position.set(x + .06, -hh + .008 + i * .028, z + .02); th.rotation.y = r + .5; grp.add(th);
  });
  return grp;
}
function makeBoots(){
  const hh = .045, grp = new THREE.Group();
  const s = new THREE.Shape();
  s.moveTo(-.06, -.15); s.lineTo(.05, -.15); s.lineTo(.05, .02); s.quadraticCurveTo(.06, .04, .12, .05);
  s.quadraticCurveTo(.18, .07, .17, .12); s.quadraticCurveTo(.16, .15, .1, .15); s.lineTo(-.06, .15); s.lineTo(-.06, -.15);
  const up = new THREE.ExtrudeGeometry(s, {depth:.065, bevelEnabled:true, bevelThickness:.008, bevelSize:.008, bevelSegments:3, curveSegments:14}); up.rotateX(-Math.PI / 2);
  const so = new THREE.ExtrudeGeometry(s, {depth:.014, bevelEnabled:false, curveSegments:14}); so.rotateX(-Math.PI / 2);
  const leatherB = new THREE.MeshStandardMaterial({color:lin('#5b3a24'), roughness:.5, metalness:.05});
  [[-.08, .05, 1], [.1, -.03, -1]].forEach(([x, z, m]) => {
    const b = new THREE.Group(); b.position.set(x, 0, z); b.scale.x = m; b.rotation.y = m * .12; grp.add(b);
    const sole = M(so, rubber); sole.position.y = -hh; b.add(sole);
    const top = M(up, leatherB); top.position.y = -hh + .022; b.add(top);
  });
  return grp;
}
function makePowerBank(){
  const hh = .045, grp = new THREE.Group();
  const face = tex(256, 450, (g, w, h) => {
    g.fillStyle = '#2b2f36'; g.fillRect(0, 0, w, h);
    g.strokeStyle = '#e8c690'; g.lineWidth = 10; g.lineJoin = 'round'; g.beginPath(); g.moveTo(140, 120); g.lineTo(100, 220); g.lineTo(160, 220); g.lineTo(118, 320); g.stroke();
    [0, 1, 2, 3].forEach(i => { g.fillStyle = i < 3 ? '#5fe08f' : '#3b414a'; g.fillRect(70 + i * 32, 390, 20, 12); });
  });
  const bank = boxTop(.17, .03, .3, face, '#2b2f36', .35, .4); bank.position.set(-.07, -hh + .015, 0); grp.add(bank);
  const plug = M(new THREE.BoxGeometry(.09, .08, .09), new THREE.MeshPhysicalMaterial({color:lin('#f4f2ee'), roughness:.3, clearcoat:.8})); plug.position.set(.12, -hh + .04, -.07); grp.add(plug);
  const c = M(new THREE.TorusGeometry(.065, .01, 8, 40), std('#f4f2ee', .5)); c.rotation.x = Math.PI / 2; c.position.set(.12, -hh + .01, .08); grp.add(c);
  return grp;
}
const BUILD = {passport:makePassport, sunscreen:makeSunscreen, hat:makeHat, swim:makeSwim, kit:makeKit, charger:makeCharger, bottle:makeBottle,
  coat:makeCoat, layers:makeLayers, beanie:makeBeanie, boots:makeBoots, powerbank:makePowerBank};
// [half height, footprint width, footprint depth] of each model, before scaling
const META = {passport:[.017, .37, .53], sunscreen:[.04, .36, .13], hat:[.065, .44, .44], swim:[.03, .38, .28], kit:[.07, .42, .24], charger:[.045, .38, .22],
  bottle:[.065, .38, .13], coat:[.06, .48, .38], layers:[.035, .42, .32], beanie:[.1, .48, .26], boots:[.045, .4, .3], powerbank:[.045, .36, .3]};
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
new IntersectionObserver(es => { visible = es[0].isIntersecting; }, {rootMargin:'100px 0px'}).observe(sec);
// the lid opens by itself when the suitcase comes into view
new IntersectionObserver(es => { if (es[0].isIntersecting && tgt < 0) goTo(0); }, {threshold:.4}).observe(stage);
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

