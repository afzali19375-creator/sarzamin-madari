class_name EnemyBoat
extends Node3D
## ناوگان مهاجمان — گام ۶R3 (بازخورد کاربر):
##   «قایق‌ها را بدون بادبان بساز؛ مینیمال بهتره» → همه‌ی انواع پارویی‌اند:
##   بدنه + نوک خمیده + پاروهای کناری. هیچ دکل/بادبانی در کار نیست.
##   «سربازهای دشمن روی قایق باشند و مشخص باشد» → مینی‌فیگرهای سرباز (رنگ
##   بر اساس نوعِ بار) روی عرشه می‌ایستند و با قایق تکان می‌خورند.
##   «قایق‌ها روی هم نروند» → جداسازی حین شنا (BOAT_SEP_DIST) + فاصله‌ی
##   پهلوگیری بزرگ‌تر (FLEET_BOAT_GAP) + ظهور پلکانی از افق.
##
## سه نوع قایق (تشخیص با اندازه/نوار/پرچمِ نوعِ بار):
##   ROWBOAT  — کوچک، ۲ پارو (ظرفیت ۳)
##   GALLEY   — متوسط، ۳ جفت پارو (ظرفیت ۶)
##   WARSHIP  — بزرگ، ۴ جفت پارو + نوار طلایی (ظرفیت ۸)
##
## پرچمِ پُپِ قایق رنگِ نوعِ بار را نشان می‌دهد:
##   سبک = عاجی | سنگین = سرخ | پرتاب‌گر = فیروزه‌ای
##
## چرخه: SAILING (از دل افق دریا) → ANCHORED (پیاده‌شدن مهاجمان) — و همان‌جا
## می‌ماند؛ هیچ بازگشتی در کار نیست (بازخورد کاربر گام ۶R2).

enum BoatState { SAILING, ANCHORED }
enum BoatType { ROWBOAT, GALLEY, WARSHIP }

signal landed(boat: EnemyBoat)

const SEA_Y := -0.18                    # هم‌خوان با IslandGround.SEA_Y
const REACH_EPS := 0.45                 # گام ۶R3: پهلوگیری بخشنده‌تر (ضد بن‌بستِ فشار قایق پارک‌شده)

var state := BoatState.SAILING
var boat_type := BoatType.GALLEY
var capacity := GameConstants.CAP_GALLEY
var anchor_point: Vector3 = Vector3.ZERO   # نقطه‌ی لنگر (روی آب، کنار ساحل)
## گام ۶R3 — نوعِ بار قایق: فقط «یک نوع سرباز» در هر قایق (بازخورد کاربر)
var cargo_kind := "light"
var cargo_count := 0

var _t := 0.0
var _heading := 0.0
var _speed_now := GameConstants.BOAT_CRUISE_SPEED
var _deck_top := 0.3
var _rider_nodes: Array[Node3D] = []      # سربازهای روی عرشه — برای شمارش تست
var _stuck_t := 0.0                       # گام ۶R4 — ساعتیِ «بی‌پیشرفتی» پهلوگیری
var _last_dist := 1e9

# ابعاد بدنه بر اساس نوع — طول در راستای +Z (جلو = +Z)
var _hull_sz := Vector3(0.95, 0.42, 2.2)
var _prow_len := 0.5
var _prow_off := 1.15
var _oar_pairs := 3


func _ready() -> void:
        _t = randf() * TAU
        global_position.y = SEA_Y
        _apply_type_dims()
        _build_visuals()
        _build_riders()
        add_to_group("enemy_boats")
        # رو به لنگر بچرخ، همان لحظه‌ی ظهور (رفع «گیج‌زدن» گام ۶R2)
        var to_anchor := Vector2(anchor_point.x - global_position.x,
                        anchor_point.z - global_position.z)
        if to_anchor.length() > 0.05:
                _heading = atan2(to_anchor.x, to_anchor.y)
        rotation.y = _heading


func _apply_type_dims() -> void:
        match boat_type:
                BoatType.ROWBOAT:
                        _hull_sz = Vector3(0.68, 0.32, 1.5)
                        _prow_len = 0.36
                        _prow_off = 0.78
                        _oar_pairs = 1
                BoatType.WARSHIP:
                        _hull_sz = Vector3(1.28, 0.56, 3.2)
                        _prow_len = 0.62
                        _prow_off = 1.68
                        _oar_pairs = 4
                _:
                        _hull_sz = Vector3(0.95, 0.42, 2.2)
                        _prow_len = 0.5
                        _prow_off = 1.15
                        _oar_pairs = 3


