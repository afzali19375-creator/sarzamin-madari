class_name IslandGround
extends Node3D
## گام ۴ R2 — زمینِ صاف به سبک Bad North (بازخورد کاربر: «کل زمین نباید بلوک‌بلوک باشد»)
##
##   * کاشی‌ها فقط «منطقی» هستند: NavGrid ۱×۱ متری + شبکه‌ی فرمان — روی زمین دیده نمی‌شوند
##   * ظاهر = یک مش یکپارچه: تپه‌ماهور هموار با وجوه تخت (flat-shaded) +
##     پرتگاه ساحلی + آب متحرک با موج و کف سفید دور ساحل (§۱۵ پرامت)
##   * پیکینگ با march ریاضی روی heightfield — بدون فیزیک، دقیق و امن در headless
##
## نگاشت مختصات دقیقاً همان NavGrid است: origin + (cell + 0.5) * cell_size.

const SEA_Y := -0.18          # سطح دریا (متر)
const BEACH_TUCK := 0.04      # لبه‌ی ساحل کمی زیر آب می‌رود تا خط ساحل نرم شود
const SKIRT_BOTTOM := -0.7    # کف پرتگاه ساحلی (زیر موج‌ها)
const PICK_MAX_DIST := 300.0

var size := 0
var sea_y := SEA_Y

var _island: Dictionary = {}
var _cell := 1.0
var _origin := Vector2.ZERO
var _corners := PackedFloat32Array()   # (size+1)² — ارتفاع گوشه‌ها برای زمینِ هموار
var _terrain_mesh: MeshInstance3D
var _water: MeshInstance3D
var _foam: MeshInstance3D


## ساخت/بازسازی کامل زمین از نتیجه‌ی WfcIsland (در regenerate دوباره صدا زده می‌شود)
func build(island: Dictionary, cell_size: float, world_origin: Vector2) -> void:
        for c in get_children():
                c.free()
        _island = island
        _cell = cell_size
        _origin = world_origin
        size = int(island["size"])
        _build_corners()
        _build_terrain_mesh()
        _build_water()
        _build_foam()


# ---------------- ارتفاع گوشه‌ها ----------------
## هر گوشه = میانگینِ ارتفاعِ سلول‌های مجاور؛ آب سهمِ «سطح دریا» می‌دهد تا
## ساحل به‌نرمی زیر آب برود و پرتگاه‌های مرتفع به‌صورت شیب تند ظاهر شوند.

func _build_corners() -> void:
        var n1 := size + 1
        _corners.resize(n1 * n1)
        var sea_contrib := SEA_Y + BEACH_TUCK
        for j in n1:
                for i in n1:
                        var acc := 0.0
                        var count := 0
                        for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
                                var cx: int = i + d.x
                                var cy: int = j + d.y
                                if cx < 0 or cy < 0 or cx >= size or cy >= size:
                                        continue
                                var ci := cy * size + cx
                                if int(_island["walkable"][ci]) == 1:
                                        acc += float(_island["tops"][ci])
                                else:
                                        acc += sea_contrib
                                count += 1
                        _corners[j * n1 + i] = acc / float(maxi(count, 1))


func corner_height(i: int, j: int) -> float:
        var n1 := size + 1
        i = clampi(i, 0, size)
        j = clampi(j, 0, size)
        return _corners[j * n1 + i]


# ---------------- مش زمین (سطح + پرتگاه ساحلی) ----------------

func _corner_world(i: int, j: int) -> Vector3:
        return Vector3(_origin.x + float(i) * _cell, corner_height(i, j),
                        _origin.y + float(j) * _cell)


