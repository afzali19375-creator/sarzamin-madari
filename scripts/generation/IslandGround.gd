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
var _walls_mesh: MeshInstance3D
var _water: MeshInstance3D
var _foam: MeshInstance3D
## گام ۶R۱۳ — مرکز/شعاعِ جزیره برای گرادیانِ عمقِ شعاعیِ آب
var _island_center := Vector2.ZERO
var _island_radius := 12.0


## ساخت/بازسازی کامل زمین از نتیجه‌ی WfcIsland (در regenerate دوباره صدا زده می‌شود)
func build(island: Dictionary, cell_size: float, world_origin: Vector2) -> void:
        for c in get_children():
                c.free()
        _island = island
        _cell = cell_size
        _origin = world_origin
        size = int(island["size"])
        _compute_island_bounds()
        _build_corners()
        _build_terrain_mesh()
        _build_water()
        _build_foam()
        _build_island_shadow()


## گام ۶R۱۳ — مرکز و شعاعِ تقریبیِ خشکی (از سلول‌های walkable) —
## شیدرِ آب با آن «حلقه‌ی کم‌عمقِ روشن» دور جزیره می‌سازد تا جزیره و دریا
## هرگز یکی دیده نشوند (بازخورد: «جزیره و دریا یکی شدن»)
func _compute_island_bounds() -> void:
        var min_c := Vector2(1e9, 1e9)
        var max_c := Vector2(-1e9, -1e9)
        var any := false
        for cy in size:
                for cx in size:
                        if int(_island["walkable"][cy * size + cx]) != 1:
                                continue
                        any = true
                        var w := Vector2(_origin.x + float(cx) * _cell,
                                        _origin.y + float(cy) * _cell)
                        min_c = min_c.min(w)
                        max_c = max_c.max(w)
        if not any:
                return
        _island_center = (min_c + max_c) * 0.5
        _island_radius = maxf((max_c - _island_center).length(),
                        (min_c - _island_center).length()) + _cell * 0.5


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
                                elif _is_water_module(ci):
                                        acc += sea_contrib
                                else:
                                        # صخره‌ی درونِ خشکی — سطحِ خودش را می‌دهد (نه گودیِ دریا)
                                        acc += float(_island["tops"][ci])
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
        # گام ۶R۱۴c — بازنویسیِ کامل به «شبکه‌ی گوشه‌ایِ ایندکس‌دار»:
        #   * رأس‌ها = (size+1)² گوشه‌ی مشترک — هر سلول فقط ۲ ایندکس-مثلث
        #   * رنگ روی گوشه‌ها توزیع و در رستر درون‌یابی می‌شود (نرم‌تر از لکه‌ی
        #     تختِ سلولی؛ و immune به هرگونه بدرفتاریِ رستر با triangle-soup —
        #     «راه‌راهِ مورب» که با soup روی llvmpipe/GPU دیده می‌شد)
        #   * winding = همان قراردادِ اثبات‌شده‌ی ۶R۱۳ (v00,v10,v11)
        # رنگ‌آمیزی «قانونی»: چمنِ یکدستِ مرجع + موتِ ارگانیک — هشِ دو-متغیره
        var mottle := PackedFloat32Array()
        mottle.resize(size * size)
        for cyy in size:
                for cxx in size:
                        var ci2 := cyy * size + cxx
                        mottle[ci2] = fposmod(
                                        sin(float(cxx) * 127.1 + float(cyy) * 311.7)
                                        * 43758.5453, 1.0)
        var mottle_s := PackedFloat32Array()
        mottle_s.resize(size * size)
        for cyb in size:
                for cxb in size:
                        var cib := cyb * size + cxb
                        var acc := mottle[cib] * 2.0
                        var cnt := 2
                        for dd in [Vector2i(1, 0), Vector2i(-1, 0),
                                        Vector2i(0, 1), Vector2i(0, -1)]:
                                var nx2: int = cxb + dd.x
                                var ny2: int = cyb + dd.y
                                if nx2 < 0 or ny2 < 0 or nx2 >= size or ny2 >= size:
                                        continue
                                acc += mottle[ny2 * size + nx2]
                                cnt += 1
                        mottle_s[cib] = acc / float(cnt)
        # --- رنگِ هر سلولِ دارایِ سطح ---
        var has_surface := PackedByteArray()
        has_surface.resize(size * size)
        var cell_col := PackedColorArray()
        cell_col.resize(size * size)
        for cy in size:
                for cx in size:
                        var ci := cy * size + cx
                        var walk := int(_island["walkable"][ci]) == 1
                        var water := _is_water_module(ci)
                        if water and not walk:
                                continue
                        has_surface[ci] = 1
                        if walk:
                                cell_col[ci] = _grass_color(mottle_s[ci],
                                                float(_island["tops"][ci]))
                        else:
                                # صخره‌ی درونِ جزیره: خاکی-زیتونیِ هم‌خانواده‌ی چمن
                                # (گچِ سفید فقط مالِ دیوارِ ساحلی است)
                                cell_col[ci] = GameConstants.COL_GRASS_DARK.lerp(
                                                GameConstants.COL_ROCK, 0.45)
        # --- رأس‌های گوشه‌ای: موقعیت + رنگِ میانگینِ سلول‌های مجاور ---
        var n1 := size + 1
        var verts := PackedVector3Array()
        verts.resize(n1 * n1)
        var cols := PackedColorArray()
        cols.resize(n1 * n1)
        var norms := PackedVector3Array()
        norms.resize(n1 * n1)
        for j in n1:
                for i in n1:
                        var vi := j * n1 + i
                        verts[vi] = _corner_world(i, j)
                        norms[vi] = Vector3.UP
                        var acc := Color(0, 0, 0, 0)
                        var cnt := 0
                        for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1),
                                        Vector2i(-1, 0), Vector2i(0, 0)]:
                                var cx: int = i + d.x
                                var cy: int = j + d.y
                                if cx < 0 or cy < 0 or cx >= size or cy >= size:
                                        continue
                                var ci3 := cy * size + cx
                                if has_surface[ci3] == 0:
                                        continue
                                acc += cell_col[ci3]
                                cnt += 1
                        cols[vi] = (acc / float(maxi(cnt, 1)))
                        cols[vi].a = 1.0
        # --- ایندکس‌ها: ۲ مثلث برای هر سلولِ دارایِ سطح (winding اثبات‌شده) ---
        var idxs := PackedInt32Array()
        for cy in size:
                for cx in size:
                        var ci := cy * size + cx
                        if has_surface[ci] == 0:
                                continue
                        var v00 := cy * n1 + cx
                        var v10 := cy * n1 + cx + 1
                        var v01 := (cy + 1) * n1 + cx
                        var v11 := (cy + 1) * n1 + cx + 1
                        idxs.append_array([v00, v10, v11, v00, v11, v01])
        var arr := []
        arr.resize(Mesh.ARRAY_MAX)
        arr[Mesh.ARRAY_VERTEX] = verts
        arr[Mesh.ARRAY_NORMAL] = norms
        arr[Mesh.ARRAY_COLOR] = cols
        arr[Mesh.ARRAY_INDEX] = idxs
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
        _terrain_mesh = MeshInstance3D.new()
        _terrain_mesh.mesh = mesh
        var mat := StandardMaterial3D.new()
        mat.vertex_color_use_as_albedo = true
        mat.roughness = 1.0
        _terrain_mesh.material_override = mat
        add_child(_terrain_mesh)
        _build_cliff_walls(mottle_s)


