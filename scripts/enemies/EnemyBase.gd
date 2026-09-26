class_name EnemyBase
extends Node3D
## مغز مهاجم یونانی — گام ۶ (§۶ سند طراحی: Hoplite سبک/سنگین، Peltast)
##
## لایه‌بندی ساده‌شده (قرینه‌ی ۴ لایه‌ی سرباز پارسی):
##   ۱) حرکت: FlowField کانالِ گروه هجوم (ENEMY_CHANNEL_BASE + raid_group) به سمت
##      خانه‌ی هدف؛ نزدیک هدف → هدایت مستقیم با گاردِ سلول غیرقابل‌عبور
##   ۲) — (مهاجمان Fidget ندارند؛ هجومی‌اند)
##   ۳) نبرد: سربازِ پارسی در شعاع توجه → درگیری تن‌به‌تن (زیرکلاس می‌تواند
##      رفتار پرتابی Peltast را جایگزین کند)
##   ۴) هدف خانه: هیچ اشغالی در کار نیست (بازخورد کاربر گام ۶R: «نیازی نیست
##      خانه را اشغال کنند؛ فقط آتش بزنند») — همه‌ی مهاجمان تا فاصله‌ی ایست
##      نزدیک می‌شوند و از آن‌جا مشعل پرتاب می‌کنند؛ نزدیک‌تر از حدِ ایمن عقب
##      می‌روند. غارت نمایشیِ گام ۶ حذف شد.
##
## رنگ‌ها فقط از پالت هخامنشی (برنز COL_ROCK، سرخ COL_CRIMSON، شن).
## صفر عدد و نوار سلامت روی صفحه (§۱۰) — فلش سفید ضربه + افتادن هنگام مرگ.
## قانون §۷: مرگ دائمی است.

const DIRECT_STEER_RADIUS := 2.0
const SEPARATION_DIST := 0.55

signal died(enemy: EnemyBase)

# ---------------- آمار کلاس (زیرکلاس‌ها در _init ست می‌کنند) ----------------
var hp := 2
var move_speed := 2.5
var attack_dmg := 1
var attack_cooldown := 1.2
var aggro_units := GameConstants.ENEMY_AGGRO_UNITS
var engage_range := GameConstants.ENEMY_ENGAGE_RANGE

# ---------------- گروه هجوم ----------------
## کانال جریان = ENEMY_CHANNEL_BASE + raid_group (۰..۳) — هر گروه میدان خودش
var raid_group := 0
## خانه‌ی هدف مشعل (XZ جهانی) — کارگردان ست می‌کند
var raid_target := Vector2.ZERO
var ground_provider: Callable = Callable()

## گام ۶R3 — «وقتی قایق لبه‌ی ساحل می‌رسد از آن پیاده بشن»: مقصد پیاده‌شدن
## (نزدیک همان قایق)؛ تا رسیدن به آن، واد می‌کند و بعد نبرد/مشعل عادی شروع می‌شود
var disembark_target := Vector2.INF
## آخرین مقصد پیاده‌شدنِ محقق‌شده — برای تست «پیاده‌شدن کنار همان قایق» (۶R3)
var last_disembark_target := Vector2.INF
var _wading := false                      # در حال پیاده‌شدن از قایق (کف آب)
var _wade_t := 0.0                        # مدت پیاده‌شدن — مهلت ایمنی ۴s (۶R3)

var dead := false
var engaged_unit: Node3D = null     # سربازِ درگیر (برای تست/کارگردان)
## بنای هدف برای مشعل — کارگردان ست می‌کند (گام ۶R)
var target_house: BuildingBase = null
## شمارنده‌ی مشعل‌های پرتاب‌شده — برای تست خودکار (گام ۶R)
var torches_thrown := 0
var _torch_cd := 1.2                # تاخیر اول کوتاه تا مشعل اول زود برسد
## گام ۶R2 — تلافی: مهاجمِ تیرخورده به شلیک‌کننده حمله می‌کند
var _chase_t := 0.0

