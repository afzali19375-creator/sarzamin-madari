class_name CommandGrid
extends Node3D
## شبکه‌ی فرمان Bad North (بازخورد کاربر: «بلوک‌ها خیلی کوچک‌اند، بزرگ‌تر شوند» +
## «مثل بد نورث: هنگام انتخاب، بلوک‌ها به‌صورت هاله‌ی سفید روی زمینِ معمولی»)
##
## گام ۶R4 — بازخورد کاربر: «بلوک‌های انتخاب‌کننده به صورت مستطیلی باشند؛
## یک حالت پرتو نور ازشون بیرون می‌زنه»:
##   * هاله‌ی دایره‌ای قبلی → «قاب مستطیلی» با پرشدگی ملایم داخل
##   * از هر بلوک یک «ستون نور» طلایی (COMMAND_BEAM_COLOR) بلند می‌شود
##     (مخروط چهاروجهیِ جمع‌شونده به بالا — شیدرِ افزایشیِ محوشونده)
##   * بلوکِ زیر ماوس + پرتوی پرنورتر و بلندتر
##   * هر سلول فرمان = ۲×۲ سلول NavGrid (۲×۲ متر)
##   * نمایان بودن فقط در «حالت فرمان» (دسته انتخاب شده + اسلوموشن)
##   * سلول‌ها با شیب زمین هم‌راستا می‌شوند (تیلت) تا در شیب‌ها فرو نروند

const MARGIN := 0.92   # نصف ضلع هاله (کمی کوچک‌تر از ۱ متر برای شکاف زیبا)

var size := 0
var cell_count := 0

var _ground: IslandGround
var _nav: NavGrid
var _origin := Vector2.ZERO
var _cells: Array[Dictionary] = []       # {cc, center, top}
var _by_cc: Dictionary = {}
var _mmi: MultiMeshInstance3D
var _beams: MultiMeshInstance3D          # گام ۶R4 — ستون نورِ هر بلوک
var _hover: MeshInstance3D
var _hover_beam: MeshInstance3D          # گام ۶R4 — پرتوی پرنورترِ بلوکِ هاور
var _hover_mat: ShaderMaterial
var _hover_index := -1


func rebuild(ground: IslandGround, nav: NavGrid) -> void:
        for c in get_children():
                c.free()
        _ground = ground
        _nav = nav
        size = ground.size
        _origin = nav.origin
        _cells.clear()
        _by_cc.clear()
        _hover_index = -1

        var half := int(GameConstants.COMMAND_CELL * 0.5)
        for cy in range(0, size - 1, half * 2):
                for cx in range(0, size - 1, half * 2):
                        var walk := 0
                        for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
                                var c2 := Vector2i(cx, cy) + d
                                if nav.is_walkable(c2):
                                        walk += 1
                        if walk < 3:
                                continue  # سلول فرمان باید تقریباً کامل روی خشکی باشد
                        var center := _origin + (Vector2(cx, cy) + Vector2(half, half)) * nav.cell_size
                        var top := _avg_top(cx, cy, half)
                        _by_cc[Vector2i(cx, cy)] = _cells.size()
                        _cells.append({"cc": Vector2i(cx, cy), "center": center, "top": top})
        cell_count = _cells.size()
        _build_visuals()


func _avg_top(cx: int, cy: int, half: int) -> float:
        var acc := 0.0
        for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
                acc += _ground.top_at(Vector2i(cx, cy) + d)
        return acc / 4.0


## گام ۶R4 — شیدرِ «قاب مستطیلی»: به‌جای گرادیان دایره‌ای، قابِ مربع با
## پرشدگی ملایم داخل — d = فاصله‌ی مربعی از مرکز در فضای UV
func _halo_shader() -> Shader:
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float intensity = 0.4;
uniform float pulse_speed = 2.4;
void fragment() {
        vec2 q = abs(UV - vec2(0.5));
        float d = max(q.x, q.y);
        float fill = smoothstep(0.5, 0.40, d) * 0.16;
        float frame = smoothstep(0.5, 0.465, d) * smoothstep(0.36, 0.45, d);
        float pulse = 0.75 + 0.25 * sin(TIME * pulse_speed);
        ALBEDO = vec3(1.0, 1.0, 0.97);
        ALPHA = (fill + frame * 0.95) * intensity * pulse;
}
"""
        return sh


## گام ۶R4 — شیدر «پرتو نور»: ستونی که از بلوک بیرون می‌زند؛ پایه پرنور،
## به سمت بالا محو — vy (ارتفاع موضعی) از vertex shader می‌آید
func _beam_shader() -> Shader:
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float intensity = 0.5;
uniform float pulse_speed = 2.6;
uniform float beam_h = 1.9;
varying float vy;
void vertex() {
        vy = VERTEX.y;
}
void fragment() {
        float h01 = clamp(vy / beam_h + 0.5, 0.0, 1.0);
        float fade = pow(1.0 - h01, 1.7);
        float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed + vy * 2.2);
        ALBEDO = vec3(1.0, 0.85, 0.54);
        ALPHA = fade * intensity * pulse;
}
"""
        return sh


