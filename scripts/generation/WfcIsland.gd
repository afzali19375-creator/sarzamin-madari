class_name WfcIsland
extends RefCounted
## گام ۴ — تولید رویه‌ای جزیره با WFC دست‌نویس (Wave Function Collapse ساده‌شده).
##
## قوانین آهنین سند طراحی:
##   * حل تعارض (contradiction) فقط با **seed جدید** — هرگز backtracking.
##   * جزیره ≤ 32×32.
##   * ۲۰ ماژول MVP با سوکت متقارن (نوع + ارتفاع) در هر چهار جهت.
##
## سازوکار: هر سلول یک «دامنه» از ماژول‌های مجاز دارد (بر اساس ماسک ساحلی)؛
## سلول با کمترین آنتروپی انتخاب، با وزنِ محلی، فرومی‌پاشد (collapse) و دامنه‌ی
## همسایه‌هایش با ماتریس سازگاری سوکت‌ها پالایش می‌شود. اگر دامنه‌ی همسایه‌ای
## خالی شود → تلاش کل باطل و با seed بعدی از صفر شروع می‌شود.
##
## خروجی: دیکشنری کامل جزیره (ماژول‌ها، walkable، ارتفاع بالا، متادیتا، آمار).

const DIR_X := [1, -1, 0, 0]
const DIR_Y := [0, 0, 1, -1]
## ۸ جهت برای ذوب دریاچه‌های داخلی (§۸.۳)
const DIR8_X := [1, -1, 0, 0, 1, 1, -1, -1]
const DIR8_Y := [0, 0, 1, -1, 1, -1, 1, -1]

var _size := 32
var _phase1 := 0.0
var _phase2 := 0.0
var _radius0 := 0.62
var _mods: Array[Dictionary] = []
var _compat_cache: Dictionary = {}

## آمار آخرین generate — برای تشخیص این‌که شکست‌ها از کدام اعتبارسنجی‌اند
## (telemetry دائمی: در تست خودکار و لاگ کاربردی استفاده می‌شود)
var last_stats := {"contradiction": 0, "land_fraction": 0, "walkable_fraction": 0, "disconnected": 0, "no_land": 0, "too_small": 0, "success": 0}


func _init() -> void:
        _build_modules()


# ---------------- ۲۰ ماژول MVP ----------------
## هر ماژول: نام، سوکت (حرف نوع + ارتفاع)، قابل‌عبور، وزن پایه،
## ارتفاع سطح بالای کاشی (متر) و رنگ پایه (پالت هخامنشی).

func _build_modules() -> void:
        # رنگ‌ها = پالت HEX مرجع پرامت §۱۴ (چمن/شن/صخره/آب)
        _mods = [
                {"name": "water_deep", "socket": "w0", "walkable": false, "weight": 3.0, "top": 0.0, "color": Color("2c5f73")},
                {"name": "water_wave", "socket": "w0", "walkable": false, "weight": 0.8, "top": 0.0, "color": Color("3a7186")},
                {"name": "water_shallow", "socket": "w0", "walkable": false, "weight": 1.4, "top": 0.0, "color": Color("4a90a4")},
                {"name": "water_foam", "socket": "w0", "walkable": false, "weight": 0.5, "top": 0.0, "color": Color("a8d8d8")},
                {"name": "sand_wet", "socket": "s0", "walkable": true, "weight": 0.7, "top": 0.18, "color": Color("d4c290")},
                {"name": "sand_dry", "socket": "s0", "walkable": true, "weight": 1.2, "top": 0.22, "color": Color("e8d5a8")},
                {"name": "sand_pebbles", "socket": "s0", "walkable": true, "weight": 0.35, "top": 0.22, "color": Color("d9c89c")},
                {"name": "sand_high", "socket": "s1", "walkable": true, "weight": 0.5, "top": 0.5, "color": Color("ecdcb2")},
                {"name": "sand_scrub", "socket": "s1", "walkable": true, "weight": 0.25, "top": 0.5, "color": Color("c2bd8a")},
                {"name": "grass_low", "socket": "g1", "walkable": true, "weight": 1.7, "top": 0.55, "color": Color("7a9a5c")},
                {"name": "grass_flowers", "socket": "g1", "walkable": true, "weight": 0.35, "top": 0.55, "color": Color("8aa86a")},
                {"name": "grass_path", "socket": "g1", "walkable": true, "weight": 0.3, "top": 0.55, "color": Color("b0a276")},
                {"name": "grass_mid", "socket": "g2", "walkable": true, "weight": 1.3, "top": 0.9, "color": Color("6d8c50")},
                {"name": "grass_bush", "socket": "g2", "walkable": true, "weight": 0.35, "top": 0.9, "color": Color("5c7a44")},
                {"name": "grass_flowers2", "socket": "g2", "walkable": true, "weight": 0.25, "top": 0.9, "color": Color("7fa055")},
                {"name": "grass_high", "socket": "g3", "walkable": true, "weight": 0.85, "top": 1.3, "color": Color("5c7a44")},
                {"name": "grass_stones", "socket": "g3", "walkable": true, "weight": 0.25, "top": 1.3, "color": Color("75855c")},
                {"name": "rock_low", "socket": "r2", "walkable": false, "weight": 0.3, "top": 1.05, "color": Color("8b8073")},
                {"name": "rock_high", "socket": "r3", "walkable": false, "weight": 0.2, "top": 1.5, "color": Color("6e6659")},
                {"name": "rock_peak", "socket": "r4", "walkable": false, "weight": 0.08, "top": 1.95, "color": Color("5e5548")},
        ]


