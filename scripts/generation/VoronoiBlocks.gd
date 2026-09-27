class_name VoronoiBlocks
extends Node3D
## پدهای مستطیلیِ فرمان — گام ۶R۱۵ (بازخورد کاربر از اسکرین‌شات‌های مرجع):
##
##   * «پدها تقریباً دیفالت مستطیلی باشند با لبه‌های کمی نرم»
##   * «پدها کل زمینه را تقریباً پوشش بدهند؛ از مستطیل‌های با ابعاد مختلف
##     استفاده کن تا کامل زمین جزیره پوشش داده شود» → چیدمانِ حریصانه‌ی
##     مستطیل‌های ۱×۱ تا ۳×۳ سلولیِ (۲ تا ۶ متر) روی شبکه‌ی فرمان ۲ متری
##   * «تا قبل از انتخاب رنگ عادی داشته باشند» → سبزِ خنثیِ مرجع، همیشه نمایان
##   * «با انتخاب دسته، پدها گرادیانِ همان رنگِ دسته بگیرند» → گرادیانِ
##     از بالای صفحه (روشن) به پایین (تیره) — دقیقاً مثل Bad North
##   * «با انتخاب، از اضلاعشان هاله‌ی نورانی بیرون بیاید» → باندِ گاوسیِ
##     اطرافِ لبه‌ی هر مستطیل (SDF جعبه‌ی گرد) که بیرون می‌تابد
##   * مسیرِ باریکِ دوبلکس پد نمی‌گیرد (سطحِ شیب، سلولِ فرمان نیست)
##
## API عمداً سازگار با نسخه‌های قبلی نگه داشته شد (صحنه/تست‌ها/probe).

const LIFT := 0.05                        # بلندی پد روی زمین (ضد z-fight)
const OWNER_OCCUPIED := -1                # پدِ خانه‌ها — هرگز به سرباز نمی‌رسد
const PICK_TOLERANCE := 0.45              # تلورانس پیکینگ بر حسب متر (SDF)
const GLOW_MARGIN := 0.5                  # حاشیه‌ی مش برای تابشِ هاله (m)
const CORNER_R := 0.26                    # شعاع نرمی گوشه‌ها (m)

var cell_count := 0                       # تعداد پدها (سازگاری نام قدیمی)

var _ground: IslandGround
var _nav: NavGrid
var _origin := Vector2.ZERO

## هر پد: {center, spot, top, hw, hh, aabb}
var _blocks: Array[Dictionary] = []
var _claims: Dictionary = {}              # index → owner_id
var _sit_of: Dictionary = {}              # owner_id → نقطه‌ی نشستِ واقعی
var _command := false
var _hover_index := -1

var _mmi: MultiMeshInstance3D             # پدها (یک draw call)
var _hover_mesh: MeshInstance3D
var _pad_mat: ShaderMaterial
var _hover_mat: ShaderMaterial

var _seed_value := 20260924


# ================= ساخت =================