var _channel := 4
var _scan_accum := 0.0
var _atk_cd := 0.0
var _striking := false                    # در چرخه‌ی ضربه (آماده‌گیری→یورش→بازگشت)
var _heading := 0.0
var _bob_t := 0.0
var _y_smooth := 0.0
var _flash_t := 10.0
var _flashing := false
var _flash_restore := Color.WHITE

# گام ۶R5 — ضدِ گیرِ پیشروی (الگوی پیروی از دیوارِ UnitBase ۶R4):
# مهاجمی که میدانِ کانال ندارد و مستقیم می‌رود، در گوشه‌ی مقعر (خانه+صخره)
# با گاردِ لغزشِ تک‌محوره پین می‌شد — ریشه‌ی «مشعل هرگز پرتاب نشد»
var _march_stall_t := 0.0         # ساعتِ بی‌پیشرفتی نسبت به بهترین فاصله
var _march_best_gd := 1e9         # بهترین فاصله تا هدف از آخرین ریست
var _march_avoid_side := 0        # ‎+۱‎ پادساعتگرد / ‎−۱‎ ساعتگرد — تعهد سمت
var _march_avoid_hold := 0.0      # ثانیه‌ی باقی‌مانده‌ی تعهد

var _model: CharacterModel
## ریشه‌ی بدن مدل (یورش/اسکواش روی آن)
var _body: Node3D
var _body_color: Color


func _init() -> void:
        pass  # زیرکلاس‌ها آمار کلاس را اینجا ست می‌کنند


func _ready() -> void:
        add_to_group("hostiles")
        _bob_t = randf() * TAU
        _y_smooth = global_position.y
        _heading = rotation.y
        _channel = GameConstants.ENEMY_CHANNEL_BASE + raid_group
        _body_color = _default_color()

        # کاراکتر Low-Poly واقعی (KayKit CC0) — همان سیستم سربازهای خودی
        _model = CharacterModel.new()
        _model.setup(_model_kind(), _body_color, 0.5, _model_special())
        add_child(_model)
        _body = _model.body_root()

        # تجهیزات اختصاصی کلاس (کلاه‌خود/سپر/نیزه‌ی پرتاب)
        _build_gear()


# ---------------- هوک‌های زیرکلاس ----------------

func _default_hp() -> int:
        return 2


func _default_color() -> Color:
        return GameConstants.COL_ROCK


## نقشِ کاراکتر KayKit (زیرکلاس‌ها override می‌کنند)
func _model_kind() -> StringName:
        return &"knight_round"


## تینت ویژه‌ی گره‌های مدل (مثلاً سپر) — زیرکلاس‌ها override
func _model_special() -> Dictionary:
        return {}


func _build_gear() -> void:
        pass


func _process(delta: float) -> void:
        if dead:
                return
        _bob_t += delta
        _tick_flash(delta)
        _atk_cd = maxf(0.0, _atk_cd - delta)
        _chase_t = maxf(0.0, _chase_t - delta)

        _scan_accum += delta
        if _scan_accum >= GameConstants.ENEMY_SCAN_INTERVAL:
                _scan_accum = 0.0
                _rescan_units()

        # ---- گام ۶R3: پیاده‌شدن از قایق (واد تا نقطه‌ی اختصاصی در ساحل) ----
        # گام ۶R4 — «اول پیاده، بعد نبرد»: با لنگرِ رندومِ ساحلی (۶R4)، موجی
        # می‌تواند کنار پستِ خودی فرود بیاید؛ مهاجمِ در حال واد که لایه‌ی نبرد
        # جلویش را می‌گرفت هرگز disembark_target را تمام نمی‌کرد (در آب گیر
        # می‌کرد و نبردِ دوطرفه هم شکل نمی‌گرفت). واد تا سلولِ خودش یا مهلت
        # ۴ ثانیه‌ای همیشه اول تمام می‌شود؛ درگیری بلافاصله بعدش از سر گرفته
        # می‌شود (engaged_unit پاک نمی‌شود).
        if _disembark_tick(Vector2(global_position.x, global_position.z), delta):
                return

        # ---- لایه ۳: درگیری با سرباز ----
        if is_instance_valid(engaged_unit) and not _unit_dead(engaged_unit):
                _combat_tick(delta)
                return
        engaged_unit = null

        # ---- لایه ۱/۴: نزدیک‌شدن به خانه و پرتاب مشعل از فاصله (گام ۶R) ----
        ## بازخورد کاربر: «نیازی نیست خانه را اشغال کنند؛ فقط آتش بزنند» —
        ## همه‌ی مهاجمان تا فاصله‌ی ایست جلو می‌روند و از آن‌جا مشعل می‌زنند.
        if _house_tick(Vector2(global_position.x, global_position.z), delta):
                return
        _march_tick(delta)