func _build_visuals() -> void:
        var wood := StandardMaterial3D.new()
        wood.albedo_color = GameConstants.COL_DOOR_WOOD
        wood.roughness = 0.9
        var cr_mat := StandardMaterial3D.new()
        cr_mat.albedo_color = GameConstants.COL_CRIMSON
        cr_mat.roughness = 0.7

        # بدنه
        var hull := MeshInstance3D.new()
        var hm := BoxMesh.new()
        hm.size = _hull_sz
        hull.mesh = hm
        hull.position.y = _hull_sz.y * 0.38
        hull.material_override = wood
        add_child(hull)

        # نوک‌های خمیده (پیش‌وپس‌سر قایق)
        for z in [-1.0, 1.0]:
                var prow := MeshInstance3D.new()
                var pm := BoxMesh.new()
                pm.size = Vector3(_hull_sz.x * 0.62, _hull_sz.y * 0.8, _prow_len)
                prow.mesh = pm
                prow.position = Vector3(0.0, _hull_sz.y * 0.67, z * _prow_off)
                prow.rotation_degrees.x = -12.0 * z
                prow.material_override = wood
                add_child(prow)

        # نوار سرخ روی بدنه (هویت مهاجم)
        var stripe := MeshInstance3D.new()
        var sm := BoxMesh.new()
        sm.size = Vector3(_hull_sz.x + 0.04, 0.1, _hull_sz.z + 0.04)
        stripe.mesh = sm
        stripe.position.y = _hull_sz.y * 0.72
        stripe.material_override = cr_mat
        add_child(stripe)

        # کشتی جنگی: نوار طلایی دوم — هویت «ناوگان بزرگ»
        if boat_type == BoatType.WARSHIP:
                var gold_stripe := MeshInstance3D.new()
                var gm := BoxMesh.new()
                gm.size = Vector3(_hull_sz.x + 0.06, 0.06, _hull_sz.z + 0.06)
                gold_stripe.mesh = gm
                gold_stripe.position.y = _hull_sz.y * 0.72 + 0.11
                var gold_mat := StandardMaterial3D.new()
                gold_mat.albedo_color = GameConstants.COL_GOLD
                gold_mat.metallic = 0.4
                gold_mat.roughness = 0.4
                gold_stripe.material_override = gold_mat
                add_child(gold_stripe)

        # پاروهای کناری — مینیمال: جعبه‌های نازک با زاویه‌ی پاروزنی
        for p in _oar_pairs:
                for side in [-1.0, 1.0]:
                        var oar := MeshInstance3D.new()
                        var om := BoxMesh.new()
                        om.size = Vector3(0.04, 0.04,
                                        0.9 if boat_type == BoatType.ROWBOAT else 1.1)
                        oar.mesh = om
                        oar.rotation_degrees = Vector3(0.0, 0.0, side * -18.0)
                        var zo := -_hull_sz.z * 0.22 + float(p) \
                                        * (_hull_sz.z * 0.44 / maxf(_oar_pairs - 1, 1.0))
                        oar.position = Vector3(side * (_hull_sz.x * 0.5 + 0.1),
                                        0.16, zo)
                        oar.material_override = wood
                        add_child(oar)

        # پرچمِ نوعِ بار روی پُپ (عقب قایق) — تشخیص «هر قایق چه دارد» از دور
        var pole := MeshInstance3D.new()
        var pm2 := CylinderMesh.new()
        pm2.top_radius = 0.018
        pm2.bottom_radius = 0.022
        pm2.height = 0.66
        pole.mesh = pm2
        pole.position = Vector3(0.0, _hull_sz.y + 0.3, -_prow_off + 0.06)
        pole.material_override = wood
        add_child(pole)

        var flag := MeshInstance3D.new()
        var fm := BoxMesh.new()
        fm.size = Vector3(0.4, 0.22, 0.02)
        flag.mesh = fm
        flag.position = Vector3(0.2, _hull_sz.y + 0.52, -_prow_off + 0.06)
        var flm := StandardMaterial3D.new()
        flm.albedo_color = cargo_color(cargo_kind)
        flm.roughness = 0.8
        flag.material_override = flm
        add_child(flag)

        _deck_top = _hull_sz.y * 0.38 + _hull_sz.y * 0.5


## رنگ نوعِ بار — از پالت هخامنشی:
##   light = عاجی | heavy = سرخ | peltast = فیروزه‌ای
static func cargo_color(kind: String) -> Color:
        match kind:
                "heavy":
                        return GameConstants.COL_CRIMSON
                "peltast":
                        return GameConstants.COL_TURQUOISE
                _:
                        return GameConstants.COL_IVORY


