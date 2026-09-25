class_name ImmortalUnit
extends UnitBase
## جاویدان (Anûšiya) — خط نگهدارنده (سند طراحی §۵):
##   «سپر از پیش رو؛ فاصله‌ی نبرد نزدیک»
##
## لایه ۳ — واکنش نبرد (گام ۵، روی کوله‌ی تمرین):
##   * دشمن در IMMORTAL_REACT_RANGE → رو به دشمن می‌چرخد و سپر بالا می‌برد
##   * مخروط سپر IMMORTAL_SHIELD_CONE_DEG از پیش رو (پیش‌فرض گام ۵؛ بالانس نهایی گام ۶)
## بصری: عاجی + نوار طلایی، سپر مستطیلی، کلاه‌خود بلند.

var _shield: MeshInstance3D
var _crest: MeshInstance3D
var shield_up := false          # برای تست خودکار و HUD
var _face_dir := 0.0            # جهت فعلیِ روکردن به دشمن
var strikes_done := 0           # برای تست خودکار (گام ۶)


func _build_gear() -> void:
        # کلاه‌خود بلند هخامنشی
        _crest = MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.02
        cm.bottom_radius = 0.12
        cm.height = 0.2
        _crest.mesh = cm
        _crest.position.y = 0.76
        var gold := StandardMaterial3D.new()
        gold.albedo_color = GameConstants.COL_GOLD
        gold.metallic = 0.6
        gold.roughness = 0.35
        _crest.material_override = gold
        add_child(_crest)

        # سپر مستطیلی — جلوی تنه (+Z مدل، سمت بینی جهت‌نما)
        _shield = MeshInstance3D.new()
        var sm := BoxMesh.new()
        sm.size = Vector3(0.44, 0.62, 0.05)
        _shield.mesh = sm
        _shield.position = Vector3(-0.16, 0.3, 0.2)
        var shield_mat := StandardMaterial3D.new()
        shield_mat.albedo_color = GameConstants.COL_DOME_TILE  # کاشی فیروزه‌ای سپر
        shield_mat.roughness = 0.5
        _shield.material_override = shield_mat
        add_child(_shield)


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
        _heading = wrapf(_heading + clampf(diff, -GameConstants.ROTATE_SPEED_RAD * delta,
                        GameConstants.ROTATE_SPEED_RAD * delta), -PI, PI)
        rotation.y = _heading
        if not shield_up:
                shield_up = true
                # سپر به سمت جلو بالا می‌آید + نشستنِ کوتاه زانو
                _shield.position = Vector3(-0.05, 0.32, 0.3)
                _body.scale = Vector3(1.0, 0.92, 1.0)
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
        _shield.position = Vector3(-0.16, 0.3, 0.2)
        _body.scale = Vector3.ONE


## یورش کوتاه به جلو هنگام ضربه (حسِ نبرد بدون انیمیشن اسکلتی)
func _lunge() -> void:
        var tw := create_tween()
        tw.tween_property(_body, "position:z", 0.14, 0.08).set_ease(Tween.EASE_OUT)
        tw.tween_property(_body, "position:z", 0.0, 0.14)


## گام ۶R3 — ژست ضربه در اوجِ یورش + گام ۶R4 — بازگشت چرخشِ کششِ ضربه
func _strike_impact_fx() -> void:
        _lunge()
        _body.rotation.y = 0.0