# ---------------- نبرد (لایه ۳) — گام ۶R3: چرخه‌ی ضربه‌ی کامل ----------------

## نبرد تن‌به‌تن پایه — Peltast override می‌کند (پرتاب + عقب‌نشینی)
## گام ۶R3 (بازخورد: «نبرد بین جنگجوها اصلا جالب نیست و خیلی ابتداییه»):
##   * ضربه = آماده‌گیری (کشش به عقب) → یورش → لحظه‌ی ضربه → بازگشت
##   * آهنگ ضربه ±۱۵٪ پراکنده → ضربه‌ها هم‌زمان و ماشینی نمی‌شوند
##   * در حین چرخه‌ی ضربه ایست می‌شود (بدون لغزش عجیب)
func _combat_tick(delta: float) -> void:
        var up := Vector2(engaged_unit.global_position.x, engaged_unit.global_position.z)
        var pos := Vector2(global_position.x, global_position.z)
        var d := pos.distance_to(up)
        if d > engage_range:
                _move_with((up - pos).normalized(), delta, move_speed)
                return
        _face_toward(up, delta)
        _bob_visual(false)
        if _striking:
                return
        if _atk_cd <= 0.0:
                _perform_strike(engaged_unit)


## چرخه‌ی ضربه: کشش → یورش → ضربه در اوج → بازگشت
func _perform_strike(target: Node3D) -> void:
        _striking = true
        _atk_cd = attack_cooldown \
                        * (1.0 + randf_range(-GameConstants.CADENCE_VARIANCE,
                        GameConstants.CADENCE_VARIANCE))
        if _model != null:
                _model.play_attack()   # انیمیشن حمله با چرخه‌ی ضربه هم‌گام
        var tw := create_tween()
        tw.tween_property(_body, "position:z", -0.1,
                        GameConstants.STRIKE_WINDUP).set_ease(Tween.EASE_OUT)
        tw.tween_property(_body, "position:z", 0.17,
                        GameConstants.STRIKE_LUNGE).set_ease(Tween.EASE_IN)
        # weakref — هدفِ آزادشده bind را نمی‌شکند و _striking گیر نمی‌کند
        var wr: WeakRef = weakref(target)
        tw.tween_callback(_strike_impact.bind(wr))
        tw.tween_property(_body, "position:z", 0.0, GameConstants.STRIKE_RECOVER)
        tw.tween_callback(func() -> void: _striking = false)


## لحظه‌ی ضربه — هدف در اوجِ یورش اعتبارسنجی می‌شود (فراری تا بردِ کشیده می‌خورد)
func _strike_impact(wr: WeakRef) -> void:
        var target: Node3D = null
        if wr != null:
                target = wr.get_ref() as Node3D
        if target == null or not is_instance_valid(target):
                return
        if _unit_dead(target):
                return
        var d := Vector2(global_position.x, global_position.z).distance_to(
                        Vector2(target.global_position.x, target.global_position.z))
        if d > engage_range + 0.6:
                return
        if not target.has_method("take_hit"):
                return
        var dir3 := target.global_position - global_position
        dir3.y = 0.0
        target.take_hit(attack_dmg,
                        dir3.normalized() if dir3.length() > 0.001 else Vector3.ZERO,
                        self)


