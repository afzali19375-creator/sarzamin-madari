class_name ChibiLook
extends RefCounted
## گام ۶R7 — بدنه‌ی «چینی» سربازها (بازخورد کاربر با تصویر مرجع Bad North):
##   * تنه‌ی اشکیِ گِرد: شکمِ کروی + کلاه‌خودِ مخروطیِ نوک‌تیز — یک مشِ ترکیبی
##   * گرادیانِ رنگِ دسته: تیره‌ی اشباع در بالا (کلاه) → محوِ روشن در پایین (شکم)
##   * صورتِ بیضیِ عاجی روی جلوی کلاه + دو پا‌ی کوتاهِ استوانه‌ای
##   * فلشِ سفیدِ ضربه با یونیفرمِ «flash» (بدون جابه‌جایی رنگ پایه)
## متریالِ شیدریِ مشترک: base_color از پالت دسته می‌آید؛ مرگ با
## GeometryInstance3D.transparency محو می‌شود (شیدر همیشه Opaque می‌ماند).

const SHADER_CODE := "
shader_type spatial;
uniform vec3 top_color : source_color = vec3(0.25, 0.36, 0.55);
uniform vec3 bottom_color : source_color = vec3(0.82, 0.88, 0.92);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
varying float vh;
void vertex() {
        vh = clamp((VERTEX.y - 0.115) / 0.73, 0.0, 1.0);
}
void fragment() {
        vec3 base = mix(bottom_color, top_color, smoothstep(0.0, 1.0, vh));
        ALBEDO = mix(base, vec3(1.0), flash);
        ROUGHNESS = 0.72;
        SPECULAR = 0.25;
}"

## محدوده‌ی عمودی بدنه در مختصات محلی مش — برای شیدر و آویزِ صورت
const BODY_LO := 0.115
const BODY_HI := 0.845
## ارتفاعِ کل بدنه — تجهیزاتِ زیرکلاس‌ها حولِ این چیده می‌شوند
const BODY_TOP := 0.845
const BELLY_MID := 0.35
const FACE_Y := 0.42
const FACE_Z := 0.19
const IVORY := Color("f2ead8")

static var _cached_body: ArrayMesh


## متریالِ گرادیانِ دسته — تیره در بالا، محوِ روشن در پایین (تصویر مرجع)
static func shader_mat(base: Color) -> ShaderMaterial:
        var sh := Shader.new()
        sh.code = SHADER_CODE
        var m := ShaderMaterial.new()
        m.shader = sh
        set_base(m, base)
        return m


## به‌روزرسانی رنگ پایه — top تیره‌ی اشباع، bottom محوِ پاستلی
static func set_base(m: ShaderMaterial, c: Color) -> void:
        if m == null:
                return
        m.set_shader_parameter("top_color", c.darkened(0.15))
        m.set_shader_parameter("bottom_color", c.lightened(0.55))


static func set_flash(m: ShaderMaterial, f: float) -> void:
        if m != null:
                m.set_shader_parameter("flash", f)


## تنه‌ی اشکی — شکمِ کروی + کلاهِ مخروطی در یک مشِ ترکیبی (یک بار ساخته می‌شود)
static func body_mesh() -> ArrayMesh:
        if _cached_body != null:
                return _cached_body
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var belly := SphereMesh.new()
        belly.radius = 0.235
        belly.height = 0.47
        belly.radial_segments = 14
        belly.rings = 8
        st.append_from(belly, 0, Transform3D(Basis(), Vector3(0, BELLY_MID, 0)))
        var hood := CylinderMesh.new()
        hood.top_radius = 0.012
        hood.bottom_radius = 0.215
        hood.height = 0.52
        hood.radial_segments = 14
        hood.cap_top = true
        st.append_from(hood, 0, Transform3D(Basis(), Vector3(0, 0.585, 0)))
        st.generate_normals()
        _cached_body = st.commit()
        return _cached_body


## صورتِ بیضیِ عاجی — فرزندِ تنه تا با بُب و یورش هم‌حرکت باشد
static func add_face(body: MeshInstance3D) -> void:
        var face := MeshInstance3D.new()
        var fm := SphereMesh.new()
        fm.radius = 0.075
        fm.height = 0.1
        fm.radial_segments = 10
        fm.rings = 6
        face.mesh = fm
        face.scale = Vector3(1.0, 1.3, 0.55)
        face.position = Vector3(0, FACE_Y, FACE_Z)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = IVORY
        mat.roughness = 0.55
        face.material_override = mat
        body.add_child(face)


## دو پا‌ی کوتاه — ثابت (بدون بُب)؛ رنگِ تیره‌ی پایه
static func add_legs(root: Node3D, base: Color) -> void:
        var mat := StandardMaterial3D.new()
        mat.albedo_color = base.darkened(0.35)
        mat.roughness = 0.8
        for sx in [-1.0, 1.0]:
                var leg := MeshInstance3D.new()
                var lm := CylinderMesh.new()
                lm.top_radius = 0.045
                lm.bottom_radius = 0.05
                lm.height = 0.16
                leg.mesh = lm
                leg.position = Vector3(0.09 * sx, 0.08, 0.005)
                leg.material_override = mat
                root.add_child(leg)


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
