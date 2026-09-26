class_name CommandGrid
extends Node3D
## شبکه‌ی فرمان «سرزمین مادری» — گام ۶R5 (بازخورد کاربر):
##
##   «باید همه چیزها چه واحد سربازها و چه خانه‌ها و هر چیزی هست فقط یک سهم از
##    بلوک مستطیلی بگیره ... بلوک‌ها به اشکالی شبیه مستطیل ولی با زاویه‌های نرم
##    باشند به طوری که کل فضایی که قابلیت رفتن توسط سربازها را داره پوشش بده ...
##    بین بلوک‌ها فاصله‌های خیلی کم باشد ولی برای کاربر قابل دیدن باشد ...
##    حالت هاله‌ی نور دقیقاً از اضلاع این اشکال بیرون بزند نه از وسطش»
##
## طراحی تازه:
##   * «تایل» = مربع ۲×۲ متری (COMMAND_CELL) با گوشه‌های نرم (شعاع COMMAND_TILE_CORNER)
##   * تایل‌ها کل سطحِ قابل‌رفتن جزیره را می‌پوشانند (سلول فرمان با ≥۳ از ۴ سلول
##     NavGrid روی خشکی) + تایلِ زیر هر خانه همیشه هست (خانه = یک بلوک کامل)
##   * شکاف باریکِ بین تایل‌ها (۲×COMMAND_TILE_INSET ≈ ۰٫۱۶ متر) — کم ولی دیدنی
##   * هاله‌ی نور فقط از «اضلاع» می‌تابد: SDF جعبه‌ی گرد + باندِ گاوسیِ لبه‌ای —
##     وسط تایل کاملاً تاریک می‌ماند (هیچ پرشدگی مرکزی)
##   * «دیوار نور»: دامنه‌ی نورانیِ کوتاه که از هر ضلع به بالا می‌رود و محو می‌شود
##   * همیشه نمایان است (سربازِ آیدل و خانه همیشه داخل بلوک دیده می‌شوند)؛
##     حالت فرمان فقط روشن‌ترش می‌کند + بلوکِ زیر ماوس پرنورتر و بلندتر
##   * تایل‌ها با شیب زمین هم‌راستا می‌شوند (تیلت) تا در شیب‌ها فرو نروند
##   * ثبتِ اشغال تایل: هر سربازِ ایستاده دقیقاً یک تایلِ آزادِ خودش را می‌گیرد
##     (claim_unique_tile) — تایلِ خانه‌ها از قبل اشغال است و به سرباز نمی‌رسد

const GROUND_INSET := GameConstants.COMMAND_TILE_INSET    # نصفِ شکاف بین تایل‌ها
const CORNER_R := GameConstants.COMMAND_TILE_CORNER       # نرمی گوشه‌ها (m)
const SKIRT_H := GameConstants.COMMAND_TILE_SKIRT_H       # بلندی دیوار نور (m)
const HOVER_SKIRT_H := SKIRT_H * 1.7
const OWNER_OCCUPIED := -1        # تایلِ خانه‌ها — هرگز به سرباز نمی‌رسد

var size := 0
var cell_count := 0

var _ground: IslandGround
var _nav: NavGrid
var _origin := Vector2.ZERO
var _cells: Array[Dictionary] = []       # {cc, center, top}
var _by_cc: Dictionary = {}
var _claims: Dictionary = {}             # cc → owner_id (تایل‌های اشغال‌شده)
var _command := false

var _mmi: MultiMeshInstance3D             # هاله‌ی لبه‌ای روی زمین
var _skirts: MultiMeshInstance3D          # دیوار نور اضلاع
var _hover: MeshInstance3D
var _hover_skirt: MeshInstance3D
var _ground_mat: ShaderMaterial
var _skirt_mat: ShaderMaterial
var _hover_mat: ShaderMaterial
var _hover_skirt_mat: ShaderMaterial
var _hover_index := -1


func rebuild(ground: IslandGround, nav: NavGrid, occupied_sites: Array[Vector2i] = []) -> void:
        for c in get_children():
                c.free()
        _ground = ground
        _nav = nav
        size = ground.size
        _origin = nav.origin
        _cells.clear()
        _by_cc.clear()
        _claims.clear()
        _hover_index = -1
        _command = false

        var half := int(GameConstants.COMMAND_CELL * 0.5)
        for cy in range(0, size - 1, half * 2):
                for cx in range(0, size - 1, half * 2):
                        var cc := Vector2i(cx, cy)
                        var walk := 0
                        for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
                                if nav.is_walkable(cc + d):
                                        walk += 1
                        if walk < 3:
                                continue  # تایل باید تقریباً کامل روی خشکی باشد
                        _add_cell(cc, half)
        # تایلِ زیر هر خانه همیشه هست — «خانه در یک واحد بلوک قرار می‌گیرد»
        for site in occupied_sites:
                if not _by_cc.has(site):
                        _add_cell(site, half)
                _claims[site] = OWNER_OCCUPIED
        cell_count = _cells.size()
        _build_visuals()


