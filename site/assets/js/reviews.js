/* NAOR ROYAL TOURS · המלצות: פס צילומי המסך שנע לבד, נגרר באצבע, ונפתח להגדלה בלחיצה. */
(function(){
const NRT = window.NRT; if (!NRT) return;
const {openDlg} = NRT;

const REV = ['img/r1.webp','img/r2.webp','img/r3.webp','img/r4.webp','img/r5.webp'];
const REV_ALT = ['לקוחות מודים לנאור אחרי אישור המלון','לקוחה מודה לנאור על הכול','לקוח מספר שהמלון מושלם ומודה על השירות','לקוח ממליץ על נאור ומודה על הסבלנות','לקוחה מודה על חופשה כשרה שלא עלתה משכורת'];
const rt = document.getElementById('rev-track');
const revHTML = REV.map((s,i) => `<button class="phone" data-src="${i}" aria-label="הגדלת המלצה: ${REV_ALT[i]}"><img src="${s}" alt="${REV_ALT[i]}" loading="lazy" decoding="async"></button>`).join('');
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
// the strip moves only while it is on screen, and its width is measured only when it changes
// (reading scrollWidth on every frame forced a full page layout 60 times a second)
let revHalf = 0, revOn = false, revRaf = 0;
const measureRev = () => { revHalf = rt.scrollWidth / 2; };
measureRev(); addEventListener('load', measureRev);
if ('ResizeObserver' in window) new ResizeObserver(measureRev).observe(rt);
rt.addEventListener('load', measureRev, true);
new IntersectionObserver(es => { revOn = es[es.length - 1].isIntersecting; if (revOn && !revRaf) revRaf = requestAnimationFrame(revLoop); }, {rootMargin:'100px 0px'}).observe(vp);
function revLoop(){
  revRaf = 0;
  if (!revOn) return;
  const half = revHalf;
  if (!rDrag){
    if (rTween){ const d = rTween * .12; rvx += d; rTween -= d; if (Math.abs(rTween) < .5) rTween = 0; }
    rvx += rvv; rvv *= .93; if (Math.abs(rvv) < .05) rvv = 0;
    if (!NRT.reduce && !rHover && !rTween && performance.now() > rIdle) rvx -= .55;
  }
  if (half > 0){ while (rvx <= -half) rvx += half; while (rvx > 0) rvx -= half; }
  rt.style.transform = `translate3d(${rvx.toFixed(2)}px,0,0)`;
  revRaf = requestAnimationFrame(revLoop);
}
rt.addEventListener('click', e => { const b = e.target.closest('.phone'); if (!b) return; lbImg.src = REV[b.dataset.src]; lbImg.alt = REV_ALT[b.dataset.src]; openDlg(lb); });
})();
