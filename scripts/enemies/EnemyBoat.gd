class_name EnemyBoat
extends Node3D
## ناوگان مهاجمان — گام ۶R2 (بازخورد کاربر):
##   «قایق‌ها باید به هر حال کنار ساحل بمانند، چه سربازهایشان بمیرند چه زنده
##   بمانند» + «چند نوع قایق: بعضی کوچک‌تر و بدون بادبان، بعضی بزرگ‌تر» +
##   «از اول جهت اشتباهی دارند و گیج می‌زنند» + «از افق آب پدیدار بشوند».
##
## سه نوع قایق:
##   ROWBOAT  — قایق کوچک پارویی، بدون دکل و بادبان (ظرفیت ۳)
##   GALLEY   — گالی متوسط با بادبان عاجی (ظرفیت ۶)
##   WARSHIP  — کشتی جنگی بزرگ با بادبان بزرگ و نوار طلایی (ظرفیت ۸)
##
## چرخه: SAILING (از دل افق دریا) → ANCHORED (پیاده‌شدن مهاجمان) — و همان‌جا
## می‌ماند؛ هیچ بازگشتی در کار نیست (بازخورد کاربر گام ۶R2).
##
## جهت اولیه: دَرَک همان لحظه‌ی ظهور رو به لنگر می‌چرخد — دیگر «گیج‌زدنِ» اولیه
## نیست (ریشه‌ی باگ: heading از صفر شروع می‌شد و قایق حین حرکت می‌چرخید).

enum BoatState { SAILING, ANCHORED }
enum BoatType { ROWBOAT, GALLEY, WARSHIP }

signal landed(boat: EnemyBoat)

const SEA_Y := -0.18                    # هم‌خوان با IslandGround.SEA_Y
const REACH_EPS := 0.3

var state := BoatState.SAILING
var boat_type := BoatType.GALLEY
var capacity := GameConstants.CAP_GALLEY
var anchor_point: Vector3 = Vector3.ZERO   # نقطه‌ی لنگر (روی آب، کنار ساحل)

var _t := 0.0
var _heading := 0.0
var _speed_now := GameConstants.BOAT_CRUISE_SPEED
var _sail: MeshInstance3D
var _sail_yard: MeshInstance3D
var _has_sail := false


func _ready() -> void:
        _t = randf() * TAU
        global_position.y = SEA_Y
        _build_visuals()
        # گام ۶R2 — رفع «گیج‌زدن اولیه»: رو به لنگر بچرخ، همان لحظه‌ی ظهور
        var to_anchor := Vector2(anchor_point.x - global_position.x,
                        anchor_point.z - global_position.z)
        if to_anchor.length() > 0.05:
                _heading = atan2(to_anchor.x, to_anchor.y)
        rotation.y = _heading


