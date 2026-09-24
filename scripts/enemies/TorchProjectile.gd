class_name TorchProjectile
extends Node3D
## مشعل پرتابی مهاجم — گام ۶R (بازخورد کاربر: «خانه‌ها را با پرتاب مشعل آتش
## بزنند»). همان حل بالستیک نیزه/تیر؛ فقط برخوردش با «ساختمان‌ها» است:
##   * برخورد با BuildingBase → take_hit(1) (با HOUSE_TORCH_HP مشعل آتش می‌گیرد)
##   * برخورد با زمین → دودِ کوتاه و ناپدیدی (شلیک خطا رفته)
## بصری: دسته‌ی چوبی + سرِ درخشان طلایی/سرخ از پالت.

const MAX_LIFE := 4.0
const BUILDING_HIT_RADIUS := 1.25

var _vel := Vector3.ZERO
var _life := 0.0
var _flame: MeshInstance3D
var _t := 0.0
var ground_provider: Callable = Callable()


static func fire(parent: Node, from: Vector3, to: Vector3,
                ground_height: Callable = Callable()) -> TorchProjectile:
        var p := TorchProjectile.new()
        p.ground_provider = ground_height
        parent.add_child(p)
        p.global_position = from
        var flat := Vector2(to.x - from.x, to.z - from.z)
        var dist := flat.length()
        var g := GameConstants.ARROW_GRAVITY
        var speed := GameConstants.TORCH_SPEED
        var t := maxf(dist / speed, 0.14)
        var v_flat := flat / t
        var v_up := (to.y - from.y) / t + 0.5 * g * t
        p._vel = Vector3(v_flat.x, v_up, v_flat.y)
        return p


func _ready() -> void:
        add_to_group("torches")
        # دسته‌ی چوبی
        var stick := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.045, 0.045, 0.42)
        stick.mesh = bm
        var wood := StandardMaterial3D.new()
        wood.albedo_color = GameConstants.COL_DOOR_WOOD
        wood.roughness = 0.9
        stick.material_override = wood
        add_child(stick)
        # سرِ آتشین — گوی درخشان نبض‌دار
        _flame = MeshInstance3D.new()
        var fm := SphereMesh.new()
        fm.radius = 0.09
        fm.height = 0.18
        _flame.mesh = fm
        _flame.position.z = 0.24
        var fl := StandardMaterial3D.new()
        fl.albedo_color = GameConstants.COL_GOLD
        fl.emission_enabled = true
        fl.emission = GameConstants.COL_CRIMSON
        fl.emission_energy_multiplier = 2.6
        _flame.material_override = fl
        add_child(_flame)


func _physics_process(delta: float) -> void:
        _life += delta
        if _life > MAX_LIFE:
                queue_free()
                return
        _t += delta
        _vel.y -= GameConstants.ARROW_GRAVITY * delta
        global_position += _vel * delta
        if _vel.length_squared() > 0.0001:
                look_at(global_position + _vel, Vector3.UP)
        if _flame != null:
                var k := 1.0 + 0.25 * sin(_t * 22.0)
                _flame.scale = Vector3(k, k, k)

        # برخورد با ساختمان → آتش‌زدن
        for n in get_tree().get_nodes_in_group("buildings"):
                var b := n as BuildingBase
                if b == null or not is_instance_valid(b) or b.burning or b.burned:
                        continue
                if global_position.distance_to(b.global_position + Vector3(0, 0.6, 0)) \
                                <= BUILDING_HIT_RADIUS:
                        b.take_hit(1)
                        queue_free()
                        return

        # برخورد با زمین → شلیک خطا رفته
        if ground_provider.is_valid():
                var xz := Vector2(global_position.x, global_position.z)
                if global_position.y <= float(ground_provider.call(xz)) + 0.03:
                        queue_free()
