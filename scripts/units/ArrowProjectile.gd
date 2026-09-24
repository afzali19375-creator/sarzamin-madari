class_name ArrowProjectile
extends Node3D
## تیر بالستیک — گام ۵ (لایه ۳) + گام ۶ (سپر سنگین، امضای آسیب جهت‌دار).
## پرتاب با حل معکوس ساده: زمان از فاصله‌ی افقی و سرعت، سرعت عمودی از جاذبه.
## برخورد با دشمن (گروه «hostiles») → ثبت ضربه + ناپدیدی؛ برخورد با زمین → ناپدیدی.
## گام ۶: اگر هدف projectile_deflected(dir) را داشته باشد و سپرش رو به تیر باشد،
## تیر خنثی می‌شود (جرقه‌ی کوچک، بدون آسیب — Hoplite سنگین §۶).
## زمین (IslandGround) از صحنه تزریق می‌شود — هیچ وابستگی به صحنه‌ی خاص.

const MAX_LIFE := 4.0
const HIT_RADIUS := GameConstants.ARROW_HIT_RADIUS

var _vel := Vector3.ZERO
var _life := 0.0
var _mesh: MeshInstance3D
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
        var t := maxf(dist / speed, 0.12)             # زمان پرواز
        var v_flat := flat / t
        var v_up := (to.y - from.y) / t + 0.5 * g * t  # حل بالستیک
        a._vel = Vector3(v_flat.x, v_up, v_flat.y)
        return a


func _ready() -> void:
        add_to_group("arrows")
        _mesh = MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.025, 0.025, 0.55)
        _mesh.mesh = bm
        var m := StandardMaterial3D.new()
        m.albedo_color = GameConstants.COL_BEACH_SAND
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _mesh.material_override = m
        add_child(_mesh)


func _physics_process(delta: float) -> void:
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

        # برخورد با زمین
        if ground_provider.is_valid():
                var xz := Vector2(global_position.x, global_position.z)
                if global_position.y <= float(ground_provider.call(xz)) + 0.02:
                        queue_free()


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
