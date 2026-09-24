class_name AutoTestRunner
extends Node
## تست خودکار گام ۳ — معیار پذیرش پیش از تحویل (بدون دخالت دست انسان):
##   1) میدان جریان منتشر می‌شود (worker compute >= 1)
##   2) واحدها واقعاً حرکت می‌کنند (جابه‌جایی > 0.5 متر تا ثانیه ۳)
##   3) کلیک راستِ شبیه‌سازی‌شده از مسیر واقعی ورودی (push_input) →
##      هدف جابه‌جا می‌شود و میدان دوباره محاسبه می‌شود (کارگر زنده بماند)
##   4) Space → حرکت آهسته 0.5 و برگشت به 1.0
##   5) همه‌ی واحدها به پرچمِ «کلیک‌شده» می‌رسند (نه پرچم قدیمی)
## اجرا:
##   godot --headless --path . res://scenes/dev/FlowFieldTest.tscn -- --autotest
## کد خروج: 0 = همه‌ی بررسی‌ها PASS، 1 = حداقل یک FAIL

const CLICK_CELL := Vector2i(6, 6)          # مقصد کلیکِ شبیه‌سازی‌شده‌ی اول
const CLICK_CELL_2 := Vector2i(26, 26)      # کلیک دوم — «بعد از رسیدن» (باگ آیدل)
const MOVE_MIN_UNITS := 8                    # حداقل واحدهایی که تا ثانیه ۳ باید تکان بخورند
const ARRIVE_MIN_UNITS := 9                  # حداقل رسیده‌ها (۱۰ از ۱۰ ممکن است به جداسازی گیر کند)
const ARRIVE_DEADLINE := 30.0                # سقف انتظار برای رسیدن (ثانیه)
const REDIRECT_GRACE := 1.5                  # سکوت بعد از کلیک دوم برای بیدارشدن رسیده‌ها
const REDIRECT_MIN_UNITS := 8                # حداقل واحدهایی که باید از رسیدن بیدار شوند
var _arrived_ref: Color = GameConstants.COL_ARRIVED

var target_scene: Node3D

var _t := 0.0
var _phase := 0
var _fails: PackedStringArray = []
var _results: PackedStringArray = []
var _spawn_pos: Array[Vector3] = []
var _goal_before := Vector2.ZERO
var _computes_before := 0
var _arrive_t0 := 0.0
var _sub := 0                 # زیرفازها داخل فاز ۵
var _arrive2_t0 := 0.0
var _redirect_t0 := 0.0


func _ready() -> void:
        print("[AUTOTEST] harness attached — 6 phases (incl. post-arrival redirect)")


func _check(name: String, ok: bool, detail: String = "") -> void:
        var line := "%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail]
        _results.append(line)
        print("[AUTOTEST] ", line)
        if not ok:
                _fails.append(name)


func _units() -> Array:
        return target_scene.get_tree().get_nodes_in_group("units")


func _process(delta: float) -> void:
        _t += delta
        match _phase:
                0:
                        if _t >= 0.6:
                                _phase0_field_ready()
                1:
                        if _t >= 3.2:
                                _phase1_motion_then_click()
                2:
                        if _t >= 3.8:
                                _phase2_field_follows_flag()
                3:
                        if _t >= 4.3:
                                _phase3_slowmo_toggle()
                4:
                        _phase4_wait_arrival()
                5:
                        _phase5_post_arrival_redirect()
                6:
                        _finish()


# ---------------- فاز ۰: زیرساخت آماده است؟ ----------------

func _phase0_field_ready() -> void:
        var info: Dictionary = PathService.debug_info()
        _check("grid_ready", info["ready"] == true)
        _check("field_published", info["has_field"] == true, "computes=%d" % info["computes"])
        _check("worker_computed_at_least_once", int(info["computes"]) >= 1)

        var n := 0
        for u in _units():
                n += 1
                _spawn_pos.append(u.global_position)
                if u is TestUnit:
                        var dc: Color = u.body_color() - _arrived_ref
                        var dist: float = sqrt(dc.r * dc.r + dc.g * dc.g + dc.b * dc.b)
                        _check("unit_%d_spawn_color_not_orange" % n, dist > 0.35, \
                                        "color=%s" % u.body_color())
        _check("unit_count_is_10", n == 10, "n=%d" % n)
        _phase = 1


