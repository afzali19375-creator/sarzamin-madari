class_name GameConstants
## ثابت‌های سراسری بازی «سرزمین مادری»
## مرجع اعداد: «پرامت فاز اول — بخش حرکت و صحنه» (سرعت ۳، شتاب ۸، اسلوموشن ۰.۵،
## دوربین ۳۶۰°، پالت HEX هخامنشی) + قوانین آهنین سند طراحی.

# ---------- هویت بیلد ----------
## روی صفحه‌ی تست و منو نمایش داده می‌شود تا همیشه مشخص باشد کاربر کدام نسخه را اجرا می‌کند
const BUILD_ID := "2026-09-24-r6"

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
const CAM_ROTATE_SPEED := 90.0            # درجه بر ثانیه (Q/E)
const CAM_NEAR := 0.1
const CAM_FAR := 200.0

# ---------- شبکه‌ی فرمان (بازخورد کاربر: بلوک‌های بزرگ‌تر + هاله سفید) ----------
const COMMAND_CELL := 2.0                 # هر سلول فرمان = ۲×۲ سلول NavGrid
const SQUADS_MAX := 4                     # میان‌بر 1..4 (الگوی Bad North)

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

# ---------- قوانین آهنین بعدی (برای گام‌های آینده) ----------
const FIRE_DESTROY_SECONDS := 10.0        # خانه در آتش پس از 10 ثانیه نابود می‌شود
const RESUPPLY_SECONDS := 5.0             # بازپرگری داخل خانه: 5 ثانیه
const LOOT_DURATION_SECONDS := 20.0       # دشمن برای غارت خانه

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
]

## رنگ وضعیت «رسیده به هدف» — سرخ روشن: کمترین فاصله‌ی رنگی با هر ۴ رنگ تولد ۰٫۵۷ است
## (نارنجی قبلی فقط ۰٫۲۵ از طلایی فاصله داشت و قابل‌اشتباه بود)
const COL_ARRIVED := Color(1.0, 0.15, 0.1)
