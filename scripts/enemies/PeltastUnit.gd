class_name PeltastUnit
extends EnemyBase
## پلتاست (§۶): پرتاب‌گر — «قبل از تماس می‌زند».
## نزدیک‌ترین سرباز در برد پرتاب → هدف؛ اگر سرباز خیلی نزدیک شد، عقب می‌رود و
## دوباره پرتاب می‌کند. پرتابه: JavelinProjectile (گروه «javelins» → گروه «units»).
## گام ۶R — مشعل‌زنی خانه‌ها برای «همه‌ی مهاجمان» به EnemyBase منتقل شد
## (_house_tick — بدون اشغال خانه، بازخورد کاربر)؛ اینجا فقط:
##   * مشعل روشن در دست (بصری)
##   * ژست اختصاصی پرتاب مشعل (بالا بردن دست)
## بصری: کاراکتر Rogue پک KayKit با تینت شنی؛ نیزه‌ی پرتاب + مشعلِ روشنِ
## دستی حفظ شده‌اند (پرتابه‌ی واقعی)، حمله = انیمیشن Throw مدل.

var javelins_thrown := 0     # برای تست خودکار
var _javelin: MeshInstance3D
var _torch_in_hand: MeshInstance3D


func _init() -> void:
        hp = GameConstants.PELTAST_HP
        move_speed = GameConstants.PELTAST_SPEED
        attack_dmg = 1
        attack_cooldown = GameConstants.PELTAST_COOLDOWN
        aggro_units = GameConstants.PELTAST_RANGE     # از فاصله هدف می‌گیرد
        engage_range = GameConstants.PELTAST_RANGE


func _default_hp() -> int:
        return GameConstants.PELTAST_HP


func _default_color() -> Color:
        return GameConstants.COL_BEACH_SAND


func _model_kind() -> StringName:
        return &"rogue_thrower"


func _build_gear() -> void:
        # نوار سرخ سر (قدِ مدلِ اسکلتی)
        var band := MeshInstance3D.new()
        var bm := TorusMesh.new()
        bm.inner_radius = 0.1
        bm.outer_radius = 0.13
        bm.rings = 10
        bm.ring_segments = 5
        band.mesh = bm
        band.position.y = 0.82
        var bmat := StandardMaterial3D.new()
        bmat.albedo_color = GameConstants.COL_CRIMSON
        bmat.roughness = 0.6
        band.material_override = bmat
        add_child(band)

        # نیزه‌ی پرتاب در دست (پرتابه‌ی واقعی — مدلِ داخل پک پنهان شد)
        _javelin = MeshInstance3D.new()
        var jm := BoxMesh.new()
        jm.size = Vector3(0.025, 0.025, 0.62)
        _javelin.mesh = jm
        _javelin.rotation_degrees = Vector3(-30.0, 0.0, 0.0)
        _javelin.position = Vector3(0.22, 0.55, 0.12)
        var wood := StandardMaterial3D.new()
        wood.albedo_color = GameConstants.COL_DOOR_WOOD
        wood.roughness = 0.85
        _javelin.material_override = wood
        add_child(_javelin)

        # گام ۶R — مشعل روشن در دست دیگر (سمت چپ مدل)
        _torch_in_hand = MeshInstance3D.new()
        var st := BoxMesh.new()
        st.size = Vector3(0.035, 0.035, 0.4)
        _torch_in_hand.mesh = st
        _torch_in_hand.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
        _torch_in_hand.position = Vector3(-0.24, 0.6, 0.1)
        var stick_mat := StandardMaterial3D.new()
        stick_mat.albedo_color = GameConstants.COL_DOOR_WOOD
        stick_mat.roughness = 0.9
        _torch_in_hand.material_override = stick_mat
        add_child(_torch_in_hand)
        # سرِ آتشین مشعل دستی
        var fl := MeshInstance3D.new()
        var fm := SphereMesh.new()
        fm.radius = 0.06
        fm.height = 0.12
        fl.mesh = fm
        fl.position = Vector3(-0.24, 0.82, 0.02)
        var flm := StandardMaterial3D.new()
        flm.albedo_color = GameConstants.COL_GOLD
        flm.emission_enabled = true
        flm.emission = GameConstants.COL_CRIMSON
        flm.emission_energy_multiplier = 2.2
        fl.material_override = flm
        add_child(fl)


## رفتار پرتابی: دور بمان، رو به هدف، پرتاب کن (override لایه ۳)
func _combat_tick(delta: float) -> void:
        var up := Vector2(engaged_unit.global_position.x, engaged_unit.global_position.z)
        var pos := Vector2(global_position.x, global_position.z)
        var d := pos.distance_to(up)

        # خیلی نزدیک شد → عقب‌نشینی کوتاه (پرتابگر بی‌سپر است)
        if d < GameConstants.PELTAST_MIN_DIST:
                _move_with((pos - up).normalized(), delta, move_speed)
                return

        _face_toward(up, delta)
        _bob_visual(false)
        if _atk_cd <= 0.0 and d <= GameConstants.PELTAST_RANGE and _los_clear(up):
                # گام ۶R3 — آهنگ پرتاب هم ±۱۵٪ پراکنده می‌شود (ضربه‌های ماشینی نه)
                _atk_cd = attack_cooldown \
                                * (1.0 + randf_range(-GameConstants.CADENCE_VARIANCE,
                                GameConstants.CADENCE_VARIANCE))
                javelins_thrown += 1
                _throw_anim()
                JavelinProjectile.fire(get_parent(),
                                global_position + Vector3(0, 0.55, 0),
                                engaged_unit.global_position + Vector3(0, 0.35, 0),
                                ground_provider)


## پرتاب به جلو — انیمیشن Throw مدل + نیزه‌ی دست لحظه‌ای محو می‌شود (رها شد)
func _throw_anim() -> void:
        if _model != null:
                _model.play_attack()
        var tw := create_tween()
        tw.tween_property(_javelin, "position:z", 0.3, 0.09).set_ease(Tween.EASE_OUT)
        tw.tween_callback(_javelin_back)


func _javelin_back() -> void:
        _javelin.position = Vector3(0.22, 0.55, 0.12)


# ---------------- گام ۶R — ژست اختصاصی پرتاب مشعل ----------------

## منطق مشعل در EnemyBase._house_tick است — اینجا فقط ژست دست
func _torch_throw_anim() -> void:
        if _torch_in_hand == null:
                return
        var tw := create_tween()
        tw.tween_property(_torch_in_hand, "rotation_degrees:x", -85.0, 0.1)
        tw.tween_property(_torch_in_hand, "rotation_degrees:x", -18.0, 0.22)


## مسیر پرتاب باز است؟ (ارتفاع خط = بیشینه‌ی شلیک‌کننده و هدف — شوتِ سربالایی بسته نمی‌شود)
func _los_clear(to: Vector2) -> bool:
        var from := Vector2(global_position.x, global_position.z)
        var dist := from.distance_to(to)
        if dist < 0.5:
                return true
        var steps := maxi(int(dist / 0.4), 2)
        var to_y := 0.0
        if is_instance_valid(engaged_unit):
                to_y = engaged_unit.global_position.y
        var line_h := maxf(global_position.y, to_y)
        for i in range(1, steps):
                var k := float(i) / float(steps)
                var p := from.lerp(to, k)
                if ground_provider.is_valid():
                        var gh: float = ground_provider.call(p)
                        if gh > line_h + 0.6:
                                return false
        return true
