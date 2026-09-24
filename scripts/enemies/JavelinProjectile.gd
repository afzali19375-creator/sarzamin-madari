class_name JavelinProjectile
extends Node3D
## نیزه‌ی پرتابی پلتاست — گام ۶ (§۶: «قبل از تماس می‌زند»).
## همان حل بالستیک تیر؛ برخورد با سربازان پارسی (گروه «units») → آسیب + ناپدیدی.
## سپر سنگین دشمنی در کار نیست (هدف = بازیکن)؛ آسیب دوستانه به دشمنان ندارد.
## زمین از صحنه تزریق می‌شود (height_at_world) — وابستگی به صحنه‌ی خاص نیست.

const MAX_LIFE := 4.0
const HIT_RADIUS := GameConstants.ARROW_HIT_RADIUS

var _vel := Vector3.ZERO
var _life := 0.0
var _mesh: MeshInstance3D
var ground_provider: Callable = Callable()


static func fire(parent: Node, from: Vector3, to: Vector3,
                ground_height: Callable = Callable()) -> JavelinProjectile:
        var j := JavelinProjectile.new()
        j.ground_provider = ground_height
        parent.add_child(j)
        j.global_position = from
        var flat := Vector2(to.x - from.x, to.z - from.z)
        var dist := flat.length()
        var g := GameConstants.ARROW_GRAVITY
        var speed := GameConstants.JAVELIN_SPEED
        var t := maxf(dist / speed, 0.12)
        var v_flat := flat / t
        var v_up := (to.y - from.y) / t + 0.5 * g * t
        j._vel = Vector3(v_flat.x, v_up, v_flat.y)
        return j


func _ready() -> void:
        add_to_group("javelins")
        _mesh = MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.03, 0.03, 0.6)
        _mesh.mesh = bm
        var m := StandardMaterial3D.new()
        m.albedo_color = GameConstants.COL_CRIMSON
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
        if _vel.length_squared() > 0.0001:
                look_at(global_position + _vel, Vector3.UP)

        for n in get_tree().get_nodes_in_group("units"):
                var u := n as Node3D
                if u == null or not u.is_inside_tree():
                        continue
                if u.has_method("is_dead") and u.is_dead():
                        continue
                if global_position.distance_to(u.global_position + Vector3(0, 0.4, 0)) \
                                <= HIT_RADIUS:
                        if u.has_method("take_hit"):
                                u.take_hit(1, _vel.normalized())
                        queue_free()
                        return

        # برخورد با زمین
        if ground_provider.is_valid():
                var xz := Vector2(global_position.x, global_position.z)
                if global_position.y <= float(ground_provider.call(xz)) + 0.02:
                        queue_free()
