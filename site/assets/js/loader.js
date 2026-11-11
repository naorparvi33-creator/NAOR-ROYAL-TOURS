/* NAOR ROYAL TOURS · טוען את קבצי האתר בסדר הנכון, ובחיסכון בנתונים.
   1. קודם כל קבצי האתר עצמו והאנימציות (קטנים). האתר נפתח מהם.
   2. ספריית התלת־ממד (המזוודה, כ-600KB) יורדת רק אחרי שהעמוד נטען, ברקע.
   3. ברשת איטית (2G/3G), במצב חיסכון בנתונים, או כשהאנימציות לא הגיעו תוך 3 שניות:
      גרסה קלה עם אותו תוכן, בלי להוריד את ספריות התלת־ממד בכלל. */
(function(){
  var d = document.documentElement;
  var c = navigator.connection || navigator.mozConnection || navigator.webkitConnection || {};
  // ?lite=1 in the address shows the light version on purpose (for checking)
  var lite = d.classList.contains('lite') || !!(c.saveData || /(^|-)(2g|3g)$/.test(c.effectiveType || '') || (c.downlink && c.downlink < 1.2) || /[?&]lite=1/.test(location.search));
  if (lite) d.classList.add('lite');

  function add(src, ordered){
    var s = document.createElement('script');
    s.src = src; s.async = !ordered;
    document.body.appendChild(s);
    return s;
  }
  var own = ['assets/js/config.js', 'assets/js/art.js', 'assets/js/main.js', 'assets/js/pack.js', 'assets/js/leads.js'];
  var started = false;
  function loadOwn(){
    if (started) return; started = true;
    own.forEach(function(src){ add(src, true); }); // in order, never waiting for a library
  }
  if (lite){ loadOwn(); return; }

  // animations (71KB): wait for them at most 3 seconds from opening the address
  var timer = setTimeout(function(){ d.classList.add('lite'); loadOwn(); }, Math.max(600, 3000 - (performance.now ? performance.now() : 0)));
  var g = add('assets/vendor/gsap.min.js', false);
  g.onload = g.onerror = function(){ clearTimeout(timer); loadOwn(); };

  // 3D library: only after the page has fully loaded, when the phone is idle
  function three(){
    if (d.classList.contains('lite')) return;
    var s = add('assets/vendor/three.min.js', false);
    s.onload = function(){ try { dispatchEvent(new Event('nrt-three')); } catch(e){} };
  }
  // ...and after the opening animation, so it never competes with the first seconds on screen
  function later(){
    var t0 = Date.now();
    (function wait(){
      var s = document.getElementById('site');
      if ((s && s.classList.contains('ready') && !document.querySelector('.intro')) || Date.now() - t0 > 8000){ if ('requestIdleCallback' in window) requestIdleCallback(three, {timeout:2000}); else setTimeout(three, 300); }
      else setTimeout(wait, 250);
    })();
  }
  if (document.readyState === 'complete') later(); else addEventListener('load', later);
})();
