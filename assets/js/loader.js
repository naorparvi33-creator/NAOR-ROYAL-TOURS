/* NAOR ROYAL TOURS · טוען את קבצי האתר בסדר הנכון.
   מצב חסכוני: בטלפון שמוגדר לחיסכון בנתונים או ברשת איטית (2G) לא נטענות
   ספריות התלת־ממד והאנימציה (כ-670KB). האתר מציג אז את אותו תוכן בגרסה סטטית. */
(function(){
  var c = navigator.connection || navigator.mozConnection || navigator.webkitConnection || {};
  // ?lite=1 in the address shows the light version on purpose (for checking)
  var lite = !!(c.saveData || /(^|-)2g$/.test(c.effectiveType || '') || /[?&]lite=1/.test(location.search));
  if (lite) document.documentElement.classList.add('lite');
  var heavy = lite ? [] : ['assets/vendor/three.min.js', 'assets/vendor/gsap.min.js'];
  var own = ['assets/js/config.js', 'assets/js/art.js', 'assets/js/main.js', 'assets/js/pack.js', 'assets/js/leads.js'];
  heavy.concat(own).forEach(function(src){
    var s = document.createElement('script');
    s.src = src; s.async = false; // async=false keeps the order: libraries first, then the site
    document.body.appendChild(s);
  });
})();