## گام ۶R۱۴c — دیوارهای گچی به‌صورت مشِ جدا (خارج از مشِ شبکه‌ایِ سطوح):
## پرتگاه ساحلی با لبه‌ی چمنی — امضای مرجع. هر دیوار = نوارِ لب (چمن→گچ)
## + بدنه‌ی گچ با گرادیان به سایه‌ی پایین.
func _build_cliff_walls(mottle_s: PackedFloat32Array) -> void:
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for cy in size:
                for cx in size:
                        var ci := cy * size + cx
                        if int(_island["walkable"][ci]) != 1:
                                continue
                        var a := _corner_world(cx, cy)
                        var b := _corner_world(cx + 1, cy)
                        var c2 := _corner_world(cx, cy + 1)
                        var d := _corner_world(cx + 1, cy + 1)
                        var lip_col := _grass_color(mottle_s[ci],
                                        float(_island["tops"][ci])) * 0.90
                        if _is_water_module_at(cx + 1, cy) or cx + 1 >= size:  # شرق
                                _add_wall(st, b, d, lip_col, Vector3(1, 0, 0))
                        if _is_water_module_at(cx - 1, cy) or cx - 1 < 0:  # غرب
                                _add_wall(st, a, c2, lip_col, Vector3(-1, 0, 0))
                        if _is_water_module_at(cx, cy + 1) or cy + 1 >= size:  # جنوب
                                _add_wall(st, c2, d, lip_col, Vector3(0, 0, 1))
                        if _is_water_module_at(cx, cy - 1) or cy - 1 < 0:  # شمال
                                _add_wall(st, a, b, lip_col, Vector3(0, 0, -1))
        st.index()
        var wmesh := st.commit()
        _walls_mesh = MeshInstance3D.new()
        _walls_mesh.mesh = wmesh
        var wmat := StandardMaterial3D.new()
        wmat.vertex_color_use_as_albedo = true
        wmat.roughness = 1.0
        _walls_mesh.material_override = wmat
        add_child(_walls_mesh)