# ---------------- سازگاری سوکت‌ها ----------------
## w=آب  s=شن  g=چمن  r=صخره — همسایگی مجاز:
##   هم‌نوع: |Δh| ≤ 1   |   آب–شن: فقط w0–s0 و w0–s1 (برِ ساحلی)
##   آب–چمن: ممنوع (ساحل شن میانشان لازم است)   |   آب–صخره: مجاز (پرتگاه دریایی)

func _compatible(a: String, b: String) -> bool:
        var key := a + "|" + b
        var cached = _compat_cache.get(key)
        if cached != null:
                return cached
        var ta := a.substr(0, 1)
        var tb := b.substr(0, 1)
        var ha := int(a.substr(1))
        var hb := int(b.substr(1))
        var ok := false
        if ta == tb:
                ok = absi(ha - hb) <= 1
        elif (ta == "w" and tb == "s") or (ta == "s" and tb == "w"):
                ok = ha == 0 and hb <= 1
        elif (ta == "w" and tb == "r") or (ta == "r" and tb == "w"):
                ok = true
        else:
                ok = absi(ha - hb) <= 1
        _compat_cache[key] = ok
        return ok


func _is_water_socket(s: String) -> bool:
        return s.substr(0, 1) == "w"


# ---------------- ماسک ساحلی و وزن محلی ----------------

func _r_eff(angle: float) -> float:
        return _radius0 + 0.15 * sin(angle * 3.0 + _phase1) + 0.08 * sin(angle * 7.0 + _phase2)


## 0 = فقط آب (شامل حلقه‌ی بیرونی) — 1 = نوار ساحلی (همه‌چیز) — 2 = فقط خشکی
func _zone(cx: int, cy: int) -> int:
        if cx == 0 or cy == 0 or cx == _size - 1 or cy == _size - 1:
                return 0
        var half := float(_size) * 0.5
        var vec := Vector2(cx - half + 0.5, cy - half + 0.5)
        var d := vec.length() / half
        var re := _r_eff(atan2(vec.y, vec.x))
        if d > re + 0.05:
                return 0
        if d < re - 0.10:
                return 2
        return 1


func _weight(ci: int, m: int) -> float:
        var w: float = _mods[m]["weight"]
        var s: String = _mods[m]["socket"]
        var cx := ci % _size
        var cy := int(ci / float(_size))
        var half := float(_size) * 0.5
        var vec := Vector2(cx - half + 0.5, cy - half + 0.5)
        var d := vec.length() / half
        var re := _r_eff(atan2(vec.y, vec.x))
        if _is_water_socket(s):
                var depth := d - re
                if _mods[m]["name"] == "water_deep":
                        return w * clampf(0.4 + depth * 5.0, 0.4, 2.6)
                return w * clampf(1.25 - depth * 4.0, 0.3, 1.4)
        var bias := clampf(1.2 - d / maxf(re, 0.05), 0.0, 1.0)
        var letter := s.substr(0, 1)
        var h := int(s.substr(1))
        if letter == "s":
                return w * (1.5 - bias)
        if letter == "g":
                if h >= 2:
                        return w * (0.3 + 1.5 * bias * bias)
                return w * (1.5 - bias)
        if letter == "r":
                return w * (0.2 + 2.2 * bias * bias)
        return w


func _initial_domain(ci: int) -> PackedInt32Array:
        var cx := ci % _size
        var cy := int(ci / float(_size))
        var zone := _zone(cx, cy)
        var dom := PackedInt32Array()
        for m in _mods.size():
                var water := _is_water_socket(_mods[m]["socket"])
                if zone == 0 and not water:
                        continue
                if zone == 2 and water:
                        continue
                dom.append(m)
        return dom


# ---------------- حل‌گر WFC ----------------