func rebuild(ground: IslandGround, nav: NavGrid, house_sites: Array[Vector2i]) -> void:
        for c in get_children():
                c.free()
        _ground = ground
        _nav = nav
        _origin = nav.origin
        _blocks.clear()
        _claims.clear()
        _sit_of.clear()
        _hover_index = -1
        _command = false

        var rng := RandomNumberGenerator.new()
        rng.seed = _seed_value
        var step := int(GameConstants.COMMAND_CELL / nav.cell_size)   # ۲ سلول nav

        # ---- ۱) ماسکِ سلول‌های فرمانِ مجاز: تقریباً کامل روی خشکی، هم‌سطح،
        #         نه روی مسیرِ شیبِ دوبلکس ----
        var present := {}
        var max_c := int(ceil(float(ground.size) / float(step)))
        for gy in max_c:
                for gx in max_c:
                        var cc := Vector2i(gx * step, gy * step)
                        var walk := 0
                        var lvl_ok := true
                        for d: Vector2i in [Vector2i(0, 0), Vector2i(step - 1, 0),
                                        Vector2i(0, step - 1), Vector2i(step - 1, step - 1)]:
                                var c2 := cc + d
                                if nav.is_walkable(c2):
                                        walk += 1
                                if ground.is_path_cell(c2):
                                        lvl_ok = false
                        var mid := ground.level_at(cc + Vector2i(step - 1, step - 1))
                        for d: Vector2i in [Vector2i(0, 0), Vector2i(step - 1, 0),
                                        Vector2i(0, step - 1)]:
                                if ground.level_at(cc + d) != mid:
                                        lvl_ok = false
                        if walk >= 3 and lvl_ok and mid != 2:
                                present[cc] = true

        # ---- ۲) چیدمانِ حریصانه‌ی مستطیل‌ها با ابعادِ متنوع ----
        var used := {}
        for gy in max_c:
                for gx in max_c:
                        var cc0 := Vector2i(gx * step, gy * step)
                        if not present.has(cc0) or used.has(cc0):
                                continue
                        # ابعادِ هدفِ تصادفی — «مستطیل‌های با ابعاد مختلف»
                        var mw := _rand_dim(rng)
                        var mh := _rand_dim(rng)
                        var w := 0
                        var h := 0
                        # گسترشِ عرضی
                        while w < mw:
                                var cx2 := cc0 + Vector2i(w * step, 0)
                                if not present.has(cx2) or used.has(cx2):
                                        break
                                w += 1
                        if w == 0:
                                continue
                        # گسترشِ طولی — کلِ ردیف باید آزاد باشد
                        while h < mh:
                                var row_ok := true
                                for k in w:
                                        var cell := cc0 + Vector2i(k * step, h * step)
                                        if not present.has(cell) or used.has(cell):
                                                row_ok = false
                                                break
                                if not row_ok:
                                        break
                                h += 1
                        for yy in h:
                                for xx in w:
                                        used[cc0 + Vector2i(xx * step, yy * step)] = true
                        _add_rect(cc0, w, h, step, rng)

        # ---- ۳) پدِ خانه‌ها: مستطیلِ اختصاصی — «خانه دقیقاً یک بلوک» ----
        var house_centers: Array[Vector2] = []
        for site in house_sites:
                var hc := nav.origin + (Vector2(site) + Vector2(1.0, 1.0)) * nav.cell_size
                house_centers.append(hc)
                _add_pad(hc, 0.94, 0.94)

        cell_count = _blocks.size()

        # خانه‌ها: پدِ خودشان → اشغال دائمی
        for hc in house_centers:
                var bi := _index_at(hc)
                if bi >= 0:
                        _claims[bi] = OWNER_OCCUPIED

        _build_visuals()


## انتخابِ تصادفیِ بعدِ هدف (۱-۳ سلول) — توزیعِ متنوع ولی قطعی
func _rand_dim(rng: RandomNumberGenerator) -> int:
        var r := rng.randf()
        if r < 0.30:
                return 1
        if r < 0.78:
                return 2
        return 3


func set_island_seed(seed_value: int) -> void:
        _seed_value = seed_value


## ساخت پد از بلوکِ (w×h) سلولِ فرمان که از cc شروع می‌شود
func _add_rect(cc: Vector2i, w: int, h: int, step: int, rng: RandomNumberGenerator) -> void:
        var half_cells := Vector2(w, h) * (float(step) * 0.5)
        var center := _origin + (Vector2(cc) + half_cells) * _nav.cell_size
        var inset := GameConstants.COMMAND_TILE_INSET
        var hw := half_cells.x * _nav.cell_size - inset
        var hh := half_cells.y * _nav.cell_size - inset
        # اگر مرکزِ پد دقیقاً روی خشکی نیست، نزدیک‌ترین نقطه‌ی مجاز
        var spot := _nearest_walkable(_nav, center, 1.4)
        if spot == Vector2.INF:
                spot = center
        _push_pad(center, spot, hw, hh)


func _add_pad(center: Vector2, hw: float, hh: float) -> void:
        var spot := _nearest_walkable(_nav, center, 1.1)
        if spot == Vector2.INF:
                spot = center
        _push_pad(center, spot, hw, hh)