func _build_terrain_mesh() -> void:
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var colors: Array = _island["meta_colors"]
        var hsh := int(_island["hash"]) % 100000
        var up := Vector3.UP
        for cy in size:
                for cx in size:
                        var ci := cy * size + cx
                        var is_land := int(_island["walkable"][ci]) == 1
                        var a := _corner_world(cx, cy)
                        var b := _corner_world(cx + 1, cy)
                        var c2 := _corner_world(cx, cy + 1)
                        var d := _corner_world(cx + 1, cy + 1)
                        if is_land:
                                # لرزش رنگی قطعی برای حس ارگانیک (مثل نسخه‌ی قبل)
                                var j := fposmod(sin(float(ci) * 12.9898 + float(hsh) * 0.017) * 43758.5453, 1.0)
                                var col: Color = colors[int(_island["modules"][ci])]
                                col = col * (0.93 + 0.13 * j)
                                _add_tri(st, a, b, d, col, up)
                                _add_tri(st, a, d, c2, col, up)
                        # پرتگاه ساحلی: لبه‌ای از خشکی که به آب می‌رسد
                        if is_land:
                                var rock := GameConstants.COL_ROCK
                                var rock_dark := GameConstants.COL_ROCK_DARK
                                if not _land_at(cx + 1, cy):  # شرق
                                        var col := rock.lerp(rock_dark, fposmod(sin(float(ci) * 3.7) * 0.5 + 0.5, 1.0) * 0.4)
                                        _add_wall(st, b, d, col)
                                if not _land_at(cx - 1, cy):  # غرب
                                        var col := rock.lerp(rock_dark, fposmod(sin(float(ci) * 5.1) * 0.5 + 0.5, 1.0) * 0.4)
                                        _add_wall(st, a, c2, col)
                                if not _land_at(cx, cy + 1):  # جنوب
                                        var col := rock.lerp(rock_dark, fposmod(sin(float(ci) * 7.3) * 0.5 + 0.5, 1.0) * 0.4)
                                        _add_wall(st, c2, d, col)
                                if not _land_at(cx, cy - 1):  # شمال
                                        var col := rock.lerp(rock_dark, fposmod(sin(float(ci) * 9.7) * 0.5 + 0.5, 1.0) * 0.4)
                                        _add_wall(st, a, b, col)
        st.generate_tangents()
        var mesh := st.commit()
        _terrain_mesh = MeshInstance3D.new()
        _terrain_mesh.mesh = mesh
        var mat := StandardMaterial3D.new()
        mat.vertex_color_use_as_albedo = true
        mat.roughness = 1.0
        _terrain_mesh.material_override = mat
        add_child(_terrain_mesh)


func _land_at(cx: int, cy: int) -> bool:
        if cx < 0 or cy < 0 or cx >= size or cy >= size:
                return false
        return int(_island["walkable"][cy * size + cx]) == 1


## دیوار عمودی از لبه‌ی ساحل تا زیر آب — پرتگاه Bad North
func _add_wall(st: SurfaceTool, p1: Vector3, p2: Vector3, col: Color) -> void:
        var b1 := Vector3(p1.x, SKIRT_BOTTOM, p1.z)
        var b2 := Vector3(p2.x, SKIRT_BOTTOM, p2.z)
        var outward := Vector3(p2.x - p1.x, 0.0, p2.z - p1.z).cross(Vector3.UP)
        _add_tri(st, p1, p2, b2, col, outward)
        _add_tri(st, p1, b2, b1, col, outward)


## مثلث با جهت‌گیری قطعی (نرمال در سمتِ دلخواه) — flat-shaded
func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color,
                desired: Vector3) -> void:
        var n := (b - a).cross(c - a)
        if n.dot(desired) < 0.0:
                var t := b
                b = c
                c = t
                n = -n
        n = n.normalized() if n.length() > 0.0001 else desired.normalized()
        for v in [a, b, c]:
                st.set_color(col)
                st.set_normal(n)
                st.add_vertex(v)


# ---------------- آب متحرک (§۱۵.۱ پرامت) ----------------