## گام ۶R3 — پیاده‌شدن از قایق: واد تا نقطه‌ی اختصاصی؛ true = مشغول
func _disembark_tick(pos: Vector2, delta: float) -> bool:
        if disembark_target == Vector2.INF:
                _wading = false
                return false
        _wade_t += delta
        var d := pos.distance_to(disembark_target)
        if d <= 0.35 or _wade_t > 4.0:
                # مهلت ایمنی: مهاجم هرگز در حلقه‌ی پیاده‌شدن گیر نمی‌کند
                last_disembark_target = disembark_target
                disembark_target = Vector2.INF
                _wading = false
                return false
        _wading = true
        var dir := (disembark_target - pos).normalized()
        if dir != Vector2.ZERO:
                _move_with(dir, delta, move_speed)
        return true


func _rescan_units() -> void:
        var best: Node3D = null
        var best_d := aggro_units
        for n in get_tree().get_nodes_in_group("units"):
                var u := n as Node3D
                if u == null or not u.is_inside_tree() or _unit_dead(u):
                        continue
                var up := Vector2(u.global_position.x, u.global_position.z)
                var d := Vector2(global_position.x, global_position.z).distance_to(up)
                if d < best_d:
                        best_d = d
                        best = u
        if best != null:
                if engaged_unit != best:
                        engaged_unit = best
                        _atk_cd = maxf(_atk_cd, 0.15)  # لحظه‌ی روکردن قبل از اولین ضربه
        else:
                # گام ۶R2 — در حال تلافی؟ هدفِ تلافی حتی بیرون آگرو رها نمی‌شود
                if _chase_t > 0.0 and is_instance_valid(engaged_unit) \
                                and not _unit_dead(engaged_unit):
                        var drop := aggro_units * GameConstants.ENEMY_CHASE_DROP_MULT
                        if Vector2(global_position.x, global_position.z).distance_to(
                                        Vector2(engaged_unit.global_position.x,
                                        engaged_unit.global_position.z)) <= drop:
                                return
                engaged_unit = null


func _unit_dead(u: Node) -> bool:
        return u.has_method("is_dead") and u.is_dead()


# ---------------- گام ۶R — آتش‌زنه‌ی خانه (بدون اشغال — بازخورد کاربر) ----------------

## خانه‌ی زنده‌ی هدف تا فاصله‌ی ایستِ نزدیک جلو می‌رود، بعد مشعل پرتاب می‌کند.
## گام ۶R2 — بازخورد کاربر: «سربازهای دشمن خیلی دور می‌ایستند؛ نزدیک‌تر بیایند»
## → مهاجمان تا ENEMY_RAID_STANDOFF (۲.۶m) جلو می‌روند و از همان‌جا پرتاب می‌کنند
##   (قبلاً از ۴.۲-۵.۵ متری پرتاب می‌شد). خروجی true = این فریم مشغول خانه است.
func _house_tick(pos: Vector2, delta: float) -> bool:
        var h := target_house
        if h == null or not is_instance_valid(h) or h.burned:
                return false
        var hxz := Vector2(h.global_position.x, h.global_position.z)
        var d := pos.distance_to(hxz)
        # زیاده‌روی نزدیک خانه → عقب (هیچ‌کس جلوی درِ خانه ازدحام نمی‌کند)
        if d < GameConstants.ENEMY_RAID_STANDOFF - 0.6:
                _move_with((pos - hxz).normalized(), delta, move_speed)
                return true
        # هنوز دور است → جلو (گام ۶R2: نزدیک‌تر از قبل)
        if d > GameConstants.ENEMY_RAID_STANDOFF:
                return false
        _face_toward(hxz, delta)
        _bob_visual(false)
        if h.burning:
                return true
        _torch_cd -= delta
        if _torch_cd <= 0.0:
                _torch_cd = GameConstants.TORCH_COOLDOWN
                torches_thrown += 1
                _torch_throw_anim()
                TorchProjectile.fire(get_parent(),
                                global_position + Vector3(0, 0.62, 0),
                                h.global_position + Vector3(0, 0.75, 0),
                                ground_provider)
        return true


