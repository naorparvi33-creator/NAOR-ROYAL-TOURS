# NAOR ROYAL TOURS · האתר

קבצי האתר נמצאים בתיקייה `site`. כל שינוי שנשמר בענף `main` עולה לאוויר לבד דרך Cloudflare Pages.

## הגדרות ב־Cloudflare Pages (פעם אחת)
- **Framework preset:** None
- **Build command:** להשאיר ריק
- **Build output directory:** `site`
- **Production branch:** `main`

## לפני כל עדכון
בקובץ `site/sw.js` מעדכנים את `VERSION`, כדי שמבקרים קבועים יקבלו את הגרסה החדשה מיד.

## Vercel
בשורש המאגר יש `vercel.json` שמגדיר את התיקייה `site` כתיקיית הפלט ואת כל הכותרות (אבטחה ומטמון), כך שאין צורך בהגדרות נוספות.
ב־Vercel: **Add New → Project → Import** של המאגר הזה, ללחוץ **Deploy**. כל דחיפה ל־`main` תעלה לאוויר לבד.
