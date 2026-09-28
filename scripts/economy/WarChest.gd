class_name WarChest
extends RefCounted
## گام M3 — خزانه‌ی جنگ: اسکلتِ اقتصاد (پیش‌نمونه‌ی گام ۸)
##
## * کلاسِ ایستا (static) — مقادیر در طولِ یک «ران» بازی و پس از بازتولیدِ
##   جزیره زنده می‌مانند (متغیرهای static در GDScript ۴ به‌ازای هر کلاس‌اند،
##   نه هر نمونه)؛ اجرای تازه‌ی صحنه در همان پروسه هم حفظ می‌شود.
## * ران (run) = زنجیره‌ی جزیره‌ها از شروع تا باخت. با «R» (جزیره‌ی تازه)
##   ران صفر می‌شود؛ با «Enter» پس از برد، جزیره‌ی بعدیِ همان ران می‌آید.
## * سکه فعلاً خرج نمی‌شود — گام ۸ (اقتصاد و ارتقا) فروشگاهِ ارتقا را روی
##   همین خزانه سوار می‌کند (EraId/EraAbilityCatalog طبق نقشه‌راه).

## سکه‌ی جمع‌شده در کل ران
static var coins := 0
## شمار جزیره‌های نجات‌یافته (سطحِ صعود = این عدد)
static var islands_cleared := 0
## شمار مهاجمانی که در کل ران کشته شده‌اند (آمار + سکه)
static var raiders_slain := 0


## شروع ران تازه — سکه‌ها و پیشرفت صفر می‌شود
static func reset_run() -> void:
        coins = 0
        islands_cleared = 0
        raiders_slain = 0


## کسب سکه (مقدار نامنفی)
static func earn(amount: int) -> void:
        if amount > 0:
                coins += amount


## خرج کردن — false = سکه کافی نبود (گام ۸ از این مسیر ارتقا می‌فروشد)
static func spend(amount: int) -> bool:
        if amount < 0 or coins < amount:
                return false
        coins -= amount
        return true


## سطحِ فعلی ران: شماره‌ی جزیره از ۰ (جزیره‌ی اول ران)
static func island_level() -> int:
        return islands_cleared