## ژست پرتاب مشعل — پیش‌فرض: یورش کوتاه؛ پلتاست ژست مشعلِ دستی دارد
func _torch_throw_anim() -> void:
        _strike_anim()


# ---------------- حرکت (لایه ۱) ----------------

func _march_tick(delta: float) -> void:
        var pos := Vector2(global_position.x, global_position.z)
        var to_goal := raid_target - pos
        var gd := to_goal.length()
        var dir := to_goal.normalized() if gd < DIRECT_STEER_RADIUS \
                        else PathService.sample_direction(pos, _channel)
        if dir == Vector2.ZERO:
                dir = to_goal.normalized()  # میدان هنوز منتشر نشده — مستقیم
        if dir != Vector2.ZERO:
                # گام ۶R5 — دورزدنِ متعهد: در حال تعهد، جهت ~۶۰° چرخیده اعمال می‌شود
                if _march_avoid_hold > 0.0:
                        _march_avoid_hold -= delta
                        dir = dir.rotated(float(_march_avoid_side) * 1.05)
                        # پیشرفتِ واقعی در حین دورزدن → خروج زودهنگام
                        if gd <= _march_best_gd - 0.3:
                                _march_avoid_hold = 0.0
                                _march_stall_t = 0.0
                var before := pos
                _move_with(dir, delta, move_speed)
                # ساعتِ بی‌پیشرفتی: لرزشِ خُرد پیشرفت نیست
                if gd < _march_best_gd - 0.01:
                        _march_best_gd = gd
                        _march_stall_t = 0.0
                else:
                        _march_stall_t += delta
                if _march_avoid_hold <= 0.0 \
                                and (_march_stall_t > 1.0 or moved_now(before) < 0.02):
                        if _march_avoid_side != 0:
                                _march_avoid_side = -_march_avoid_side  # سمت قبلی شکست خورد
                        else:
                                _march_avoid_side = _march_pick_side(pos, to_goal.normalized())
                        _march_avoid_hold = 1.2
                        _march_stall_t = 0.0
                        _march_best_gd = minf(_march_best_gd, gd)
        else:
                _bob_visual(false)


## پیشرویِ همین فریم (متر) — صفر بودن یعنی گاردِ لغزش قدم را بلعید
func moved_now(before: Vector2) -> float:
        return Vector2(global_position.x, global_position.z).distance_to(before)


## انتخاب سمتِ دورزدن: سمتی که قدمِ چرخیده‌ی اولش بازتر است (الگوی _wf_pick_side)
func _march_pick_side(from: Vector2, to_dir: Vector2) -> int:
        var nav := PathService.nav
        if nav == null:
                return 1
        var best := 1
        var best_d := -1.0
        for side in [1, -1]:
                var cand := from + to_dir.rotated(float(side) * 1.05) * 0.6
                var d := from.distance_to(cand) if nav.is_walkable(nav.world_to_cell(cand)) \
                                else 0.0
                if d > best_d:
                        best_d = d
                        best = side
        # هر دو سمت یکسان بود → سمت عوض شود تا از تکرارِ مسیرِ شکست‌خورده بگریزد
        if best_d <= 0.0:
                best = -_march_avoid_side if _march_avoid_side != 0 else 1
        return best


