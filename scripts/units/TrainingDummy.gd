class_name TrainingDummy
extends Node3D
## کوله‌ی تمرین — هدفِ نمایش «لایه ۳: واکنش نبرد» در گام ۵.
## جایگزین موقت دشمنان است (Hoplite/Peltast در گام ۶ می‌آیند)؛ گروه «hostiles».
## رنگ‌ها فقط از پالت موجود: بدنه شن ساحلی + پایه چوبی — بدون HEX جدید.
##
## آمار برای تست خودکار: hits (تیرهای خورده) + take_hit() وول کوچک.

var hits := 0
var alive := true

var _wobble_t := 10.0
var _base_rot := 0.0


func _ready() -> void:
        add_to_group("hostiles")

        var straw := StandardMaterial3D.new()
        straw.albedo_color = GameConstants.COL_BEACH_SAND
        straw.roughness = 0.95

        var wood := StandardMaterial3D.new()
        wood.albedo_color = GameConstants.COL_DOOR_WOOD
        wood.roughness = 0.9

        # پایه‌ی چوبی
        var pole := MeshInstance3D.new()
        var pm := CylinderMesh.new()
        pm.top_radius = 0.05
        pm.bottom_radius = 0.07
        pm.height = 0.9
        pole.mesh = pm
        pole.position.y = 0.45
        pole.material_override = wood
        add_child(pole)

        # پایه‌ی چهارپایه
        var leg := MeshInstance3D.new()
        var lm := CylinderMesh.new()
        lm.top_radius = 0.3
        lm.bottom_radius = 0.34
        lm.height = 0.08
        leg.mesh = lm
        leg.position.y = 0.04
        leg.material_override = wood
        add_child(leg)

        # بدنه‌ی کاهی
        var torso := MeshInstance3D.new()
        var tm := CylinderMesh.new()
        tm.top_radius = 0.22
        tm.bottom_radius = 0.26
        tm.height = 0.6
        torso.mesh = tm
        torso.position.y = 1.05
        torso.material_override = straw
        add_child(torso)

        # سرِ کاهی
        var head := MeshInstance3D.new()
        var hm := SphereMesh.new()
        hm.radius = 0.14
        hm.height = 0.28
        head.mesh = hm
        head.position.y = 1.48
        head.material_override = straw
        add_child(head)

        _base_rot = rotation.y


func is_alive() -> bool:
        return alive


func take_hit(dmg: int = 1, _from_dir: Vector3 = Vector3.ZERO) -> void:
        hits += dmg
        _wobble_t = 0.0


func _process(delta: float) -> void:
        if _wobble_t < 0.8:
                _wobble_t += delta
                var k := sin(_wobble_t * 18.0) * (1.0 - _wobble_t / 0.8)
                rotation.z = k * 0.18
                rotation.y = _base_rot + k * 0.3
        else:
                rotation.z = 0.0
                rotation.y = _base_rot
