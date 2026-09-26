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
## مالکِ تایلِ «دسته» (گام ۶R6) — شناسه‌های منفیِ دور از instance_idها
const OWNER_SQUAD_BASE := -100000

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
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float intensity = 0.38;
uniform float pulse_speed = 1.3;
uniform float cell = 2.0;
uniform float inset = 0.08;
uniform float corner = 0.30;
uniform float sigma_in = 0.034;
uniform float sigma_out = 0.06;
void fragment() {
        vec2 p = (UV - vec2(0.5)) * cell;
        float b = cell * 0.5 - inset;
        vec2 q = abs(p) - vec2(b - corner);
        float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner;
        float sg = sd > 0.0 ? sigma_out : sigma_in;
        float g = exp(-(sd * sd) / (sg * sg));
        float pulse = 0.82 + 0.18 * sin(TIME * pulse_speed);
        ALBEDO = vec3(1.0, 0.84, 0.52);
        ALPHA = g * intensity * pulse;
}
"""
        return sh


## دیوار نور — دامنه‌ای که از ضلع‌های تایل بالا می‌رود؛ پایه پرنور، بالا محو
func _skirt_shader() -> Shader:
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float intensity = 0.30;
uniform float pulse_speed = 1.3;
uniform float skirt_h = 0.55;
varying float vy;
void vertex() {
        vy = VERTEX.y;
}
void fragment() {
        float h01 = clamp(vy / skirt_h, 0.0, 1.0);
        float fade = pow(1.0 - h01, 1.7);
        float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed);
        ALBEDO = vec3(1.0, 0.84, 0.52);
        ALPHA = fade * intensity * pulse;
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
        _mmi.visible = true
        add_child(_mmi)

        # دیوار نور اضلاع — حلقه‌ی جعبه‌ی گردِ عمودی
        var ring := _skirt_ring_mesh(SKIRT_H)
        var smm := MultiMesh.new()
        smm.transform_format = MultiMesh.TRANSFORM_3D
        smm.mesh = ring
        smm.instance_count = maxi(_cells.size(), 1)
        for i in _cells.size():
                smm.set_instance_transform(i, _cell_transform(_cells[i]["center"], 0.05))
        _skirts = MultiMeshInstance3D.new()
        _skirts.multimesh = smm
        _skirt_mat = ShaderMaterial.new()
        _skirt_mat.shader = _skirt_shader()
        _skirt_mat.set_shader_parameter("skirt_h", SKIRT_H)
        _skirts.material_override = _skirt_mat
        _skirts.visible = true
        add_child(_skirts)

        # بلوکِ هاور (فقط حالت فرمان) — پرنورتر و بلندتر
        _hover = MeshInstance3D.new()
        _hover.mesh = pm
        _hover_mat = ShaderMaterial.new()
        _hover_mat.shader = _edge_glow_shader()
        _hover_mat.set_shader_parameter("intensity", 1.05)
        _hover_mat.set_shader_parameter("pulse_speed", 5.0)
        _hover.material_override = _hover_mat
        _hover.visible = false
        add_child(_hover)

        _hover_skirt = MeshInstance3D.new()
        _hover_skirt.mesh = _skirt_ring_mesh(HOVER_SKIRT_H)
        _hover_skirt_mat = ShaderMaterial.new()
        _hover_skirt_mat.shader = _skirt_shader()
        _hover_skirt_mat.set_shader_parameter("intensity", 0.62)
        _hover_skirt_mat.set_shader_parameter("pulse_speed", 4.5)
        _hover_skirt_mat.set_shader_parameter("skirt_h", HOVER_SKIRT_H)
        _hover_skirt.material_override = _hover_skirt_mat
        _hover_skirt.visible = false
        add_child(_hover_skirt)


## حلقه‌ی عمودیِ جعبه‌ی گرد — دیوار نور: هر ضلع/گوشه یک نوار از زمین تا skirt_h
func _skirt_ring_mesh(h: float) -> ArrayMesh:
        var b := GameConstants.COMMAND_CELL * 0.5 - GROUND_INSET - 0.012
        var r := CORNER_R
        var pts: Array[Vector2] = []
        # مسیر پادساعتگرد: ۴ کمانِ گوشه (۹۰° هرکدام، ۷ قطعه) — ضلع‌های مستقیم
        # به‌صورت پاره‌خطِ بینِ پایانِ یک کمان و آغازِ کمانِ بعدی می‌آیند
        for si in 4:
                var a0 := float(si) * TAU * 0.25
                var mid := a0 + TAU * 0.125
                var ccenter := Vector2(signf(cos(mid)), signf(sin(mid))) * (b - r)
                for k in 7:
                        var ang := a0 + TAU * 0.25 * (float(k) / 6.0)
                        pts.append(ccenter + Vector2(cos(ang), sin(ang)) * r)
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for i in pts.size():
                var p1 := pts[i]
                var p2 := pts[(i + 1) % pts.size()]
                # نرمالِ بیرونی در جعبه‌ی گرد = شعاعی از مرکز (هم در ضلع، هم در کمان)
                var n1 := Vector3(p1.x, 0.0, p1.y).normalized()
                var n2 := Vector3(p2.x, 0.0, p2.y).normalized()
                var q1 := Vector3(p1.x, 0.0, p1.y)
                var q2 := Vector3(p2.x, 0.0, p2.y)
                st.set_normal(n1)
                st.add_vertex(q1)
                st.set_normal(n2)
                st.add_vertex(q2)
                st.set_normal(n2)
                st.add_vertex(Vector3(q2.x, h, q2.z))
                st.set_normal(n1)
                st.add_vertex(q1)
                st.set_normal(n2)
                st.add_vertex(Vector3(q2.x, h, q2.z))
                st.set_normal(n1)
                st.add_vertex(Vector3(q1.x, h, q1.z))
        return st.commit()


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
                _ground_mat.set_shader_parameter("intensity", 0.62 if _command else 0.36)
                _ground_mat.set_shader_parameter("pulse_speed", 2.2 if _command else 1.3)
        if _skirt_mat != null:
                _skirt_mat.set_shader_parameter("intensity", 0.44 if _command else 0.28)
                _skirt_mat.set_shader_parameter("pulse_speed", 2.2 if _command else 1.3)


## ورود/خروج حالت فرمان — تایل‌ها همیشه نمایان‌اند؛ اینجا فقط پرنورتر می‌شوند
func set_command_mode(on: bool) -> void:
        _command = on
        _apply_command_params()
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


## گام ۶R5 — برای تست خودکار: تایل‌ها همیشه نمایان‌اند
func tiles_visible() -> bool:
        return _mmi != null and _mmi.visible and _skirts != null and _skirts.visible


## گام ۶R4/۶R5 — سازگاری تست: تعداد دیوارهای نور ساخته‌شده (== تعداد تایل‌ها)
func beam_instance_count() -> int:
        if _skirts == null or _skirts.multimesh == null:
                return 0
        return int(_skirts.multimesh.instance_count)


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
        var best_cc := _find_free_tile(xz, max_r)
        if best_cc.x < -100:
                return xz
        _claims[best_cc] = owner_id
        return _cells[_by_cc[best_cc]]["center"]


## گام ۶R6 — باگ ۴: «سربازهای یک دسته باید مثل Bad North در یک بلوک متراکم
## جمع شوند؛ اشکالی ندارد کاملاً فشرده باشند». کل دسته روی «یک تایل» می‌نشیند:
## خروجی = count موقعیتِ فشرده (شبکه‌ی چلیک بدون خلأ) داخل همان تایل.
## تایلِ دسته با مالکِ ویژه (OWNER_SQUAD_BASE + squad_key) ثبت می‌شود تا
## با تایل‌های تک‌سربازه (claim_unique_tile — خروج گاریسون) تداخل نکند.
func claim_squad_block(xz: Vector2, squad_key: int, count: int,
                max_r := 3.4) -> Array[Vector2]:
        var owner_id := OWNER_SQUAD_BASE + squad_key
        release_owner(owner_id)
        var out: Array[Vector2] = []
        var tile_center := xz
        if _nav != null and size > 0:
                var best_cc := _find_free_tile(xz, max_r)
                if best_cc.x > -100:
                        _claims[best_cc] = owner_id
                        tile_center = _cells[_by_cc[best_cc]]["center"]
        _append_dense(out, tile_center, count)
        return out


## جست‌وجوی تایلِ آزادِ نزدیک (مشترکِ claim_unique_tile و claim_squad_block)
func _find_free_tile(xz: Vector2, max_r: float) -> Vector2i:
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
        return best_cc


## شبکه‌ی چلیکِ فشرده دور مرکز — بدون خلأ؛ فاصله ۰٫۵m (تا ۴ نفر) و ۰٫۳۶m
## بعدش، تا همه داخل شعاع ۰٫۵۵ متریِ مرکز تایل بمانند (چک «سرباز داخل بلوک»)
func _append_dense(out: Array[Vector2], center: Vector2, count: int) -> void:
        if count <= 0:
                return
        var cols := mini(int(ceil(sqrt(float(count)))), 3)
        var spacing := 0.5 if cols <= 2 else 0.36
        var rows := int(ceil(float(count) / float(cols)))
        var x0 := -spacing * float(cols - 1) * 0.5
        var y0 := -spacing * float(rows - 1) * 0.5
        var nav := _nav
        for i in count:
                var r := floori(float(i) / float(cols))
                var c := i - r * cols
                var p := center + Vector2(x0 + float(c) * spacing,
                                y0 + float(r) * spacing)
                # گارد سلولِ بسته: به مرکز تایل کشیده می‌شود (تایلِ مرکزش باز است)
                if nav != null and not nav.is_walkable(nav.world_to_cell(p)):
                        p = center + (p - center) * 0.5
                        if not nav.is_walkable(nav.world_to_cell(p)):
                                p = center
                out.append(p)


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