func _build_visuals() -> void:
        var wood := StandardMaterial3D.new()
        wood.albedo_color = GameConstants.COL_DOOR_WOOD
        wood.roughness = 0.9
        var cr_mat := StandardMaterial3D.new()
        cr_mat.albedo_color = GameConstants.COL_CRIMSON
        cr_mat.roughness = 0.7

        # ابعاد بدنه بر اساس نوع — طول در راستای +Z (جلو = +Z)
        var hull_sz := Vector3(0.95, 0.42, 2.2)
        var prow_len := 0.5
        var prow_off := 1.15
        var sail_w := 1.35
        var sail_h := 1.15
        var mast_h := 1.7
        match boat_type:
                BoatType.ROWBOAT:
                        hull_sz = Vector3(0.68, 0.32, 1.5)
                        prow_len = 0.36
                        prow_off = 0.78
                BoatType.WARSHIP:
                        hull_sz = Vector3(1.28, 0.56, 3.2)
                        prow_len = 0.62
                        prow_off = 1.68
                        sail_w = 1.85
                        sail_h = 1.55
                        mast_h = 2.3
                _:
                        pass

        # بدنه
        var hull := MeshInstance3D.new()
        var hm := BoxMesh.new()
        hm.size = hull_sz
        hull.mesh = hm
        hull.position.y = hull_sz.y * 0.38
        hull.material_override = wood
        add_child(hull)

        # نوک‌های خمیده (پیش‌وپس‌سر قایق)
        for z in [-1.0, 1.0]:
                var prow := MeshInstance3D.new()
                var pm := BoxMesh.new()
                pm.size = Vector3(hull_sz.x * 0.62, hull_sz.y * 0.8, prow_len)
                prow.mesh = pm
                prow.position = Vector3(0.0, hull_sz.y * 0.67, z * prow_off)
                prow.rotation_degrees.x = -12.0 * z
                prow.material_override = wood
                add_child(prow)

        # نوار سرخ روی بدنه (هویت مهاجم)
        var stripe := MeshInstance3D.new()
        var sm := BoxMesh.new()
        sm.size = Vector3(hull_sz.x + 0.04, 0.1, hull_sz.z + 0.04)
        stripe.mesh = sm
        stripe.position.y = hull_sz.y * 0.72
        stripe.material_override = cr_mat
        add_child(stripe)

        # کشتی جنگی: نوار طلایی دوم — هویت «ناوگان بزرگ»
        if boat_type == BoatType.WARSHIP:
                var gold_stripe := MeshInstance3D.new()
                var gm := BoxMesh.new()
                gm.size = Vector3(hull_sz.x + 0.06, 0.06, hull_sz.z + 0.06)
                gold_stripe.mesh = gm
                gold_stripe.position.y = hull_sz.y * 0.72 + 0.11
                var gold_mat := StandardMaterial3D.new()
                gold_mat.albedo_color = GameConstants.COL_GOLD
                gold_mat.metallic = 0.4
                gold_mat.roughness = 0.4
                gold_stripe.material_override = gold_mat
                add_child(gold_stripe)

        # قایق پارویی: بدون دکل و بادبان (بازخورد کاربر) — فقط پاروهای کناری
        if boat_type == BoatType.ROWBOAT:
                for side in [-1.0, 1.0]:
                        var oar := MeshInstance3D.new()
                        var om := BoxMesh.new()
                        om.size = Vector3(0.04, 0.04, 0.9)
                        oar.mesh = om
                        oar.rotation_degrees = Vector3(0.0, 0.0, side * -18.0)
                        oar.position = Vector3(side * 0.42, 0.16, -0.15)
                        oar.material_override = wood
                        add_child(oar)
                _has_sail = false
                return

        # دکل و بازوی بادبان (گالی و کشتی جنگی)
        _has_sail = true
        var mast := MeshInstance3D.new()
        var mm := CylinderMesh.new()
        mm.top_radius = 0.045 if boat_type == BoatType.GALLEY else 0.06
        mm.bottom_radius = 0.06 if boat_type == BoatType.GALLEY else 0.08
        mm.height = mast_h
        mast.mesh = mm
        mast.position.y = mast_h * 0.5 + 0.14
        mast.material_override = wood
        add_child(mast)

        _sail_yard = MeshInstance3D.new()
        var ym := BoxMesh.new()
        ym.size = Vector3(sail_w + 0.15, 0.06, 0.06)
        _sail_yard.mesh = ym
        _sail_yard.position.y = 0.14 + mast_h
        _sail_yard.material_override = wood
        add_child(_sail_yard)

        # بادبان عاجی — جعبه‌ی نازک عمودی (فروکش مستقیم با scale:y)
        _sail = MeshInstance3D.new()
        var plane := BoxMesh.new()
        plane.size = Vector3(sail_w, sail_h, 0.02)
        _sail.mesh = plane
        _sail.position.y = 0.14 + mast_h * 0.62
        var sail_mat := StandardMaterial3D.new()
        sail_mat.albedo_color = GameConstants.COL_IVORY
        sail_mat.roughness = 0.95
        _sail.material_override = sail_mat
        add_child(_sail)


func has_sail() -> bool:
        return _has_sail


func type_name() -> String:
        match boat_type:
                BoatType.ROWBOAT:
                        return "rowboat"
                BoatType.WARSHIP:
                        return "warship"
                _:
                        return "galley"


func _process(delta: float) -> void:
        _t += delta
        # تکان‌خوردن روی موج
        global_position.y = SEA_Y + sin(_t * 1.5) * 0.05
        rotation.z = sin(_t * 1.1) * 0.02

        match state:
                BoatState.SAILING:
                        # گام ۶R2 — کروز تند در دریای باز، ترمز نرم برای پهلوگیری
                        var dist := _xz().distance_to(
                                        Vector2(anchor_point.x, anchor_point.z))
                        var want := GameConstants.BOAT_SPEED \
                                        if dist <= GameConstants.BOAT_DOCK_ZONE \
                                        else GameConstants.BOAT_CRUISE_SPEED
                        _speed_now = lerpf(_speed_now, want, clampf(1.5 * delta, 0.0, 1.0))
                        _sail_toward(anchor_point, delta)
                        if dist <= REACH_EPS:
                                state = BoatState.ANCHORED
                                _furl_sail()
                                landed.emit(self)
                _:
                        pass


func _xz() -> Vector2:
        return Vector2(global_position.x, global_position.z)


func _sail_toward(target: Vector3, delta: float) -> void:
        var tp := Vector2(target.x, target.z)
        var pos := _xz()
        var to := tp - pos
        var dist := to.length()
        var step := _speed_now * delta
        if dist <= step:
                pos = tp
        else:
                pos += to.normalized() * step
        global_position.x = pos.x
        global_position.z = pos.y
        # چرخش نرم به سمت حرکت
        var target_h := atan2(to.x, to.y)
        var diff := wrapf(target_h - _heading, -PI, PI)
        _heading = wrapf(_heading + clampf(diff, -1.2 * delta, 1.2 * delta), -PI, PI)
        rotation.y = _heading


## بادبان کشیدن هنگام لنگر (فروکش به نیمه)
func _furl_sail() -> void:
        if not _has_sail or _sail == null:
                return
        var tw := create_tween()
        tw.tween_property(_sail, "scale:y", 0.3, 0.6).set_ease(Tween.EASE_OUT)
        tw.parallel().tween_property(_sail_yard, "position:y",
                        _sail_yard.position.y - 0.42, 0.6)
