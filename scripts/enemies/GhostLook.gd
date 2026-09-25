class_name GhostLook
extends RefCounted
## گام ۶R8 — بدنه‌ی «شبح» مهاجمان (تصویرِ مرجعِ کاربر — سربازِ شنل‌پوشِ مرگ):
##   * شنلِ زنگیِ شناور: چرخشِ پروفایلِ بدنه دورِ محورِ Y + لبه‌ی پایینِ پاره‌پاره
##   * گرادیانِ عمودی: بنفشِ خیلی‌تیره در بالا → ارغوانیِ محو در پایین (مثلِ مرجع)
##   * ماسکِ بیضیِ استخوانی فقط با دو چشمِ مربعیِ سیاه — بدونِ دهان و بینی
##   * بدونِ پا — شناور روی زمین (شناوری در EnemyBase._bob_visual)
## همان رابطِ ChibiLook (shader_mat/set_base/set_flash/body_mesh/add_face/
## fade_parts) تا EnemyBase فقط نامِ کلاس را عوض کند.
## رنگ‌ها فقط از پالتِ شبح (GameConstants.COL_GHOST_*) — قانونِ پالتِ HEX.

const SHADER_CODE := "
shader_type spatial;
uniform vec3 top_color : source_color = vec3(0.125, 0.06, 0.125);
uniform vec3 bottom_color : source_color = vec3(0.43, 0.37, 0.43);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
varying float vh;
void vertex() {
        vh = clamp(VERTEX.y / 0.845, 0.0, 1.0);
}
void fragment() {
        vec3 base = mix(bottom_color, top_color, smoothstep(0.0, 1.0, vh));
        ALBEDO = mix(base, vec3(1.0), flash);
        ROUGHNESS = 0.8;
        SPECULAR = 0.15;
}"

## ارتفاعِ کل بدنه — تجهیزاتِ زیرکلاس‌ها حولِ این چیده می‌شوند
const BODY_HI := 0.845
## مرکز و جلوی ماسک (فرزندِ تنه — با بُب و یورش هم‌حرکت)
const FACE_Y := 0.72
const FACE_Z := 0.115
const EYE_Y := 0.735
const EYE_Z := 0.166

## پروفایلِ شنل — (ارتفاع، شعاع) از نوکِ کلاه تا پایینِ دامن
const PROFILE := [
        Vector2(0.845, 0.018),
        Vector2(0.825, 0.07),
        Vector2(0.785, 0.118),
        Vector2(0.72, 0.146),
        Vector2(0.635, 0.152),
        Vector2(0.545, 0.172),
        Vector2(0.43, 0.205),
        Vector2(0.31, 0.228),
        Vector2(0.185, 0.242),
]
const SEGMENTS := 12          # دندانه‌های لبه — ۶ نوک + ۶ فرورفتگی
const HEM_POINT_Y := 0.062    # نوک‌های پاره‌ی شنل
const HEM_NOTCH_Y := 0.03     # فرورفتگی‌های بینِ نوک‌ها
const HEM_POINT_R := 0.248
const HEM_NOTCH_R := 0.226

static var _cached_body: ArrayMesh


## متریالِ گرادیانِ شبح — از رنگِ پایه‌ی کلاس مشتق می‌شود
static func shader_mat(base: Color) -> ShaderMaterial:
        var sh := Shader.new()
        sh.code = SHADER_CODE
        var m := ShaderMaterial.new()
        m.shader = sh
        set_base(m, base)
        return m


## به‌روزرسانی رنگ پایه — بالا: نیم‌تیره (تقریباً سیاهِ بنفش)، پایین: محوِ ارغوانی
## (رنگِ پایه‌ی هر کلاس فقط ته‌رنگِ ظریف می‌دهد — هویتِ بصری از مرجع می‌آید)
static func set_base(m: ShaderMaterial, c: Color) -> void:
        if m == null:
                return
        m.set_shader_parameter("top_color", c.darkened(0.5))
        m.set_shader_parameter("bottom_color", c.lightened(0.38))


static func set_flash(m: ShaderMaterial, f: float) -> void:
        if m != null:
                m.set_shader_parameter("flash", f)