## مینی‌فیگرهای سرباز روی عرشه — دو ردیف پشت‌به‌پشت، رنگ = نوعِ بار
## «باید سرباز های دشمن روی قایق باشند و این مشخص باشه» (بازخورد کاربر)
func _build_riders() -> void:
        var n := maxi(cargo_count, 0)
        if n == 0:
                return
        var body_mat := StandardMaterial3D.new()
        body_mat.albedo_color = cargo_color(cargo_kind)
        body_mat.roughness = 0.8
        var head_mat := StandardMaterial3D.new()
        head_mat.albedo_color = GameConstants.COL_ROCK
        head_mat.roughness = 0.85
        # چیدمان: حداکثر ۳ نفر در هر ردیف؛ ردیف‌ها با فاصله در طول قایق
        var per_row := mini(n, 3)
        var rows := int(ceil(float(n) / float(per_row)))
        var ri := 0
        for r in rows:
                var in_row := mini(per_row, n - r * per_row)
                for c in in_row:
                        var rider := Node3D.new()
                        var lx := (float(c) - float(in_row - 1) * 0.5) * 0.24
                        var lz := (float(r) - float(rows - 1) * 0.5) * 0.5
                        rider.position = Vector3(lx, _deck_top, lz)
                        var body := MeshInstance3D.new()
                        var bm := CylinderMesh.new()
                        bm.top_radius = 0.07
                        bm.bottom_radius = 0.095
                        bm.height = 0.3
                        body.mesh = bm
                        body.position.y = 0.15
                        body.material_override = body_mat
                        rider.add_child(body)
                        var head := MeshInstance3D.new()
                        var hm := SphereMesh.new()
                        hm.radius = 0.055
                        hm.height = 0.11
                        head.mesh = hm
                        head.position.y = 0.34
                        head.material_override = head_mat
                        rider.add_child(head)
                        add_child(rider)
                        _rider_nodes.append(rider)
                        ri += 1


func has_sail() -> bool:
        return false  # گام ۶R3: همه‌ی قایق‌ها بی‌بادبان (مینیمال — بازخورد کاربر)


func rider_count() -> int:
        return _rider_nodes.size()


func type_name() -> String:
        match boat_type:
                BoatType.ROWBOAT:
                        return "rowboat"
                BoatType.WARSHIP:
                        return "warship"
                _:
                        return "galley"


## ارتفاع عرشه در مختصات جهانی — نقطه‌ی spawn مهاجم هنگام پیاده‌شدن
func deck_world_y() -> float:
        return global_position.y + _deck_top


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
                        _separate_from_boats(delta)
                        # گام ۶R4 — ضد قفل‌شدن پهلوگیری: دو موجِ هم‌ساحل (انتخاب
                        # ساحل رندوم) ممکن است قایقی را که به لنگر خودش می‌رسد
                        # با جداسازی بیرون برانند و هرگز به REACH_EPS نرسد.
                        # اگر نزدیک لنگر است و ۳ ثانیه پیشرفتی نکرد → همان‌جا
                        # لنگر می‌اندازد تا پیاده‌شدن قفل نشود.
                        if dist <= GameConstants.BOAT_DOCK_ZONE * 2.2:
                                if absf(dist - _last_dist) < 0.06:
                                        _stuck_t += delta
                                else:
                                        _stuck_t = 0.0
                                _last_dist = dist
                                if _stuck_t > 3.0 \
                                                and dist <= GameConstants.BOAT_SEP_PARKED + 0.7:
                                        state = BoatState.ANCHORED
                                        landed.emit(self)
                                        return
                        else:
                                _stuck_t = 0.0
                                _last_dist = dist
                        if dist <= REACH_EPS:
                                state = BoatState.ANCHORED
                                landed.emit(self)
                _:
                        pass


func _xz() -> Vector2:
        return Vector2(global_position.x, global_position.z)


## گام ۶R3 — «قایق‌ها روی هم میرن»: پس‌زنی ملایم قایق‌های نزدیک هم حین شنا
func _separate_from_boats(delta: float) -> void:
        var pos := _xz()
        var push := Vector2.ZERO
        for b in get_tree().get_nodes_in_group("enemy_boats"):
                var ob := b as EnemyBoat
                if ob == null or ob == self or not ob.is_inside_tree():
                        continue
                # گام ۶R3 — قایقِ پارک‌شده شعاع کوچک‌تر (فقط ضدِ تداخل بدنه) تا
                # قایقِ در حال پهلوگیری از رسیدن به لنگرِ خودش باز نماند
                var sep_d := GameConstants.BOAT_SEP_DIST
                if ob.state == BoatState.ANCHORED:
                        sep_d = GameConstants.BOAT_SEP_PARKED
                var op := ob._xz()
                var diff := pos - op
                var d := diff.length()
                if d > 0.001 and d < sep_d:
                        push += (diff / d) * (sep_d - d)
        if push == Vector2.ZERO:
                return
        push = push * GameConstants.BOAT_SEP_PUSH * delta
        global_position.x += push.x
        global_position.z += push.y


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
