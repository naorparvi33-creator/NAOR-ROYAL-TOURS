# NAOR ROYAL TOURS · האתר

קבצי האתר נמצאים בתיקייה `site`. כל שינוי שנשמר בענף `main` עולה לאוויר לבד דרך Cloudflare Pages.

## הגדרות ב־Cloudflare Pages (פעם אחת)
- **Framework preset:** None
- **Build command:** להשאיר ריק
- **Build output directory:** `site`
- **Production branch:** `main`

## לפני כל עדכון
בקובץ `site/sw.js` מעדכנים את `VERSION`, כדי שמבקרים קבועים יקבלו את הגרסה החדשה מיד.