## تنه‌ی شنل — لاتِه‌ی پروفایل + لبه‌ی پاره‌پاره + زیرِ بسته (یک بار ساخته می‌شود)
static func body_mesh() -> ArrayMesh:
        if _cached_body != null:
                return _cached_body
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var rings: Array = []
        for p in PROFILE:
                rings.append(_ring(p.x, p.y))
        # لبه‌ی پاره‌پاره — نوک‌ها و فرورفتگی‌های یک‌درمیان
        var hem: Array = []
        for j in SEGMENTS:
                var point := (j % 2) == 0
                hem.append(_vertex_at(j, HEM_POINT_Y if point else HEM_NOTCH_Y,
                                HEM_POINT_R if point else HEM_NOTCH_R))
        rings.append(hem)
        # زیرِ شنل — جمع‌شده به داخل (سایه‌ی زیرِ شبح)
        rings.append(_ring(0.0, 0.09))
        for i in range(rings.size() - 1):
                _band(st, rings[i], rings[i + 1])
        var cap_ring: Array = rings[rings.size() - 1]
        var c := Vector3(0.0, 0.015, 0.0)
        for j in SEGMENTS:
                var j1 := (j + 1) % SEGMENTS
                st.add_vertex(cap_ring[j])
                st.add_vertex(c)
                st.add_vertex(cap_ring[j1])
        st.generate_normals()
        _cached_body = st.commit()
        return _cached_body


## ردیفِ کاملِ دورِ محور — آرایه‌ی رئوس
static func _ring(y: float, r: float) -> Array:
        var out: Array = []
        for j in SEGMENTS:
                out.append(_vertex_at(j, y, r))
        return out


static func _vertex_at(j: int, y: float, r: float) -> Vector3:
        var a := TAU * float(j) / float(SEGMENTS)
        return Vector3(r * sin(a), y, r * cos(a))


## نوارِ بینِ دو ردیف — پیچش مثلث‌ها طوری که نرمال‌ها بیرون‌رو باشند
static func _band(st: SurfaceTool, upper: Array, lower: Array) -> void:
        for j in SEGMENTS:
                var j1 := (j + 1) % SEGMENTS
                st.add_vertex(upper[j])
                st.add_vertex(lower[j])
                st.add_vertex(lower[j1])
                st.add_vertex(upper[j])
                st.add_vertex(lower[j1])
                st.add_vertex(upper[j1])


## ماسکِ بیضیِ استخوانی روی جلوی کلاه + دو چشمِ مربعیِ سیاه
static func add_face(body: MeshInstance3D) -> void:
        var face := MeshInstance3D.new()
        var fm := SphereMesh.new()
        fm.radius = 0.095
        fm.height = 0.19
        fm.radial_segments = 12
        fm.rings = 7
        face.mesh = fm
        face.scale = Vector3(1.0, 1.05, 0.52)
        face.position = Vector3(0, FACE_Y, FACE_Z)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = GameConstants.COL_GHOST_BONE
        mat.roughness = 0.62
        face.material_override = mat
        body.add_child(face)
        var emat := StandardMaterial3D.new()
        emat.albedo_color = Color("100a10")
        emat.roughness = 0.5
        for sx in [-1.0, 1.0]:
                var eye := MeshInstance3D.new()
                var bm := BoxMesh.new()
                bm.size = Vector3(0.024, 0.032, 0.016)
                eye.mesh = bm
                eye.position = Vector3(0.036 * sx, EYE_Y, EYE_Z)
                eye.material_override = emat
                body.add_child(eye)


## دستِ خاکستریِ کوچک — برای گرفتنِ شمشیر/نیزه (مثلِ مرجع)
static func add_hand(root: Node3D, pos: Vector3) -> void:
        var hand := MeshInstance3D.new()
        var hm := SphereMesh.new()
        hm.radius = 0.038
        hm.height = 0.076
        hm.radial_segments = 8
        hm.rings = 5
        hand.mesh = hm
        hand.position = pos
        var mat := StandardMaterial3D.new()
        mat.albedo_color = GameConstants.COL_GHOST_HAND
        mat.roughness = 0.75
        hand.material_override = mat
        root.add_child(hand)


## همه‌ی مش‌های شاخه برای محوشدنِ مرگ — پرچمِ SquadFlag مستثنا
## (پرچم بعد از مرگِ فرمانده به عضو بعدی منتقل می‌شود و نباید محو شود)
static func fade_parts(root: Node3D) -> Array:
        var out: Array = []
        var stack: Array = [root]
        while stack.size() > 0:
                var n: Node = stack.pop_back()
                for c in n.get_children():
                        if c is SquadFlag:
                                continue
                        stack.push_back(c)
                if n is MeshInstance3D:
                        out.append(n)
        return out
