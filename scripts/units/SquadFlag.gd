class_name SquadFlag
extends Node3D
## پرچم فرمانده دسته — گام ۶R (بازخورد کاربر: «هر دسته یک فرمانده داشته باشد
## که پرچم دستش باشد؛ هر دسته پرچم خاص خودش»).
##
##   * دَرَک چوبی + نوک طلایی + پارچه‌ی موج‌دار (شیدر سینوسی — لبه‌ی آزاد بیشتر)
##   * رنگ پارچه = رنگ دسته از پالت هخامنشی → هر دسته پرچم خودش را دارد
##   * فرمانده = عضو اول دسته؛ با مرگش پرچم به عضو زنده‌ی بعدی منتقل می‌شود
##     (صحنه با reparent منتقل می‌کند)

const FLAG_SHADER := "
shader_type spatial;
uniform vec4 albedo : source_color = vec4(0.9, 0.85, 0.7, 1.0);
uniform float wave_amp = 0.055;
uniform float wave_freq = 8.0;
void vertex() {
        float k = UV.x;
        VERTEX.z += sin(TIME * wave_freq + k * 6.2831) * wave_amp * k;
        VERTEX.y += sin(TIME * wave_freq * 0.63 + k * 4.7) * wave_amp * 0.45 * k;
}
void fragment() {
        ALBEDO = albedo.rgb;
        ROUGHNESS = 0.9;
}"

var _cloth_mat: ShaderMaterial


func _ready() -> void:
        # دَرَک
        var pole := MeshInstance3D.new()
        var pm := CylinderMesh.new()
        pm.top_radius = 0.018
        pm.bottom_radius = 0.024
        pm.height = 1.15
        pole.mesh = pm
        pole.position.y = 0.58
        var wood := StandardMaterial3D.new()
        wood.albedo_color = GameConstants.COL_DOOR_WOOD
        wood.roughness = 0.85
        pole.material_override = wood
        add_child(pole)

        # نوک طلایی
        var tip := MeshInstance3D.new()
        var tm := SphereMesh.new()
        tm.radius = 0.045
        tm.height = 0.09
        tip.mesh = tm
        tip.position.y = 1.18
        var gold := StandardMaterial3D.new()
        gold.albedo_color = GameConstants.COL_GOLD
        gold.metallic = 0.5
        gold.roughness = 0.35
        tip.material_override = gold
        add_child(tip)

        # پارچه‌ی موج‌دار — صفحه‌ی عمودی؛ لبه‌ی چپ چسبیده به دَرَک
        var cloth := MeshInstance3D.new()
        var plane := PlaneMesh.new()
        plane.size = Vector2(GameConstants.SQUAD_FLAG_W, GameConstants.SQUAD_FLAG_H)
        plane.subdivide_width = 8
        plane.subdivide_depth = 3
        cloth.mesh = plane
        # صفحه‌ی XZ → عمودی رو به ±Z؛ لبه‌ی آزاد پرچم به سمت +X مدل
        cloth.rotation_degrees.x = -90.0
        cloth.position = Vector3(GameConstants.SQUAD_FLAG_W * 0.5, 1.06, 0.0)
        _cloth_mat = ShaderMaterial.new()
        var sh := Shader.new()
        sh.code = FLAG_SHADER
        _cloth_mat.shader = sh
        _cloth_mat.set_shader_parameter("albedo", GameConstants.COL_IVORY)
        cloth.material_override = _cloth_mat
        add_child(cloth)


## رنگ پرچم = رنگ دسته (هر دسته پرچم خاص خودش)
func set_color(c: Color) -> void:
        if _cloth_mat != null:
                _cloth_mat.set_shader_parameter("albedo", c)


func flag_color() -> Color:
        if _cloth_mat != null:
                return _cloth_mat.get_shader_parameter("albedo")
        return GameConstants.COL_IVORY