## حرکت با گاردِ سلول غیرقابل‌عبور (آب/خانه/بیرون شبکه) + لغزش تک‌محوره
func _move_with(dir: Vector2, delta: float, speed: float) -> void:
        var pos := Vector2(global_position.x, global_position.z)
        var next := pos + dir * speed * delta
        var nav := PathService.nav
        if nav != null:
                var cur_ok := nav.is_walkable(nav.world_to_cell(pos))
                if not cur_ok:
                        # گام ۶R3 — فرار از سلول بسته (خانه/صخره/آب): به‌جای یخ‌زدن
                        # ابدی، حرکتِ بی‌گارد به سمت مقصد امن:
                        #   * وادکننده → سلولِ پیاده‌شدنِ «خودش» (پخش‌شده در ساحل —
                        #     نه ازدحام همگی روی نزدیک‌ترین سلول)
                        #   * بقیه → نزدیک‌ترین سلولِ قابل‌عبور
                        var esc_point: Vector2
                        if disembark_target != Vector2.INF:
                                esc_point = disembark_target
                        else:
                                esc_point = nav.cell_center(
                                                _nearest_walkable_cell_esc(pos))
                        var to_esc := esc_point - pos
                        if to_esc.length() > 0.05:
                                next = pos + to_esc.normalized() * speed * delta
                elif not nav.is_walkable(nav.world_to_cell(next)):
                        var slide1 := Vector2(next.x, pos.y)
                        var slide2 := Vector2(pos.x, next.y)
                        if nav.is_walkable(nav.world_to_cell(slide1)):
                                next = slide1
                        elif nav.is_walkable(nav.world_to_cell(slide2)):
                                next = slide2
                        else:
                                next = pos
                next = nav.clamp_to_grid(next)
        # گام ۶R3 — وادکننده از جداسازی معاف است: فشارِ ۸ مهاجمِ هم‌زمان روی
        # ساحل، پیاده‌شدن را چندمتری جابه‌جا می‌کرد؛ هم‌پوشانیِ موقتِ فرود طبیعی است
        pos = next
        if not _wading:
                pos = _separate(next)
                # جداسازی هیچ‌کس را به سلول بسته نمی‌اندازد (فشار ازدحام
                # ساحل/پشت خانه نباید مهاجم را در صخره یا آبِ عمیق دفن کند)
                if nav != null and not nav.is_walkable(nav.world_to_cell(pos)):
                        pos = next
        var gy := 0.0
        if ground_provider.is_valid():
                gy = ground_provider.call(pos)
        # گام ۶R3 — هنگام پیاده‌شدن، کف آب (نه بستر دریا)
        if _wading:
                gy = maxf(gy, GameConstants.WADE_Y)
        _y_smooth = lerpf(_y_smooth, gy, clampf(10.0 * delta, 0.0, 1.0))
        global_position = Vector3(pos.x, _y_smooth, pos.y)
        _turn_to(atan2(dir.x, dir.y), delta)
        _bob_visual(true)


## نزدیک‌ترین سلول قابل‌عبور (مارپیچ کوچک) — برای فرار از سلول بسته (گام ۶R3)
func _nearest_walkable_cell_esc(from: Vector2) -> Vector2i:
        var nav := PathService.nav
        if nav == null:
                return Vector2i.ZERO
        var base := nav.world_to_cell(from)
        if nav.is_walkable(base):
                return base
        for r in range(1, 8):
                for dy in range(-r, r + 1):
                        for dx in range(-r, r + 1):
                                var c := base + Vector2i(dx, dy)
                                if nav.is_walkable(c):
                                        return c
        return base


func _separate(pos: Vector2) -> Vector2:
        var out := pos
        for other in get_tree().get_nodes_in_group("hostiles"):
                var h := other as Node3D
                if h == null or h == self or not h.is_inside_tree():
                        continue
                if h.has_method("is_dead") and h.is_dead():
                        continue
                var op := Vector2(h.global_position.x, h.global_position.z)
                var diff := out - op
                var d := diff.length()
                if d > 0.001 and d < SEPARATION_DIST:
                        out += (diff / d) * (SEPARATION_DIST - d) * 0.5
        # گام ۶R3 — سقف نرم: جداسازی «هل دادن» است نه تله‌پورت؛ ۸ مهاجم روی
        # یک نقطه نباید در یک فریم به چند متری پرت شوند
        var corr := out - pos
        if corr.length() > 0.14:
                corr = corr.normalized() * 0.14
                out = pos + corr
        return out


