class_name HopliteLight
extends EnemyBase
## هوپلیت سبک (§۶): سریع، کم‌جان — خط اول پیاده‌نظام یونانی.
## بصری: بدنه‌ی برنزی-خاکستری (COL_ROCK) + چُک سرخ (COL_CRIMSON) + نیزه‌ی کوتاه.

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


func _build_gear() -> void:
        # چُک سرخ روی کلاه
        var crest := MeshInstance3D.new()
        var cm := BoxMesh.new()
        cm.size = Vector3(0.04, 0.12, 0.22)
        crest.mesh = cm
        crest.position.y = 0.78
        var cmat := StandardMaterial3D.new()
        cmat.albedo_color = GameConstants.COL_CRIMSON
        cmat.roughness = 0.6
        crest.material_override = cmat
        add_child(crest)

        # نیزه‌ی کوتاه در دست راست
        var spear := MeshInstance3D.new()
        var sm := CylinderMesh.new()
        sm.top_radius = 0.015
        sm.bottom_radius = 0.02
        sm.height = 1.3
        spear.mesh = sm
        spear.rotation_degrees = Vector3(70.0, 0.0, 0.0)
        spear.position = Vector3(0.2, 0.4, 0.3)
        var wood := StandardMaterial3D.new()
        wood.albedo_color = GameConstants.COL_DOOR_WOOD
        wood.roughness = 0.85
        spear.material_override = wood
        add_child(spear)
