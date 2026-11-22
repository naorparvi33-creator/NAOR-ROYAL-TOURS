/* NAOR ROYAL TOURS · התנהגות כללית של העמוד: כפתורים מגנטיים, חשיפת אזורים בגלילה,
   פס ההתקדמות, התפריט העליון, ותפריט הנגישות. */
(function(){
const NRT = window.NRT; if (!NRT) return;
const {site, store, fine} = NRT;

/* ---------------- Magnetic buttons ---------------- */
if (fine){
  document.querySelectorAll('.mag').forEach(b => {
    b.addEventListener('pointermove', e => { if (NRT.reduce) return; const r = b.getBoundingClientRect(); b.style.transform = `translate(${(e.clientX - r.left - r.width/2)*.22}px,${(e.clientY - r.top - r.height/2)*.3}px)`; });
    b.addEventListener('pointerleave', () => { b.style.transition = 'transform .6s cubic-bezier(.34,1.56,.64,1)'; b.style.transform = ''; setTimeout(() => b.style.transition = '', 600); });
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
function onScroll(){
  const max = document.documentElement.scrollHeight - innerHeight;
  progress.style.transform = `scaleX(${max > 0 ? scrollY/max : 0})`;
  header.classList.toggle('solid', scrollY > 40);
  const r = steps.getBoundingClientRect(), p = Math.min(Math.max((innerHeight*.85 - r.top)/(innerHeight*.6), 0), 1);
  routePath.style.strokeDashoffset = routeLen*(1 - p);
  const pr = portraitImg.getBoundingClientRect(), pp = (pr.top + pr.height/2 - innerHeight/2)/innerHeight;
  if (!NRT.reduce) portraitImg.style.transform = `translateY(${(-8 - pp*10).toFixed(2)}%)`;
}
// at most one update per frame, however many scroll events the phone fires
let scrollRaf = 0;
addEventListener('scroll', () => { if (!scrollRaf) scrollRaf = requestAnimationFrame(() => { scrollRaf = 0; onScroll(); }); }, {passive:true}); onScroll();
const links = [...document.querySelectorAll('.nav a')], secs = links.map(a => document.querySelector(a.getAttribute('href')));
const navIO = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting){ const i = secs.indexOf(e.target); links.forEach((l,j) => l.classList.toggle('on', i === j)); } }), {rootMargin:'-45% 0px -50% 0px'});
secs.forEach(s => s && navIO.observe(s));

/* ---------------- Accessibility menu ---------------- */
const aBtn = document.getElementById('a11y-btn'), aPanel = document.getElementById('a11y-panel');
aBtn.addEventListener('click', () => { const open = aPanel.hidden; aPanel.hidden = !open; aBtn.setAttribute('aria-expanded', open); });
const applyA = (cls, on) => { site.classList.toggle(cls, on); if (cls === 'a-still') NRT.reduce = on || matchMedia('(prefers-reduced-motion: reduce)').matches; };
aPanel.querySelectorAll('[data-a]').forEach(b => {
  const k = b.dataset.a, saved = store.get('nrt-' + k) === '1';
  if (saved){ b.setAttribute('aria-pressed','true'); applyA(k, true); }
  b.addEventListener('click', () => { const on = b.getAttribute('aria-pressed') !== 'true'; b.setAttribute('aria-pressed', on); applyA(k, on); store.set('nrt-' + k, on ? '1' : '0'); });
});
addEventListener('keydown', e => { if (e.key === 'Escape' && !aPanel.hidden){ aPanel.hidden = true; aBtn.setAttribute('aria-expanded','false'); aBtn.focus(); } });
})();
