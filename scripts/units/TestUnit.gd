class_name TestUnit
extends Node3D
## واحد آزمون حرکت — پارامترها مستقیم از «پرامت فاز اول §۵»:
##   سرعت پایه 3.0 m/s با تغییر تصادفی 0.95–1.05× | شتاب 8 m/s²
##   چرخش 360 درجه بر ثانیه | فاصله‌ی آرایش 1.2 m | Fidget هر 2–5s به مدت 0.3–0.8s
##
## گام ۴ R2 (بازخورد کاربر): «سربازها باید روی سلول انتخابی بایستند»
##   → هر واحد یک اسلات آرایش درون/اطراف سلول فرمان می‌گیرد و «رسیدن» یعنی
##     ایستادن واقعی روی اسلات (±0.45m)، نه گم‌شدن دور هدف.

const ARRIVE_RADIUS := 1.0        # حالت بدون اسلات (صحنه‌ی FlowFieldTest)
const SLOT_ARRIVE_RADIUS := 0.45  # رسیدن واقعی روی اسلات آرایش
const DIRECT_STEER_RADIUS := 1.6  # نزدیک هدفِ جریان، flow صفر است → مستقیم
const SLOT_STEER_RADIUS := 2.2    # نزدیک اسلات → مستقیم به اسلات خودش
const SEPARATION_DIST := 0.5

var _vel := Vector2.ZERO
var _arrived := false
var _bob_t := 0.0
var _spawn_color: Color
var _mat: StandardMaterial3D
var _body: MeshInstance3D
var _heading := 0.0

## §۵.۱ — لایه ۱: هر سرباز سرعت کمی متفاوت دارد (0.95× تا 1.05×)
var speed_mult := 1.0

## صحنه این را به IslandGround.height_at_world وصل می‌کند تا واحد روی زمینِ
## هموار بایستد (بدون آن: y = 0 مثل صحنه‌ی FlowFieldTest)
var ground_provider: Callable = Callable()
var _y_smooth := 0.0

## گام ۴ R2 — اسلات آرایش (جهانی XZ). «رسیدن» = ایستادن روی اسلات.
var _slot := Vector2.ZERO
var _has_slot := false

## Fidget (§۵.۳) — فقط وقتی در آرایش ایستاده؛ از صحنه قابل خاموش‌شدن (تست قطعی)
var fidget_enabled := true
var _fidget_timer := 0.0
var _fidget_state := 0  # 0=ایست 1=خارج‌شدن 2=بازگشت
var _fidget_from := Vector2.ZERO
var _fidget_to := Vector2.ZERO
var _fidget_t := 0.0
var _fidget_dur := 0.5
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
        add_to_group("units")
        _bob_t = randf() * TAU
        _y_smooth = global_position.y
        _heading = rotation.y

        _spawn_color = GameConstants.UNIT_PALETTE.pick_random()
        _mat = StandardMaterial3D.new()
        _mat.albedo_color = _spawn_color
        _mat.roughness = 0.8

        # رسیدن موقتی است: با جابه‌جایی پرچم باید دوباره راه بیفتد
        # (رفع باگ «گیر کردن در آیدل بعد از رسیدن»)
        GameEvents.goal_changed.connect(_on_goal_changed)

        # تنه
        _body = MeshInstance3D.new()
        var body_mesh := CylinderMesh.new()
        body_mesh.top_radius = 0.14
        body_mesh.bottom_radius = 0.2
        body_mesh.height = 0.5
        _body.mesh = body_mesh
        _body.position.y = 0.25
        _body.material_override = _mat
        add_child(_body)

        # سر
        var head := MeshInstance3D.new()
        var head_mesh := SphereMesh.new()
        head_mesh.radius = 0.11
        head_mesh.height = 0.22
        head.mesh = head_mesh
        head.position.y = 0.58
        head.material_override = _mat
        add_child(head)

        # بینی جهت‌نما (به سمت +Z مدل)
        var nose := MeshInstance3D.new()
        var nose_mesh := BoxMesh.new()
        nose_mesh.size = Vector3(0.08, 0.08, 0.14)
        nose.mesh = nose_mesh
        nose.position = Vector3(0.0, 0.32, 0.22)
        nose.material_override = _mat
        add_child(nose)

        _fidget_timer = _rng.randf_range(GameConstants.FIDGET_INTERVAL_MIN,
                        GameConstants.FIDGET_INTERVAL_MAX)


