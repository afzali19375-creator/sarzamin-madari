class_name Formation
extends Object
## گام M2 — چینشِ بلوکیِ لوزیِ لانه‌زنبوری (بازخورد کاربر: «چینش دسته‌ها» با تصویر مرجع)
##
## * هر دسته = ۱ فرمانده + ۹ سرباز؛ بلوکِ فشرده به شکل لوزی — نه دایره، نه صف.
## * ردیف‌ها زیگزاگی (staggered/hex-packed): هر ردیف نسبت به قبلی نیم‌فاصله
##   جابجاست تا سربازها پشت هم مخفی نشوند.
## * ریاضیِ چیدمان = شبکه‌ی شش‌ضلعی با گامِ «فاصله‌ی همسایه»:
##     فاصله‌ی ردیف‌ها = فاصله‌ی همسایه × √3/2 ≈ ۰٫۸۷ (همان FORMATION_ROW_FACTOR)
##   نتیجه: همه‌ی همسایه‌های بلافصل دقیقاً به فاصله‌ی spacing‌اند → هیچ
##   تداخلِ برخوردی رخ نمی‌دهد (فاصله ≥ قطرِ برخورد × ضریب)، ولی از دید
##   ایزومتریک بدنه‌ها جزئی روی هم می‌افتند — مثل مرجع.
## * ترتیبِ LOCALS = اولویتِ نگه‌داشتنِ خانه‌ها: با کشته‌شدن سربازها بلوک روی
##   همین لیست «فشرده» می‌شود (خانه‌ی خالی نمی‌ماند؛ لوزی از پهلو/عقب جمع می‌شود).
## * فرمانده = خانه‌ی ۰ = مرکز بلوک، کمی عقب‌تر از ردیف جلو؛ پرچمش از میان
##   سربازها بالا می‌آید.
##
## مختصاتِ محلی: x = پهلو (m)، y = عمق (m)؛ +y = جلوی بلوک (سمتِ جهتِ حرکت).

## ۱۰ خانه: ۰ فرمانده | ۱..۲ جلوی فرمانده | ۳..۴ بال‌ها | ۵..۶ عقب | ۷..۹ ردیفِ جلو
## مقادیر بر حسبِ «فاصله‌ی همسایه» ضرب می‌شوند (spacing) — عمق‌ها ×۰٫۸۶۶ همان
## گامِ لانه‌زنبوری است تا فاصله‌ی قطری همسایه‌ها هم دقیقاً spacing بماند.
const LOCALS: Array[Vector2] = [
        Vector2(0.0, 0.0),            # ۰ — فرمانده (مرکز، کمی عقب‌تر از ردیف جلو)
        Vector2(0.5, 0.866),          # ۱ — ردیفِ پیشِ فرمانده (راست)
        Vector2(-0.5, 0.866),         # ۲ — (چپ)
        Vector2(1.0, 0.0),            # ۳ — بالِ راست
        Vector2(-1.0, 0.0),           # ۴ — بالِ چپ
        Vector2(0.5, -0.866),         # ۵ — ردیفِ عقب (راست)
        Vector2(-0.5, -0.866),        # ۶ — (چپ)
        Vector2(0.0, 1.732),          # ۷ — نوکِ جلو (مرکز)
        Vector2(1.0, 1.732),          # ۸ — ردیفِ جلو (راست)
        Vector2(-1.0, 1.732),         # ۹ — ردیفِ جلو (چپ)
]


## n خانه‌ی اولِ بلوک بر حسبِ متر (n ≤ ۱۰) — فشرده‌شدن با مرگ‌ها همین‌جا رخ می‌دهد
static func block_locals(n: int) -> Array[Vector2]:
        var out: Array[Vector2] = []
        for i in mini(n, LOCALS.size()):
                out.append(LOCALS[i])
        return out


## چرخشِ بلوک به سمتِ facing و انتقال به مرکز (center).
## facing = زاویه‌ی جهتِ حرکت در صفحه‌ی XZ؛ جلوی بلوک (محلی +y) به همان سمت می‌رود
## تا «ردیف جلو همیشه سمتِ حرکت» باشد.
static func to_world(locals: Array[Vector2], center: Vector2,
                facing: float) -> Array[Vector2]:
        var ca := cos(facing)
        var sa := sin(facing)
        var out: Array[Vector2] = []
        for l in locals:
                # محلی (side, depth) → جهان: جلو (0,1) → (cos, sin)، پهلو (1,0) → عمود
                out.append(center + Vector2(
                                -l.x * sa + l.y * ca,
                                l.x * ca + l.y * sa))
        return out


## زاویه‌ی facing از بردارِ جهتِ حرکت (صفحه‌ی XZ به‌صورت Vector2(x, z))
static func facing_from_dir(d: Vector2) -> float:
        if d.length() < 0.0001:
                return 0.0
        return atan2(d.y, d.x)


## نزدیک‌ترین فاصله‌ی جفتیِ چیدمان — برای تست/تضمینِ «بدون تداخلِ برخوردی»
static func min_pair_distance(locals: Array[Vector2], spacing: float) -> float:
        var best := INF
        for i in locals.size():
                for j in range(i + 1, locals.size()):
                        best = minf(best, locals[i].distance_to(locals[j]) * spacing)
        return best
