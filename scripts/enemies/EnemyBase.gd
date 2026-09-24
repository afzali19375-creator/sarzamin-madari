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
var _heading := 0.0
var _bob_t := 0.0
var _y_smooth := 0.0
var _flash_t := 10.0
var _flashing := false
var _flash_restore := Color.WHITE

var _mat: StandardMaterial3D
var _body: MeshInstance3D
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
        _mat = StandardMaterial3D.new()
        _mat.albedo_color = _body_color
        _mat.roughness = 0.8

        # تنه
        _body = MeshInstance3D.new()
        var bm := CylinderMesh.new()
        bm.top_radius = 0.15
        bm.bottom_radius = 0.21
        bm.height = 0.52
        _body.mesh = bm
        _body.position.y = 0.26
        _body.material_override = _mat
        add_child(_body)

        # سر
        var head := MeshInstance3D.new()
        var hm := SphereMesh.new()
        hm.radius = 0.11
        hm.height = 0.22
        head.mesh = hm
        head.position.y = 0.6
        head.material_override = _mat
        add_child(head)

        # تجهیزات اختصاصی کلاس (کلاه‌خود/سپر/نیزه‌ی پرتاب)
        _build_gear()


# ---------------- هوک‌های زیرکلاس ----------------

func _default_hp() -> int:
        return 2


func _default_color() -> Color:
        return GameConstants.COL_ROCK


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


# ---------------- نبرد (لایه ۳) ----------------

## نبرد تن‌به‌تن پایه — Peltast override می‌کند (پرتاب + عقب‌نشینی)
func _combat_tick(delta: float) -> void:
        var up := Vector2(engaged_unit.global_position.x, engaged_unit.global_position.z)
        var pos := Vector2(global_position.x, global_position.z)
        var d := pos.distance_to(up)
        if d > engage_range:
                _move_with((up - pos).normalized(), delta, move_speed)
                return
        _face_toward(up, delta)
        _bob_visual(false)
        if _atk_cd <= 0.0:
                _atk_cd = attack_cooldown
                _strike_anim()
                if engaged_unit.has_method("take_hit"):
                        var dir3 := engaged_unit.global_position - global_position
                        dir3.y = 0.0
                        engaged_unit.take_hit(attack_dmg,
                                        dir3.normalized() if dir3.length() > 0.001
                                        else Vector3.ZERO)


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
        var dir := to_goal.normalized() if to_goal.length() < DIRECT_STEER_RADIUS \
                        else PathService.sample_direction(pos, _channel)
        if dir == Vector2.ZERO:
                dir = to_goal.normalized()  # میدان هنوز منتشر نشده — مستقیم
        if dir != Vector2.ZERO:
                _move_with(dir, delta, move_speed)
        else:
                _bob_visual(false)


## حرکت با گاردِ سلول غیرقابل‌عبور (آب/خانه/بیرون شبکه) + لغزش تک‌محوره
func _move_with(dir: Vector2, delta: float, speed: float) -> void:
        var pos := Vector2(global_position.x, global_position.z)
        var next := pos + dir * speed * delta
        var nav := PathService.nav
        if nav != null:
                if not nav.is_walkable(nav.world_to_cell(next)):
                        var slide1 := Vector2(next.x, pos.y)
                        var slide2 := Vector2(pos.x, next.y)
                        if nav.is_walkable(nav.world_to_cell(slide1)):
                                next = slide1
                        elif nav.is_walkable(nav.world_to_cell(slide2)):
                                next = slide2
                        else:
                                next = pos
                next = nav.clamp_to_grid(next)
        pos = _separate(next)
        var gy := 0.0
        if ground_provider.is_valid():
                gy = ground_provider.call(pos)
        _y_smooth = lerpf(_y_smooth, gy, clampf(10.0 * delta, 0.0, 1.0))
        global_position = Vector3(pos.x, _y_smooth, pos.y)
        _turn_to(atan2(dir.x, dir.y), delta)
        _bob_visual(true)


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
        var target := 0.26 + (absf(sin(_bob_t * 9.0)) * 0.045 if moving else 0.0)
        var k := clampf(12.0 * get_process_delta_time(), 0.0, 1.0)
        _body.position.y = lerpf(_body.position.y, target, k)


## یورش کوتاه به جلو هنگام ضربه/پرتاب
func _strike_anim() -> void:
        var tw := create_tween()
        tw.tween_property(_body, "position:z", 0.14, 0.08).set_ease(Tween.EASE_OUT)
        tw.tween_property(_body, "position:z", 0.0, 0.14)


func _tick_flash(delta: float) -> void:
        if not _flashing:
                return
        _flash_t += delta
        if _flash_t >= 0.12:
                _flashing = false
                _mat.albedo_color = _flash_restore


# ---------------- آسیب و مرگ (§۷: دائمی) ----------------

func is_dead() -> bool:
        return dead


func is_alive() -> bool:
        return not dead


## ضربه (تیر/ضربه‌ی تن‌به‌تن) — گام ۶R2: اگر «attacker» شناخته باشد، مهاجم
## به شلیک‌کننده تلافی می‌کند (تعقیبِ کوتاه حتی بیرون شعاع توجه)
func take_hit(dmg: int = 1, _from_dir: Vector3 = Vector3.ZERO,
                attacker: Node3D = null) -> void:
        if dead:
                return
        hp -= dmg
        _flash_restore = _mat.albedo_color
        _mat.albedo_color = Color(1, 1, 1, 1)
        _flash_t = 0.0
        _flashing = true
        if attacker != null and is_instance_valid(attacker) \
                        and attacker.is_in_group("units") \
                        and not _unit_dead(attacker):
                engaged_unit = attacker
                _atk_cd = maxf(_atk_cd, 0.3)   # لحظه‌ی روکردن به سمت شلیک‌کننده
                _chase_t = GameConstants.ENEMY_CHASE_SECONDS
        if hp <= 0:
                die()


func die() -> void:
        if dead:
                return
        dead = true
        engaged_unit = null
        remove_from_group("hostiles")
        died.emit(self)
        set_process(false)
        var y0 := position.y
        var tw := create_tween()
        tw.set_parallel(true)
        tw.tween_property(self, "rotation:z", PI * 0.5, 0.42).set_ease(Tween.EASE_OUT)
        tw.tween_property(self, "position:y", y0 - 0.14, 0.42)
        _mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        tw.tween_property(_mat, "albedo_color:a", 0.0, GameConstants.DEATH_FADE_SECONDS) \
                        .set_delay(0.35)
        tw.chain().tween_callback(queue_free)