func _push_pad(center: Vector2, spot: Vector2, hw: float, hh: float) -> void:
        _blocks.append({
                "center": center, "spot": spot,
                "top": _ground.height_at_world(center),
                "hw": hw, "hh": hh,
                "aabb": Rect2(center - Vector2(hw, hh),
                                Vector2(hw, hh) * 2.0).grow(GLOW_MARGIN + 0.4),
        })


func _nearest_walkable(nav: NavGrid, from: Vector2, max_r: float) -> Vector2:
        var cells := int(ceil(max_r / nav.cell_size))
        var base := nav.world_to_cell(from)
        var best := Vector2.INF
        var best_d := max_r
        for dy in range(-cells, cells + 1):
                for dx in range(-cells, cells + 1):
                        var c := base + Vector2i(dx, dy)
                        if not nav.is_walkable(c):
                                continue
                        var cc := nav.cell_center(c)
                        var d := cc.distance_to(from)
                        if d <= best_d:
                                best_d = d
                                best = cc
        return best


# ================= متریک مستطیل (SDF جعبه‌ی گرد) =================

## فاصله‌ی علامت‌دار از پد (متر؛ منفی = داخل)
func _rect_sdf(i: int, xz: Vector2) -> float:
        var b := _blocks[i]
        var d := (xz - (b["center"] as Vector2)).abs()
        var q := d - Vector2(float(b["hw"]), float(b["hh"]))
        return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() \
                        + minf(maxf(q.x, q.y), 0.0)


## پدِ زیر نقطه (داخلِ دقیق) — برای مالکیت
func _index_at(xz: Vector2) -> int:
        for i in _blocks.size():
                if not (_blocks[i]["aabb"] as Rect2).has_point(xz):
                        continue
                if _rect_sdf(i, xz) <= 0.0:
                        return i
        return -1


## نزدیک‌ترین پد با تلورانس متر (کلیکِ حاشیه هم می‌گیرد)
func _nearest_index(xz: Vector2, tol_m: float) -> int:
        var best := -1
        var best_d := tol_m
        for i in _blocks.size():
                if not (_blocks[i]["aabb"] as Rect2).grow(0.6).has_point(xz):
                        continue
                var d := _rect_sdf(i, xz)
                if d < best_d:
                        best_d = d
                        best = i
        return best


# ================= بصری‌ها =================