func _attempt(rng: RandomNumberGenerator) -> PackedInt32Array:
        var n := _size * _size
        var assigned := PackedInt32Array()
        assigned.resize(n)
        assigned.fill(-1)
        var domains: Array = []
        domains.resize(n)
        for i in n:
                domains[i] = _initial_domain(i)
        var open: Array[int] = []
        open.resize(n)
        for i in n:
                open[i] = i
        while not open.is_empty():
                # کمترین آنتروپی = کم‌عضوترین دامنه‌ی باز
                var best_k := 0
                var best_len := 2147483647
                for k in open.size():
                        var l: int = domains[open[k]].size()
                        if l < best_len:
                                best_len = l
                                best_k = k
                var ci: int = open[best_k]
                var dom: PackedInt32Array = domains[ci]
                if dom.is_empty():
                        return PackedInt32Array()  # تعارض → کل تلاش باطل (بدون backtracking)
                var m := _weighted_pick(ci, dom, rng)
                assigned[ci] = m
                open[best_k] = open[open.size() - 1]
                open.remove_at(open.size() - 1)
                var cx := ci % _size
                var cy := int(ci / float(_size))
                for d in 4:
                        var nx: int = cx + DIR_X[d]
                        var ny: int = cy + DIR_Y[d]
                        if nx < 0 or ny < 0 or nx >= _size or ny >= _size:
                                continue
                        var ni := ny * _size + nx
                        if assigned[ni] != -1:
                                continue
                        var s_m: String = _mods[m]["socket"]
                        var nd := PackedInt32Array()
                        for cand in domains[ni]:
                                if _compatible(s_m, _mods[cand]["socket"]):
                                        nd.append(cand)
                        if nd.is_empty():
                                return PackedInt32Array()  # تعارض
                        domains[ni] = nd
        return assigned


func _weighted_pick(ci: int, dom: PackedInt32Array, rng: RandomNumberGenerator) -> int:
        var total := 0.0
        for m in dom:
                total += _weight(ci, m)
        if total <= 0.0:
                return dom[0]
        var roll := rng.randf() * total
        var acc := 0.0
        for m in dom:
                acc += _weight(ci, m)
                if roll <= acc:
                        return m
        return dom[dom.size() - 1]


# ---------------- بسته‌بندی و اعتبارسنجی ----------------
## اعتبارسنجی سخت‌گیرانه: اگر جزیره «قابل‌بازی» نباشد (خشکی کم/زیاد یا
## تکه‌تکه)، مثل تعارض با آن رفتار می‌شود → seed بعدی.

func generate(seed_value: int, grid_size: int = 32) -> Dictionary:
        var t0 := Time.get_ticks_usec()
        _size = clampi(grid_size, 16, 32)
        last_stats = {"contradiction": 0, "land_fraction": 0, "walkable_fraction": 0, "disconnected": 0, "no_land": 0, "too_small": 0, "success": 0}
        var rng := RandomNumberGenerator.new()
        for attempt in range(1, 49):
                rng.seed = hash("%d:%d" % [seed_value, attempt])
                _phase1 = rng.randf() * TAU
                _phase2 = rng.randf() * TAU
                ## گام ۶R۱۲ — «جزیره زیاده بزرگ بود»: شعاع پایه ۰٫۷۲→۰٫۵۶
                ## (قطرِ خشکی ~۱۷–۱۹m به‌جای ~۲۳m — نسبت سرباز/جزیره مثل مرجع)
                _radius0 = 0.56 + rng.randf() * 0.06
                var grid := _attempt(rng)
                if grid.is_empty():
                        last_stats["contradiction"] += 1
                        continue
                var packed := _package(grid, seed_value, attempt, t0)
                if packed.get("ok", false) == true:
                        last_stats["success"] += 1
                        return packed
                # شکست اعتبارسنجی — نوعش را ثبت کن (برای ریشه‌یابی)
                if packed.has("reason"):
                        var reason: String = packed["reason"]
                        last_stats[reason] = int(last_stats.get(reason, 0)) + 1
        return {"ok": false, "seed_used": seed_value, "attempts": 48, "stats": last_stats.duplicate()}


