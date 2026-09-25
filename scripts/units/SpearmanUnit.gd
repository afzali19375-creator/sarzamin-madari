class_name SpearmanUnit
extends UnitBase
## نیزه‌دار — ضد سواره/ضد پیاده (سند طراحی §۵ + قانون آهنین §۴):
##   «نیزه‌دار هنگام حرکت نمی‌جنگد — فقط در ایست/آماده‌باش»
##
## لایه ۳ — واکنش نبرد (گام ۵، روی کوله‌ی تمرین):
##   * در حرکت (MOVING): هرگز — حتی اگر دشمن وسط بینی باشد؛ نیزه بالا می‌ماند
##   * در ایست + دشمن در SPEARMAN_BRACE_RANGE → آماده‌باش: نیزه افقی می‌شود
## بصری: فیروزه‌ای + نیزه‌ی بلند ۲.۲ متری روی بازوی راست.

const SPEAR_LEN := 2.2

var _spear: MeshInstance3D
var _spear_pivot: Node3D
var brace_active := false       # برای تست خودکار و HUD
var _brace_k := 0.0             # 0=نیزه بالا (مسیر) → 1=افقی (آماده‌باش)
var strikes_done := 0           # برای تست خودکار (گام ۶)

const SPEAR_UP_DEG := 55.0
const SPEAR_BRACE_DEG := 6.0


func _build_gear() -> void:
        # پیوت نیزه روی شانه‌ی راست (بدنه‌ی چینی ۶R۷ — بالاتر و کشیده‌تر)
        _spear_pivot = Node3D.new()
        _spear_pivot.position = Vector3(0.21, 0.44, 0.0)
        add_child(_spear_pivot)

        _spear = MeshInstance3D.new()
        var sm := CylinderMesh.new()
        sm.top_radius = 0.02
        sm.bottom_radius = 0.03
        sm.height = SPEAR_LEN
        _spear.mesh = sm
        # نیزه در راستای +Z مدل (جهت نگاه) — پیوت زاویه‌اش را تعیین می‌کند
        _spear.rotation_degrees.x = 90.0
        _spear.position = Vector3(0.0, 0.0, SPEAR_LEN * 0.5 - 0.3)
        var wood := StandardMaterial3D.new()
        wood.albedo_color = GameConstants.COL_DOOR_WOOD
        wood.roughness = 0.85
        _spear.material_override = wood
        _spear_pivot.add_child(_spear)
        _spear_pivot.rotation_degrees.x = -SPEAR_UP_DEG  # در مسیر: نیزه رو به بالا


func _combat_wants(_hostile: Node3D) -> bool:
        # ⚠️ قانون آهنین: نیزه‌دار هنگام حرکت نمی‌جنگد
        return _arrived


func _default_hp() -> int:
        return GameConstants.PLAYER_HP_SPEARMAN


func _combat_tick(delta: float, hostile: Node3D) -> void:
        # آماده‌باش: رو به دشمن + نیزه به‌تدریج افقی می‌شود
        brace_active = true
        var d := hostile.global_position - global_position
        var face := atan2(d.x, d.z)
        var diff := wrapf(face - _heading, -PI, PI)
        _heading = wrapf(_heading + clampf(diff, -GameConstants.ROTATE_SPEED_RAD * delta,
                        GameConstants.ROTATE_SPEED_RAD * delta), -PI, PI)
        rotation.y = _heading
        _brace_k = move_toward(_brace_k, 1.0, 3.0 * delta)
        _spear_pivot.rotation_degrees.x = lerpf(-SPEAR_UP_DEG, -SPEAR_BRACE_DEG, _brace_k)
        # گام ۶ — ضربه‌ی نیزه، فقط در آماده‌باش و در برد نیزه (قانون آهنین کلاس)
        # گام ۶R3 — ضربه‌ی نیزه داخل چرخه‌ی کشش→یورش→ضربه (reach قطعی پاس می‌شود)
        if _brace_k > 0.85 and _dist_xz_to(hostile) <= GameConstants.SPEARMAN_REACH:
                if _try_strike(delta, GameConstants.SPEARMAN_STRIKE_COOLDOWN,
                                hostile, 1, GameConstants.SPEARMAN_REACH):
                        strikes_done += 1


func _combat_end() -> void:
        brace_active = false
        _brace_k = 0.0
        _spear_pivot.rotation_degrees.x = -SPEAR_UP_DEG


## یورش نیزه به جلو هنگام ضربه
func _thrust() -> void:
        var z0 := SPEAR_LEN * 0.5 - 0.3
        var tw := create_tween()
        tw.tween_property(_spear, "position:z", z0 + 0.55, 0.09).set_ease(Tween.EASE_OUT)
        tw.tween_property(_spear, "position:z", z0, 0.16)


## گام ۶R3 — ژست نیزه در لحظه‌ی ضربه + گام ۶R4 — بازگشت چرخشِ کششِ ضربه
func _strike_impact_fx() -> void:
        _thrust()
        _body.rotation.y = 0.0


## هنگام شروع حرکت نیزه باید بالا برگردد (لایه ۱ آماده‌ی سفر)
func _process(delta: float) -> void:
        if not _arrived and not _in_combat and brace_active:
                _combat_end()
        super(delta)
