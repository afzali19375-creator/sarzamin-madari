class_name ArrowProjectile
extends Node3D
## تیر بالستیک — گام ۵ (لایه ۳) + گام ۶ (سپر سنگین، امضای آسیب جهت‌دار).
## پرتاب با حل معکوس ساده: زمان از فاصله‌ی افقی و سرعت، سرعت عمودی از جاذبه.
## گام ۶R9 — (بازخورد کاربر: «پرتاب تیر کمان‌ها بهتر بشود»):
##   * تیرِ چندقطعه‌ای: ساقِ روشن + سره‌ی فولادی + پرِ متقاطعِ دم
##   * قوسِ خواناتر: پرواز کمی کشیده‌تر می‌شود تا فرازِ تیر دیده شود
##   * تیرِ خطاخورده در زمین می‌نشیند (چند ثانیه، بعد محو) — میدانِ پر از تیر
## برخورد با دشمن (گروه «hostiles») → ثبت ضربه + خون؛ برخورد با زمین → فرونشستن.
## گام ۶: اگر هدف projectile_deflected(dir) را داشته باشد و سپرش رو به تیر باشد،
## تیر خنثی می‌شود (جرقه‌ی کوچک، بدون آسیب — Hoplite سنگین §۶).

const MAX_LIFE := 6.0
const HIT_RADIUS := GameConstants.ARROW_HIT_RADIUS
const ARC_BOOST := 1.22                 # کششِ پرواز → قوسِ بلندتر و خواناتر
const STUCK_SECONDS := 5.0              # تیرِ فرونشسته در زمین

var _vel := Vector3.ZERO
var _life := 0.0
var _stuck := false
var _mesh: MeshInstance3D
var _fade_meshes: Array = []                  # برای محوِ تیرِ فرونشسته
var ground_provider: Callable = Callable()   # IslandGround.height_at_world
## گام ۶R2 — شلیک‌کننده: به هدف پاس می‌شود تا مهاجمِ تلافی‌گر بداند کیست
var shooter: Node3D = null


static func fire(parent: Node, from: Vector3, to: Vector3,
                ground_height: Callable = Callable(),
                from_shooter: Node3D = null) -> ArrowProjectile:
        var a := ArrowProjectile.new()
        a.ground_provider = ground_height
        a.shooter = from_shooter
        parent.add_child(a)
        a.global_position = from
        var flat := Vector2(to.x - from.x, to.z - from.z)
        var dist := flat.length()
        var g := GameConstants.ARROW_GRAVITY
        var speed := GameConstants.ARROW_SPEED
        # گام ۶R9 — قوسِ خوانا: زمان پرواز ۲۲٪ کشیده‌تر از مستقیم‌ترین حل
        var t := maxf(dist / speed * ARC_BOOST, 0.14)
        var v_flat := flat / t
        var v_up := (to.y - from.y) / t + 0.5 * g * t  # حل بالستیک
        a._vel = Vector3(v_flat.x, v_up, v_flat.y)
        return a


func _ready() -> void:
        add_to_group("arrows")
        _build_arrow_mesh()