func _land_at(cx: int, cy: int) -> bool:
        if cx < 0 or cy < 0 or cx >= size or cy >= size:
                return false
        return int(_island["walkable"][cy * size + cx]) == 1


## گام ۶R۱۴ — دیوارِ گچیِ دولایه: نوارِ لبه‌ی چمنی (۰٫۱۳m) + بدنه‌ی گچِ سفید
## با گرادیانِ ملایم به سایه‌ی پایین — windingِ اثبات‌شده حفظ شده، فقط
## نرمالِ attribute به «بیرونِ واقعی» ست می‌شود (نورِ صحیح)
func _add_wall(st: SurfaceTool, p1: Vector3, p2: Vector3, lip_col: Color,
                outward: Vector3) -> void:
        var b1 := Vector3(p1.x, SKIRT_BOTTOM, p1.z)
        var b2 := Vector3(p2.x, SKIRT_BOTTOM, p2.z)
        var lip := 0.13
        var m1 := Vector3(p1.x, p1.y - lip, p1.z)
        var m2 := Vector3(p2.x, p2.y - lip, p2.z)
        var chalk := GameConstants.COL_CLIFF
        var chalk_dark := GameConstants.COL_CLIFF_DARK
        # نوارِ لب: چمن → گچِ سفید
        _add_tri2(st, p1, lip_col, p2, lip_col, m2, chalk, outward)
        _add_tri2(st, p1, lip_col, m2, chalk, m1, chalk, outward)
        # بدنه: گچِ سفید → سایه‌ی پایین
        _add_tri2(st, m1, chalk, m2, chalk, b2, chalk_dark, outward)
        _add_tri2(st, m1, chalk, b2, chalk_dark, b1, chalk_dark, outward)