func _package(grid: PackedInt32Array, seed_used: int, attempt: int, t0: int) -> Dictionary:
        var n := _size * _size
        var modules := PackedInt32Array()
        modules.resize(n)
        var walkable := PackedByteArray()
        walkable.resize(n)
        var tops := PackedFloat32Array()
        tops.resize(n)
        var land := 0
        var walk := 0
        for i in n:
                var m := grid[i]
                modules[i] = m
                walkable[i] = 1 if _mods[m]["walkable"] else 0
                tops[i] = _mods[m]["top"]
                if not _is_water_socket(_mods[m]["socket"]):
                        land += 1
                if walkable[i] == 1:
                        walk += 1
        var frac := float(land) / float(n)
        # گام ۶R۱۲ — جزیره‌ی کوچک‌تر: کرانِ خشکی ۰٫۱۴–۰٫۵۵ (قبلاً ۰٫۲۰–۰٫۶۲)
        if frac < 0.14 or frac > 0.55:
                return {"reason": "land_fraction"}
        # §۸.۳ — نسخه‌ی ۶R۱۲: «قابل‌عبور ≥ ۲۱٪» با جزیره‌ی کوچک‌تر (قبلاً ۴۰٪)
        if float(walk) < float(n) * 0.21:
                return {"reason": "walkable_fraction"}
        # --- پس‌پردازش اتصال: «جزیره‌های شنیِ ریز» را در آب ذوب کن ---
        # در نوار ساحلی گاهی یک تک‌کاشی شن وسط آب می‌ماند؛ این جزیره‌های کوچک
        # بازی را خراب نمی‌کنند ولی باید حذف شوند تا خشکی همیشه یک تکه باشد.
        # تبدیل به آب با سوکت w0 با همسایه‌های آبی سازگار است (تعارض سوکت ندارد).
        var comp := PackedInt32Array()
        comp.resize(n)
        comp.fill(-1)
        var comps: Array[PackedInt32Array] = []
        for i in n:
                if walkable[i] == 1 and comp[i] == -1:
                        var id := comps.size()
                        var cells := PackedInt32Array()
                        var q: Array[int] = [i]
                        comp[i] = id
                        var head := 0
                        while head < q.size():
                                var cur: int = q[head]
                                head += 1
                                cells.append(cur)
                                var cx := cur % _size
                                var cy := int(cur / float(_size))
                                for d in 4:
                                        var nx: int = cx + DIR_X[d]
                                        var ny: int = cy + DIR_Y[d]
                                        if nx < 0 or ny < 0 or nx >= _size or ny >= _size:
                                                continue
                                        var ni := ny * _size + nx
                                        if comp[ni] == -1 and walkable[ni] == 1:
                                                comp[ni] = id
                                                q.append(ni)
                        comps.append(cells)
        if comps.is_empty():
                return {"reason": "no_land"}
        var biggest := 0
        for ci in comps.size():
                if comps[ci].size() > comps[biggest].size():
                        biggest = ci
        if comps[biggest].size() < 90:
                return {"reason": "too_small"}
        var water_module := -1
        for m in _mods.size():
                if _is_water_socket(_mods[m]["socket"]):
                        water_module = m
                        break
        for ci in comps.size():
                if ci == biggest:
                        continue
                for i in comps[ci]:
                        modules[i] = water_module
                        walkable[i] = 0
                        tops[i] = 0.0
        # --- ذوب دریاچه‌های تک‌سلولیِ محصور در خشکی ---
        # §۸.۳ پرامت: «هیچ آب در وسط جزیره نباید» — سلول آب که هر ۸ همسایه‌اش
        # خشکی است به چمن تبدیل می‌شود (چند گذر تا جابه‌جایی ثابت).
        _melt_inner_lakes(modules, walkable, tops)
        # --- گام ۶R۱۵ — جزیره‌ی دوبلکس (بازخورد کاربر از اسکرین‌شات‌های مرجع):
        # «جزیره باید حالت دوبلکس داشته باشد؛ کاراکترها از فضای بالایی به فضای
        # پایین بیایند؛ یک مسیر کوتاه و باریک» — سقفِ بالایی ~۴۰٪ خشکی در یک
        # کلاهکِ سمت‌دار + پرتگاهِ داخلی + یک گذرگاهِ ۲ سلولی با شیب نرم.
        var duplex_rng := RandomNumberGenerator.new()
        duplex_rng.seed = hash("%d:%d:duplex" % [seed_used, attempt])
        var duplex := _assign_duplex(modules, walkable, tops, duplex_rng)
        land = 0
        walk = 0
        for i in n:
                if not _is_water_socket(_mods[modules[i]]["socket"]):
                        land += 1
                if walkable[i] == 1:
                        walk += 1
        var names := PackedStringArray()
        var sockets := PackedStringArray()
        var colors: Array[Color] = []
        var meta_walk := PackedByteArray()
        var meta_tops := PackedFloat32Array()
        for mod in _mods:
                names.append(mod["name"])
                sockets.append(mod["socket"])
                colors.append(mod["color"])
                meta_walk.append(1 if mod["walkable"] else 0)
                meta_tops.append(mod["top"])
        var hsh := 0
        for m in modules:
                hsh = ((hsh * 31 + m) & 0x7FFFFFFF)
        var out := {
                "ok": true,
                "size": _size,
                "modules": modules,
                "walkable": walkable,
                "tops": tops,
                "meta_names": names,
                "meta_sockets": sockets,
                "meta_walkable": meta_walk,
                "meta_colors": colors,
                "meta_tops": meta_tops,
                "seed_used": seed_used,
                "attempts": attempt,
                "gen_ms": float(Time.get_ticks_usec() - t0) / 1000.0,
                "land_count": land,
                "walkable_count": walk,
                "hash": hsh,
        }
        if not duplex.is_empty():
                out["levels"] = duplex["levels"]
                out["duplex"] = duplex
        return out


