class_name GameConstants
## ثابت‌های سراسری بازی «سرزمین مادری»
## مرجع اعداد: «پرامت فاز اول — بخش حرکت و صحنه» (سرعت ۳، شتاب ۸، اسلوموشن ۰.۵،
## دوربین ۳۶۰°، پالت HEX هخامنشی) + قوانین آهنین سند طراحی.

# ---------- هویت بیلد ----------
## روی صفحه‌ی تست و منو نمایش داده می‌شود تا همیشه مشخص باشد کاربر کدام نسخه را اجرا می‌کند
const BUILD_ID := "2026-09-25-r13"

# ---------- زمان‌بندی و اسلوموشن (§۶ پرامت) ----------
const SLOWMO_SCALE := 0.5                 # قانون: انتخاب جوخه یا نگه‌داشتن Space → 0.5
const SLOWMO_IN_SECONDS := 0.15           # Tween ورود به اسلوموشن
const SLOWMO_OUT_SECONDS := 0.2           # Tween بازگشت به نرمال
const FIELD_RECOMPUTE_INTERVAL := 0.2     # به‌روزرسانی FlowField هر 0.2 ثانیه
const MAIN_READ_BUDGET_MS := 0.5          # بودجه‌ی خواندن مسیر در نخ اصلی (< 0.5ms)

# ---------- حرکت (§۵ پرامت) ----------
const SPEED_BASE := 3.0                   # سرعت پایه m/s
const SPEED_VARIATION := 0.05             # 0.95× تا 1.05× برای هر سرباز
const ACCEL := 8.0                        # شتاب m/s²
const ROTATE_SPEED_RAD := TAU             # چرخش ۳۶۰ درجه بر ثانیه
const FORMATION_SPACING := 1.2            # فاصله‌ی آرایش بین سربازان (m)

# ---------- Fidget (§۵.۲ پرامت) ----------
const FIDGET_INTERVAL_MIN := 2.0          # فاصله‌ی زمانی 2–5 s
const FIDGET_INTERVAL_MAX := 5.0
const FIDGET_DUR_MIN := 0.3               # مدت 0.3–0.8 s
const FIDGET_DUR_MAX := 0.8
const FIDGET_DIST_MIN := 0.4              # فاصله از جوخه 0.4–0.8 m
const FIDGET_DIST_MAX := 0.8

# ---------- نقاط مسیر (§۴ پرامت) ----------
const WAYPOINT_MAX := 8
const WAYPOINT_WAIT := 0.2                # انتظار در هر Waypoint
const COL_WAYPOINT := Color("3ab0a0")     # خط مسیر فیروزه‌ای، Alpha 0.6

# ---------- دوربین (§۷ پرامت) ----------
const CAM_FOV := 55.0
const CAM_PITCH_DEG := -55.0
const CAM_YAW0_DEG := 45.0                # قابل چرخش ۳۶۰ درجه
const CAM_HEIGHT0 := 18.0
const CAM_MIN_HEIGHT := 12.0
const CAM_MAX_HEIGHT := 26.0
const CAM_ZOOM_SPEED := 6.0               # m/s
const CAM_ROTATE_SPEED := 120.0           # درجه بر ثانیه (Q/E/جهت‌نما) — بازخورد کاربر: چرخش حس‌بهتر
const CAM_DRAG_SENS := 0.35               # حساسیت چرخش با کشیدن موس/لمس (اندروید) — گام ۶R2
const CAM_DRAG_START_PX := 12.0           # آستانه‌ی تفکیک «تپ» از «کشیدن» (px)
const CAM_NEAR := 0.1
const CAM_FAR := 200.0

# ---------- شبکه‌ی فرمان (بازخورد کاربر: بلوک‌های بزرگ‌تر + هاله سفید) ----------
const COMMAND_CELL := 2.0                 # هر سلول فرمان = ۲×۲ سلول NavGrid
const SQUADS_MAX := 5                     # میان‌بر 1..5 — گام ۶R4: «دسته‌های خودی خیلی کم‌اند»