## مثلث با windingِ اثبات‌شده‌ی ۶R۱۳ (flip وقتی n·desired > 0) اما با
## نرمالِ attribute مستقل = جهتِ هندسیِ واقعی (برای نورِ صحیحِ خورشید)
func _add_tri2(st: SurfaceTool, a: Vector3, ca: Color, b: Vector3, cb: Color,
                c: Vector3, cc: Color, shade: Vector3) -> void:
        var n := (b - a).cross(c - a)
        if n.dot(shade) > 0.0:
                var t := b
                b = c
                c = t
                var tc := cb
                cb = cc
                cc = tc
        var sn := shade.normalized()
        for pair in [[a, ca], [b, cb], [c, cc]]:
                st.set_color(pair[1])
                st.set_normal(sn)
                st.add_vertex(pair[0])


## کواتِ سطحِ بالای زمین — همان ترتیبِ رئوسِ اثبات‌شده، نرمال = UP واقعی
func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
                col: Color) -> void:
        _add_tri2(st, a, col, b, col, d, col, Vector3.UP)
        _add_tri2(st, a, col, d, col, c, col, Vector3.UP)


## گام ۶R۱۴ — آیا این سلول (ایندکسی) آبِ دریا است؟
func _is_water_module(ci: int) -> bool:
        var sockets: PackedStringArray = _island["meta_sockets"]
        var mi := int(_island["modules"][ci])
        return mi >= 0 and mi < sockets.size() and sockets[mi].begins_with("w")


func _is_water_module_at(cx: int, cy: int) -> bool:
        if cx < 0 or cy < 0 or cx >= size or cy >= size:
                return true   # بیرونِ گرید = دریا
        return _is_water_module(cy * size + cx)


## چمنِ نرمِ مرجع: لرپِ ملایمِ دو سبز + کمی روشن‌تر در ارتفاعِ بیشتر
func _grass_color(m: float, top: float) -> Color:
        var col := GameConstants.COL_GRASS_DARK.lerp(GameConstants.COL_GRASS_LIGHT,
                        clampf(m, 0.0, 1.0))
        col = col.lerp(Color.WHITE, clampf((top - 0.55) * 0.09, 0.0, 0.09))
        return col