## ذوبِ «همه‌ی» دریاچه‌های محصور در خشکی (§۸.۳: «هیچ آب در وسط جزیره نباید»)
## گام ۶R۱۴ — نسخه‌ی فلود-فیل: از هر سلولِ آبیِ مرزی سیلاب می‌کنیم؛ هر سلولِ آبی
## که از مرز قابل‌دسترس نبود = «دریاچه‌ی داخلی» (هر اندازه، حتی چندسلولی) → چمن.
## قبلاً فقط تک‌سلولی‌ها ذوب می‌شدند و تالاب‌های ۲-۵ سلولی به‌صورت «حفره‌ی آب
## وسط جزیره» باقی می‌ماندند (بازخورد تصویری کاربر). قطعی و بدون بازگشت.
@warning_ignore("integer_division")
func _melt_inner_lakes(modules: PackedInt32Array, walkable: PackedByteArray,
                tops: PackedFloat32Array) -> void:
        var grass_module := -1
        for m in _mods.size():
                if _mods[m]["name"] == "grass_low":
                        grass_module = m
                        break
        if grass_module < 0:
                return
        var n := _size * _size
        var is_water := PackedByteArray()
        is_water.resize(n)
        var sea := PackedByteArray()
        sea.resize(n)
        # گام ۶R۱۴c — کلِ فرایند ۲ دور کامل می‌رود: پرکردنِ تنگه‌ها در دورِ اول
        # ممکن است کانال‌های باقی‌مانده را «دریاچه‌ی بسته» کند؛ دورِ دوم با
        # is_water تازه‌سازی‌شده آن‌ها را هم ذوب می‌کند.
        for _round in 2:
                # --- ۱) علامت‌گذاریِ آب ---
                for i in n:
                        is_water[i] = 0 if walkable[i] == 1 else 1
                for i in n:
                        sea[i] = 0
                # --- ۲) سیلاب از مرز گرید (دریای بیرونی) ---
                var q: Array[int] = []
                for cy in _size:
                        for cx in _size:
                                if cx == 0 or cy == 0 or cx == _size - 1 or cy == _size - 1:
                                        var bi := cy * _size + cx
                                        if is_water[bi] == 1 and sea[bi] == 0:
                                                sea[bi] = 1
                                                q.append(bi)
                var head := 0
                while head < q.size():
                        var cur: int = q[head]
                        head += 1
                        var cx := cur % _size
                        var cy := int(cur / float(_size))
                        for d in 4:
                                var nx: int = cx + DIR_X[d]
                                var ny: int = cy + DIR_Y[d]
                                if nx < 0 or ny < 0 or nx >= _size or ny >= _size:
                                        continue
                                var ni := ny * _size + nx
                                if is_water[ni] == 1 and sea[ni] == 0:
                                        sea[ni] = 1
                                        q.append(ni)
                # --- ۳) ذوبِ دریاچه‌های محصور ---
                for cy in _size:
                        for cx in _size:
                                var i := cy * _size + cx
                                if is_water[i] == 1 and sea[i] == 0:
                                        modules[i] = grass_module
                                        walkable[i] = 1
                                        tops[i] = _mods[grass_module]["top"]
                # --- ۴) پرکردنِ تنگه‌ها ---
                # اثباتِ پرابِ رندر (۶R۱۴c): WFC کانال‌های آبِ ۱-۳ سلولی می‌سازد
                # که جزیره را به نوارهای موازی می‌شکند (بازخورد تصویری: «راه‌راه
                # مورب روی کل جزیره» — در نمایِ سایه‌دار، سطحِ آبِ کانال با حلقه‌ی
                # کم‌عمقِ روشن، سفیدِ شسته می‌شود). قانون: سلولِ آبِ متصل به دریا
                # که در هر دو سمتِ یک محور تا ۵ سلول خشکی دارد = شکاف → چمن.
                # خلیجِ پهن (≥۶ سلول) و دریایِ باز دست‌نخورده می‌مانند.
                for _pass in 8:
                        var any_fill := false
                        for cy in _size:
                                for cx in _size:
                                        var i2 := cy * _size + cx
                                        if walkable[i2] == 1 or is_water[i2] == 0 \
                                                        or sea[i2] == 0:
                                                continue
                                        if (_scan_land(walkable, cx, cy, 1, 0, 5) \
                                                        and _scan_land(walkable, cx, cy, -1, 0, 5)) \
                                                        or (_scan_land(walkable, cx, cy, 0, 1, 5) \
                                                        and _scan_land(walkable, cx, cy, 0, -1, 5)):
                                                modules[i2] = grass_module
                                                walkable[i2] = 1
                                                tops[i2] = _mods[grass_module]["top"]
                                                any_fill = true
                        if not any_fill:
                                break


