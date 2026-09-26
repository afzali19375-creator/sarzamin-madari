class_name HopliteLight
extends EnemyBase
## هوپلیت سبک (§۶): سریع، کم‌جان — خط اول مهاجمان.
## گام ۶R9 — شمشیرِ چندقطعه‌ایِ واضح روی پیوتِ دست: تیغه‌ی سبز-سفیدِ مرجع با
## محافظِ برنز، دسته‌ی چرمی و سوئینگِ اسلش واقعی (بازخورد: «شمشیر قشنگ‌تر و
## واضح‌تر بشن و به شکل زیبا حرکت کند و به دشمن بخورد»).

func _init() -> void:
        hp = GameConstants.HOPLITE_LIGHT_HP
        move_speed = GameConstants.HOPLITE_LIGHT_SPEED
        attack_dmg = GameConstants.HOPLITE_LIGHT_DMG
        attack_cooldown = GameConstants.HOPLITE_LIGHT_COOLDOWN
        engage_range = GameConstants.ENEMY_ENGAGE_RANGE


func _default_hp() -> int:
        return GameConstants.HOPLITE_LIGHT_HP


func _default_color() -> Color:
        return GameConstants.COL_ENEMY_LIGHT


## گام ۶R12 — مهاجمِ انسانی: وایکینگِ تبر‌دار (Quaternius Ultimate)
func _model_kind() -> StringName:
        return &"viking"


func _build_gear() -> void:
        # شمشیرِ برنزی در دست — سوئینگ با انیمیشن Sword_Attack هم‌خوان است
        _swing_weapon = WeaponLook.sword(Color("c9963c"), 0.48)
        _swing_weapon.rotation_degrees.z = -12.0   # تیغه کمی به بیرونِ بدن
        _hand.add_child(_swing_weapon)
