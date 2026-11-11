/* נטען ב-head: מסמן שיש JavaScript כדי שהאנימציות יתחילו בלי הבהוב.
   ברשת איטית (או במצב חיסכון בנתונים) התוכן מוצג מיד, בלי לחכות לאנימציות.
   אם קבצי האתר לא הגיעו תוך 4 שניות, התוכן מוצג בכל מקרה. */
(function(){
  var d = document.documentElement;
  var c = navigator.connection || navigator.mozConnection || navigator.webkitConnection || {};
  var slow = !!(c.saveData || /(^|-)(2g|3g)$/.test(c.effectiveType || '') || (c.downlink && c.downlink < 1.2) || /[?&]lite=1/.test(location.search));
  if (slow){ d.classList.add('lite'); return; } // keep "no-js": the text is visible right away
  d.classList.remove('no-js'); d.classList.add('js');
  setTimeout(function(){
    var s = document.getElementById('site');
    // main.js marks the site with 'js' as soon as it runs, and then has its own safety timer
    if (!s || !s.classList.contains('js')){ d.classList.remove('js'); if (s) s.classList.remove('js'); }
  }, 4000);
})();