## گام ۶R۱۴c — آیا در جهتِ (dx,dy) تا «reach» سلول خشکی هست؟ (برای تشخیص تنگه)
func _scan_land(walkable: PackedByteArray, cx: int, cy: int,
                dx: int, dy: int, reach: int) -> bool:
        for r in range(1, reach + 1):
                var nx: int = cx + dx * r
                var ny: int = cy + dy * r
                if nx < 0 or ny < 0 or nx >= _size or ny >= _size:
                        return false
                if walkable[ny * _size + nx] == 1:
                        return true
        return false


# ---------------- گام ۶R۱۵ — جزیره‌ی دوبلکس ----------------
## مثل اسکرین‌شات‌های مرجع: یک «کلاهکِ» بلند (~۳۰-۴۵٪ خشکی) در یک سمتِ جزیره
## با ارتفاعِ ثابتِ UPPER_TOP، پرتگاهِ گچیِ داخلی، و «یک مسیرِ کوتاهِ باریک»
## (۲ سلول پهنا، ۵-۷ سلول طول) که دو سطح را با شیبِ نرم به هم وصل می‌کند.
##
## خروجی (اگر ممکن نشد = دیکشنری خالی → جزیره تختِ عادی):
##   levels: PackedInt32Array  (۰ = سطح پایین، ۱ = سقف، ۲ = سلولِ شیبِ مسیر)
##   axis / entry / len  — هندسه‌ی شیب برای IslandGround (میان‌یابی گوشه‌ها)
##   path_cells          — سلول‌های مسیر (پدِ فرمان نباید رویشان بنشیند)

const DUPLEX_UPPER_TOP := 2.1       # بلندی سقف (m) — بالاتر از بلندترین چمنِ پایین
                                    # (grass_high=1.3) تا هیچ عبورِ غیرمسیر نماند
const DUPLEX_MIN_FRAC := 0.22       # کمترین سهمِ مجازِ سقف از خشکی
const DUPLEX_MAX_FRAC := 0.46
const DUPLEX_RAMP_DIFF := 0.55      # اختلافِ ارتفاعی که «پرتگاه» حساب می‌شود

@warning_ignore("integer_division")
func _assign_duplex(modules: PackedInt32Array, walkable: PackedByteArray,
                tops: PackedFloat32Array, rng: RandomNumberGenerator) -> Dictionary:
        var n := _size * _size
        # --- مرکز و شعاعِ خشکی (در سلول) ---
        var cx_acc := 0.0
        var cy_acc := 0.0
        var wcount := 0
        for i in n:
                if walkable[i] == 1:
                        cx_acc += i % _size
                        cy_acc += i / _size
                        wcount += 1
        if wcount < 90:
                return {}
        var cc := Vector2(cx_acc / wcount, cy_acc / wcount)
        var r_max := 0.0
        for i in n:
                if walkable[i] == 1:
                        var p := Vector2(i % _size, i / _size)
                        r_max = maxf(r_max, p.distance_to(cc))
        # --- ۸ جهتِ نامزد؛ اولین جهتی که کلاهکِ مجاز بدهد برنده است ---
        var levels := PackedInt32Array()
        levels.resize(n)
        var base_ang := rng.randf() * TAU
        for attempt_dir in 8:
                var ang := base_ang + attempt_dir * (TAU / 8.0)
                var dirv := Vector2(cos(ang), sin(ang))
                var upper: Array[int] = []
                for i in n:
                        if walkable[i] != 1:
                                continue
                        var p := Vector2(i % _size, i / _size)
                        if (p - cc).dot(dirv) > r_max * 0.32:
                                upper.append(i)
                var frac := float(upper.size()) / float(wcount)
                if frac < DUPLEX_MIN_FRAC or frac > DUPLEX_MAX_FRAC:
                        continue
                # --- گام ۶R۱۵b — سقف باید ۴جهته هم‌بند باشد: سقفِ چندتکه
                # یعنی قطعه‌ای بدونِ دسترسی به مسیر (قانونِ قطریِ هم‌سطح
                # هم بخشِ مورب را پاس می‌دهد، پس هم‌بندیِ ۴جهته کافی است)
                if not _upper_connected(upper):
                        continue
                # --- یال‌های مرزیِ بالایی-پایینی (هر دو قابل‌عبور) ---
                var edges: Array[Vector2i] = []   # x=ایندکسِ پایین، y=ایندکسِ بالایی
                for ui in upper:
                        var ux: int = ui % _size
                        var uy: int = ui / _size
                        for d in 4:
                                var nx: int = ux + DIR_X[d]
                                var ny: int = uy + DIR_Y[d]
                                if nx < 0 or ny < 0 or nx >= _size or ny >= _size:
                                        continue
                                var ni: int = ny * _size + nx
                                if walkable[ni] == 1 and levels_scan_is_lower(ni, upper):
                                        edges.append(Vector2i(ni, ui))
                if edges.size() < 3:
                        continue
                # --- انتخابِ محلِ مسیر از میانِ یال‌ها (تصادفیِ قطعی) ---
                var e := edges[rng.randi_range(0, edges.size() - 1)]
                var path := _carve_ramp(e, walkable, modules, upper, rng)
                if path.is_empty():
                        continue
                # --- اعمال ارتفاع سقف + سلول‌های شیب ---
                for i in n:
                        levels[i] = 0
                for ui in upper:
                        levels[ui] = 1
                        if walkable[ui] == 1:
                                tops[ui] = DUPLEX_UPPER_TOP
                var ramp_cells: PackedInt32Array = path["cells"]
                var axis: Vector2 = path["axis"]
                var entry := Vector2(path["entry"].x, path["entry"].y)
                var plen: float = path["len"]
                for ci in ramp_cells:
                        levels[ci] = 2
                        var center := Vector2(ci % _size, ci / _size)
                        var t := clampf((center - entry).dot(axis) / plen, 0.0, 1.0)
                        tops[ci] = lerpf(path["low_top"], DUPLEX_UPPER_TOP, t)
                return {
                        "levels": levels,
                        "upper_top": DUPLEX_UPPER_TOP,
                        "axis": axis,
                        "entry": entry,
                        "len": plen,
                        "low_top": float(path["low_top"]),
                        "path_cells": ramp_cells,
                        "upper_count": upper.size(),
                }
        return {}


