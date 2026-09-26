class_name ImmortalUnit
extends UnitBase
## جاویدان (Anûšiya) — خط نگهدارنده (سند طراحی §۵):
##   «سپر از پیش رو؛ فاصله‌ی نبرد نزدیک»
##
## لایه ۳ — واکنش نبرد (گام ۵، روی کوله‌ی تمرین):
##   * دشمن در IMMORTAL_REACT_RANGE → رو به دشمن می‌چرخد و سپر بالا می‌برد
##   * مخروط سپر IMMORTAL_SHIELD_CONE_DEG از پیش رو (پیش‌فرض گام ۵؛ بالانس نهایی گام ۶)
## بصری: کاراکتر Knight پک KayKit (شمشیر + سپر مستطیلی) — سپر به رنگ کاشیِ
## فیروزه‌ای هخامنشی تینت می‌شود؛ حالت سپر = انیمیشن Blocking مدل.


var shield_up := false          # برای تست خودکار و HUD
var _face_dir := 0.0            # جهت فعلیِ روکردن به دشمن
var strikes_done := 0           # برای تست خودکار (گام ۶)


func _model_kind() -> StringName:
        return &"knight"


func _model_special() -> Dictionary:
        # سپر مستطیلیِ مدل → کاشی فیروزه‌ای (هویت بصری جاویدان)
        return {"Rectangle_Shield": GameConstants.COL_DOME_TILE}


func _combat_wants(hostile: Node3D) -> bool:
        # جاویدان خط نگهدارنده است؛ ولی فرمانِ تازه‌ی کاربر اولویت دارد:
        # تا وقتی «در سفر» است فقط تماسِ بسیار نزدیک واکنش می‌دهد
        if _is_traveling():
                return _dist_xz_to(hostile) <= GameConstants.IMMORTAL_ENGAGE_RANGE + 0.3
        return true


func _default_hp() -> int:
        return GameConstants.PLAYER_HP_IMMORTAL


func _combat_tick(delta: float, hostile: Node3D) -> void:
        # رو به دشمن بایست (چرخش قانون‌مند ۳۶۰°/s)
        var d := hostile.global_position - global_position
        _face_dir = atan2(d.x, d.z)
        var diff := wrapf(_face_dir - _heading, -PI, PI)
        _heading = wrapf(_heading + clampf(diff,
                        -GameConstants.ROTATE_SPEED_RAD * delta,
                        GameConstants.ROTATE_SPEED_RAD * delta), -PI, PI)
        rotation.y = _heading
        if not shield_up:
                shield_up = true
                # سپر بالا می‌آید (انیمیشن Blocking) + نشستنِ کوتاه زانو
                if _model != null:
                        _model.set_blocking(true)
                _body.scale = Vector3(1.0, 0.94, 1.0)
        # گام ۶R2 — شمشیرزن تیرانداز را تعقیب می‌کند (بازخورد کاربر:
        # «سرباز شمشیرزن به سرباز تیرانداز نزدیک نمی‌شود») — یورش با سپرِ بالا
        if _combat_move_toward(delta, hostile, GameConstants.IMMORTAL_ENGAGE_RANGE,
                        GameConstants.SPEED_BASE * speed_mult * 0.9):
                return
        # گام ۶ — ضربه‌ی تن‌به‌تن در فاصله‌ی نبرد نزدیک
        # گام ۶R3 — یورش (_lunge) در لحظه‌ی ضربه داخل چرخه‌ی _strike_impact_fx
        if _dist_xz_to(hostile) <= GameConstants.IMMORTAL_ENGAGE_RANGE:
                if _try_strike(delta, GameConstants.IMMORTAL_STRIKE_COOLDOWN,
                                hostile, 1, GameConstants.IMMORTAL_ENGAGE_RANGE):
                        strikes_done += 1


func _combat_end() -> void:
        shield_up = false
        if _model != null:
                _model.set_blocking(false)
        _body.scale = Vector3.ONE


## یورش کوتاه به جلو هنگام ضربه (روی انیمیشن حمله‌ی مدل)
func _lunge() -> void:
        var tw := create_tween()
        tw.tween_property(_body, "position:z", 0.14, 0.08).set_ease(Tween.EASE_OUT)
        tw.tween_property(_body, "position:z", 0.0, 0.14)


## گام ۶R3 — ژست ضربه در اوجِ یورش + گام ۶R4 — بازگشت چرخشِ کششِ ضربه
func _strike_impact_fx() -> void:
        _lunge()
        _body.rotation.y = 0.0