# ---------- گام ۶R4 — بلوک انتخاب مستطیلی + پرتو نور (بازخورد کاربر) ----------
## «بلوک‌های انتخاب‌کننده که روی زمین ظاهر می‌شوند به صورت مستطیلی باشند؛
##  یک حالت پرتو نور ازشون بیرون می‌زنه» → قاب مستطیلی + ستون نور طلایی
const COMMAND_BEAM_HEIGHT := 1.9          # بلندی پرتو نور از بلوک (m)
const COMMAND_BEAM_COLOR := Color("ffd98a")  # طلایی روشن پرتو (خانواده‌ی COL_GOLD)

# ---------- واکنش نبرد — لایه ۳ (گام ۵) ----------
## ⚠️ اعداد این بخش «پیش‌فرض موقتِ گام ۵» برای نمایش لایه ۳ روی کوله‌ی تمرین‌اند؛
## بالانس نهایی بعد از ورود دشمنان (Hoplite/Peltast) در گام ۶ با تأیید کاربر قطعی می‌شود.
const COMBAT_SCAN_INTERVAL := 0.25       # فاصله‌ی جست‌وجوی دشمن (s)
const AGGRO_RADIUS := 6.0                # شعاع توجه به دشمن (m)
const ARCHER_RANGE := 8.0                # برد کمان (m)
const ARCHER_COOLDOWN := 2.0             # فاصله‌ی شلیک (s)
const ARROW_SPEED := 10.0                # سرعت پرتاب تیر (m/s)
const ARROW_GRAVITY := 9.8               # جاذبه‌ی بالستیک تیر
const ARROW_HIT_RADIUS := 0.5            # شعاع برخورد تیر با هدف (m)
const SPEARMAN_BRACE_RANGE := 3.5        # برد «آماده‌باش» نیزه‌دار — فقط در ایست (m)
const SPEARMAN_REACH := 1.8              # برد نیزه در حالت آماده‌باش (m)
const IMMORTAL_REACT_RANGE := 4.0        # برد روکردن/سپرگیری جاویدان (m)
const IMMORTAL_ENGAGE_RANGE := 1.6       # فاصله‌ی نبرد نزدیک جاویدان (m)
const IMMORTAL_SHIELD_CONE_DEG := 70.0   # مخروط سپر از پیش رو (درجه)
const FRIENDLY_CORRIDOR_HALF_W := 0.8    # نیم‌پهنای کریدور «بدون آسیب دوستانه» کماندار (m)

# ---------- گام ۶ — دشمنان و موج هجوم (§۶ سند طراحی) ----------
## ⚠️ اعداد این بخش «پیش‌فرض موقتِ گام ۶»‌اند (پرامت فاز اول اعداد نبرد نداشت)؛
## بالانس نهایی با تأیید کاربر قطعی می‌شود.
## گام ۶R2 — بازخورد کاربر «کاربر هم به راحتی می‌بازد»: موج کمتر و خانه‌های
## مقاوم‌تر؛ و «مهاجمان زودتر متوجه سربازها می‌شوند» (آگرو بزرگ‌تر).
## گام ۶R4 — دسته‌های بازیکن ۳→۵ شد؛ کانال‌های ۰..۴ مال خودی‌هاست
const ENEMY_CHANNEL_BASE := 5            # کانال FlowField گروه‌های هجوم (۵..۸) — ۰..۴ مال دسته‌های بازیکن
const ENEMY_AGGRO_UNITS := 4.8           # سربازِ در این شعاع، هدف درگیری دشمن می‌شود (m)
const ENEMY_ENGAGE_RANGE := 1.4          # برد تماس نزدیک دشمن (m)
const ENEMY_SCAN_INTERVAL := 0.3         # فاصله‌ی جست‌وجوی سرباز (s)
## تلافی: مهاجمِ ضربه‌خورده از تیر، به شلیک‌کننده حمله می‌کند (بازخورد گام ۶R2)
const ENEMY_CHASE_SECONDS := 6.0         # مدت تعقیبِ هدفِ تلافی حتی بیرون آگرو (s)
const ENEMY_CHASE_DROP_MULT := 2.2       # تعقیب تا این ضریبِ آگرو ادامه دارد (m = aggro × این)