func _add_cell(cc: Vector2i, half: int) -> void:
        var center := _origin + (Vector2(cc) + Vector2(half, half)) * _nav.cell_size
        _by_cc[cc] = _cells.size()
        _cells.append({"cc": cc, "center": center, "top": _avg_top(cc, half)})


func _avg_top(cc: Vector2i, half: int) -> float:
        var acc := 0.0
        for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
                acc += _ground.top_at(cc + d)
        return acc / 4.0


# ---------------- شیدرها ----------------

## هاله‌ی لبه‌ای — SDF جعبه‌ی گرد؛ نور فقط باندِ باریکِ دورِ ضلع‌ها:
## بیرونِ ضلع (تا داخل شکاف) پهن‌تر و نرم‌تر، داخلِ ضلع تندتر محو —
## «هاله دقیقاً از اضلاع بیرون می‌زند، نه از وسط»
func _edge_glow_shader() -> Shader:
        # گام ۶R۱۴ — پدِ بیضیِ «روشن‌تر از چمن» مثل مرجع: لکه‌ی نرمِ پاستلیِ
        # سبزِ روشن (قبلاً لکه‌ی تیره بود و حسِ لکه‌ی کثیف می‌داد)
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never;
uniform float intensity = 0.8;
uniform float rx = 0.80;
uniform float ry = 0.68;
uniform float soft = 0.22;
void fragment() {
        vec2 p = UV - vec2(0.5);
        float d = length(vec2(p.x / rx, p.y / ry));
        float a = (1.0 - smoothstep(1.0 - soft, 1.0, d)) * intensity * 0.55;
        ALBEDO = vec3(0.718, 0.788, 0.557);
        ALPHA = a;
}
"""
        return sh


# ---------------- ساخت بصری‌ها ----------------

func _build_visuals() -> void:
        # سطح زمین: کواترِ کاملِ سلول — گردی و شکاف داخل شیدر با SDF ساخته می‌شود
        var pm := PlaneMesh.new()
        pm.size = Vector2(GameConstants.COMMAND_CELL, GameConstants.COMMAND_CELL)
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = pm
        mm.instance_count = maxi(_cells.size(), 1)
        for i in _cells.size():
                mm.set_instance_transform(i, _cell_transform(_cells[i]["center"], 0.07))
        _mmi = MultiMeshInstance3D.new()
        _mmi.multimesh = mm
        _ground_mat = ShaderMaterial.new()
        _ground_mat.shader = _edge_glow_shader()
        _apply_command_params()
        _mmi.material_override = _ground_mat
        # گام ۶R۱۴ — پدها «مخفی تا کلیک روی دسته» (بازخورد کاربر):
        # جزیره‌ی آرامِ بدون لکه؛ فقط در حالت فرمان ظاهر می‌شوند
        _mmi.visible = false
        add_child(_mmi)

        # گام ۶R11 — دیوارهای نورِ اضلاع حذف شدند (بازخورد: «تایل‌ها خوب
        # نیستند») — فقط پدِ بیضیِ روی زمین؛ هاور = پدِ پرنورتر
        _hover = MeshInstance3D.new()
        _hover.mesh = pm
        _hover_mat = ShaderMaterial.new()
        _hover_mat.shader = _edge_glow_shader()
        _hover_mat.set_shader_parameter("intensity", 1.05)
        _hover.material_override = _hover_mat
        _hover.visible = false
        add_child(_hover)


## ترنسفورم هم‌راستا با شیب زمین (تیلت) + lift بالای سطح
func _cell_transform(center: Vector2, lift: float) -> Transform3D:
        var h := GameConstants.COMMAND_CELL * 0.5 - 0.06
        var h00 := _ground.height_at_world(center + Vector2(-h, -h))
        var h10 := _ground.height_at_world(center + Vector2(h, -h))
        var h01 := _ground.height_at_world(center + Vector2(-h, h))
        var h11 := _ground.height_at_world(center + Vector2(h, h))
        var dx := Vector3(2.0 * h, h10 - h00, 0.0)
        var dz := Vector3(0.0, h11 - h01, 2.0 * h)
        var n := dx.cross(dz).normalized()
        if n.y < 0.0:
                n = -n
        var x_axis := Vector3(1, 0, 0) - n * n.x
        x_axis = x_axis.normalized() if x_axis.length() > 0.001 else Vector3(1, 0, 0)
        var z_axis := x_axis.cross(n).normalized()
        var basis := Basis(x_axis, n, z_axis)
        var mid_h := _ground.height_at_world(center)
        return Transform3D(basis, Vector3(center.x, mid_h + lift, center.y))


# ---------------- روشنایی حالت فرمان ----------------

func _apply_command_params() -> void:
        if _ground_mat != null:
                _ground_mat.set_shader_parameter("intensity", 0.85 if _command else 0.55)


## ورود/خروج حالت فرمان — گام ۶R۱۴: پدها فقط در حالت فرمان «نمایان» می‌شوند
func set_command_mode(on: bool) -> void:
        _command = on
        _apply_command_params()
        if _mmi != null:
                _mmi.visible = on
        if not on:
                _clear_hover()


func _clear_hover() -> void:
        _hover_index = -1
        if _hover != null:
                _hover.visible = false
        if _hover_skirt != null:
                _hover_skirt.visible = false


## هاور با نشانگر — بلوکِ زیر ماوس پرنورتر + دیوار نور بلندتر
func hover_at_world(xz: Vector2) -> Dictionary:
        var info := cell_at_world(xz)
        if not bool(info.get("ok", false)):
                _clear_hover()
                return info
        if int(info["index"]) != _hover_index:
                _hover_index = int(info["index"])
                var c: Dictionary = _cells[_hover_index]
                var t := _cell_transform(c["center"], 0.07)
                _hover.transform = t
                _hover.visible = true
                t.origin.y -= 0.02
                _hover_skirt.transform = t
                _hover_skirt.visible = true
        return info


## سلول فرمانِ زیر نقطه‌ی جهانی (بدون اثر جانبی)
func cell_at_world(xz: Vector2) -> Dictionary:
        if _ground == null or size == 0 or _nav == null:
                return {"ok": false}
        var step := int(GameConstants.COMMAND_CELL / _nav.cell_size)  # ۲ سلول NavGrid
        var local := (xz - _origin) / GameConstants.COMMAND_CELL
        var cc := Vector2i(floori(local.x) * step, floori(local.y) * step)
        if not _by_cc.has(cc):
                return {"ok": false, "cc": cc}
        var index := int(_by_cc[cc])
        var c: Dictionary = _cells[index]
        return {"ok": true, "index": index, "cc": cc,
                        "center": c["center"], "top": c["top"]}


func cell_info(index: int) -> Dictionary:
        if index < 0 or index >= _cells.size():
                return {}
        return _cells[index]


func is_command_mode() -> bool:
        return _command


## گام ۶R11 — برای تست خودکار: پدها همیشه نمایان‌اند (دیوار نور حذف شد)
func tiles_visible() -> bool:
        return _mmi != null and _mmi.visible


## گام ۶R11 — تعداد پدهای ساخته‌شده (== تعداد تایل‌ها؛ برای تست خودکار)
func beam_instance_count() -> int:
        if _mmi == null or _mmi.multimesh == null:
                return 0
        return int(_mmi.multimesh.instance_count)


# ---------------- ثبتِ اشغال تایل (هر سرباز = یک بلوک) ----------------

## نزدیک‌ترین تایلِ «آزاد» به نقطه — در شعاع max_r؛ مرکز تایل باید روی سلولِ
## قابل‌عبور باشد. تایلِ خانه‌ها (OWNER_OCCUPIED) و تایلِ سربازانِ دیگر رد می‌شود.
## خروجی: مرکز تایلِ تصاحب‌شده (یا همان نقطه، اگر تایلِ آزادی نبود)
## گام ۶R5 — شعاع ۲٫۶ متری: اسلاتِ حاشیه‌ی ساحل/صخره (بیرون از ناحیه‌ی تایل‌خورده)
## هم به نزدیک‌ترین بلوک کشیده می‌شود تا «هر سربازِ آیدل داخل بلوک» برقرار بماند
func claim_unique_tile(xz: Vector2, owner_id: int, max_r := 2.6) -> Vector2:
        release_owner(owner_id)
        if _nav == null or size == 0:
                return xz
        var step := int(GameConstants.COMMAND_CELL / _nav.cell_size)
        var local := (xz - _origin) / GameConstants.COMMAND_CELL
        var base := Vector2i(floori(local.x) * step, floori(local.y) * step)
        var best_cc := Vector2i(-9999, -9999)
        var best_d := max_r
        for dy in range(-step, step + 1, step):
                for dx in range(-step, step + 1, step):
                        var cc := base + Vector2i(dx, dy)
                        if not _by_cc.has(cc) or _claims.has(cc):
                                continue
                        var c: Dictionary = _cells[_by_cc[cc]]
                        var center: Vector2 = c["center"]
                        if not _nav.is_walkable(_nav.world_to_cell(center)):
                                continue
                        var d := center.distance_to(xz)
                        if d < best_d:
                                best_d = d
                                best_cc = cc
        if best_cc.x < -100:
                return xz
        _claims[best_cc] = owner_id
        return _cells[_by_cc[best_cc]]["center"]


## آزادسازی تایل‌های یک مالک (سرباز مرد / جابه‌جا شد)
func release_owner(owner_id: int) -> void:
        var dead: Array = []
        for cc in _claims:
                if int(_claims[cc]) == owner_id:
                        dead.append(cc)
        for cc in dead:
                _claims.erase(cc)


## آزادسازی همه به‌جز تایل‌های خانه‌ها (بازتولید جزیره)
func release_all_claims() -> void:
        var dead: Array = []
        for cc in _claims:
                if int(_claims[cc]) != OWNER_OCCUPIED:
                        dead.append(cc)
        for cc in dead:
                _claims.erase(cc)


## برای تست خودکار: تعداد تایل‌های اشغال‌شده توسط سربازان (بدون خانه‌ها)
func claim_count() -> int:
        var n := 0
        for cc in _claims:
                if int(_claims[cc]) != OWNER_OCCUPIED:
                        n += 1
        return n
