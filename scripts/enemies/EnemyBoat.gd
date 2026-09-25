class_name EnemyBoat
extends Node3D
## قایق مهاجمان — گام ۶R6 (بازخورد کاربر: «سیستم حمل‌ونقل واقعی»):
##
##   * سربازانِ روی قایق «موجودیت‌های واقعی»اند (EnemyBase با اسکریپت AI خودش)
##     و «فرزند نود قایق»ند تا همراه آن حرکت کنند — آدمک‌های ثابتِ قبلی حذف شدند
##   * مدل بصری قایق فقط بدنه‌ی چوبی است (بدنه + نوک خمیده + نوار + پاروها) —
##     آدمک ثابت و پرچمِ بار حذف شد؛ نوعِ بار را خودِ سربازانِ روی عرشه نشان می‌دهند
##   * ماشین حالت قایق:
##       SAILING      → حرکت روی آب؛ سربازان Riding (AI/کولایدر خاموش)
##       LANDING      → رسیدن به ساحل (رسیدن به لنگر تحلیلی — معادل Area3D)
##       DISEMBARKING → reparent سربازان به ریشه‌ی صحنه با حفظ موقعیت جهانی
##                      (بدون تلپورت) + واد تا سلول پیاده‌شدنِ خودشان
##       DEPARTING    → قایق از ساحل دور می‌شود و ناپدید می‌گردد (queue_free)
##   * «اسپاونر قدیمی» حذف شد: سربازانی که پیاده می‌شوند همان‌هایی‌اند که از
##     ابتدا سوار بودند (کارگردان از اول آن‌ها را سوار قایق می‌کند)
##
## چرخه‌ی پیشین (پارک دائمی در ساحل — گام ۶R2) با دستور تازه‌ی کاربر جایگزین شد.

enum BoatState { SAILING, LANDING, DISEMBARKING, DEPARTING }
enum BoatType { ROWBOAT, GALLEY, WARSHIP }

signal landed(boat: EnemyBoat)                     # پهلوگیری کامل (شروع تخلیه)
signal soldier_disembarked(boat: EnemyBoat, s: EnemyBase)   # هر پیاده‌شدن
signal departed(boat: EnemyBoat)                   # آغاز دورشدن از ساحل
signal gone(boat: EnemyBoat)                       # گام ۶R۷ — ناپدیدیِ نهایی (قبل از queue_free)

const SEA_Y := -0.18                    # هم‌خوان با IslandGround.SEA_Y
const REACH_EPS := 0.45                 # گام ۶R3: پهلوگیری بخشنده‌تر (ضد بن‌بست)

var state := BoatState.SAILING
var boat_type := BoatType.GALLEY
var capacity := GameConstants.CAP_GALLEY
var anchor_point: Vector3 = Vector3.ZERO   # نقطه‌ی لنگر (روی آب، کنار ساحل)
## جهت بیرون جزیره (از مرکز به سمت دریا) — برای DEPARTING (ست توسط کارگردان)
var outward_dir := Vector2.RIGHT
## ریشه‌ی صحنه برای reparent سربازان (ست توسط کارگردان — raiders_root)
var disembark_root: Node3D = null
## گام ۶R6 — نوعِ بار قایق: فقط «یک نوع سرباز» در هر قایق
var cargo_kind := "light"
var cargo_count := 0

var _t := 0.0
var _heading := 0.0
var _speed_now := GameConstants.BOAT_CRUISE_SPEED
var _deck_top := 0.3
var _stuck_t := 0.0                       # گام ۶R4 — ساعتیِ «بی‌پیشرفتی» پهلوگیری
var _last_dist := 1e9
var _hold_t := 0.0                        # توقف کوتاه LANDING
var _dis_t := 0.0                         # شمارنده‌ی پیاده‌شدن پلکانی
var _depart_t := 0.0                      # عمر مرحله‌ی DEPARTING (مهلت ایمنی)

