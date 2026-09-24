class_name UnitBase
extends Node3D
## پایه‌ی همه‌ی واحدهای نبرد «سرزمین مادری» — معماری رفتار ۴ لایه (سند طراحی §۴):
##
##   لایه ۱ — حرکت پایه: FlowField «چندکاناله» به سمت اسلات آرایش خودش
##            (سرعت 3±5%، شتاب 8، چرخش 360°/s — §۵ پرامت فاز اول)
##   لایه ۲ — Fidget: وقتی بیکار است وول می‌خورد (2–5s → قدم 0.4–0.8m به مدت 0.3–0.8s)
##   لایه ۳ — واکنش نبرد: دشمن در شعاع → رفتار کلاس (در زیرکلاس‌ها override)
##   لایه ۴ — AI مستقل: بدون فرمان → بازگشت به پست (گام ۵)؛ گام ۶+: دفاع از خانه/
##            عقب‌نشینی به قایق (در زیرکلاس‌ها توسعه می‌یابد)
##
## اولویت هر فریم: لایه ۳ > لایه ۱/۲. قانون آهنین کلاس‌ها در زیرکلاس اعمال می‌شود
## (مثلاً «نیزه‌دار هنگام حرکت نمی‌جنگد»).
##
## گام ۵ — هر دسته کانال جریان خودش را دارد: sample_direction(pos, squad_id).

const ARRIVE_RADIUS := 1.0        # حالت بدون اسلات (صحنه‌ی FlowFieldTest)
const SLOT_ARRIVE_RADIUS := 0.45  # رسیدن واقعی روی اسلات آرایش
const DIRECT_STEER_RADIUS := 1.6  # نزدیک هدفِ جریان، flow صفر است → مستقیم
const SLOT_STEER_RADIUS := 2.2    # نزدیک اسلات → مستقیم به اسلات خودش
const SEPARATION_DIST := 0.5

# ---------------- شناسه و کانال (گام ۵) ----------------
## کانال میدان جریان این واحد = شناسه‌ی دسته (0..3)
var squad_id := 0
## رنگ دسته (پالت هخامنشی) — اگر ست نشود، تصادفی از پالت
var squad_color := Color(0, 0, 0, 0)

# ---------------- لایه ۱: حرکت ----------------
## §۵.۱ — هر سرباز سرعت کمی متفاوت دارد (0.95× تا 1.05×)
var speed_mult := 1.0

## صحنه این را به IslandGround.height_at_world وصل می‌کند تا واحد روی زمینِ
## هموار بایستد (بدون آن: y = 0 مثل صحنه‌ی FlowFieldTest)
var ground_provider: Callable = Callable()
var _y_smooth := 0.0

## اسلات آرایش (جهانی XZ). «رسیدن» = ایستادن روی اسلات.
var _slot := Vector2.ZERO
var _has_slot := false

var _vel := Vector2.ZERO
var _arrived := false
var _bob_t := 0.0
var _heading := 0.0

# ---------------- لایه ۲: Fidget ----------------
var fidget_enabled := true
var _fidget_timer := 0.0
var _fidget_state := 0  # 0=ایست 1=خارج‌شدن 2=بازگشت
var _fidget_from := Vector2.ZERO
var _fidget_to := Vector2.ZERO
var _fidget_t := 0.0
var _fidget_dur := 0.5
var _rng := RandomNumberGenerator.new()

# ---------------- لایه ۳: واکنش نبرد ----------------
var _scan_accum := 0.0
var _combat_target: Node3D = null
var _in_combat := false      # فلگ صریح — freed == null در Godot 4 گول نمی‌زند
var _shoot_cooldown := 0.0

# ---------------- بصری ----------------
var _spawn_color: Color
var _mat: StandardMaterial3D
var _body: MeshInstance3D
var _ring: MeshInstance3D


func _ready() -> void:
        add_to_group("units")
        _bob_t = randf() * TAU
        _y_smooth = global_position.y
        _heading = rotation.y

        if squad_color.a > 0.0:
                _spawn_color = squad_color
        else:
                _spawn_color = GameConstants.UNIT_PALETTE.pick_random()
        _mat = StandardMaterial3D.new()
        _mat.albedo_color = _spawn_color
        _mat.roughness = 0.8

        # رسیدن موقتی است: با جابه‌جایی پرچم باید دوباره راه بیفتد
        # (رفع باگ «گیر کردن در آیدل بعد از رسیدن») — فقط برای کانال ۰/بدون اسلات
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

        # حلقه‌ی انتخاب (فقط دسته‌ی انتخابی — الگوی Bad North)
        _ring = MeshInstance3D.new()
        var ring_mesh := CylinderMesh.new()
        ring_mesh.top_radius = 0.42
        ring_mesh.bottom_radius = 0.42
        ring_mesh.height = 0.02
        _ring.mesh = ring_mesh
        _ring.position.y = 0.03
        var ring_mat := StandardMaterial3D.new()
        ring_mat.albedo_color = Color(1, 1, 1, 0.35)
        ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _ring.material_override = ring_mat
        _ring.visible = false
        add_child(_ring)

        # تجهیزات اختصاصی کلاس (سپر/نیزه/کمان — در زیرکلاس‌ها)
        _build_gear()

        _fidget_timer = _rng.randf_range(GameConstants.FIDGET_INTERVAL_MIN,
                        GameConstants.FIDGET_INTERVAL_MAX)


