class_name BuildingBase
extends Node3D
## ساختمان جزیره — گام ۶R (بازخورد کاربر: «سربازهای دشمن خانه‌ها را با پرتاب
## مشعل آتش بزنند»).
##
##   * جان دارد: هر مشعل برخوردی ۱ آسیب — با HOUSE_TORCH_HP مشعل آتش می‌گیرد
##   * آتش: شعله‌های نبض‌دار (طلایی/سرخ پالت) + نور + دود؛ دیوارها کم‌کم ذغالی
##   * پس از FIRE_DESTROY_SECONDS → فروریختن: تیره‌شدن کل + فرورفتن در زمین
##     (تلی از آوار می‌ماند؛ سلول‌های NavGrid مسدود می‌مانند)
##   * سیگنال‌ها: ignited / burned_down — صحنه تُست و منطق گاریسون را وصل می‌کند
##
## آوار و آتش فقط از پالت هخامنشی: COL_CRIMSON / COL_GOLD / COL_DOOR_WOOD /
## COL_ROCK_DARK. بدون عدد روی صفحه (§۱۰).

signal ignited(building: BuildingBase)
signal burned_down(building: BuildingBase)

var max_hp := GameConstants.HOUSE_TORCH_HP
var hp := GameConstants.HOUSE_TORCH_HP
var burning := false
var burned := false

var _mats: Array[StandardMaterial3D] = []     # ماتریال‌های ثبت‌شده برای ذغالی‌شدن
var _base_colors: Array[Color] = []
var _flames: Array[MeshInstance3D] = []
var _smokes: Array[MeshInstance3D] = []
var _fire_light: OmniLight3D
var _burn_left := GameConstants.FIRE_DESTROY_SECONDS
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
        _rng.seed = hash("building:" + str(get_instance_id()))
        _t = _rng.randf() * TAU


## ثبت ماتریال‌های بصری — IslandProps هنگام ساخت مش‌ها صدا می‌زند
func register_material(m: StandardMaterial3D) -> void:
        if m == null or _mats.has(m):
                return
        _mats.append(m)
        _base_colors.append(m.albedo_color)


func _process(delta: float) -> void:
        _t += delta
        if not burning or burned:
                return
        _burn_left -= delta
        # شعله‌های نبض‌دار — هر شعله فاز خودش را دارد
        for i in _flames.size():
                var f := _flames[i]
                var ph := float(i) * 2.1
                var k := 0.75 + 0.25 * sin(_t * 11.0 + ph)
                f.scale = Vector3(k, 1.0 + 0.28 * sin(_t * 8.0 + ph * 1.7), k)
                f.rotation.y += delta * (2.0 + float(i))
        # دود بالا رونده
        for i in _smokes.size():
                var s := _smokes[i]
                var cyc := fmod(_t * 0.45 + float(i) * 0.33, 1.0)
                s.position.y = 1.4 + cyc * 1.6
                var sk := 0.9 + cyc * 1.5
                s.scale = Vector3(sk, sk, sk)
        if _fire_light != null:
                _fire_light.light_energy = 1.5 + 0.5 * sin(_t * 13.0)
        # ذغالی‌شدن تدریجی دیوارها
        var burn_k := 1.0 - clampf(_burn_left / GameConstants.FIRE_DESTROY_SECONDS, 0.0, 1.0)
        for i in _mats.size():
                var target := _base_colors[i].lerp(GameConstants.COL_ROCK_DARK, 0.55 * burn_k) \
                                .lerp(Color(0.08, 0.07, 0.06), 0.75 * burn_k)
                _mats[i].albedo_color = _mats[i].albedo_color.lerp(target, clampf(2.0 * delta, 0.0, 1.0))
        if _burn_left <= 0.0:
                _collapse()


# ---------------- آسیب و آتش ----------------