# ---------------- فاز ۱: حرکت خودبه‌خودی + کلیک راست ----------------

func _phase1_motion_then_click() -> void:
        var units := _units()
        var moved := 0
        for i in units.size():
                if units[i].global_position.distance_to(_spawn_pos[i]) > 0.5:
                        moved += 1
        _check("units_move_on_field", moved >= MOVE_MIN_UNITS, \
                        "%d/%d moved > 0.5m by t=3.2s" % [moved, units.size()])

        var cam: Camera3D = target_scene.get_viewport().get_camera_3d()
        _check("camera_exists", cam != null)
        if cam == null:
                _finish()
                return

        var nav: NavGrid = PathService.nav
        var world: Vector2 = nav.cell_center(CLICK_CELL)
        var screen: Vector2 = cam.unproject_position(Vector3(world.x, 0.0, world.y))

        var ev := InputEventMouseButton.new()
        ev.button_index = MOUSE_BUTTON_RIGHT
        ev.pressed = true
        ev.position = screen
        ev.global_position = screen
        ev.button_mask = MOUSE_BUTTON_MASK_RIGHT

        _goal_before = PathService.goal_world()
        _computes_before = int(PathService.debug_info()["computes"])
        # in_local_coords=true → مختصاتِ ما مستقیم به _input می‌رسد (در headless
        # تبدیل window→viewport با اندازه‌ی صفر پنجره نقطه را خراب می‌کند)
        target_scene.get_viewport().push_input(ev, true)  # همان مسیر ورودی واقعی بازیکن

        var goal_after: Vector2 = PathService.goal_world()
        _check("rightclick_moves_goal", goal_after.distance_to(_goal_before) > 0.1, \
                        "before=(%.1f,%.1f) after=(%.1f,%.1f)" % [_goal_before.x, _goal_before.y, goal_after.x, goal_after.y])
        _phase = 2


# ---------------- فاز ۲: میدان باید از پرچم پیروی کند ----------------

func _phase2_field_follows_flag() -> void:
        var info: Dictionary = PathService.debug_info()
        var computes_now: int = int(info["computes"])
        _check("field_recomputed_after_click", computes_now > _computes_before, \
                        "computes before=%d now=%d" % [_computes_before, computes_now])

        var want: Vector2 = PathService.nav.cell_center(CLICK_CELL)
        var g: Vector2 = info["goal"]
        _check("goal_is_click_point", g.distance_to(want) <= 1.01, \
                        "goal=(%.1f,%.1f) want=(%.1f,%.1f)" % [g.x, g.y, want.x, want.y])
        _phase = 3


# ---------------- فاز ۳: Space → slow-mo ----------------

func _phase3_slowmo_toggle() -> void:
        var ev := InputEventKey.new()
        ev.physical_keycode = KEY_SPACE
        ev.keycode = KEY_SPACE
        ev.pressed = true
        target_scene.get_viewport().push_input(ev)
        var ts := Engine.time_scale
        _check("space_toggles_slowmo_on", absf(ts - 0.5) < 0.01, "time_scale=%.2f" % ts)

        var ev2 := InputEventKey.new()
        ev2.physical_keycode = KEY_SPACE
        ev2.keycode = KEY_SPACE
        ev2.pressed = true
        target_scene.get_viewport().push_input(ev2)
        _check("space_toggles_slowmo_off", absf(Engine.time_scale - 1.0) < 0.01, \
                        "time_scale=%.2f" % Engine.time_scale)
        _phase = 4
        _arrive_t0 = _t


# ---------------- فاز ۴: رسیدن به پرچمِ کلیک‌شده ----------------