## هوک بصری زیرکلاس‌ها — بین ساخت تنه و شروع Fidget
func _build_gear() -> void:
        pass


## هوک لایه ۳ زیرکلاس‌ها — آیا این واحد می‌خواهد با هدف بجنگد؟
## (قوانین کلاس: نیزه‌دار فقط ایست، کماندار ایست + مسیر باز، جاویدان همیشه)
func _combat_wants(_hostile: Node3D) -> bool:
        return false


## هوک لایه ۳ زیرکلاس‌ها — اجرای رفتار نبرد در هر فریمِ فعال
func _combat_tick(_delta: float, _hostile: Node3D) -> void:
        pass


## پایان رفتار نبرد (خروج هدف از برد / مرگ) — زیرکلاس ژست را برمی‌گرداند
func _combat_end() -> void:
        pass


# ---------------- اسلات آرایش ----------------

## اسلات آرایش این واحد را تعیین می‌کند (صحنه قبل از فرمان صدا می‌زند)
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


## هدف مؤثر این واحد: اسلات خودش یا هدف سراسری جریان (کانال ۰)
func _effective_goal() -> Vector2:
        return _slot if _has_slot else PathService.goal_world()


func _effective_arrive_radius() -> float:
        return SLOT_ARRIVE_RADIUS if _has_slot else ARRIVE_RADIUS


# ---------------- حلقه‌ی اصلی: ۴ لایه با اولویت ----------------

func _process(delta: float) -> void:
        _bob_t += delta

        # ---- لایه ۳: واکنش نبرد (بالاترین اولویت) ----
        _scan_accum += delta
        if _scan_accum >= GameConstants.COMBAT_SCAN_INTERVAL:
                _scan_accum = 0.0
                _rescan_hostile()
        if _in_combat and is_instance_valid(_combat_target):
                _combat_tick(delta, _combat_target)
                return

        # ---- لایه ۱/۲: حرکت و Fidget ----
        if _arrived:
                # لایه ۴ (گام ۵): آشکارسازی جابه‌جایی بیرونی (ضربه/کولک) —
                # واحدِ کناررفته خودش به پست بازمی‌گردد (گام ۶: دفاع از خانه/عقب‌نشینی)
                # ⚠️ در حین Fidget اعمال نمی‌شود (قدم وول تا 0.8m قانونی است)
                if _has_slot and _fidget_state == 0 \
                                and Vector2(global_position.x, global_position.z).distance_to(_slot) \
                                > SLOT_ARRIVE_RADIUS + 0.25:
                        _arrived = false
                        _vel = Vector2.ZERO
                        _set_color(_spawn_color)
                        return
                if _fidget_state != 0:
                        _process_fidget(delta)
                else:
                        # ایست در آرایش + تیک Fidget
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
                        else PathService.sample_direction(pos, squad_id)
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


## وضعیت مغز واحد — برای تست خودکار و HUD
func brain_state() -> StringName:
        if _in_combat:
                return &"combat"
        if _arrived:
                return &"fidget" if _fidget_state != 0 else &"idle"
        return &"moving"


func is_arrived() -> bool:
        return _arrived


func is_fidgeting() -> bool:
        return _arrived and _fidget_state != 0


## هدف فعلی لایه ۳ (null = بیرون نبرد)
func combat_target() -> Node3D:
        return _combat_target


## شعاع جست‌وجوی دشمن این کلاس — کماندار باید از «برد شلیک» ببیند
func _scan_radius() -> float:
        return GameConstants.AGGRO_RADIUS


func _rescan_hostile() -> void:
        var h := _nearest_hostile(_scan_radius())
        if h != null and _combat_wants(h):
                if not _in_combat or _combat_target != h:
                        _combat_begin(h)
                return
        if _in_combat:
                # پایان نبرد — حتی اگر هدف آزاد شده باشد (بازگرداندن ژست کلاس)
                _in_combat = false
                _combat_target = null
                _combat_end()


func _combat_begin(h: Node3D) -> void:
        # نبرد بر Fidget اولویت دارد — وول‌خوردن لغو می‌شود
        _fidget_state = 0
        _combat_target = h
        _in_combat = true


func _nearest_hostile(max_dist: float) -> Node3D:
        var best: Node3D = null
        var best_d := max_dist
        for n in get_tree().get_nodes_in_group("hostiles"):
                var h := n as Node3D
                if h == null or not h.is_inside_tree():
                        continue
                if h.has_method("is_alive") and not h.is_alive():
                        continue
                var d := global_position.distance_to(h.global_position)
                if d < best_d:
                        best_d = d
                        best = h
        return best


