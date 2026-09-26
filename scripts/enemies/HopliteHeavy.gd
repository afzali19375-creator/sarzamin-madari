class_name HopliteHeavy
extends EnemyBase
## هوپلیت سنگین (§۶): کند، جانِ زیاد، «کمان را خنثی می‌کند — فقط از پشت/پهلو آسیب».
## سپر بزرگ رو به مدلِ +Z؛ تیر/پرتابی که از مخروطِ پیش‌رو بیاید روی سپر می‌شکند
## (جرقه‌ی سفید، بدون آسیب). ضربه‌ی تن‌به‌تن و پرتاب از پهلو-پشت معمولی اثر می‌کند.

var deflects := 0          # شمار تیرهای خنثی‌شده — برای تست خودکار


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


func _model_kind() -> StringName:
        return &"knight_round"


func _model_special() -> Dictionary:
        # سپر گردِ مدل → سرخ یونانی (تفکیک از جاویدانِ فیروزه‌ای‌سپر)
        return {"Round_Shield": GameConstants.COL_CRIMSON}


func _build_gear() -> void:
        # تنه‌ی تنومندتر (روی ریشه‌ی مدل)
        _body.scale = Vector3(1.1, 1.05, 1.1)
        # سپر و کلاه‌خود داخل مدلِ Knight موجودند — تجهیزِ پروسیجرال حذف شد


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