func _pad_shader() -> Shader:
        # گام ۶R۱۵ — پدِ مستطیلیِ لبه‌نرم + گرادیانِ انتخاب + هاله‌ی اضلاع:
        #   * fill = SDF جعبه‌ی گرد با لبه‌ی نرم (۰٫۱m)
        #   * گرادیان: SCREEN_UV.y — بالای کادر روشن → پایینِ کادر تیره
        #   * هاله: باندِ گاوسی چسبیده به لبه که «بیرون» می‌تابد + درخششِ
        #     داخلیِ ملایم — وسطِ پدِ غیرِ انتخابی هیچ نور اضافه‌ای ندارد
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;
uniform float intensity = 0.62;
uniform float highlight = 0.0;      // ۱ = دسته‌ای انتخاب شده است
uniform vec3 highlight_col : source_color = vec3(0.24, 0.86, 0.94);
uniform float hover_boost = 0.0;    // فقط متریالِ هاور
// INSTANCE_CUSTOM فقط در vertex() در دسترس است — به fragment واریینگ می‌شود
varying vec2 v_size_m;
void vertex() {
        v_size_m = INSTANCE_CUSTOM.xy;
}
void fragment() {
        vec2 size_m = v_size_m;
        vec2 plane_m = size_m + vec2(0.5);
        vec2 p = (UV - vec2(0.5)) * plane_m;
        float r = 0.26;
        vec2 half_m = size_m * 0.5;
        vec2 q = abs(p) - (half_m - vec2(r));
        float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
        float fill = 1.0 - smoothstep(-0.10, 0.02, sd);
        vec3 base = COLOR.rgb;
        float gy = 1.0 - SCREEN_UV.y;
        // گام ۶R۱۵b — گرادیانِ «شست‌وشو» نه «پوششِ کامل»: سبزِ پد زیر رنگ
        // دسته دیده می‌شود و سفیدِ سوخته نمی‌زند (بازخورد تصویری شات۲)
        vec3 grad = highlight_col * mix(0.35, 0.90, gy);
        vec3 col = mix(base, grad, highlight * 0.72);
        float band = exp(-pow(max(sd, 0.0) / 0.10, 2.0));
        float halo = band * highlight;
        float inner = exp(-pow(max(-sd, 0.0) / 0.38, 2.0)) * highlight * 0.20;
        col += highlight_col * (halo * 0.75 + inner);
        col += vec3(1.0) * hover_boost * fill * 0.25;
        float a = fill * intensity + halo * 0.65;
        ALBEDO = col;
        ALPHA = clamp(a, 0.0, 1.0);
}
"""
        return sh


func _build_visuals() -> void:
        var pm := PlaneMesh.new()
        pm.size = Vector2(1.0, 1.0)
        pm.subdivide_width = 0
        pm.subdivide_depth = 0
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.use_colors = true
        mm.use_custom_data = true
        mm.mesh = pm
        mm.instance_count = maxi(_blocks.size(), 1)
        var rng := RandomNumberGenerator.new()
        rng.seed = _seed_value + 77
        for i in _blocks.size():
                mm.set_instance_transform(i, _pad_transform(_blocks[i]))
                var base := GameConstants.COL_PAD_LIGHT.lerp(
                                GameConstants.COL_PAD_DARK, rng.randf() * 0.8)
                mm.set_instance_color(i, base)
                var b := _blocks[i]
                mm.set_instance_custom_data(i, Color(
                                float(b["hw"]) * 2.0, float(b["hh"]) * 2.0, 0.0, 0.0))
        _mmi = MultiMeshInstance3D.new()
        _mmi.multimesh = mm
        _pad_mat = ShaderMaterial.new()
        _pad_mat.shader = _pad_shader()
        _pad_mat.set_shader_parameter("intensity", 0.62)
        _pad_mat.set_shader_parameter("highlight", 0.0)
        _mmi.material_override = _pad_mat
        # گام ۶R۱۵ — پدها «بخشی از زمین»‌اند: همیشه نمایان (مثل مرجع)
        _mmi.visible = true
        add_child(_mmi)

        # هاور — همان مستطیل پرنورتر روی پدِ زیر ماوس
        _hover_mesh = MeshInstance3D.new()
        _hover_mesh.mesh = pm
        _hover_mat = ShaderMaterial.new()
        _hover_mat.shader = _pad_shader()
        _hover_mat.set_shader_parameter("intensity", 1.0)
        _hover_mat.set_shader_parameter("hover_boost", 1.0)
        _hover_mesh.material_override = _hover_mat
        _hover_mesh.visible = false
        add_child(_hover_mesh)


## ترنسفورم هم‌راستا با شیب زمین (تیلت) + lift — مقیاس = پد + حاشیه‌ی هاله
func _pad_transform(b: Dictionary) -> Transform3D:
        var center: Vector2 = b["center"]
        var hw: float = float(b["hw"])
        var hh: float = float(b["hh"])
        var h00 := _ground.height_at_world(center + Vector2(-hw, -hh))
        var h10 := _ground.height_at_world(center + Vector2(hw, -hh))
        var h01 := _ground.height_at_world(center + Vector2(-hw, hh))
        var h11 := _ground.height_at_world(center + Vector2(hw, hh))
        var dx := Vector3(2.0 * hw, h10 - h00, 0.0)
        var dz := Vector3(0.0, h11 - h01, 2.0 * hh)
        var n := dx.cross(dz).normalized()
        if n.y < 0.0:
                n = -n
        var x_axis := Vector3(1, 0, 0) - n * n.x
        x_axis = x_axis.normalized() if x_axis.length() > 0.001 else Vector3(1, 0, 0)
        var z_axis := x_axis.cross(n).normalized()
        var basis := Basis(x_axis, n, z_axis)
        var mid_h := _ground.height_at_world(center)
        return Transform3D(basis,
                        Vector3(center.x, mid_h + LIFT, center.y)) \
                        .scaled_local(Vector3(hw * 2.0 + GLOW_MARGIN, 1.0,
                                        hh * 2.0 + GLOW_MARGIN))


# ================= انتخاب و حالت فرمان =================

func set_command_mode(on: bool) -> void:
        _command = on
        if _pad_mat != null:
                # گام ۶R۱۶ — جزیره‌ی کوچک‌تر = تایل‌های بزرگ‌تر در کادر؛
                # شدتِ ۰٫۸ کلِ جزیره را «سوخته‌ی زرد» می‌کرد → ۰٫۷۰
                _pad_mat.set_shader_parameter("intensity", 0.70 if on else 0.62)
        if not on:
                _clear_hover()


func is_command_mode() -> bool:
        return _command


## گام ۶R۱۵ — رنگِ دسته‌ی انتخابی: گرادیان + هاله‌ی اضلاع روی «همه‌ی» پدها
func set_selection(col: Color, on: bool) -> void:
        if _pad_mat != null:
                _pad_mat.set_shader_parameter("highlight", 1.0 if on else 0.0)
                _pad_mat.set_shader_parameter("highlight_col", col)
        if _hover_mat != null:
                _hover_mat.set_shader_parameter("highlight", 1.0 if on else 0.0)
                _hover_mat.set_shader_parameter("highlight_col", col)


func is_selection_highlight() -> bool:
        if _pad_mat == null:
                return false
        return float(_pad_mat.get_shader_parameter("highlight")) > 0.5


func _clear_hover() -> void:
        _hover_index = -1
        if _hover_mesh != null:
                _hover_mesh.visible = false


func hover_at_world(xz: Vector2) -> Dictionary:
        var info := block_at_world(xz)
        if not bool(info.get("ok", false)):
                _clear_hover()
                return info
        var idx := int(info["index"])
        if idx != _hover_index:
                _hover_index = idx
                _hover_mesh.transform = _pad_transform(_blocks[idx])
                _hover_mesh.visible = true
        return info


# ================= پرس‌وجو (سازگار با API قبلی) =================

## پدِ زیر نقطه‌ی جهانی — با تلورانسِ لبه (کلیکِ حاشیه‌ی پد هم ثبت می‌شود)
func block_at_world(xz: Vector2) -> Dictionary:
        if _ground == null or cell_count == 0 or _nav == null:
                return {"ok": false}
        var i := _nearest_index(xz, PICK_TOLERANCE)
        if i < 0:
                return {"ok": false}
        var b := _blocks[i]
        return {"ok": true, "index": i, "center": b["spot"], "top": b["top"]}


func cell_at_world(xz: Vector2) -> Dictionary:
        return block_at_world(xz)


func cell_info(index: int) -> Dictionary:
        if index < 0 or index >= _blocks.size():
                return {}
        var b := _blocks[index]
        return {"cc": Vector2i(index, 0), "center": b["spot"], "top": b["top"]}


func tiles_visible() -> bool:
        return _mmi != null and _mmi.visible


func beam_instance_count() -> int:
        if _mmi == null or _mmi.multimesh == null:
                return 0
        return int(_mmi.multimesh.instance_count)


# ================= ثبتِ اشغال پد (هر سرباز = یک بلوک) =================

## نزدیک‌ترین پدِ «آزاد» به نقطه — خروجی: نقطه‌ی نشستِ پدِ تصاحب‌شده
func claim_unique_block(xz: Vector2, owner_id: int, max_r := 2.2,
                from_xz := Vector2.INF) -> Vector2:
        release_owner(owner_id)
        if _nav == null or cell_count == 0:
                return xz
        var best := -1
        var best_d := max_r
        var best_clear := -1
        var best_clear_d := max_r
        for i in _blocks.size():
                if _claims.has(i):
                        continue
                var spot: Vector2 = _blocks[i]["spot"]
                if not _nav.is_walkable(_nav.world_to_cell(spot)):
                        continue
                var d := spot.distance_to(xz)
                if d >= best_d and d >= best_clear_d:
                        continue
                var clear := from_xz != Vector2.INF and _straight_clear(from_xz, spot)
                if clear:
                        if d < best_clear_d:
                                best_clear_d = d
                                best_clear = i
                if d < best_d:
                        best_d = d
                        best = i
        var pick := best_clear if best_clear >= 0 else best
        # پاس دوم با شعاع دوبرابر: کنارِ خانه‌ها پدِ آزادِ نزدیک کم است
        if pick < 0 and max_r < 5.0:
                return claim_unique_block(xz, owner_id, max_r * 2.0, from_xz)
        if pick < 0:
                return xz
        _claims[pick] = owner_id
        # گام ۶R۱۵ — نقطه‌ی نشست داخلِ مستطیل‌های بزرگ: روی پدِ ۳×۳ (۶ متر)
        # مرکزِ پد تا ۲٫۵m از درخواست دور است؛ نقطه‌ی درخواست را داخلِ مستطیل
        # گیر می‌اندازیم تا آرایشِ آیدل متراکم بماند (چکِ idle_squads_packed)
        var b := _blocks[pick]
        var c2: Vector2 = b["center"]
        var hw2: float = maxf(float(b["hw"]) - 0.30, 0.2)
        var hh2: float = maxf(float(b["hh"]) - 0.30, 0.2)
        var clamped := Vector2(clampf(xz.x, c2.x - hw2, c2.x + hw2),
                        clampf(xz.y, c2.y - hh2, c2.y + hh2))
        var sit := _nearest_walkable(_nav, clamped, 1.6)
        if sit == Vector2.INF:
                sit = b["spot"]
        _sit_of[owner_id] = sit
        return sit


## پدِ claimedِ یک مالک — نقطه‌ی نشستِ واقعی (برای تست «سرباز داخل بلوکِ خودش»)
func spot_of_owner(owner_id: int) -> Vector2:
        if _sit_of.has(owner_id):
                return _sit_of[owner_id]
        for i in _claims:
                if int(_claims[i]) == owner_id:
                        return _blocks[i]["spot"]
        return Vector2.INF


## پاره‌خطِ مستقیمِ بدون سلولِ بلاک (نمونه‌برداری ۰٫۳۵m — قرارداد گاریسون)
func _straight_clear(a: Vector2, b: Vector2) -> bool:
        var dist := a.distance_to(b)
        if dist < 0.3:
                return true
        var steps := maxi(int(dist / 0.35), 2)
        for i in range(1, steps + 1):
                var k := float(i) / float(steps)
                var p := a.lerp(b, k)
                if not _nav.is_walkable(_nav.world_to_cell(p)):
                        return false
        return true


## سازگاری با فراخوانی قدیمی صحنه
func claim_unique_tile(xz: Vector2, owner_id: int, max_r := 2.2,
                from_xz := Vector2.INF) -> Vector2:
        return claim_unique_block(xz, owner_id, max_r, from_xz)


func owner_of(index: int) -> int:
        return int(_claims.get(index, -2))


func owner_at_world(xz: Vector2) -> int:
        var i := _index_at(xz)
        return int(_claims.get(i, -2)) if i >= 0 else -2


func release_owner(owner_id: int) -> void:
        var dead: Array = []
        for i in _claims:
                if int(_claims[i]) == owner_id:
                        dead.append(i)
        for i in dead:
                _claims.erase(i)
        _sit_of.erase(owner_id)


## آزادسازی همه به‌جز پدهای خانه‌ها (بازتولید جزیره)
func release_all_claims() -> void:
        var dead: Array = []
        for i in _claims:
                if int(_claims[i]) != OWNER_OCCUPIED:
                        dead.append(i)
        for i in dead:
                _claims.erase(i)
        _sit_of.clear()


## برای تست خودکار: تعداد پدهای اشغال‌شده توسط سربازان (بدون خانه‌ها)
func claim_count() -> int:
        var n := 0
        for i in _claims:
                if int(_claims[i]) != OWNER_OCCUPIED:
                        n += 1
        return n