## آیا مسیر شلیک از این واحد تا نقطه‌ی هدف باز است؟ (قانون کماندار §۵ سند طراحی)
## زمینِ تپه‌مانند وسط مسیر = مسیر بسته؛ در گام ۶ صخره/سپر دشمن هم اضافه می‌شود.
func has_clear_shot(from_xz: Vector2, from_y: float, to_xz: Vector2, to_y: float) -> bool:
        var dist := from_xz.distance_to(to_xz)
        if dist < 0.5:
                return true
        var steps := maxi(int(dist / 0.4), 2)
        var line_h := maxf(from_y, to_y)
        for i in range(1, steps):
                var k := float(i) / float(steps)
                var p := from_xz.lerp(to_xz, k)
                if ground_provider.is_valid():
                        var gh: float = ground_provider.call(p)
                        # تیر از فراز قوس بالستیک رد می‌شود — سقفِ مجاز: خط مستقیم + نیم‌متر
                        if gh > line_h + 0.5:
                                return false
        return true


## آیا بین این واحد و هدف، هم‌رزمی ایستاده؟ (قانون «آسیب دوستانه ندارد»)
## برای جلوگیری از بن‌بستِ آرایشِ فشرده، فقط هم‌رزمیِ «میانه‌ی مسیر» مانع است:
##   * هم‌رزمیِ شانه‌به‌شانه در ۲۰٪ ابتدای مسیر سد نیست (تیر از فراز سرشان می‌رود)
##   * هم‌رزمیِ چسبیده به هدف سد نیست
func friendly_in_corridor(target_xz: Vector2) -> bool:
        var from := Vector2(global_position.x, global_position.z)
        var to := target_xz
        var seg := to - from
        var seg_len := seg.length()
        if seg_len < 0.001:
                return false
        for n in get_tree().get_nodes_in_group("units"):
                var u := n as Node3D
                if u == null or u == self:
                        continue
                var up := Vector2(u.global_position.x, u.global_position.z)
                var t := clampf((up - from).dot(seg) / (seg_len * seg_len), 0.0, 1.0)
                if t < 0.2 or t > 0.85:
                        continue
                var proj := from + seg * t
                if proj.distance_to(up) <= GameConstants.FRIENDLY_CORRIDOR_HALF_W \
                                and up.distance_to(to) > 0.9:
                        return true
        return false


## پرچم سراسری جابه‌جا شد → «رسیده‌های بدون اسلات» بیدار می‌شوند (صحنه‌ی FlowFieldTest)
func _on_goal_changed(_new_goal: Vector2) -> void:
        if _arrived and not _has_slot:
                _arrived = false
                _vel = Vector2.ZERO
                _set_color(_spawn_color)  # برگشت به رنگ تولد
                _body.position.y = 0.25


## حلقه‌ی انتخاب دسته (Bad North: زیر دسته‌ی انتخابی حلقه‌ی سفید)
func set_selected_ring(on: bool) -> void:
        if _ring != null:
                _ring.visible = on


func is_ring_visible() -> bool:
        return _ring != null and _ring.visible


## «در سفر به فرمان جدید است؟» — لایه ۳ نباید فرمان کاربر را خفه کند:
## تا وقتی واحد دور از اسلاتِ تازه است، فقط تماسِ نزدیک (CONTACT) واکنش می‌دهد
func _is_traveling() -> bool:
        return _has_slot and not _arrived \
                and _effective_goal().distance_to(
                        Vector2(global_position.x, global_position.z)) > SLOT_STEER_RADIUS + 0.6


func _dist_xz_to(n: Node3D) -> float:
        return Vector2(global_position.x, global_position.z).distance_to(
                Vector2(n.global_position.x, n.global_position.z))


func body_color() -> Color:
        return _mat.albedo_color


## رنگ فعلی بدنه — برای تست خودکار (رنگ تولد نباید سرخ «رسیده» باشد)
func spawn_color() -> Color:
        return _spawn_color


## جداسازی ساده بین واحدها (تا روی هم نلغزند) — هزینه با ≤۱۶ واحد ناچیز است
func _separate(pos: Vector2) -> Vector2:
        var others := get_tree().get_nodes_in_group("units")
        for other in others:
                if other == self:
                        continue
                # رسیده‌ها جا می‌دهند: دورِ اسلات جمع می‌شوند ولی مانع رسيدن بقیه نمی‌شوند
                if other is UnitBase and other.is_arrived():
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


# ---------------- Fidget (§۵.۳ پرامت — لایه ۲) ----------------
## «واحدها وول می‌خورند و شلوغ می‌کنند؛ گاهی یک جامانده بیرون می‌زند»

func _tick_fidget_timer(delta: float) -> void:
        if not fidget_enabled or not _has_slot:
                return
        _fidget_timer -= delta
        if _fidget_timer > 0.0:
                return
        _fidget_timer = _rng.randf_range(GameConstants.FIDGET_INTERVAL_MIN,
                        GameConstants.FIDGET_INTERVAL_MAX)
        # یک قدم کوتاه به بیرون آرایش (0.4–0.8 m) — به سمت خودِ اسلات برنمی‌گردیم
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