## مثلث با جهت‌گیری قطعی — گام ۶R۱۳: قراردادِ winding در Godot 4 برعکسِ
## حدسِ قبلی بود و «نیمی از مثلث‌های» زمین back-face می‌شدند (بازخورد کاربر:
## «جزیره نابود شد و جزیره و دریا یکی شدن» — فقط تکه‌های پراکنده دیده می‌شد).
## پرابِ رندر اثبات کرد: با CULL_DISABLED کل جزیره سالم است → جهتِ نهایی باید
## برعکس می‌شد. اکنون flip برای قراردادِ رسمیِ Godot (CW = رویه‌ی جلو) انجام می‌شود.
func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color,
                desired: Vector3) -> void:
        var n := (b - a).cross(c - a)
        if n.dot(desired) > 0.0:
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
        # گام ۶R۱۴b — «GPU را ببر بالا، نگران نباش» (کاربر): subdiv به ۹۶ برگشت
        # — سطحِ موجِ نرم‌تر؛ Adreno 618 با ~۱۸ هزار مثلثِ آب مشکلی ندارد
        pm.subdivide_width = 96
        pm.subdivide_depth = 96
        _water.mesh = pm
        # گام ۶R۱۳ — بازنویسی کاملِ آب (بازخورد: «دریا ضعیفه؛ حسِ واقعی و آرامش
        # نمیده؛ جزیره و دریا یکی شدن»):
        #   * گرادیانِ عمقِ شعاعی: حلقه‌ی فیروزه‌ایِ کم‌عمقِ روشن چسبیده به ساحل
        #     → آبیِ عمیقِ آرام دورتر — خطِ ساحل همیشه خوانا
        #   * موجِ کوچکِ کند (آرامش) + مواجِ ریزِ دوم روی نرمال‌ها (زندگی)
        #   * براقیتِ خورشید (ROUGHNESS پایین + SPECULAR بالا) — حسِ واقعیِ آب
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
uniform vec3 shallow_col : source_color = vec3(0.490, 0.706, 0.659);
uniform vec3 deep_col : source_color = vec3(0.216, 0.412, 0.470);
uniform vec2 island_center = vec2(0.0, 0.0);
uniform float island_radius = 12.0;
uniform float wave_speed = 0.15;
uniform float wave_height = 0.020;
uniform float wave_freq = 0.7;
uniform float normal_strength = 0.32;
uniform float fresnel = 0.20;
varying float vwave;
varying vec3 vwp;
float wave_h(vec2 p, float t) {
        return sin(p.x * wave_freq + t * wave_speed * 2.0) * 0.65
                + cos(p.y * wave_freq * 1.35 + t * wave_speed * 1.55) * 0.35;
}
void vertex() {
        vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        vwp = wp;
        float h = wave_h(wp.xz, TIME);
        VERTEX.y += h * wave_height;
        vwave = h;
        float e = 0.45;
        float hx = wave_h(wp.xz + vec2(e, 0.0), TIME) - wave_h(wp.xz - vec2(e, 0.0), TIME);
        float hz = wave_h(wp.xz + vec2(0.0, e), TIME) - wave_h(wp.xz - vec2(0.0, e), TIME);
        NORMAL = normalize(vec3(-hx * wave_height / e * 40.0 * normal_strength, 1.0,
                        -hz * wave_height / e * 40.0 * normal_strength));
}
void fragment() {
        // عمقِ شعاعی دور جزیره + لرزشِ زاویه‌ای تا لبه، ساحلیِ ارگانیک بماند
        float d = length(vwp.xz - island_center);
        float ang = atan(vwp.z - island_center.y, vwp.x - island_center.x);
        float wob = sin(ang * 4.0) * 0.6 + sin(ang * 7.0 + 1.7) * 0.4;
        float shore = 1.0 - smoothstep(island_radius + 0.5 + wob,
                        island_radius + 6.0 + wob, d);
        float m = smoothstep(-0.8, 1.0, vwave);
        vec3 col = mix(deep_col, shallow_col, clamp(shore + 0.10 * m, 0.0, 1.0));
        float fr = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
        col = mix(col, vec3(0.90, 0.93, 0.92), fr * fresnel);
        ALBEDO = col;
        // گام ۶R۱۴c — براقیتِ ملایم‌تر: اسپکولارِ تند روی آبِ خاکستریِ مرجع
        // لکه‌ی سفیدِ سوسوزن می‌ساخت؛ مرجع آبِ ماتِ آرام دارد
        ROUGHNESS = 0.46;
        SPECULAR = 0.38;
}
"""
        var mat := ShaderMaterial.new()
        mat.shader = sh
        mat.set_shader_parameter("shallow_col", GameConstants.COL_WATER_SHALLOW)
        mat.set_shader_parameter("deep_col", GameConstants.COL_WATER_DEEP)
        mat.set_shader_parameter("island_center", _island_center)
        mat.set_shader_parameter("island_radius", _island_radius)
        _water.material_override = mat
        _water.position = Vector3(0, SEA_Y, 0)
        add_child(_water)

        # گام ۶R6 — کولایدر آب: هیچ موجودیتِ فیزیکی وارد/از آن عبور نمی‌کند
        # (حرکتِ تحلیلیِ واحدها از قبل با NavGrid از آب دوری می‌کند)
        var water_body := StaticBody3D.new()
        water_body.name = "WaterCollider"
        var wshape := CollisionShape3D.new()
        var wbox := BoxShape3D.new()
        wbox.size = Vector3(320, 0.3, 320)
        wshape.shape = wbox
        wshape.position = Vector3(0, SEA_Y - 0.15, 0)
        water_body.add_child(wshape)
        water_body.collision_layer = 4
        water_body.collision_mask = 0
        add_child(water_body)


# ---------------- کف ساحل (حلقه‌ی سفید دور جزیره — امضای Bad North) ----------------

func _build_foam() -> void:
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        # گام ۶R۱۴ — حلقه‌ی کفِ مرجع: «خطِ تیزِ سفیدِ چسبیده به ساحل» +
        # «هاله‌ی نرمِ کم‌رنگ» بیرونی — آلفای هر رأس داخل رنگِ رأس است؛
        # نبضِ خیلی ملایم فقط حسِ زندگی می‌دهد (قبلاً ۰٫۴۵ چشم‌آزار بود)
        for cy in size:
                for cx in size:
                        if not _land_at(cx, cy):
                                continue
                        var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
                        for dir in dirs:
                                if _land_at(cx + dir.x, cy + dir.y):
                                        continue
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
                                var y := SEA_Y + 0.03
                                # خطِ تیز: ۰٫۰۵ → ۰٫۳۲ متر (آلفا ۰٫۸۵)
                                _foam_quad(st, p1, p2, out3, 0.05, 0.32, y,
                                                0.85, 0.55)
                                # هاله‌ی نرم: ۰٫۳۲ → ۱٫۰ متر (۰٫۳۰ → صفر)
                                _foam_quad(st, p1, p2, out3, 0.32, 1.00, y,
                                                0.30, 0.0)
        var mesh := st.commit()
        _foam = MeshInstance3D.new()
        _foam.mesh = mesh
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
void fragment() {
        float pulse = 0.88 + 0.12 * sin(TIME * 0.9 + (VERTEX.x + VERTEX.z) * 0.0);
        ALBEDO = vec3(0.98, 0.99, 0.98);
        ALPHA = COLOR.a * pulse;
}
"""
        var mat := ShaderMaterial.new()
        mat.shader = sh
        _foam.material_override = mat
        add_child(_foam)