func _build_visuals() -> void:
        var pm := PlaneMesh.new()
        pm.size = Vector2(MARGIN * 2.0, MARGIN * 2.0)
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = pm
        mm.instance_count = maxi(_cells.size(), 1)
        for i in _cells.size():
                mm.set_instance_transform(i, _cell_transform(_cells[i]["center"], _cells[i]["top"]))
        _mmi = MultiMeshInstance3D.new()
        _mmi.multimesh = mm
        var mat := ShaderMaterial.new()
        mat.shader = _halo_shader()
        mat.set_shader_parameter("intensity", 0.42)
        mat.set_shader_parameter("pulse_speed", 2.4)
        _mmi.material_override = mat
        _mmi.visible = false
        add_child(_mmi)

        # گام ۶R4 — پرتو نور هر بلوک: مخروط چهاروجهی (مقطع مربعی، جمع‌شونده به بالا)
        var bm := CylinderMesh.new()
        bm.top_radius = 0.22
        bm.bottom_radius = 0.40
        bm.height = GameConstants.COMMAND_BEAM_HEIGHT
        bm.radial_segments = 4
        bm.rings = 1
        var bmm := MultiMesh.new()
        bmm.transform_format = MultiMesh.TRANSFORM_3D
        bmm.mesh = bm
        bmm.instance_count = maxi(_cells.size(), 1)
        for i in _cells.size():
                var t := _cell_transform(_cells[i]["center"], _cells[i]["top"])
                t.origin.y += GameConstants.COMMAND_BEAM_HEIGHT * 0.5 - 0.02
                # چرخش ۴۵° تا وجهِ مربع با ضلع بلوک هم‌راستا شود
                t.basis = t.basis.rotated(Vector3(0, 1, 0), PI * 0.25)
                bmm.set_instance_transform(i, t)
        _beams = MultiMeshInstance3D.new()
        _beams.multimesh = bmm
        var bmat := ShaderMaterial.new()
        bmat.shader = _beam_shader()
        bmat.set_shader_parameter("intensity", 0.34)
        bmat.set_shader_parameter("pulse_speed", 2.6)
        bmat.set_shader_parameter("beam_h", GameConstants.COMMAND_BEAM_HEIGHT)
        _beams.material_override = bmat
        _beams.visible = false
        add_child(_beams)

        _hover = MeshInstance3D.new()
        _hover.mesh = pm
        _hover_mat = ShaderMaterial.new()
        _hover_mat.shader = _halo_shader()
        _hover_mat.set_shader_parameter("intensity", 1.0)
        _hover_mat.set_shader_parameter("pulse_speed", 5.0)
        _hover.material_override = _hover_mat
        _hover.visible = false
        add_child(_hover)

        # گام ۶R4 — پرتوی بلندتر و پرنورتر برای بلوکِ زیر ماوس
        var hb := CylinderMesh.new()
        hb.top_radius = 0.16
        hb.bottom_radius = 0.34
        hb.height = GameConstants.COMMAND_BEAM_HEIGHT * 1.35
        hb.radial_segments = 4
        hb.rings = 1
        _hover_beam = MeshInstance3D.new()
        _hover_beam.mesh = hb
        var hbmat := ShaderMaterial.new()
        hbmat.shader = _beam_shader()
        hbmat.set_shader_parameter("intensity", 0.7)
        hbmat.set_shader_parameter("pulse_speed", 4.5)
        hbmat.set_shader_parameter("beam_h", GameConstants.COMMAND_BEAM_HEIGHT * 1.35)
        _hover_beam.material_override = hbmat
        _hover_beam.visible = false
        add_child(_hover_beam)


## ترنسفورم هم‌راستا با شیب زمین (تیلت) + کمی بالاتر از سطح
func _cell_transform(center: Vector2, top: float) -> Transform3D:
        var h := MARGIN - 0.06
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
        return Transform3D(basis, Vector3(center.x, mid_h + 0.07, center.y))


# ---------------- حالت فرمان و هاور ----------------

## ورود/خروج حالت فرمان (دسته انتخاب شد / لغو شد)
func set_command_mode(on: bool) -> void:
        if _mmi != null:
                _mmi.visible = on
        if _beams != null:
                _beams.visible = on
        if not on:
                _clear_hover()


func _clear_hover() -> void:
        _hover_index = -1
        if _hover != null:
                _hover.visible = false
        if _hover_beam != null:
                _hover_beam.visible = false


## هاور با نشانگر — سلول سفیدِ زیر ماوس پرنورتر می‌شود + پرتوی بلندتر
func hover_at_world(xz: Vector2) -> Dictionary:
        var info := cell_at_world(xz)
        if not bool(info.get("ok", false)):
                _clear_hover()
                return info
        if int(info["index"]) != _hover_index:
                _hover_index = int(info["index"])
                var c: Dictionary = _cells[_hover_index]
                var t := _cell_transform(c["center"], c["top"])
                _hover.transform = t
                _hover.visible = _mmi != null and _mmi.visible
                if _hover_beam != null:
                        t.origin.y += GameConstants.COMMAND_BEAM_HEIGHT * 1.35 * 0.5 - 0.02
                        t.basis = t.basis.rotated(Vector3(0, 1, 0), PI * 0.25)
                        _hover_beam.transform = t
                        _hover_beam.visible = _mmi != null and _mmi.visible
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
        return _mmi != null and _mmi.visible


## گام ۶R4 — برای تست خودکار: تعداد پرتوهای نور ساخته‌شده (== تعداد بلوک‌ها)
func beam_instance_count() -> int:
        if _beams == null or _beams.multimesh == null:
                return 0
        return int(_beams.multimesh.instance_count)


## گام ۶R4 — برای تست خودکار: پرتوها فقط در حالت فرمان دیده می‌شوند
func beams_visible() -> bool:
        return _beams != null and _beams.visible