func _build_water() -> void:
        _water = MeshInstance3D.new()
        var pm := PlaneMesh.new()
        pm.size = Vector2(320, 320)
        pm.subdivide_width = 96
        pm.subdivide_depth = 96
        _water.mesh = pm
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
uniform vec3 shallow_col : source_color = vec3(0.290, 0.565, 0.643);
uniform vec3 deep_col : source_color = vec3(0.173, 0.373, 0.451);
uniform float wave_speed = 0.3;
uniform float wave_height = 0.05;
uniform float wave_freq = 0.8;
uniform float normal_strength = 0.4;
uniform float fresnel = 0.3;
varying float vwave;
float wave_h(vec2 p, float t) {
        return sin(p.x * wave_freq + t * wave_speed * 2.0) * 0.7
                + cos(p.y * wave_freq * 1.3 + t * wave_speed * 1.6) * 0.3;
}
void vertex() {
        vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        float h = wave_h(wp.xz, TIME);
        VERTEX.y += h * wave_height;
        vwave = h;
        float e = 0.4;
        float hx = wave_h(wp.xz + vec2(e, 0.0), TIME) - wave_h(wp.xz - vec2(e, 0.0), TIME);
        float hz = wave_h(wp.xz + vec2(0.0, e), TIME) - wave_h(wp.xz - vec2(0.0, e), TIME);
        NORMAL = normalize(vec3(-hx * wave_height / e * 40.0 * normal_strength, 1.0,
                        -hz * wave_height / e * 40.0 * normal_strength));
}
void fragment() {
        float m = smoothstep(-0.8, 1.0, vwave);
        vec3 col = mix(deep_col, shallow_col, 0.45 + 0.35 * m);
        float fr = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
        col = mix(col, vec3(0.90, 0.94, 0.92), fr * fresnel);
        ALBEDO = col;
        ROUGHNESS = 0.5;
        SPECULAR = 0.25;
}
"""
        var mat := ShaderMaterial.new()
        mat.shader = sh
        mat.set_shader_parameter("shallow_col", GameConstants.COL_WATER_SHALLOW)
        mat.set_shader_parameter("deep_col", GameConstants.COL_WATER_DEEP)
        _water.material_override = mat
        _water.position = Vector3(0, SEA_Y, 0)
        add_child(_water)


# ---------------- کف ساحل (حلقه‌ی سفید دور جزیره — امضای Bad North) ----------------

func _build_foam() -> void:
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var white := Color(0.96, 0.98, 0.97)
        for cy in size:
                for cx in size:
                        if not _land_at(cx, cy):
                                continue
                        var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
                        for dir in dirs:
                                if _land_at(cx + dir.x, cy + dir.y):
                                        continue
                                # لبه‌ی مشترک این سلول با سلول آبی → نوار کف به سمت آب
                                var ex := _origin.x + float(cx) * _cell
                                var ey := _origin.y + float(cy) * _cell
                                var p1: Vector3
                                var p2: Vector3
                                if dir.x == 1:
                                        p1 = Vector3(ex + _cell, 0, ey)
                                        p2 = Vector3(ex + _cell, 0, ey + _cell)
                                elif dir.x == -1:
                                        p1 = Vector3(ex, 0, ey)
                                        p2 = Vector3(ex, 0, ey + _cell)
                                elif dir.y == 1:
                                        p1 = Vector3(ex, 0, ey + _cell)
                                        p2 = Vector3(ex + _cell, 0, ey + _cell)
                                else:
                                        p1 = Vector3(ex, 0, ey)
                                        p2 = Vector3(ex + _cell, 0, ey)
                                var out3 := Vector3(dir.x, 0, dir.y)
                                var q1 := p1 + out3 * 0.28
                                var q2 := p2 + out3 * 0.28
                                var q3 := p2 + out3 * 0.85
                                var q4 := p1 + out3 * 0.85
                                var y := SEA_Y + 0.03
                                _foam_tri(st, Vector3(q1.x, y, q1.z), Vector3(q2.x, y, q2.z),
                                                Vector3(q3.x, y, q3.z), white)
                                _foam_tri(st, Vector3(q1.x, y, q1.z), Vector3(q3.x, y, q3.z),
                                                Vector3(q4.x, y, q4.z), white)
        var mesh := st.commit()
        _foam = MeshInstance3D.new()
        _foam.mesh = mesh
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
varying vec3 vwp;
void vertex() {
        vwp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
        float pulse = 0.62 + 0.38 * sin(TIME * 1.7 + (vwp.x + vwp.z) * 0.9);
        ALBEDO = vec3(0.97, 0.99, 0.98);
        ALPHA = 0.52 * pulse;
}
"""
        var mat := ShaderMaterial.new()
        mat.shader = sh
        _foam.material_override = mat
        add_child(_foam)