const HOPLITE_LIGHT_HP := 2              # سبک: سریع، کم‌جان
const HOPLITE_LIGHT_SPEED := 2.7
const HOPLITE_LIGHT_DMG := 1
const HOPLITE_LIGHT_COOLDOWN := 1.2

const HOPLITE_HEAVY_HP := 5              # سنگین: کند، جانِ زیاد، سپرِ پیش‌رو تیر را خنثی می‌کند
const HOPLITE_HEAVY_SPEED := 1.9
const HOPLITE_HEAVY_DMG := 1
const HOPLITE_HEAVY_COOLDOWN := 1.6
const HOPLITE_HEAVY_SHIELD_CONE_DEG := 100.0  # مخروط سپر از پیش رو (تیر/پرتاب از پهلو-پشت رد می‌شود)

const PELTAST_HP := 2                    # پرتاب‌گر: قبل از تماس می‌زند، اگر نزدیک شد عقب می‌رود
const PELTAST_SPEED := 2.4
const PELTAST_RANGE := 5.5
const PELTAST_COOLDOWN := 2.8
const PELTAST_MIN_DIST := 3.0            # کمتر از این فاصله → عقب‌نشینی کوتاه
const JAVELIN_SPEED := 12.0

# --- جان سربازان بازیکن (صفر عدد روی صفحه §۱۰ — فقط فلش دیداری) ---
## گام ۶R4 — «شمشیرزن‌های خودی قوی‌تر باشند و هلث بیشتری داشته باشند»:
## جاویدان ۴→۶ جان (دو ضربه‌ی اضافه تحمل می‌کند) + آهنگ ضربه تندتر
const PLAYER_HP_IMMORTAL := 6
const PLAYER_HP_SPEARMAN := 3
const PLAYER_HP_ARCHER := 2
const IMMORTAL_STRIKE_COOLDOWN := 0.95   # ضربه‌ی تن‌به‌تن جاویدان (s) — ۶R4: تندتر
const SPEARMAN_STRIKE_COOLDOWN := 1.4    # ضربه‌ی نیزه (فقط آماده‌باش) (s)

# --- موج هجوم (§۶: گروه‌های ۵ تا ۱۵ نفره با ناوگان قایق‌های پارویی) ---
## گام ۶R2 — «کاربر به راحتی می‌بازد»: فاصله‌ی موج‌ها ۴۵→۶۰s و حداکثر ۲ گروه
## هم‌زمان (قبلاً ۳ قایق).
## گام ۶R4 — «هر مرحله از آسان به سخت؛ در دورهای اول دسته‌ها با هم نیایند»:
## دشواری صعودی در InvasionDirector.ascend_spec / max_concurrent_waves.
## گام ۶R4 — «کشتی‌ها باید با سرعت کم به ساحل نزدیک بشوند تا کاربر فرصت
## تصمیم‌گیری و استراتژی چیدن داشته باشد»: کروز ۴.۶→۲.۶ و پهلوگیری ۲.۲→۱.۴
const WAVE_INTERVAL := 60.0              # فاصله‌ی موج‌های خودکار (s)
const WAVE_SIZE_MIN := 5
const WAVE_SIZE_MAX := 9
const WAVE_MAX_CONCURRENT := 2           # سقف هم‌زمانِ دیرهنگام (دورهای اول ۱ است — صعودی)
const BOAT_SPEED := 1.4                  # سرعت پهلوگیری نهایی (m/s) — ۶R4: آهسته‌تر
const BOAT_CRUISE_SPEED := 2.6           # سرعت کروز در دریای باز — ۶R4: آهسته برای تصمیم‌گیری
const BOAT_SPAWN_DIST := 34.0            # فاصله‌ی ظهور قایق از لنگر — نزدیک خط افق آب (m)
const BOAT_DOCK_ZONE := 6.0              # فاصله‌ی ترمز به سرعت پهلوگیری (m)
const DEATH_FADE_SECONDS := 1.6          # محو جسد (لکه‌ی خون در گام ۷ می‌آید)