## اسلات آرایش این واحد را تعیین می‌کند (صحنه قبل از set_goal_world صدا می‌زند)
func set_slot(world_xz: Vector2) -> void:
        _slot = world_xz
        _has_slot = true
        if _arrived:
                _arrived = false
                _set_color(_spawn_color)
                _body.position.y = 0.25


func clear_slot() -> void:
        _has_slot = false


func has_slot() -> bool:
        return _has_slot


func slot_pos() -> Vector2:
        return _slot


## هدف مؤثر این واحد: اسلات خودش یا هدف سراسری جریان
func _effective_goal() -> Vector2:
        return _slot if _has_slot else PathService.goal_world()


func _effective_arrive_radius() -> float:
        return SLOT_ARRIVE_RADIUS if _has_slot else ARRIVE_RADIUS


func _process(delta: float) -> void:
        _bob_t += delta
        if _arrived:
                if _fidget_state != 0:
                        _process_fidget(delta)
                else:
                        # جشن کوچک رسیدن: پریدن بالا-پایین + رنگ سرخ روشن
                        _body.position.y = 0.25 + absf(sin(_bob_t * 6.0)) * 0.1
                        _tick_fidget_timer(delta)
                return

        var pos := Vector2(global_position.x, global_position.z)
        var goal := _effective_goal()
        var to_goal := goal - pos
        var arrive_r := _effective_arrive_radius()
        if to_goal.length() <= arrive_r:
                _arrived = true
                _vel = Vector2.ZERO
                _set_color(GameConstants.COL_ARRIVED)  # سرخ روشن = رسیده به هدف
                return

        # نزدیک اسلات/هدف، جریان صفر می‌شود → هدایت مستقیم (رفع باگ «یخ زدن»)
        var steer_r := SLOT_STEER_RADIUS if _has_slot else DIRECT_STEER_RADIUS
        var dir := to_goal.normalized() if to_goal.length() < steer_r \
                        else PathService.sample_direction(pos)
        if dir == Vector2.ZERO:
                return  # میدان هنوز منتشر نشده یا هدف دست‌نیافتنی → ایست

        var speed := GameConstants.SPEED_BASE * speed_mult
        var desired := dir * speed
        # §۵.۲ — شتاب 8 m/s² (به‌جای lerp نمایی: حرکت قابل‌پیش‌بینی و قانون‌مند)
        _vel = _vel.move_toward(desired, GameConstants.ACCEL * delta)
        if _vel.length_squared() < 0.0001:
                return
        pos += _vel * delta
        pos = _separate(pos)
        pos = PathService.clamp_to_grid(pos)
        # ایستادن روی زمین هموار (اگر provider وصل باشد) — هموارشده تا نپَرد
        var gy := 0.0
        if ground_provider.is_valid():
                gy = ground_provider.call(pos)
        _y_smooth = lerpf(_y_smooth, gy, clampf(10.0 * delta, 0.0, 1.0))
        global_position = Vector3(pos.x, _y_smooth, pos.y)

        # §۵.۲ — چرخش ۳۶۰ درجه بر ثانیه (به‌جای چرخش آنی)
        var moving := _vel.length_squared() > 0.01
        if moving:
                var target := atan2(_vel.x, _vel.y)
                var diff := wrapf(target - _heading, -PI, PI)
                _heading = wrapf(_heading + clampf(diff, -GameConstants.ROTATE_SPEED_RAD * delta,
                                GameConstants.ROTATE_SPEED_RAD * delta), -PI, PI)
                rotation.y = _heading
        _bob_visual(moving)


func is_arrived() -> bool:
        return _arrived


