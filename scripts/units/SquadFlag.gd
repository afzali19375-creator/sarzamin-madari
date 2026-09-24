class_name SquadFlag
extends Node3D
## پرچم فرمانده دسته — گام ۶R (بازخورد کاربر: «هر دسته یک فرمانده داشته باشد
## که پرچم دستش باشد؛ هر دسته پرچم خاص خودش»).
##
## گام ۶R2 — بازخورد کاربر: «بهتره پرچم‌ها واضح‌تر بشه»:
##   * پرچم بزرگ‌تر (۰.۸×۰.۵۲m) با دَرَک بلندتر (۱.۵m) — از پشت سربازها دیده می‌شود
##   * حاشیه‌ی عاجی دور پارچه + درخشش ملایم رنگ دسته (EMISSION) — خوانا در هر زمینه
##   * موجِ پررنگ‌تر (دامنه ۰.۰۸۵) تا در نگاه اول «پرچم» شمرده شود
##
##   * رنگ پارچه = رنگ دسته از پالت هخامنشی → هر دسته پرچم خودش را دارد
##   * فرمانده = عضو اول دسته؛ با مرگش پرچم به عضو زنده‌ی بعدی منتقل می‌شود
##     (صحنه با reparent منتقل می‌کند)

const FLAG_SHADER := "
shader_type spatial;
uniform vec4 albedo : source_color = vec4(0.9, 0.85, 0.7, 1.0);
uniform float wave_amp = 0.085;
uniform float wave_freq = 8.0;
void vertex() {
        float k = UV.x;
        VERTEX.z += sin(TIME * wave_freq + k * 6.2831) * wave_amp * k;
        VERTEX.y += sin(TIME * wave_freq * 0.63 + k * 4.7) * wave_amp * 0.45 * k;
}
void fragment() {
        // گام ۶R2 — حاشیه‌ی عاجی دور پارچه + درخشش ملایم: پرچم واضح در هر زمینه
        float bx = min(UV.x, 1.0 - UV.x);
        float by = min(UV.y, 1.0 - UV.y);
        float border = 1.0 - clamp(min(bx, by) * 7.0, 0.0, 1.0);
        vec3 cloth = albedo.rgb;
        vec3 trim = vec3(0.94, 0.90, 0.76);
        ALBEDO = mix(cloth, trim, border * 0.92);
        EMISSION = cloth * (0.28 - border * 0.2);
        ROUGHNESS = 0.9;
}"

var _cloth_mat: ShaderMaterial


func _ready() -> void:
        var pole_h := GameConstants.SQUAD_FLAG_POLE_H
        # دَرَک
        var pole := MeshInstance3D.new()
        var pm := CylinderMesh.new()
        pm.top_radius = 0.02
        pm.bottom_radius = 0.028
        pm.height = pole_h
        pole.mesh = pm
        pole.position.y = pole_h * 0.5
        var wood := StandardMaterial3D.new()
        wood.albedo_color = GameConstants.COL_DOOR_WOOD
        wood.roughness = 0.85
        pole.material_override = wood
        add_child(pole)

        # نوک طلایی
        var tip := MeshInstance3D.new()
        var tm := SphereMesh.new()
        tm.radius = 0.055
        tm.height = 0.11
        tip.mesh = tm
        tip.position.y = pole_h + 0.03
        var gold := StandardMaterial3D.new()
        gold.albedo_color = GameConstants.COL_GOLD
        gold.metallic = 0.5
        gold.roughness = 0.35
        gold.emission_enabled = true
        gold.emission = GameConstants.COL_GOLD
        gold.emission_energy_multiplier = 0.45
        tip.material_override = gold
        add_child(tip)

        # پارچه‌ی موج‌دار — صفحه‌ی عمودی؛ لبه‌ی چپ چسبیده به دَرَک
        var cloth := MeshInstance3D.new()
        var plane := PlaneMesh.new()
        plane.size = Vector2(GameConstants.SQUAD_FLAG_W, GameConstants.SQUAD_FLAG_H)
        plane.subdivide_width = 10
        plane.subdivide_depth = 4
        cloth.mesh = plane
        # صفحه‌ی XZ → عمودی رو به ±Z؛ لبه‌ی آزاد پرچم به سمت +X مدل
        cloth.rotation_degrees.x = -90.0
        cloth.position = Vector3(GameConstants.SQUAD_FLAG_W * 0.5,
                        pole_h - 0.09, 0.0)
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
