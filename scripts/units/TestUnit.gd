class_name TestUnit
extends Node3D
## واحد آزمون گام ۳: حرکت روی FlowField منتشرشده توسط نخ پایدار.
## در گام‌های بعد، معماری چهارلایه (حرکت پایه → Fidget → واکنش نبرد → AI مستقل)
## و سه کلاس (Immortal/Spearman/Archer) روی همین شالوده ساخته می‌شوند.

const SPEED := 2.2
const ARRIVE_RADIUS := 1.0  # بازتر از 0.4 — تا ازدحام دور پرچم مانع ثبت رسیدن نشود
const DIRECT_STEER_RADIUS := 1.6  # در این شعاع، جریانِ سلولِ هدف صفر است → مستقیم به پرچم
const SEPARATION_DIST := 0.5

var _vel := Vector2.ZERO
var _arrived := false
var _bob_t := 0.0
var _spawn_color: Color
var _mat: StandardMaterial3D
var _body: MeshInstance3D

## گام ۴ — صحنه این را به IslandTiles.height_at_world وصل می‌کند تا واحد
## روی سقف کاشی‌ها بایستد (بدون آن: y = 0 مثل صحنه‌ی FlowFieldTest)
var ground_provider: Callable = Callable()
var _y_smooth := 0.0


func _ready() -> void:
        add_to_group("units")
        _bob_t = randf() * TAU
        _y_smooth = global_position.y

        _spawn_color = GameConstants.UNIT_PALETTE.pick_random()
        _mat = StandardMaterial3D.new()
        _mat.albedo_color = _spawn_color
        _mat.roughness = 0.8

        # رسیدن موقتی است: با جابه‌جایی پرچم باید دوباره راه بیفتند
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


func _process(delta: float) -> void:
        _bob_t += delta
        if _arrived:
                # جشن کوچک رسیدن: پریدن بالا-پایین + رنگ نارنجی روشن — از دور هم واضح است
                _body.position.y = 0.25 + absf(sin(_bob_t * 6.0)) * 0.1
                return

        var pos := Vector2(global_position.x, global_position.z)
        var goal := PathService.goal_world()
        var to_goal := goal - pos
        if to_goal.length() <= ARRIVE_RADIUS:
                _arrived = true
                _vel = Vector2.ZERO
                _set_color(GameConstants.COL_ARRIVED)  # سرخ روشن = رسیده به هدف
                return

        var dir := PathService.sample_direction(pos)
        # نزدیک پرچم، flow سلول هدف صفر است (همسایه‌ی ارزان‌تری ندارد) و واحد
        # پشت شعاع رسیدن «یخ» می‌زد — باگ گزارش‌شده‌ی «رسیدن کار نمی‌کند».
        # راه‌حل: در شعاع نزدیک، مستقیم به خود پرچم هدایت شو.
        if to_goal.length() < DIRECT_STEER_RADIUS:
                dir = to_goal.normalized()
        if dir == Vector2.ZERO:
                return  # میدان هنوز منتشر نشده یا هدف دست‌نیافتنی → ایست

        var desired := dir * SPEED
        var k := clampf(10.0 * delta, 0.0, 1.0)
        _vel = _vel.lerp(desired, k)
        pos += _vel * delta
        pos = _separate(pos)
        pos = PathService.clamp_to_grid(pos)
        # ایستادن روی سقف کاشی (اگر provider وصل باشد) — هموارشده تا پله‌ها نپَرد
        var gy := 0.0
        if ground_provider.is_valid():
                gy = ground_provider.call(pos)
        _y_smooth = lerpf(_y_smooth, gy, clampf(10.0 * delta, 0.0, 1.0))
        global_position = Vector3(pos.x, _y_smooth, pos.y)

        var moving := _vel.length_squared() > 0.01
        if moving:
                rotation.y = atan2(_vel.x, _vel.y)  # چرخش مدل (+Z رو به حرکت)
        _bob_visual(moving)


func is_arrived() -> bool:
        return _arrived


## پرچم جابه‌جا شد → همه‌ی «رسیده‌ها» بیدار می‌شوند و دوباره راه می‌افتند
func _on_goal_changed(_new_goal: Vector2) -> void:
        if _arrived:
                _arrived = false
                _vel = Vector2.ZERO
                _set_color(_spawn_color)  # برگشت به رنگ تولد
                _body.position.y = 0.25


## رنگ فعلی بدنه — برای تست خودکار (رنگ تولد نباید نارنجی «رسیده» باشد)
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