# ---------- قوانین آهنین بعدی (برای گام‌های آینده) ----------
## گام ۶R2 — «کاربر به راحتی می‌بازد»: خانه‌ها با ۳ مشعل آتش می‌گیرند (۳→) و
## فروریختن ۱۴ ثانیه طول می‌کشد تا فرصت نجات برسد.
const FIRE_DESTROY_SECONDS := 14.0        # خانه در آتش پس از 14 ثانیه نابود می‌شود
## مدت اشغال خانه توسط دسته‌ی خودی تا «تکمیل دسته» — عدد کاربر: ۲۰ ثانیه
const LOOT_DURATION_SECONDS := 20.0

# ---------- گام ۶R — مشعل، اشغال خانه، فرمانده و پرچم ----------
## ⚠️ اعداد این بخش «پیش‌فرض موقت»‌اند (کاربر فقط ۲۰ ثانیه را قطعی داد)؛
## بالانس بعد از تست کاربر قطعی می‌شود.
## گام ۶R2 — بازخورد کاربر: «سربازهای دشمن خیلی دور می‌ایستند؛ نزدیک‌تر بیایند»
## → مهاجمان تا ۲.۶ متری خانه جلو می‌روند و از همان‌جا مشعل پرتاب می‌کنند.
const TORCH_COOLDOWN := 4.0               # فاصله‌ی پرتاب مشعل‌ها (s) — بالانس گام ۶R2
const TORCH_SPEED := 9.0                  # سرعت مشعل پرتابی (m/s)
const HOUSE_TORCH_HP := 3                 # تعداد مشعل لازم تا آتش‌گرفتن خانه (بالانس گام ۶R2)
const ENEMY_RAID_STANDOFF := 2.6          # فاصله‌ی ایست مهاجمان از خانه — نزدیک (بازخورد کاربر)
const GARRISON_SNAP := 2.0                # فرمان روی سلولِ این فاصله از خانه = اشغال خانه (m)
const GARRISON_EMERGE_RING := 2.1         # شعاع بیرون‌آمدن/آرایش بعد از خروج از خانه (m)
## گام ۶R2 — بازخورد کاربر: «پرچم‌ها واضح‌تر بشه» — پرچم بزرگ‌تر با دَرَک بلندتر
const SQUAD_FLAG_W := 0.8                 # پهنای پرچم فرمانده (m)
const SQUAD_FLAG_H := 0.52                # بلندی پارچه‌ی پرچم (m)
const SQUAD_FLAG_POLE_H := 1.5            # بلندی دَرَک پرچم (m)

# ---------- گام ۶R3 — ناوگان مهاجم: قایق مینیمال بی‌بادبان (بازخورد کاربر) ----------
## «قایق‌ها را بدون بادبان بساز؛ مینیمال بهتره» + «هر قایق یک نوع سرباز»
## + «قایق‌ها روی هم نروند» + «از جهات مختلف جزیره بیایند» + «سربازها روی قایق
## دیده شوند و در ساحل پیاده شوند»
const FLEET_BOAT_GAP := 3.0               # فاصله‌ی پهلوگیری قایق‌های یک ناوگان کنار هم (m) — ۶R3: بزرگ‌تر
const CAP_ROWBOAT := 3                    # قایق کوچک پارویی
const CAP_GALLEY := 6                     # گالی متوسط (پاروهای کناری)
const CAP_WARSHIP := 8                    # کشتی جنگی بزرگ (پارو ردیفی + نوار طلایی)
const FLEET_SPAWN_STAGGER := 3.0          # ظهور پلکانی قایق‌های ناوگان از افق (m فاصله‌ی اضافه)
const BOAT_SEP_DIST := 2.8                # شعاع جداسازی قایق‌های «در حال شنا»
const BOAT_SEP_PARKED := 1.7              # شعاع جداسازی از قایقِ «پارک‌شده» — فقط ضد تداخل بدنه
const BOAT_SEP_PUSH := 1.5                # شدت پس‌زنی جانبی جداسازی (ضریب)
const SHORE_DIVERSITY_MIN_DEG := 55.0     # حداقل فاصله‌ی زاویه‌ای فرود از موج‌های قبلی (deg)
## گام ۶R4 — شعاع «اشغال ساحل»: ساحلی که قایقی (پارک‌شده/در راه) در این فاصله
## دارد، برای موج بعدی انتخاب نمی‌شود تا دو ناوگان روی یک نقطه نریزند
const SHORE_OCCUPY_RADIUS := 4.0          # (m)
const SHORE_RECENT_MAX := 3               # حافظه‌ی جهت فرود موج‌های آخر
const WADE_Y := -0.12                     # کف آب هنگام پیاده‌شدن از قایق (سطح دریا −۰.۱۸)

