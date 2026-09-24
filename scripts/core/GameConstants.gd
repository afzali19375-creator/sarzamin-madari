class_name GameConstants
## ثابت‌های سراسری بازی «سرزمین مادری»
## پالت هخامنشی + زمان‌بندی‌های قانون‌مند (قوانین آهنین سند طراحی)

# ---------- زمان‌بندی ----------
const SLOWMO_SCALE := 0.5                 # قانون: انتخاب پرچم یا Space → time_scale = 0.5
const FIELD_RECOMPUTE_INTERVAL := 0.2     # به‌روزرسانی FlowField هر 0.2 ثانیه
const MAIN_READ_BUDGET_MS := 0.5          # بودجه‌ی خواندن مسیر در نخ اصلی (< 0.5ms)

# ---------- قوانین آهنین بعدی (برای گام‌های آینده) ----------
const FIRE_DESTROY_SECONDS := 10.0        # خانه در آتش پس از 10 ثانیه نابود می‌شود
const RESUPPLY_SECONDS := 5.0             # بازپرگری داخل خانه: 5 ثانیه
const LOOT_DURATION_SECONDS := 20.0       # دشمن برای غارت خانه

# ---------- پالت هخامنشی ----------
const COL_TURQUOISE := Color("1f8a8a")    # فیروزه‌ای
const COL_TURQUOISE_DEEP := Color("0a3d46")
const COL_GOLD := Color("d4af37")         # طلایی
const COL_IVORY := Color("e9dfc8")        # عاجی
const COL_CRIMSON := Color("c9564a")      # سرخ پارسی
const COL_SAND := Color("c2b280")         # شنی
const COL_NIGHT := Color("0c2f36")

const UNIT_PALETTE: Array[Color] = [
	Color("e0d6b8"), # عاجی
	Color("2f8f83"), # فیروزه‌ای
	Color("d4af37"), # طلایی
	Color("3f6fb5"), # لاجوردی — بدون نارنجی/سرخ تا با وضعیت «رسیده» اشتباه نشود
]