## گام ۶R9 — تیرِ چندقطعه‌ای: ساق + سره‌ی فولادی + پرِ دم (خوانا در پرواز)
## ⚠️ نکته‌ی look_at: محور ‎−Z به سمت حرکت است — سره روی ‎−Z ساخته می‌شود
func _build_arrow_mesh() -> void:
        _mesh = MeshInstance3D.new()
        add_child(_mesh)
        var fletch_parts: Array = []
        # ساقِ روشن
        var shaft := MeshInstance3D.new()
        var sm := CylinderMesh.new()
        sm.top_radius = 0.011
        sm.bottom_radius = 0.011
        sm.height = 0.5
        shaft.mesh = sm
        shaft.rotation_degrees.x = 90.0
        shaft.position.z = 0.04
        var wood := StandardMaterial3D.new()
        wood.albedo_color = Color("d9c49a")
        wood.roughness = 0.7
        shaft.material_override = wood
        _mesh.add_child(shaft)
        # سره‌ی فولادی — جلو (‎−Z)
        var tip := MeshInstance3D.new()
        var tm := CylinderMesh.new()
        tm.top_radius = 0.001
        tm.bottom_radius = 0.02
        tm.height = 0.09
        tip.mesh = tm
        tip.rotation_degrees.x = 90.0
        tip.position.z = -0.24
        var steel := StandardMaterial3D.new()
        steel.albedo_color = GameConstants.STEEL_BLADE
        steel.metallic = 0.7
        steel.roughness = 0.3
        tip.material_override = steel
        _mesh.add_child(tip)
        # پرِ دم — دو ورقِ متقاطعِ روشن (عقبِ تیر)
        for ry in [0.0, 90.0]:
                var fl := MeshInstance3D.new()
                var fm := BoxMesh.new()
                fm.size = Vector3(0.055, 0.007, 0.1)
                fl.mesh = fm
                fl.position.z = 0.26
                fl.rotation_degrees.z = ry
                var fmat := StandardMaterial3D.new()
                fmat.albedo_color = GameConstants.COL_CRIMSON
                fmat.roughness = 0.8
                fl.material_override = fmat
                _mesh.add_child(fl)
                fletch_parts.append(fl)
        _fade_meshes = [_mesh, shaft, tip] + fletch_parts


func _physics_process(delta: float) -> void:
        if _stuck:
                return   # فرونشسته — فقط منتظر محوشدن است
        _life += delta
        if _life > MAX_LIFE:
                queue_free()
                return
        _vel.y -= GameConstants.ARROW_GRAVITY * delta
        global_position += _vel * delta
        # جهت تیر = راستای سرعت
        if _vel.length_squared() > 0.0001:
                look_at(global_position + _vel, Vector3.UP)
        for n in get_tree().get_nodes_in_group("hostiles"):
                var h := n as Node3D
                if h == null or not h.is_inside_tree():
                        continue
                if h.has_method("is_alive") and not h.is_alive():
                        continue
                if h.has_method("is_dead") and h.is_dead():
                        continue
                if global_position.distance_to(h.global_position + Vector3(0, 0.4, 0)) \
                                <= HIT_RADIUS:
                        var v_norm := _vel.normalized()
                        if h.has_method("projectile_deflected") \
                                        and h.projectile_deflected(v_norm):
                                _spawn_deflect_ping(h.global_position + Vector3(0, 0.45, 0))
                                queue_free()
                                return
                        if h.has_method("take_hit"):
                                h.take_hit(1, v_norm, shooter)
                        queue_free()
                        return

        # برخورد با زمین → فرونشستن در خاک (گام ۶R9) + محوِ نرم بعداً
        if ground_provider.is_valid():
                var xz := Vector2(global_position.x, global_position.z)
                var gy := float(ground_provider.call(xz))
                if global_position.y <= gy + 0.02:
                        _stick_in_ground(gy)


## تیر در زمین می‌نشیند — نوکش زیر خاک با زاویه‌ی فراز؛ بعد محوِ نرم
func _stick_in_ground(gy: float) -> void:
        _stuck = true
        global_position.y = gy + 0.09
        set_physics_process(false)
        var tw := create_tween()
        tw.tween_interval(STUCK_SECONDS)
        # محوِ هم‌زمانِ همه‌ی قطعه‌ها (استپِ جدا — نه با تأخیرِ دوبل)
        tw.tween_callback(func() -> void:
                for m in _fade_meshes:
                        if m is GeometryInstance3D and is_instance_valid(m):
                                var mt := (m as GeometryInstance3D).create_tween()
                                mt.tween_property(m, "transparency", 1.0, 1.2))
        tw.tween_interval(1.3)
        tw.tween_callback(queue_free)


## جرقه‌ی کوچکِ خنثی‌شدن تیر روی سپر (§۱۰ — حالت دیداری، بدون عدد)
func _spawn_deflect_ping(at: Vector3) -> void:
        var ping := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 0.07
        sm.height = 0.14
        ping.mesh = sm
        var m := StandardMaterial3D.new()
        m.albedo_color = Color(1, 1, 1, 0.9)
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        ping.material_override = m
        var parent := get_parent()
        if parent == null:
                return
        parent.add_child(ping)
        ping.global_position = at
        var tw := ping.create_tween()
        tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
        tw.tween_callback(ping.queue_free)
