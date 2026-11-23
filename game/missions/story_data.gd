extends RefCounted
## Story campaign data: "Glass City" (עיר של זכוכית), an original story in 8 chapters.
## Maya, a former detective, recruits the player (a courier who owes her a favour) to
## bring down Gideon Shachar, a property tycoon who runs the city through "the Company".
## Dialogue lines: {"who": speaker id, "he": ..., "en": ...}. UI strings go to Loc.

const STRINGS := {
	"he": {
		"spk_maya": "מאיה",
		"spk_dudi": "דודי",
		"spk_eli": "אלי",
		"spk_noa": "נועה",
		"spk_gideon": "גדעון שחר",
		"spk_barzel": "ברזל",
		"spk_radio": "קשר",
		"spk_you": "אתה",
		"spk_victim": "עובר אורח",
		"dlg_tap": "הקש להמשך",
		"story": "סיפור",
		"story_done": "הסיפור הושלם · עיר של זכוכית",
		"story_credits": "תודה ששיחקת! המשך לחקור את העיר: פסלונים, קפיצות ועבודות צד.",
		"progress_line": "סיפור %d/8 · פסלונים %d/20 · קפיצות %d/%d",
		"st_1": "עד המדינה",
		"st_2": "הספר השחור",
		"st_3": "המוסך של דודי",
		"st_4": "צללים",
		"st_5": "טווח רחוק",
		"st_6": "דדליין",
		"st_7": "שובל של ראיות",
		"st_8": "מגדל שחר",
		"bar_vip": "רכב העד",
		"bar_target_car": "רכב נמלט",
		"bar_garage": "המוסך",
		"bar_detect": "חשד",
		"bar_cargo": "מטען שביר",
		"bar_boss": "ברזל",
		"bar_wave": "גל",
		"ob_escort_follow": "לווה את הרכב של אלי לבית המבטחים. הישאר קרוב",
		"ob_escort_close": "התקרב לרכב של אלי!",
		"ob_escort_ambush": "מארב! חסל את התוקפים (%d נותרו)",
		"ob_get_car": "היכנס לרכב שחונה ליד",
		"ob_chase": "עצור את הרכב הנמלט! ירה בו או נגח בו",
		"ob_chase_far": "הוא בורח! התקרב לרכב",
		"ob_grab_ledger": "קח את הספר השחור מההריסות",
		"ob_defend": "הגן על המוסך · גל %d מתוך 3 (%d תוקפים)",
		"ob_defend_next": "הגל הבא מגיע...",
		"ob_defend_return": "חזור למוסך!",
		"ob_stealth_in": "הגע למניפסט בלי להיראות. כריעה מקטינה את טווח הראייה של השומרים",
		"ob_stealth_out": "יש לך את המניפסט. התרחק מהאזור",
		"ob_sniper_go": "הגע לעמדת הצליפה בפארק",
		"ob_sniper_shoot": "חסל את הרצל קורן על הגג (השתמש בכוונת)",
		"ob_sniper_close": "קרוב מדי! הוא יבחין בך",
		"ob_sniper_flee": "הוא בורח! עכשיו או לעולם לא",
		"ob_deliver_get": "היכנס לרכב המשלוח",
		"ob_deliver_go": "הבא את הכוננים לנועה. סע בזהירות, המטען שביר",
		"ob_evidence": "אסוף את הראיות (%d מתוך 4)",
		"ob_final_wave": "הסתער על מגדל שחר · גל %d מתוך 3 (%d נותרו)",
		"ob_final_boss": "חסל את ברזל!",
		"ob_final_arrest": "גש לגדעון שחר",
		"ctx_evidence": "קח ראיה",
		"ctx_manifest": "קח מניפסט",
		"ctx_ledger": "קח ספר",
		"fail_vip_dead": "הרכב של אלי הושמד",
		"fail_vip_lost": "איבדת את הרכב של אלי",
		"fail_lost_car": "הרכב הנמלט נעלם",
		"fail_garage": "המוסך הועלה באש",
		"fail_left": "נטשת את המשימה",
		"fail_spotted": "נתפסת!",
		"fail_target_escaped": "המטרה ברחה",
		"fail_cargo": "המטען נהרס",
		"fail_time": "נגמר הזמן",
		"fail_car_lost": "הרכב הושמד",
		"fail_died": "נפצעת קשה",
		"owl": "פסלון זהב",
		"owl_all": "כל 20 הפסלונים נמצאו!",
		"stunt": "קפיצת פעלולים!",
		"stunt_unique": "קפיצה ייחודית %d/%d",
		"stunt_fail": "נחיתה גרועה",
		"stunt_all": "כל הקפיצות הושלמו!",
		"ev_mug": "שוד ברחוב",
		"ev_mug_ob": "עצור את השודד!",
		"ev_mug_thanks": "תודה! הצלת אותי",
		"ev_mug_escaped": "השודד ברח",
		"ev_chase": "רכב מילוט",
		"ev_chase_ob": "עצור את רכב המילוט!",
		"ev_chase_lost": "רכב המילוט נעלם",
		"odd_job": "עבודה",
	},
	"en": {
		"spk_maya": "Maya",
		"spk_dudi": "Dudi",
		"spk_eli": "Eli",
		"spk_noa": "Noa",
		"spk_gideon": "Gideon Shachar",
		"spk_barzel": "Barzel",
		"spk_radio": "Radio",
		"spk_you": "You",
		"spk_victim": "Bystander",
		"dlg_tap": "Tap to continue",
		"story": "Story",
		"story_done": "Story complete · Glass City",
		"story_credits": "Thanks for playing! Keep exploring: statuettes, stunt jumps and odd jobs.",
		"progress_line": "Story %d/8 · Statuettes %d/20 · Jumps %d/%d",
		"st_1": "The Witness",
		"st_2": "The Black Ledger",
		"st_3": "Dudi's Garage",
		"st_4": "Shadows",
		"st_5": "Long Range",
		"st_6": "Deadline",
		"st_7": "Paper Trail",
		"st_8": "Shachar Tower",
		"bar_vip": "Witness car",
		"bar_target_car": "Fleeing car",
		"bar_garage": "Garage",
		"bar_detect": "Suspicion",
		"bar_cargo": "Fragile cargo",
		"bar_boss": "Barzel",
		"bar_wave": "Wave",
		"ob_escort_follow": "Escort Eli's car to the safe house. Stay close",
		"ob_escort_close": "Get closer to Eli's car!",
		"ob_escort_ambush": "Ambush! Take out the attackers (%d left)",
		"ob_get_car": "Get in the car parked nearby",
		"ob_chase": "Stop the fleeing car! Shoot it or ram it",
		"ob_chase_far": "He's getting away! Close the distance",
		"ob_grab_ledger": "Take the black ledger from the wreck",
		"ob_defend": "Defend the garage · wave %d of 3 (%d attackers)",
		"ob_defend_next": "Next wave incoming...",
		"ob_defend_return": "Get back to the garage!",
		"ob_stealth_in": "Reach the manifest unseen. Crouching shortens the guards' sight",
		"ob_stealth_out": "You have the manifest. Leave the area",
		"ob_sniper_go": "Go to the sniping spot in the park",
		"ob_sniper_shoot": "Take out Herzl Koren on the roof (use your sights)",
		"ob_sniper_close": "Too close! He will notice you",
		"ob_sniper_flee": "He's running! Now or never",
		"ob_deliver_get": "Get in the delivery car",
		"ob_deliver_go": "Bring the drives to Noa. Drive carefully, the cargo is fragile",
		"ob_evidence": "Collect the evidence (%d of 4)",
		"ob_final_wave": "Storm Shachar Tower · wave %d of 3 (%d left)",
		"ob_final_boss": "Take down Barzel!",
		"ob_final_arrest": "Walk up to Gideon Shachar",
		"ctx_evidence": "Take evidence",
		"ctx_manifest": "Take manifest",
		"ctx_ledger": "Take ledger",
		"fail_vip_dead": "Eli's car was destroyed",
		"fail_vip_lost": "You lost Eli's car",
		"fail_lost_car": "The fleeing car got away",
		"fail_garage": "The garage burned down",
		"fail_left": "You abandoned the mission",
		"fail_spotted": "You were spotted!",
		"fail_target_escaped": "The target escaped",
		"fail_cargo": "The cargo is ruined",
		"fail_time": "Out of time",
		"fail_car_lost": "The car was destroyed",
		"fail_died": "Badly hurt",
		"owl": "Golden statuette",
		"owl_all": "All 20 statuettes found!",
		"stunt": "Stunt jump!",
		"stunt_unique": "Unique jump %d/%d",
		"stunt_fail": "Bad landing",
		"stunt_all": "All stunt jumps done!",
		"ev_mug": "Street robbery",
		"ev_mug_ob": "Stop the mugger!",
		"ev_mug_thanks": "Thank you! You saved me",
		"ev_mug_escaped": "The mugger got away",
		"ev_chase": "Getaway car",
		"ev_chase_ob": "Stop the getaway car!",
		"ev_chase_lost": "The getaway car got away",
		"odd_job": "Job",
	},
}