## آیا ایندکس در فهرستِ «بالایی»ها نیست؟ (کمکیِ کوچک — O(1) با ستِ موقت)
func levels_scan_is_lower(ci: int, upper: Array[int]) -> bool:
        return not upper.has(ci)


## هم‌بندیِ ۴جهته‌ی سلول‌های سقف (BFS از اولین عضو)
@warning_ignore("integer_division")
func _upper_connected(upper: Array[int]) -> bool:
        if upper.is_empty():
                return false
        var member := {}
        for ui in upper:
                member[ui] = true
        var seen := {upper[0]: true}
        var q: Array[int] = [upper[0]]
        var head := 0
        while head < q.size():
                var cur: int = q[head]
                head += 1
                var cx: int = cur % _size
                var cy: int = cur / _size
                for d in 4:
                        var nx: int = cx + DIR_X[d]
                        var ny: int = cy + DIR_Y[d]
                        if nx < 0 or ny < 0 or nx >= _size or ny >= _size:
                                continue
                        var ni: int = ny * _size + nx
                        if seen.has(ni) or not member.has(ni):
                                continue
                        seen[ni] = true
                        q.append(ni)
        return seen.size() == upper.size()


## تراشِ مسیرِ شیب از یالِ (پایین x، بالا y):
## ۳ سلول به سمتِ پایین + یال + ۳ سلول به سمتِ بالا؛ پهنا = ۲ سلول.
## گام ۶R۱۵b — راستی‌آزماییِ «اتصالِ واقعی»: ستونِ تراش‌خورده ممکن است
## حفره‌ی آب/صخره داشته باشد و دهانه‌ها به هم نرسند (بذرهای ۳ و ۱۱ در پراب).
## شرطِ پذیرش: BFS داخلِ سلول‌های شیب از سمتِ پایین به سمتِ بالا برقرار باشد
## و هر دهانه به سلولِ walkableِ همان سطح ختم شود. در شکست، سمتِ مخالف
## امتحان می‌شود؛ سپس {} (تا جهت/یالِ بعدی امتحان شود).
@warning_ignore("integer_division")
func _carve_ramp(edge: Vector2i, walkable: PackedByteArray,
                modules: PackedInt32Array, upper: Array[int],
                rng: RandomNumberGenerator) -> Dictionary:
        var lo := edge.x
        var hi := edge.y
        var hx := hi % _size
        var hy := hi / _size
        var dx := hx - (lo % _size)
        var dy := hy - (lo / _size)
        if absi(dx) + absi(dy) != 1:
                return {}
        var axis := Vector2(dx, dy)          # از پایین به بالا (یکی از ۴ جهت)
        var perp := Vector2(-dy, dx)         # عمود بر مسیر
        var side0 := 1 if rng.randf() < 0.5 else -1
        var boundary_proj := Vector2(hx, hy).dot(axis)
        for side_try in 2:
                var side := side0 if side_try == 0 else -side0
                var cells_set := {}
                # ستونِ اصلی: از ۳ پایین‌تر تا ۳ بالاتر
                for k in range(-3, 4):
                        var cx: int = hx - dx * k
                        var cy: int = hy - dy * k
                        if cx < 1 or cy < 1 or cx >= _size - 1 or cy >= _size - 1:
                                continue
                        var ci := cy * _size + cx
                        if walkable[ci] == 1:
                                cells_set[ci] = true
                        # پهنای دوم: یک سلول کنارِ ستون
                        var px: int = cx + int(perp.x) * side
                        var py: int = cy + int(perp.y) * side
                        if px < 1 or py < 1 or px >= _size - 1 or py >= _size - 1:
                                continue
                        var pi2 := py * _size + px
                        if walkable[pi2] == 1:
                                cells_set[pi2] = true
                if cells_set.size() < 6:
                        continue
                var path := _validate_ramp(cells_set, walkable, axis,
                                boundary_proj)
                if path.is_empty():
                        continue
                var cells: PackedInt32Array = path["cells"]
                # ارتفاعِ دهانه‌ی پایین از ماژولِ واقعیِ اولین سلول
                var min_proj := 1e9
                var entry_cell := -1
                var max_proj := -1e9
                for ci2 in cells:
                        var center := Vector2(ci2 % _size, ci2 / _size)
                        var pr := center.dot(axis)
                        if pr < min_proj:
                                min_proj = pr
                                entry_cell = ci2
                        max_proj = maxf(max_proj, pr)
                if entry_cell < 0:
                        continue
                var low_top := 0.55
                var mi := int(modules[entry_cell])
                if mi >= 0 and mi < _mods.size():
                        low_top = float(_mods[mi]["top"])
                return {
                        "cells": cells,
                        "axis": axis,
                        "entry": Vector2(min_proj * axis.x, min_proj * axis.y),
                        "entry_proj": min_proj,
                        "len": maxf(max_proj - min_proj, 1.0),
                        "low_top": low_top,
                }
        return {}


