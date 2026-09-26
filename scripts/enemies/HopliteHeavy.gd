class_name HopliteHeavy
extends EnemyBase
## هوپلیت سنگین (§۶): کند، جانِ زیاد، «کمان را خنثی می‌کند — فقط از پشت/پهلو آسیب».
## سپر بزرگ رو به مدلِ +Z؛ تیر/پرتابی که از مخروطِ پیش‌رو بیاید روی سپر می‌شکند
## (جرقه‌ی سفید، بدون آسیب). ضربه‌ی تن‌به‌تن و پرتاب از پهلو-پشت معمولی اثر می‌کند.
## گام ۶R12 — بصری: شهسوارِ قرمزِ تیره + سپرِ برنزیِ لبه‌دار (انسانی، نه شبح)

var deflects := 0          # شمار تیرهای خنثی‌شده — برای تست خودکار
var _shield: MeshInstance3D


func _init() -> void:
        hp = GameConstants.HOPLITE_HEAVY_HP
        move_speed = GameConstants.HOPLITE_HEAVY_SPEED
        attack_dmg = GameConstants.HOPLITE_HEAVY_DMG
        attack_cooldown = GameConstants.HOPLITE_HEAVY_COOLDOWN
        engage_range = GameConstants.ENEMY_ENGAGE_RANGE
        aggro_units = 3.0


func _default_hp() -> int:
        return GameConstants.HOPLITE_HEAVY_HP


func _default_color() -> Color:
        return GameConstants.COL_ENEMY_HEAVY


## گام ۶R12 — شهسوار (Knight_Male پک Quaternius Ultimate)
func _model_kind() -> StringName:
        return &"knight_heavy"


func _build_gear() -> void:
        # گام ۶R9 — شمشیرِ برنز در دستِ راست: ضربه‌ی سنگینِ او اکنون «دیده می‌شود»
        _swing_weapon = WeaponLook.sword(Color("c9963c"), 0.44)
        _swing_weapon.rotation_degrees.z = -14.0
        _hand.add_child(_swing_weapon)

        # سپر بزرگ مستطیلی رو به +Z (سمت نگاه) — جلوی تنه
        _shield = MeshInstance3D.new()
        var sm := BoxMesh.new()
        sm.size = Vector3(0.5, 0.6, 0.06)
        _shield.mesh = sm
        _shield.position = Vector3(-0.06, 0.42, 0.28)
        var shield_mat := StandardMaterial3D.new()
        shield_mat.albedo_color = GameConstants.COL_ENEMY_SHIELD
        shield_mat.roughness = 0.55
        _shield.material_override = shield_mat
        add_child(_shield)

        # لبه‌ی برنزی سپر
        var rim := MeshInstance3D.new()
        var rm := BoxMesh.new()
        rm.size = Vector3(0.56, 0.06, 0.07)
        rim.mesh = rm
        rim.position = Vector3(-0.06, 0.71, 0.28)
        var rim_mat := StandardMaterial3D.new()
        rim_mat.albedo_color = Color("b98d4a")
        rim_mat.roughness = 0.5
        rim.material_override = rim_mat
        add_child(rim)


## آیا این پرتابه در مخروط سپر پیش‌رو است؟ (سپر روی +Z مدل با heading فعلی)
func projectile_deflected(projectile_dir: Vector3) -> bool:
        var fwd := Vector3(sin(_heading), 0.0, cos(_heading))
        var incoming := -projectile_dir
        incoming.y = 0.0
        if incoming.length_squared() < 0.0001:
                return false
        incoming = incoming.normalized()
        var cos_half := cos(deg_to_rad(GameConstants.HOPLITE_HEAVY_SHIELD_CONE_DEG * 0.5))
        var blocked := fwd.dot(incoming) >= cos_half
        if blocked:
                deflects += 1
        return blocked