func _foam_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
        for v in [a, b, c]:
                st.set_color(col)
                st.set_normal(Vector3.UP)
                st.add_vertex(v)


# ---------------- پرس‌وجو (همان قرارداد قبلی IslandTiles) ----------------

func cell_at_world(xz: Vector2) -> Vector2i:
        var local := (xz - _origin) / _cell
        return Vector2i(floori(local.x), floori(local.y))


func in_bounds(cell: Vector2i) -> bool:
        return cell.x >= 0 and cell.y >= 0 and cell.x < size and cell.y < size


func _idx(cell: Vector2i) -> int:
        return cell.y * size + cell.x


func top_at(cell: Vector2i) -> float:
        if not in_bounds(cell):
                return 0.0
        return float(_island["tops"][_idx(cell)])


## ارتفاع زمینِ هموار در نقطه‌ی جهانی — درون‌یابی دوخطی گوشه‌ها (provider واحدها)
func height_at_world(xz: Vector2) -> float:
        if size == 0:
                return 0.0
        var local := (xz - _origin) / _cell
        var fx := clampf(local.x, 0.0, float(size) - 0.0001)
        var fy := clampf(local.y, 0.0, float(size) - 0.0001)
        var i := int(fx)
        var j := int(fy)
        var u := fx - float(i)
        var v := fy - float(j)
        var h00 := corner_height(i, j)
        var h10 := corner_height(i + 1, j)
        var h01 := corner_height(i, j + 1)
        var h11 := corner_height(i + 1, j + 1)
        return lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), v)


func walkable_at(cell: Vector2i) -> bool:
        if not in_bounds(cell):
                return false
        return int(_island["walkable"][_idx(cell)]) == 1


func module_name_at(cell: Vector2i) -> String:
        if not in_bounds(cell):
                return "out"
        return String(_island["meta_names"][int(_island["modules"][_idx(cell)])])


## پرتاب پرتو از دوربین به ماوس — march روی heightfield (بدون فیزیک، دقیق)
func ray_pick(cam: Camera3D, mouse: Vector2) -> Dictionary:
        if cam == null or size == 0:
                return {}
        var from := cam.project_ray_origin(mouse)
        var dir := cam.project_ray_normal(mouse)
        var step := 0.3
        var prev_diff := from.y - height_at_world(Vector2(from.x, from.z))
        var hit_t := -1.0
        var t := step
        while t < PICK_MAX_DIST:
                var p := from + dir * t
                var diff := p.y - height_at_world(Vector2(p.x, p.z))
                if diff <= 0.0 and prev_diff > 0.0:
                        # دوبخشی کردن برای دقت سانتی‌متری
                        var lo := t - step
                        var hi := t
                        for _r in 10:
                                var mid := (lo + hi) * 0.5
                                var pm := from + dir * mid
                                if pm.y - height_at_world(Vector2(pm.x, pm.z)) > 0.0:
                                        lo = mid
                                else:
                                        hi = mid
                        hit_t = (lo + hi) * 0.5
                        break
                prev_diff = diff
                t += step
        var xz := Vector2.ZERO
        if hit_t < 0.0:
                # پرتو به زمین نخورد → صفحه‌ی افقی (آسمان/افق) — رفتار قبلی
                var ip = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
                if ip == null:
                        return {}
                xz = Vector2(ip.x, ip.z)
        else:
                var p := from + dir * hit_t
                xz = Vector2(p.x, p.z)
        var cell := cell_at_world(xz)
        if not in_bounds(cell):
                return {"in_island": false, "cell": cell}
        var i := _idx(cell)
        return {
                "in_island": true,
                "cell": cell,
                "walkable": int(_island["walkable"][i]) == 1,
                "top": float(_island["tops"][i]),
                "module": String(_island["meta_names"][int(_island["modules"][i])]),
        }