func _phase4_wait_arrival() -> void:
        var units := _units()
        var arrived := 0
        var arrived_at_click := 0
        var want: Vector2 = PathService.nav.cell_center(CLICK_CELL)
        for u in units:
                if u is TestUnit and u.is_arrived():
                        arrived += 1
                        var p: Vector3 = u.global_position
                        if Vector2(p.x, p.z).distance_to(want) <= 1.5:
                                arrived_at_click += 1
        if arrived >= ARRIVE_MIN_UNITS or (_t - _arrive_t0) > ARRIVE_DEADLINE:
                _check("units_arrive_flag", arrived >= ARRIVE_MIN_UNITS, \
                                "%d/%d arrived in %.1fs" % [arrived, units.size(), _t - _arrive_t0])
                _check("arrived_units_at_CLICKED_flag", arrived_at_click >= ARRIVE_MIN_UNITS, \
                                "%d/%d within 1.5m of clicked cell %s" % [arrived_at_click, units.size(), CLICK_CELL])
                _phase = 5
                _sub = 0


# ---------------- فاز ۵: کلیک دوم بعد از رسیدن (باگ «گیر کردن در آیدل») ----------------

func _phase5_post_arrival_redirect() -> void:
        match _sub:
                0:
                        # همان لحظه‌ای که همه دور پرچم اول قرمز شده‌اند، پرچم را برمی‌گردانیم
                        var cam: Camera3D = target_scene.get_viewport().get_camera_3d()
                        var nav: NavGrid = PathService.nav
                        var world: Vector2 = nav.cell_center(CLICK_CELL_2)
                        var screen: Vector2 = cam.unproject_position(Vector3(world.x, 0.0, world.y))
                        var ev := InputEventMouseButton.new()
                        ev.button_index = MOUSE_BUTTON_RIGHT
                        ev.pressed = true
                        ev.position = screen
                        ev.global_position = screen
                        ev.button_mask = MOUSE_BUTTON_MASK_RIGHT
                        target_scene.get_viewport().push_input(ev, true)
                        _redirect_t0 = _t
                        _sub = 1
                1:
                        # پس از ۱.۵ ثانیه: رسیده‌ها باید بیدار شده باشند (قرمز → رنگ تولد، در حال حرکت)
                        if _t - _redirect_t0 >= REDIRECT_GRACE:
                                var awake := 0
                                for u in _units():
                                        if u is TestUnit and not u.is_arrived():
                                                awake += 1
                                _check("arrived_units_wake_on_new_click", awake >= REDIRECT_MIN_UNITS, \
                                                "%d/%d marching again 1.5s after 2nd click" % [awake, _units().size()])
                                _arrive2_t0 = _t
                                _sub = 2
                2:
                        # و در نهایت باید به پرچم دوم برسند
                        var want: Vector2 = PathService.nav.cell_center(CLICK_CELL_2)
                        var arrived2 := 0
                        for u in _units():
                                if u is TestUnit and u.is_arrived():
                                        var p: Vector3 = u.global_position
                                        if Vector2(p.x, p.z).distance_to(want) <= 1.5:
                                                arrived2 += 1
                        if arrived2 >= ARRIVE_MIN_UNITS or (_t - _arrive2_t0) > ARRIVE_DEADLINE:
                                _check("units_reach_SECOND_flag", arrived2 >= ARRIVE_MIN_UNITS, \
                                                "%d/%d at cell %s in %.1fs" % [arrived2, _units().size(), CLICK_CELL_2, _t - _arrive2_t0])
                                _phase = 6


# ---------------- پایان ----------------

func _finish() -> void:
        print("[AUTOTEST] ----------------------------------------")
        for r in _results:
                print("[AUTOTEST] ", r)
        var ok := _fails.is_empty()
        print("[AUTOTEST] RESULT: %s  (%d checks, %d fails)" % \
                        ["PASS" if ok else "FAIL", _results.size(), _fails.size()])
        set_process(false)
        get_tree().quit(0 if ok else 1)