## نوارِ کف بین دو فاصله‌ی بیرون‌سو از لبه‌ی ساحل — آلفای لبه‌ها روی رأس‌ها
func _foam_quad(st: SurfaceTool, p1: Vector3, p2: Vector3, out3: Vector3,
                d0: float, d1: float, y: float, a0: float, a1: float) -> void:
        var q1 := p1 + out3 * d0
        var q2 := p2 + out3 * d0
        var q3 := p2 + out3 * d1
        var q4 := p1 + out3 * d1
        var c1 := Color(1, 1, 1, a0)
        var c2 := Color(1, 1, 1, a1)
        _foam_tri(st, Vector3(q1.x, y, q1.z), c1,
                        Vector3(q2.x, y, q2.z), c1,
                        Vector3(q3.x, y, q3.z), c2)
        _foam_tri(st, Vector3(q1.x, y, q1.z), c1,
                        Vector3(q3.x, y, q3.z), c2,
                        Vector3(q4.x, y, q4.z), c2)


func _foam_tri(st: SurfaceTool, a: Vector3, ca: Color, b: Vector3, cb: Color,
                c: Vector3, cc: Color) -> void:
        for pair in [[a, ca], [b, cb], [c, cc]]:
                st.set_color(pair[1])
                st.set_normal(Vector3.UP)
                st.add_vertex(pair[0])


# ---------------- سایه‌ی نرمِ جزیره روی آب (امضای مرجع) ----------------

func _build_island_shadow() -> void:
        var sz := maxf(_island_radius * 2.3, 10.0)
        var pm := PlaneMesh.new()
        pm.size = Vector2(sz, sz * 0.82)
        var mi := MeshInstance3D.new()
        mi.mesh = pm
        mi.position = Vector3(_island_center.x + 0.9, SEA_Y + 0.015,
                        _island_center.y + 0.7)
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
void fragment() {
        float d = length(UV - vec2(0.5)) * 2.0;
        float a = (1.0 - smoothstep(0.55, 1.0, d)) * 0.15;
        ALBEDO = vec3(0.16, 0.22, 0.22);
        ALPHA = a;
}
"""
        var mat := ShaderMaterial.new()
        mat.shader = sh
        mi.material_override = mat
        add_child(mi)


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