const REWARDS := [1500, 2000, 2500, 3000, 4000, 3500, 4500, 12000]


static func L(who: String, he: String, en: String) -> Dictionary:
	return {"who": who, "he": he, "en": en}


## Dialogue for a chapter: "intro", "outro" and named mid-mission beats.
static func dialogue(chapter: int, beat: String) -> Array:
	match "%d_%s" % [chapter, beat]:
		# 1 · The Witness (escort)
		"0_intro":
			return [
				L("maya", "אתה עדיין חייב לי על הסיפור עם המשאית. היום אתה משלם.", "You still owe me for that truck business. Today you pay up."),
				L("maya", "אלי ברק, רואה החשבון של גדעון שחר, מוכן להעיד. יש לו את הספרים של 'החברה'.", "Eli Barak, Gideon Shachar's accountant, is ready to testify. He has the Company's books."),
				L("eli", "אני לא בנוי לזה... הם יודעים שעזבתי. תישאר צמוד אליי, בבקשה.", "I'm not cut out for this... they know I left. Please stay close."),
				L("maya", "הוא נוסע לבית המבטחים במזרח העיר. שמור עליו בחיים.", "He's driving to the safe house in the east of the city. Keep him alive."),
			]
		"0_ambush":
			return [
				L("eli", "הם חוסמים את הכביש! אני עוצר!", "They're blocking the road! I'm stopping!"),
				L("maya", "מארב. תוריד אותם לפני שהם מגיעים אליו.", "Ambush. Take them down before they reach him."),
			]
		"0_resume":
			return [L("eli", "נקי? אני ממשיך לנסוע. אל תעזוב אותי.", "Clear? I'm moving again. Don't leave me.")]
		"0_outro":
			return [
				L("eli", "הגענו... אני לא מאמין שאני חי.", "We made it... I can't believe I'm alive."),
				L("maya", "עבודה טובה. גדעון יודע עכשיו שמישהו נלחם בו. תהיה מוכן.", "Good work. Gideon knows now that someone is fighting back. Be ready."),
			]
		# 2 · The Black Ledger (chase)
		"1_intro":
			return [
				L("maya", "חדשות רעות. מישהו מבפנים מסר את בית המבטחים. נהג של החברה חטף את הספר השחור של אלי.", "Bad news. Someone inside gave up the safe house. A Company driver grabbed Eli's black ledger."),
				L("eli", "בלי הספר אין עדות! יש בו כל שוחד, כל חתימה!", "Without the ledger there's no case! Every bribe, every signature is in it!"),
				L("maya", "הוא בורח ברכב שחור. יש רכב חונה לידך. עצור אותו בכל מחיר.", "He's running in a dark car. There's a car parked next to you. Stop him at any cost."),
			]
		"1_wreck":
			return [L("maya", "הוא לא ילך לשום מקום. קח את הספר מהרכב.", "He's not going anywhere. Get the ledger out of the car.")]
		"1_outro":
			return [
				L("maya", "יש לנו אותו. דודי ישמור עליו במוסך שלו, אף אחד לא יחפש שם.", "We've got it. Dudi will keep it in his garage, nobody will look there."),
			]
		# 3 · Dudi's Garage (defend)
		"2_intro":
			return [
				L("dudi", "אחי! שלושה רכבים של החברה עצרו מול המוסך. הם באו בשביל הספר.", "Brother! Three Company cars just stopped outside my garage. They came for the ledger."),
				L("dudi", "יש לי פה מכלי דלק. אם הם מגיעים לדלת, הכל עולה באש.", "I've got fuel tanks in here. If they reach the door, the whole place goes up."),
				L("maya", "אל תיתן להם להתקרב למוסך. הם יבואו בגלים.", "Don't let them near the garage. They'll come in waves."),
			]
		"2_wave":
			return [L("dudi", "עוד רכב! הם לא מוותרים!", "Another car! They don't give up!")]
		"2_outro":
			return [
				L("dudi", "המוסך שלי עומד! אני חייב לך בירה... או עשר.", "My garage is still standing! I owe you a beer... or ten."),
				L("maya", "אחד הפצועים דיבר. החברה מעבירה משהו הלילה דרך המגרש במערב.", "One of the wounded talked. The Company is moving something tonight through the lot in the west."),
			]
		# 4 · Shadows (stealth)
		"3_intro":
			return [
				L("maya", "במגרש יש מניפסט משלוחים: רשימה של כל מי שמקבל מעטפות מגדעון.", "There's a shipping manifest in that lot: a list of everyone taking envelopes from Gideon."),
				L("maya", "השומרים חמושים. אם הם רואים אותך, המשלוח נעלם. אל תירה, הם ישמעו.", "The guards are armed. If they see you, the shipment vanishes. Don't shoot, they'll hear it."),
				L("maya", "כרע כשאתה קרוב, ותקוף מאחור באגרופים אם אין ברירה.", "Crouch when you're close, and take them from behind with your fists if you must."),
			]
		"3_got":
			return [L("maya", "יש לך אותו? מעולה. עכשיו צא משם בשקט.", "Got it? Great. Now get out of there quietly.")]
		"3_outro":
			return [
				L("maya", "השם שמופיע הכי הרבה ברשימה: הרצל קורן, איש הכספים של גדעון.", "The name that shows up most on the list: Herzl Koren, Gideon's money man."),
				L("maya", "והוא מתכנן לטוס הלילה עם כל הכסף.", "And he's planning to fly out tonight with all the money."),
			]
		# 5 · Long Range (sniper)
		"4_intro":
			return [
				L("radio", "...קורן נפגש עם הקונה על הגג ממזרח לפארק. עשר דקות, לא יותר...", "...Koren meets the buyer on the roof east of the park. Ten minutes, no more..."),
				L("maya", "אם הוא עולה למטוס, אנחנו מאבדים את הכסף ואת העדות. אין דרך להגיע אליו מקרוב.", "If he boards that plane we lose the money and the testimony. There's no way to get close."),
				L("maya", "יש עמדה טובה בפארק. קח את הנשק הארוך ביותר שלך, וחכה לירייה נקייה.", "There's a good spot in the park. Take your longest gun and wait for a clean shot."),
			]
		"4_spot":
			return [L("maya", "אתה בעמדה. כוון לראש, זו הירייה היחידה שבטוח עובדת.", "You're in position. Aim for the head, it's the only shot that's sure to work.")]
		"4_outro":
			return [
				L("maya", "קורן בחוץ. בכיס שלו היו כוננים קשיחים, נועה כבר מחכה להם.", "Koren is down. He had hard drives on him, Noa is waiting for them."),
			]
		# 6 · Deadline (timed delivery)
		"5_intro":
			return [
				L("noa", "אני נועה, מהעיתון. העיתון יורד לדפוס עוד מעט, ואני צריכה את הכוננים עכשיו.", "I'm Noa, from the paper. We go to print very soon, and I need those drives now."),
				L("dudi", "שמתי אותם ברכב, עטופים בשמיכות. אבל תיזהר, כל מכה ואתה מאבד את המידע.", "I put them in the car, wrapped in blankets. But careful, every crash costs you data."),
			]
		"5_outro":
			return [
				L("noa", "הגעת בזמן! זה... זה גדול יותר ממה שחשבתי. אבל אני צריכה הוכחות פיזיות.", "Right on time! This... this is bigger than I thought. But I need physical proof."),
			]
		# 7 · Paper Trail (collect evidence)
		"6_intro":
			return [
				L("noa", "הכוננים מראים ארבעה מקומות שבהם החברה מחביאה מסמכים: חוזים, תמונות, מעטפות.", "The drives show four places where the Company hides documents: contracts, photos, envelopes."),
				L("maya", "בשניים מהם יש שומרים. בשניים האחרים אולי לא. תאסוף הכל.", "Two of them are guarded. The other two maybe not. Collect everything."),
			]
		"6_got1":
			return [L("noa", "חוזה בנייה מזויף, עם חתימה של סגן ראש העיר. מדהים.", "A forged building contract, signed by the deputy mayor. Incredible.")]
		"6_got2":
			return [L("noa", "תמונות של גדעון עם הפקח. זה הולך לעמוד הראשון.", "Photos of Gideon with the inspector. That's going on the front page.")]
		"6_got3":
			return [L("maya", "מעטפות מסומנות. המשטרה לא תוכל להתעלם מזה.", "Marked envelopes. The police can't ignore this.")]
		"6_outro":
			return [
				L("noa", "הכתבה מתפרסמת מחר בבוקר. גדעון יודע את זה.", "The story runs tomorrow morning. Gideon knows it."),
				L("gideon", "אתה חושב שעיתון יעצור אותי? העיר הזאת שלי. כל לבנה בה.", "You think a newspaper will stop me? This city is mine. Every brick of it."),
				L("maya", "הוא מתבצר במגדל עם כל האנשים שלו. זה נגמר הלילה.", "He's dug in at the tower with all his men. It ends tonight."),
			]
		# 8 · Shachar Tower (final shootout)
		"7_intro":
			return [
				L("maya", "יש לי ניידות שמחכות שתי רחובות משם. ברגע שהכניסה נקייה, הן נכנסות.", "I've got patrol cars waiting two streets away. The moment the entrance is clear, they move in."),
				L("barzel", "אז אתה הבחור שמשחק אותה גיבור. בוא, אני מחכה לך.", "So you're the one playing hero. Come on, I'm waiting for you."),
				L("maya", "ברזל מוביל את השומרים של גדעון. בלעדיו, כולם יתפזרו.", "Barzel runs Gideon's guards. Without him, they'll all scatter."),
			]
		"7_boss":
			return [L("barzel", "מספיק עם החובבנים. עכשיו זה ביני לבינך.", "Enough with the amateurs. Now it's between you and me.")]
		"7_arrest":
			return [L("gideon", "חכה! חכה... אני יורד. אל תירה.", "Wait! Wait... I'm coming down. Don't shoot.")]
		"7_outro":
			return [
				L("gideon", "יש לי עורכי דין, שופטים, חברים... אתה לא מבין עם מי אתה מתעסק.", "I have lawyers, judges, friends... you don't understand who you're dealing with."),
				L("maya", "היו לך. הספר השחור, המניפסט והכתבה של נועה. אתה עצור, גדעון.", "You had them. The ledger, the manifest and Noa's story. You're under arrest, Gideon."),
				L("dudi", "אז... בירה? אמרתי עשר, נכון?", "So... beer? I said ten, right?"),
				L("maya", "החוב שלך סגור. אבל העיר הזאת עוד צריכה מישהו כמוך.", "Your debt is paid. But this city still needs someone like you."),
			]
	return []