# سربازانِ سوار — موجودیت‌های واقعی (فرزند این نود)
var _riders: Array[EnemyBase] = []
var _disembark_cells: Array[Vector2] = []   # سلول پیاده‌شدنِ هر سرباز (کارگردان)
var _next_rider := 0

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

        # بدنه — «مدل بصری قایق فقط بدنه‌ی چوبی باشد»
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

        # نوار سرخ روی بدنه (هویت مهاجم — بخشی از بدنه)
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

        # ⚠️ آدمک‌های ثابت و پرچمِ بار حذف شدند — سربازانِ واقعی (فرزندان این نود)
        # روی عرشه می‌ایستند (کارگردان با board_soldier سوارشان می‌کند)
        _deck_top = _hull_sz.y * 0.38 + _hull_sz.y * 0.5


func has_sail() -> bool:
        return false  # گام ۶R3: همه‌ی قایق‌ها بی‌بادبان (مینیمال — بازخورد کاربر)


# ---------------- سوار/پیاده‌ی سربازان واقعی (گام ۶R6) ----------------

## سوار کردن یک موجودیت واقعی روی عرشه — فرزند این قایق می‌شود
## (باید قبل از add_child قایق یا حداقل قبل از اولین فریم صدا زده شود)
func board_soldier(s: EnemyBase) -> void:
        if s == null:
                return
        var idx := _riders.size()
        _riders.append(s)
        # چیدمان عرشه: حداکثر ۳ نفر در هر ردیف؛ ردیف‌ها در طول قایق
        var per_row := mini(capacity, 3)
        var row := idx / per_row
        var col := idx % per_row
        var in_row := mini(per_row, _riders.size() - row * per_row)
        var lx := (float(col) - float(in_row - 1) * 0.5) * 0.26
        var lz := (float(row) - float(maxi(1, int(ceil(float(capacity) / per_row))) - 1) * 0.5) * 0.55
        s.position = Vector3(lx, _deck_top, lz)
        s.riding = true          # _ready: خارج از hostiles + بدون AI
        add_child(s)


## سلول‌های پیاده‌شدن (کارگردان هنگام سیگنال landed ست می‌کند) + آغاز تخلیه
func start_disembark(cells: Array[Vector2]) -> void:
        _disembark_cells = cells.duplicate()
        _next_rider = 0
        _dis_t = 0.0
        if state == BoatState.LANDING:
                state = BoatState.DISEMBARKING


## تعداد سربازانِ سوار — سازگار با تست‌های «riders on deck»
func rider_count() -> int:
        var n := 0
        for r in _riders:
                if is_instance_valid(r) and not r.is_dead():
                        n += 1
        return n


func riders() -> Array[EnemyBase]:
        return _riders.duplicate()


func all_disembarked() -> bool:
        return _next_rider >= _riders.size()


func type_name() -> String:
        match boat_type:
                BoatType.ROWBOAT:
                        return "rowboat"
                BoatType.WARSHIP:
                        return "warship"
                _:
                        return "galley"


