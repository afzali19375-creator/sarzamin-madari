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
        return {
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


## ذوب دریاچه‌های تک‌سلولی محصور در خشکی (§۸.۳: «هیچ آب در وسط جزیره نباید»)
## سلول آب که هر ۸ همسایه‌اش خشکی/قابل‌عبور است → چمن low (g1، ارتفاع همسایه‌ها).
## قطعی و بدون بازگشت — چند گذر تا جای‌به‌جایی ثابت (حلقه‌های ۲-تایی را هم می‌خورد).
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
        for _pass in 8:
                var changed := false
                for cy in _size:
                        for cx in _size:
                                var i := cy * _size + cx
                                if walkable[i] == 1:
                                        continue  # خشکی است
                                var surrounded := true
                                for d in 8:
                                        var nx: int = cx + DIR8_X[d]
                                        var ny: int = cy + DIR8_Y[d]
                                        if nx < 0 or ny < 0 or nx >= _size or ny >= _size:
                                                surrounded = false
                                                break
                                        var ni := ny * _size + nx
                                        if walkable[ni] == 0:
                                                surrounded = false
                                                break
                                if not surrounded:
                                        continue
                                modules[i] = grass_module
                                walkable[i] = 1
                                tops[i] = _mods[grass_module]["top"]
                                changed = true
                if not changed:
                        break
