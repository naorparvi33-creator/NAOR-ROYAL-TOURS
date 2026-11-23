# מחולל הדמויות

יוצר דמויות אנושיות מציאותיות עם שלד למשחק, באמצעות MakeHuman (התוסף MPFB2, רישיון CC0) בתוך Blender כספריית Python.

דרישות: `pip install bpy` (Blender 5.x) ו-`git clone https://github.com/makehumancommunity/mpfb2 /tmp/mpfb2`.

```bash
./cast.sh          # יוצר את player.glb ואת ped_01..08.glb בתיקייה assets/characters
```

כל דמות: גוף MakeHuman עם 53 עצמות (game_engine), חולצה, מכנסיים, נעליים ושיער שנבנים על הגוף, ועור שנצבע לפי המסכות של MakeHuman.
אפשר לשנות מגדר, גיל, מבנה גוף, מוצא, צבע עור, שיער ובגדים ב-JSON שבתוך cast.sh.