## ارتفاع عرشه در مختصات جهانی — نقطه‌ی سرباز هنگام پیاده‌شدن
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
                        # گام ۶R4 — ضد قفل‌شدن پهلوگیری: دو موجِ هم‌ساحل ممکن است
                        # قایق را با جداسازی بیرون برانند و هرگز به REACH_EPS نرسند
                        if dist <= GameConstants.BOAT_DOCK_ZONE * 2.2:
                                if absf(dist - _last_dist) < 0.06:
                                        _stuck_t += delta
                                else:
                                        _stuck_t = 0.0
                                _last_dist = dist
                                if _stuck_t > 3.0 \
                                                and dist <= GameConstants.BOAT_SEP_PARKED + 0.7:
                                        _begin_landing()
                                        return
                        else:
                                _stuck_t = 0.0
                                _last_dist = dist
                        if dist <= REACH_EPS:
                                _begin_landing()
                BoatState.LANDING:
                        # توقف کوتاه روی خط ساحل؛ سپس تخلیه (کارگردان سلول‌ها را
                        # در start_disembark می‌دهد؛ اگر نیامد، خودمان شروع می‌کنیم)
                        _hold_t += delta
                        if _hold_t >= GameConstants.BOAT_LANDING_HOLD \
                                        and _disembark_cells.is_empty() == false:
                                state = BoatState.DISEMBARKING
                        elif _hold_t > 2.0:
                                # کارگردان پاسخ نداد (گروه پاک شده) — بدون بارِ فعال
                                state = BoatState.DISEMBARKING
                BoatState.DISEMBARKING:
                        # پیاده‌شدن پلکانی: هر BOAT_DISEMBARK_STAGGER یک سرباز
                        # reparent می‌شود (حفظ موقعیت جهانی — بدون تلپورت)
                        _dis_t -= delta
                        if _dis_t <= 0.0 and _next_rider < _riders.size():
                                _dis_t = GameConstants.BOAT_DISEMBARK_STAGGER
                                var s := _riders[_next_rider]
                                _next_rider += 1
                                if is_instance_valid(s) and not s.is_dead():
                                        var cell := Vector2(global_position.x,
                                                        global_position.z)
                                        if (_next_rider - 1) < _disembark_cells.size():
                                                cell = _disembark_cells[_next_rider - 1]
                                        s.detach_from_transport(disembark_root, cell)
                                        soldier_disembarked.emit(self, s)
                        if _next_rider >= _riders.size():
                                _begin_departing()
                BoatState.DEPARTING:
                        # دورشدن از ساحل به سمت دریای باز + ناپدیدشدن
                        _depart_t += delta
                        var out3 := Vector3(outward_dir.x, 0.0, outward_dir.y)
                        var target := anchor_point + out3 \
                                        * GameConstants.BOAT_DEPART_FREE_DIST
                        _speed_now = lerpf(_speed_now, GameConstants.BOAT_DEPART_SPEED,
                                        clampf(0.8 * delta, 0.0, 1.0))
                        _sail_toward(target, delta)
                        var d_now := _xz().distance_to(
                                        Vector2(anchor_point.x, anchor_point.z))
                        # ⚠️ تلورانسِ ممیز شناور: چسبیدنِ دقیق به target ممکن است
                        # d_now را ۲۵٫۹۹۹ نگه دارد — ۰٫۰۵m بخشندگی + مهلت ۴۰s
                        if d_now >= GameConstants.BOAT_DEPART_FREE_DIST - 0.05 \
                                        or _depart_t > 40.0:
                                # گام ۶R۷ — سیگنالِ پیش از آزادشدن: کارگردان همان لحظه
                                # گروه را می‌بندد (رفعِ تأخیر ۰٫۳ ثانیه‌ایِ پاکسازی)
                                gone.emit(self)
                                queue_free()


## گذار SAILING → LANDING (رسیدن به ساحل)
func _begin_landing() -> void:
        state = BoatState.LANDING
        _hold_t = 0.0
        landed.emit(self)


## گذار DISEMBARKING → DEPARTING
func _begin_departing() -> void:
        state = BoatState.DEPARTING
        _depart_t = 0.0
        departed.emit(self)


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
                # قایقِ در حال تخلیه/لنگر شعاع کوچک‌تر (فقط ضدِ تداخل بدنه) تا
                # قایقِ در حال پهلوگیری از رسیدن به لنگرِ خودش باز نماند
                var sep_d := GameConstants.BOAT_SEP_DIST
                if ob.state != BoatState.SAILING:
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
        if to.length() > 0.05:
                var target_h := atan2(to.x, to.y)
                var diff := wrapf(target_h - _heading, -PI, PI)
                _heading = wrapf(_heading + clampf(diff, -1.2 * delta, 1.2 * delta),
                                -PI, PI)
                rotation.y = _heading
