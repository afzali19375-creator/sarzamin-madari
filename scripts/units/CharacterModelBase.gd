class_name CharacterModelBase
extends Node3D
## گام ۶R16 — پایه‌ی مشترکِ مدلِ کاراکتر (سرباز/دشمن):
##
##   * CharacterModel       → مدلِ اسکلتیِ سه‌بعدیِ Quaternius (مسیرِ قدیمی)
##   * SpriteCharacterModel → اسپرایتِ دوبعدیِ بیلبوردی (Bad North — مسیرِ ۶R16)
##
## انتخابِ مسیر با GameConstants.UNITS_2D در UnitBase/EnemyBase انجام می‌شود.
## هر دو پیاده‌سازی «همین API» را دارند تا UnitBase از هیچی خبردار نشود:
##   setup / body_root / apply_team_tint / display_color / tint_amount /
##   set_moving / play_attack / play_hit / play_death / set_blocking /
##   set_crouch / freeze_pose / flash_white / fade_out


## ساخت و آماده‌سازی — قبل از add_child صدا زده می‌شود (به درخت نیاز ندارد)
func setup(_kind: StringName, _tint: Color, _tint_k := 0.42,
                _special: Dictionary = {}) -> void:
        pass


## گره‌ی بدنه (برای تویین‌های لانژ/ضربه‌ی زیرکلاس‌ها)
func body_root() -> Node3D:
        return self


## تینتِ گرادیانیِ تیم: amt = ۰ عادی | ۱ انتخابِ کامل | ~۰٫۵ دشمن
func apply_team_tint(_tint: Color, _amt := 0.0) -> void:
        pass


## آخرین رنگِ تینتِ اعمال‌شده (مصرفِ تستِ خودکار)
func display_color() -> Color:
        return Color.WHITE


## میزانِ گرادیانِ فعلی (۰=عادی، ۱=انتخاب کامل)
func tint_amount() -> float:
        return 0.0


## وضعیت حرکت → انیمیشن Walk/Idle
func set_moving(_moving: bool) -> void:
        pass


## انیمیشن‌های یک‌باره
func play_attack() -> void:
        pass


func play_hit() -> void:
        pass


func play_death() -> void:
        pass


## ایستِ سپری (در مسیر ۲بعدی: فریمِ سپر — در مسیر ۳بعدی: no-op)
func set_blocking(_on: bool) -> void:
        pass


## نشستنِ کوتاهِ زانو (حالتِ سپر) — مقیاسِ قد حفظ می‌شود
func set_crouch(_k: float) -> void:
        pass


## توقفِ فوریِ انیمیشن در ژستِ فعلی (جسدِ یخ‌زده)
func freeze_pose() -> void:
        pass


## فلش سفید کلاسیک هنگام ضربه
func flash_white() -> void:
        pass


## محوِ جسد (آلفا → صفر)
func fade_out(_secs: float) -> void:
        pass