# ---------- گام ۶R3 — حس نبرد تن‌به‌تن (بازخورد: «نبرد ابتداییه») ----------
## چرخه‌ی ضربه: آماده‌گیری (عقب) → یورش (جلو) → لحظه‌ی ضربه → بازگشت.
const STRIKE_WINDUP := 0.13               # کشش ضربه پیش از یورش (s) — دیده‌شدن ضربه
const STRIKE_LUNGE := 0.08                # یورش به جلو (s)
const STRIKE_RECOVER := 0.18              # بازگشت به حالت (s)
const MELEE_KNOCKBACK := 0.16             # پس‌زنی ضربه‌خورده (m)
const CADENCE_VARIANCE := 0.15            # پراکندگی آهنگ ضربه ±۱۵٪ (ضربه‌ها هم‌زمان نمی‌شوند)

# ---------- پالت هخامنشی (§۱۴ پرامت — HEX مرجع) ----------
const COL_TURQUOISE := Color("1f8a8a")    # فیروزه‌ای (UI)
const COL_TURQUOISE_DEEP := Color("0a3d46")
const COL_GOLD := Color("d4af37")         # طلایی (UI)
const COL_IVORY := Color("e9dfc8")        # عاجی (UI)
const COL_CRIMSON := Color("c9564a")      # سرخ پارسی
const COL_NIGHT := Color("0c2f36")        # منو

# --- محیط ---
const COL_SKY := Color("d4e4ec")              # آسمان
const COL_WATER_SHALLOW := Color("4a90a4")    # آب کم‌عمق
const COL_WATER_DEEP := Color("2c5f73")       # آب عمیق
const COL_BEACH_SAND := Color("e8d5a8")       # شن ساحل
const COL_GRASS_LIGHT := Color("7a9a5c")      # چمن روشن
const COL_GRASS_DARK := Color("5c7a44")       # چمن تیره
const COL_ROCK := Color("8b8073")             # صخره
const COL_ROCK_DARK := Color("5e5548")        # صخره تیره
const COL_SUN := Color("fff4d6")              # نور خورشید

# --- ساختمان‌ها ---
const COL_DOME_WALL := Color("e8d9b8")        # دیوار گنبد
const COL_DOME_TILE := Color("3ab0a0")        # کاشی گنبد
const COL_TILE_PATTERN := Color("2a8070")     # الگوی کاشی
const COL_DOOR_WOOD := Color("6b4a2e")        # در چوبی
const COL_WINDCATCHER := Color("d4b483")      # بادگیر
const COL_FIRETEMPLE := Color("c4b5a0")       # آتشکده (سنگ)

const UNIT_PALETTE: Array[Color] = [
        Color("e0d6b8"), # عاجی
        Color("2f8f83"), # فیروزه‌ای
        Color("d4af37"), # طلایی
        Color("3f6fb5"), # لاجوردی — بدون نارنجی/سرخ تا با وضعیت «رسیده» اشتباه نشود
        Color("5e3a6e"), # گام ۶R4 — ارغوانی شاهی (دسته‌ی پنجم)؛ از سرخِ «رسیده» دور است
]

## رنگ وضعیت «رسیده به هدف» — سرخ روشن: کمترین فاصله‌ی رنگی با هر ۴ رنگ تولد ۰٫۵۷ است
## (نارنجی قبلی فقط ۰٫۲۵ از طلایی فاصله داشت و قابل‌اشتباه بود)
const COL_ARRIVED := Color(1.0, 0.15, 0.1)
