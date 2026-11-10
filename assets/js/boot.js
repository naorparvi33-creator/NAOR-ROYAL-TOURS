/* נטען ב-head: מסמן שיש JavaScript כדי שהאנימציות יתחילו בלי הבהוב.
   אם משהו נכשל, אחרי 6 שניות התוכן מוצג בכל מקרה. */
(function(){
  var d = document.documentElement;
  d.classList.remove('no-js'); d.classList.add('js');
  setTimeout(function(){
    var s = document.getElementById('site');
    if (!s || !s.classList.contains('ready')){ d.classList.remove('js'); if (s) s.classList.remove('js'); }
  }, 6000);
})();
