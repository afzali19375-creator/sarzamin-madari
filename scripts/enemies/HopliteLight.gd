class_name HopliteLight
extends EnemyBase
## هوپلیت سبک (§۶): سریع، کم‌جان — خط اول مهاجمان.
## گام ۶R8 — بصری: شبحِ بنفش (COL_GHOST_LIGHT) با شمشیرِ کم‌رنگِ عمودی —
## دقیقاً مثلِ تصویرِ مرجعِ کاربر (تیغه‌ی سبز-سفید + دستِ خاکستری).

func _init() -> void:
        hp = GameConstants.HOPLITE_LIGHT_HP
        move_speed = GameConstants.HOPLITE_LIGHT_SPEED
        attack_dmg = GameConstants.HOPLITE_LIGHT_DMG
        attack_cooldown = GameConstants.HOPLITE_LIGHT_COOLDOWN
        engage_range = GameConstants.ENEMY_ENGAGE_RANGE


func _default_hp() -> int:
        return GameConstants.HOPLITE_LIGHT_HP


func _default_color() -> Color:
        return GameConstants.COL_GHOST_LIGHT


func _build_gear() -> void:
        # شمشیرِ کم‌رنگِ عمودی در سمتِ راستِ مدل — تیغه‌ی سبز-سفیدِ مرجع
        var blade := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.055, 0.52, 0.014)
        blade.mesh = bm
        blade.position = Vector3(0.24, 0.53, 0.15)
        var bmat := StandardMaterial3D.new()
        bmat.albedo_color = GameConstants.COL_GHOST_BLADE
        bmat.roughness = 0.45
        blade.material_override = bmat
        add_child(blade)

        # محافظِ دسته — خاکستریِ مرجع
        var guard := MeshInstance3D.new()
        var gm := BoxMesh.new()
        gm.size = Vector3(0.1, 0.028, 0.038)
        guard.mesh = gm
        guard.position = Vector3(0.24, 0.265, 0.15)
        var gmat := StandardMaterial3D.new()
        gmat.albedo_color = GameConstants.COL_GHOST_HAND
        gmat.roughness = 0.7
        guard.material_override = gmat
        add_child(guard)

        # دستِ خاکستریِ گیرنده‌ی دسته
        GhostLook.add_hand(self, Vector3(0.24, 0.235, 0.15))
