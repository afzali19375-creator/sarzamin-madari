class_name ArrowProjectile
extends Node3D
## تیر بالستیک — گام ۵ (نمایش لایه ۳ روی کوله‌ی تمرین) و زیربنای گام ۶.
## پرتاب با حل معکوس ساده: زمان از فاصله‌ی افقی و سرعت، سرعت عمودی از جاذبه.
## برخورد با دشمن (گروه «hostiles») → ثبت ضربه + ناپدیدی؛ برخورد با زمین → ناپدیدی.
## زمین (IslandGround) از صحنه تزریق می‌شود — هیچ وابستگی به صحنه‌ی خاص.

const MAX_LIFE := 4.0
const HIT_RADIUS := GameConstants.ARROW_HIT_RADIUS

var _vel := Vector3.ZERO
var _life := 0.0
var _mesh: MeshInstance3D
var ground_provider: Callable = Callable()   # IslandGround.height_at_world


static func fire(parent: Node, from: Vector3, to: Vector3,
                ground_height: Callable = Callable()) -> ArrowProjectile:
        var a := ArrowProjectile.new()
        a.ground_provider = ground_height
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
                if global_position.distance_to(h.global_position + Vector3(0, 0.4, 0)) \
                                <= HIT_RADIUS:
                        if h.has_method("take_hit"):
                                h.take_hit()
                        queue_free()
                        return

        # برخورد با زمین
        if ground_provider.is_valid():
                var xz := Vector2(global_position.x, global_position.z)
                if global_position.y <= float(ground_provider.call(xz)) + 0.02:
                        queue_free()
