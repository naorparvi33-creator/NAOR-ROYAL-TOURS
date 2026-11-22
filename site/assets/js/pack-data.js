/* NAOR ROYAL TOURS · "מה לארוז": התוכן בלבד. רשימות הקיץ והחורף והאייקונים שלהן.
   כדי לשנות פריט או ניסוח, עורכים רק את הקובץ הזה. */
window.NRT_PACK = (function(){
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
return {ICONS, SEASONS};
})();
