class_name HopliteLight
extends EnemyBase
## هوپلیت سبک (§۶): سریع، کم‌جان — خط اول پیاده‌نظام یونانی.
## بصری: کاراکتر Barbarian پک KayKit (تبر + سپر گرد) با تینتِ برنزی +
## چُک سرخ (COL_CRIMSON) — نشانگر «مهاجم سبک».


func _init() -> void:
        hp = GameConstants.HOPLITE_LIGHT_HP
        move_speed = GameConstants.HOPLITE_LIGHT_SPEED
        attack_dmg = GameConstants.HOPLITE_LIGHT_DMG
        attack_cooldown = GameConstants.HOPLITE_LIGHT_COOLDOWN
        engage_range = GameConstants.ENEMY_ENGAGE_RANGE


func _default_hp() -> int:
        return GameConstants.HOPLITE_LIGHT_HP


func _default_color() -> Color:
        return GameConstants.COL_ROCK


func _model_kind() -> StringName:
        return &"barbarian"


func _build_gear() -> void:
        # چُک سرخ روی کلاه (قدِ مدلِ اسکلتی)
        var crest := MeshInstance3D.new()
        var cm := BoxMesh.new()
        cm.size = Vector3(0.04, 0.12, 0.22)
        crest.mesh = cm
        crest.position.y = 0.98
        var cmat := StandardMaterial3D.new()
        cmat.albedo_color = GameConstants.COL_CRIMSON
        cmat.roughness = 0.6
        crest.material_override = cmat
        add_child(crest)
