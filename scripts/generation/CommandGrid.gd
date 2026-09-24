class_name CommandGrid
extends Node3D
## شبکه‌ی فرمان Bad North (بازخورد کاربر: «بلوک‌ها خیلی کوچک‌اند، بزرگ‌تر شوند» +
## «مثل بد نورث: هنگام انتخاب، بلوک‌ها به‌صورت هاله‌ی سفید روی زمینِ معمولی»)
##
##   * هر سلول فرمان = ۲×۲ سلول NavGrid (۲×۲ متر) — بزرگ‌تر از نسخه‌ی قبل
##   * فقط سلول‌های مجاز (≥۳ از ۴ زیرسلول قابل‌عبور) هاله‌ی سفید دارند
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
var _hover: MeshInstance3D
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


func _halo_shader() -> Shader:
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float intensity = 0.4;
uniform float pulse_speed = 2.4;
void fragment() {
        float d = length(UV - vec2(0.5));
        float halo = smoothstep(0.5, 0.18, d);
        float edge = smoothstep(0.5, 0.44, d) * smoothstep(0.36, 0.44, d);
        float pulse = 0.75 + 0.25 * sin(TIME * pulse_speed);
        ALBEDO = vec3(1.0, 1.0, 0.97);
        ALPHA = (halo * 0.5 + edge * 0.9) * intensity * pulse;
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

        _hover = MeshInstance3D.new()
        _hover.mesh = pm
        _hover_mat = ShaderMaterial.new()
        _hover_mat.shader = _halo_shader()
        _hover_mat.set_shader_parameter("intensity", 1.0)
        _hover_mat.set_shader_parameter("pulse_speed", 5.0)
        _hover.material_override = _hover_mat
        _hover.visible = false
        add_child(_hover)


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
        if not on:
                _clear_hover()


func _clear_hover() -> void:
        _hover_index = -1
        if _hover != null:
                _hover.visible = false


## هاور با نشانگر — سلول سفیدِ زیر ماوس پرنورتر می‌شود
func hover_at_world(xz: Vector2) -> Dictionary:
        var info := cell_at_world(xz)
        if not bool(info.get("ok", false)):
                _clear_hover()
                return info
        if int(info["index"]) != _hover_index:
                _hover_index = int(info["index"])
                var c: Dictionary = _cells[_hover_index]
                _hover.transform = _cell_transform(c["center"], c["top"])
                _hover.visible = _mmi != null and _mmi.visible
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