## مشعل برخوردی / ضربه — هر برخورد ۱ آسیب؛ رسیدن به صفر = آتش
func take_hit(dmg: int = 1) -> void:
        if burning or burned:
                return
        hp -= dmg
        _hit_flash()
        if hp <= 0:
                ignite()


func _hit_flash() -> void:
        for i in _mats.size():
                _mats[i].albedo_color = _base_colors[i].lerp(Color.WHITE, 0.55)
        var tw := create_tween()
        tw.tween_interval(0.09)
        tw.tween_callback(_restore_colors)


func _restore_colors() -> void:
        if burning:
                return
        for i in _mats.size():
                _mats[i].albedo_color = _base_colors[i]


func ignite() -> void:
        if burning or burned:
                return
        burning = true
        _build_fire_visuals()
        ignited.emit(self)


func _build_fire_visuals() -> void:
        # شعله‌ها — مخروط‌های درخشان از پالت (طلایی + سرخ پارسی)
        var fire_specs := [
                {"pos": Vector3(0.0, 1.15, 0.0), "r": 0.34, "col": GameConstants.COL_GOLD},
                {"pos": Vector3(0.4, 0.95, 0.25), "r": 0.24, "col": GameConstants.COL_CRIMSON},
                {"pos": Vector3(-0.38, 0.9, -0.3), "r": 0.2, "col": GameConstants.COL_CRIMSON.lerp(GameConstants.COL_GOLD, 0.4)},
        ]
        for spec in fire_specs:
                var f := MeshInstance3D.new()
                var cm := CylinderMesh.new()
                cm.top_radius = 0.02
                cm.bottom_radius = spec["r"]
                cm.height = 0.75
                cm.radial_segments = 8
                f.mesh = cm
                f.position = spec["pos"]
                var fm := StandardMaterial3D.new()
                fm.albedo_color = spec["col"]
                fm.emission_enabled = true
                fm.emission = spec["col"]
                fm.emission_energy_multiplier = 2.2
                fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                fm.albedo_color.a = 0.92
                f.material_override = fm
                add_child(f)
                _flames.append(f)
        # دود — کره‌های خاکستری نیمه‌شفاف
        for i in 3:
                var s := MeshInstance3D.new()
                var sm := SphereMesh.new()
                sm.radius = 0.22
                sm.height = 0.44
                s.mesh = sm
                var sm2 := StandardMaterial3D.new()
                sm2.albedo_color = Color(0.25, 0.24, 0.23, 0.35)
                sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                s.material_override = sm2
                s.position = Vector3(0, 1.4 + float(i) * 0.3, 0)
                add_child(s)
                _smokes.append(s)
        # نور آتش
        _fire_light = OmniLight3D.new()
        _fire_light.light_color = GameConstants.COL_GOLD
        _fire_light.omni_range = 5.5
        _fire_light.light_energy = 1.6
        _fire_light.position.y = 1.2
        add_child(_fire_light)


## فروریختن — تیره‌شدن کل + فرورفتن در زمین؛ تله‌ی آوار می‌ماند (آخر صحنه)
func _collapse() -> void:
        burned = true
        burning = false
        # خاموشی شعله‌ها
        for f in _flames:
                var tw := create_tween()
                tw.tween_property(f, "scale", Vector3(0.05, 0.02, 0.05), 0.5)
                tw.tween_callback(f.queue_free)
        _flames.clear()
        for s in _smokes:
                var tw2 := create_tween()
                tw2.tween_property(s, "position:y", s.position.y + 1.2, 1.2)
                tw2.parallel().tween_callback(s.queue_free)
        _smokes.clear()
        if _fire_light != null:
                var tw3 := create_tween()
                tw3.tween_property(_fire_light, "light_energy", 0.0, 0.8)
                tw3.tween_callback(_fire_light.queue_free)
                _fire_light = null
        # فرورفتن آوار + تیرگی کامل
        var y0 := position.y
        var tw4 := create_tween()
        tw4.tween_property(self, "position:y", y0 - 0.32, 1.1) \
                        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
        burned_down.emit(self)