func is_fidgeting() -> bool:
        return _arrived and _fidget_state != 0


## پرچم/اسلات جابه‌جا شد → «رسیده‌ها» بیدار می‌شوند و دوباره راه می‌افتند
func _on_goal_changed(_new_goal: Vector2) -> void:
        if _arrived and not _has_slot:
                _arrived = false
                _vel = Vector2.ZERO
                _set_color(_spawn_color)  # برگشت به رنگ تولد
                _body.position.y = 0.25


## رنگ فعلی بدنه — برای تست خودکار (رنگ تولد نباید سرخ «رسیده» باشد)
func body_color() -> Color:
        return _mat.albedo_color


## جداسازی ساده بین واحدها (تا روی هم نلغزند) — با ۱۰ واحد هزینه‌ای ندارد
func _separate(pos: Vector2) -> Vector2:
        var others := get_tree().get_nodes_in_group("units")
        for other in others:
                if other == self:
                        continue
                # رسیده‌ها جا می‌دهند: دورِ پرچم جمع می‌شوند ولی مانع رسيدن بقیه نمی‌شوند
                if other is TestUnit and other.is_arrived():
                        continue
                var op := Vector2(other.global_position.x, other.global_position.z)
                var diff := pos - op
                var d := diff.length()
                if d > 0.001 and d < SEPARATION_DIST:
                        pos += (diff / d) * (SEPARATION_DIST - d) * 0.5
        return pos


func _bob_visual(moving: bool) -> void:
        var target := 0.25 + (absf(sin(_bob_t * 9.0)) * 0.045 if moving else 0.0)
        var k := clampf(12.0 * get_process_delta_time(), 0.0, 1.0)
        _body.position.y = lerpf(_body.position.y, target, k)


func _set_color(c: Color) -> void:
        _mat.albedo_color = c


# ---------------- Fidget (§۵.۳ پرامت) ----------------
## «واحدها وول می‌خورند و شلوغ می‌کنند؛ گاهی یک جامانده بیرون می‌زند»

func _tick_fidget_timer(delta: float) -> void:
        if not fidget_enabled or not _has_slot:
                return
        _fidget_timer -= delta
        if _fidget_timer > 0.0:
                return
        _fidget_timer = _rng.randf_range(GameConstants.FIDGET_INTERVAL_MIN,
                        GameConstants.FIDGET_INTERVAL_MAX)
        # یک قدم کوتاه به بیرون آرایش (0.4–0.8 m) — به سمت خودِ سلول فرمان برنمی‌گردیم
        var ang := _rng.randf() * TAU
        var dist := _rng.randf_range(GameConstants.FIDGET_DIST_MIN, GameConstants.FIDGET_DIST_MAX)
        _fidget_from = _slot
        _fidget_to = _slot + Vector2(cos(ang), sin(ang)) * dist
        _fidget_t = 0.0
        _fidget_dur = _rng.randf_range(GameConstants.FIDGET_DUR_MIN, GameConstants.FIDGET_DUR_MAX)
        _fidget_state = 1


func _process_fidget(delta: float) -> void:
        _fidget_t += delta
        var k := clampf(_fidget_t / _fidget_dur, 0.0, 1.0)
        var target := (_fidget_to if _fidget_state == 1 else _fidget_from)
        var pos := _fidget_from.lerp(target, k) if _fidget_state == 1 \
                        else _fidget_to.lerp(target, k)
        var gy := 0.0
        if ground_provider.is_valid():
                gy = ground_provider.call(pos)
        _y_smooth = lerpf(_y_smooth, gy, clampf(10.0 * delta, 0.0, 1.0))
        global_position = Vector3(pos.x, _y_smooth, pos.y)
        _body.position.y = 0.25 + absf(sin(_bob_t * 7.0)) * 0.03
        if k >= 1.0:
                if _fidget_state == 1:
                        _fidget_state = 2  # بازگشت به آرایش
                        _fidget_t = 0.0
                else:
                        _fidget_state = 0