## BFS داخلِ ستونِ شیب + شرطِ اتصالِ دو دهانه به سطوحِ واقعی
@warning_ignore("integer_division")
func _validate_ramp(cells_set: Dictionary, walkable: PackedByteArray,
                axis: Vector2, boundary_proj: float) -> Dictionary:
        # جداسازیِ دو سرِ ستون با پروجکشن روی محور (مرز = پروجکشنِ سلولِ بالاییِ یال)
        var low_side: Array[int] = []
        var high_side: Array[int] = []
        for c in cells_set:
                var ci := int(c)
                var center := Vector2(ci % _size, ci / _size)
                if center.dot(axis) <= boundary_proj:
                        low_side.append(ci)
                else:
                        high_side.append(ci)
        if low_side.is_empty() or high_side.is_empty():
                return {}
        # BFS از هر سلولِ سمتِ پایین داخلِ ستون
        var seen := {}
        var q: Array[int] = []
        for c in low_side:
                seen[c] = true
                q.append(c)
        var head := 0
        while head < q.size():
                var cur: int = q[head]
                head += 1
                var cx: int = cur % _size
                var cy: int = cur / _size
                for d in 4:
                        var nx: int = cx + DIR_X[d]
                        var ny: int = cy + DIR_Y[d]
                        var ni: int = ny * _size + nx
                        if nx < 0 or ny < 0 or nx >= _size or ny >= _size:
                                continue
                        if seen.has(ni) or not cells_set.has(ni):
                                continue
                        seen[ni] = true
                        q.append(ni)
        var reached_high := false
        for c in high_side:
                if seen.has(c):
                        reached_high = true
        if not reached_high:
                return {}
        # دهانه‌ی پایین: حداقل یکی از سلول‌های دیده‌شده همسایه‌ی walkableِ
        # «سمتِ پایینِ مرز» داشته باشد
        var low_ok := false
        var high_ok := false
        for c in seen:
                var ci3 := int(c)
                var cx3: int = ci3 % _size
                var cy3: int = ci3 / _size
                for d in 4:
                        var nx3: int = cx3 + DIR_X[d]
                        var ny3: int = cy3 + DIR_Y[d]
                        if nx3 < 0 or ny3 < 0 or nx3 >= _size or ny3 >= _size:
                                continue
                        var ni3: int = ny3 * _size + nx3
                        if walkable[ni3] == 0 or cells_set.has(ni3):
                                continue
                        var pr3 := Vector2(nx3, ny3).dot(axis)
                        if pr3 < boundary_proj:
                                low_ok = true
                        else:
                                high_ok = true
        if not (low_ok and high_ok):
                return {}
        var cells := PackedInt32Array()
        for c in cells_set:
                cells.append(int(c))
        return {"cells": cells}
