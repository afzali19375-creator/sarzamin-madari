class_name HopliteHeavy
extends EnemyBase
## هوپلیت سنگین (§۶): کند، جانِ زیاد، «کمان را خنثی می‌کند — فقط از پشت/پهلو آسیب».
## سپر بزرگ رو به مدلِ +Z؛ تیر/پرتابی که از مخروطِ پیش‌رو بیاید روی سپر می‌شکند
## (جرقه‌ی سفید، بدون آسیب). ضربه‌ی تن‌به‌تن و پرتاب از پهلو-پشت معمولی اثر می‌کند.

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
        return GameConstants.COL_ROCK_DARK


func _build_gear() -> void:
        # تنه‌ی تنومندتر
        _body.scale = Vector3(1.12, 1.06, 1.12)

        # سپر بزرگ مستطیلی رو به +Z (سمت نگاه)
        _shield = MeshInstance3D.new()
        var sm := BoxMesh.new()
        sm.size = Vector3(0.56, 0.74, 0.06)
        _shield.mesh = sm
        _shield.position = Vector3(-0.04, 0.34, 0.3)
        var shield_mat := StandardMaterial3D.new()
        shield_mat.albedo_color = GameConstants.COL_FIRETEMPLE
        shield_mat.roughness = 0.55
        _shield.material_override = shield_mat
        add_child(_shield)

        # لبه‌ی برنزی سپر
        var rim := MeshInstance3D.new()
        var rm := BoxMesh.new()
        rm.size = Vector3(0.6, 0.06, 0.07)
        rim.mesh = rm
        rim.position = Vector3(-0.04, 0.7, 0.3)
        var rim_mat := StandardMaterial3D.new()
        rim_mat.albedo_color = GameConstants.COL_GOLD
        rim_mat.metallic = 0.5
        rim_mat.roughness = 0.4
        rim.material_override = rim_mat
        add_child(rim)

        # کلاه‌خود کریت‌سپر
        var helm := MeshInstance3D.new()
        var hm := CylinderMesh.new()
        hm.top_radius = 0.02
        hm.bottom_radius = 0.13
        hm.height = 0.16
        helm.mesh = hm
        helm.position.y = 0.76
        var hmat := StandardMaterial3D.new()
        hmat.albedo_color = GameConstants.COL_GOLD
        hmat.metallic = 0.5
        hmat.roughness = 0.4
        helm.material_override = hmat
        add_child(helm)


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