# ---------------- جهت و بصری ----------------

func _face_toward(p: Vector2, delta: float) -> void:
        var d := p - Vector2(global_position.x, global_position.z)
        if d.length() > 0.01:
                _turn_to(atan2(d.x, d.y), delta)


func _turn_to(target: float, delta: float) -> void:
        var diff := wrapf(target - _heading, -PI, PI)
        _heading = wrapf(_heading + clampf(diff, -GameConstants.ROTATE_SPEED_RAD * delta,
                        GameConstants.ROTATE_SPEED_RAD * delta), -PI, PI)
        rotation.y = _heading


func _bob_visual(moving: bool) -> void:
        if _model != null:
                _model.set_moving(moving)


## یورش کوتاه به جلو هنگام ضربه/پرتاب
func _strike_anim() -> void:
        if _model != null:
                _model.play_attack()
        var tw := create_tween()
        tw.tween_property(_body, "position:z", 0.14, 0.08).set_ease(Tween.EASE_OUT)
        tw.tween_property(_body, "position:z", 0.0, 0.14)


func _tick_flash(delta: float) -> void:
        # فلش سفید داخل CharacterModel مدیریت می‌شود — تیکِ قدیمی خنثی
        pass


# ---------------- آسیب و مرگ (§۷: دائمی) ----------------

func is_dead() -> bool:
        return dead


func is_alive() -> bool:
        return not dead


## ضربه (تیر/ضربه‌ی تن‌به‌تن) — گام ۶R2: اگر «attacker» شناخته باشد، مهاجم
## به شلیک‌کننده تلافی می‌کند (تعقیبِ کوتاه حتی بیرون شعاع توجه)
## گام ۶R3: پس‌زنی کوتاه در جهت ضربه — حس جسمِ درگیری
func take_hit(dmg: int = 1, from_dir: Vector3 = Vector3.ZERO,
                attacker: Node3D = null) -> void:
        if dead:
                return
        hp -= dmg
        if _model != null:
                _model.flash_white()
                _model.play_hit()
        _knockback(from_dir)
        if attacker != null and is_instance_valid(attacker) \
                        and attacker.is_in_group("units") \
                        and not _unit_dead(attacker):
                engaged_unit = attacker
                _atk_cd = maxf(_atk_cd, 0.3)   # لحظه‌ی روکردن به سمت شلیک‌کننده
                _chase_t = GameConstants.ENEMY_CHASE_SECONDS
        if hp <= 0:
                die()


## پس‌زنی — فقط روی زمینِ قابل‌عبور (ضربه به داخل آب نمی‌برد)
func _knockback(from_dir: Vector3) -> void:
        if from_dir.length() < 0.01:
                return
        var k2 := Vector2(from_dir.x, from_dir.z).normalized() \
                        * GameConstants.MELEE_KNOCKBACK
        var np := Vector2(global_position.x, global_position.z) + k2
        var nav := PathService.nav
        if nav != null and not nav.is_walkable(nav.world_to_cell(np)):
                return
        global_position.x = np.x
        global_position.z = np.y


func die() -> void:
        if dead:
                return
        dead = true
        engaged_unit = null
        remove_from_group("hostiles")
        died.emit(self)
        set_process(false)
        # انیمیشن مرگِ اسکلتی + محوِ جسد
        if _model != null:
                _model.play_death()
                _model.fade_out(GameConstants.DEATH_FADE_SECONDS)
        var tw := create_tween()
        tw.tween_interval(GameConstants.DEATH_FADE_SECONDS + 0.6)
        tw.tween_callback(queue_free)
