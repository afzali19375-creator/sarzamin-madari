extends Node3D
## صحنه‌ی آزمون گام ۲ و ۳ — معیار تحویل سند طراحی:
## «۱۰ واحد، یک هدف — بدون فریم‌دراپ؛ خواندن مسیر در نخ اصلی < 0.5ms»
##
## کنترل‌ها:
##   کلیک راست → جابه‌جایی پرچم هدف
##   Space     → حرکت آهسته (time_scale = 0.5 — همان قانون نبرد بازی)

const GRID_W := 32
const GRID_H := 32
const CELL := 1.0
const UNIT_COUNT := 10

const FONT_FA := "res://assets/fonts/Vazirmatn-Regular.ttf"

const OBSTACLE_RECTS: Array[Rect2i] = [
        Rect2i(8, 6, 4, 2),
        Rect2i(16, 12, 2, 6),
        Rect2i(22, 20, 5, 2),
        Rect2i(6, 22, 3, 3),
        Rect2i(14, 4, 2, 2),
        Rect2i(25, 8, 2, 4),
]
const SPAWN_MIN := Vector2i(2, 2)
const SPAWN_MAX := Vector2i(7, 29)
const GOAL_CELL := Vector2i(24, 24)

var _goal_flag: Node3D
var _stats_label: Label
var _time_scale := 1.0
var _ui_accum := 0.0
var _last_input_msg := "none yet"
# تشخیص‌های بصری برای کاربر: پیام شناور + حلقه‌ی کلیک + سلامت میدان
var _toast: Label
var _toast_t := 10.0
var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D
var _marker_t := 10.0
var _last_computes := -1
var _stall := 0.0


func _ready() -> void:
        _build_world()
        PathService.setup_grid(GRID_W, GRID_H, CELL, Vector2(-GRID_W, -GRID_H) * CELL * 0.5)
        PathService.auto_recompute = true
        _build_obstacles()
        _build_goal_flag(GOAL_CELL)
        _spawn_units()
        _build_click_marker()
        _build_ui()
        # تست خودکارِ پیش از تحویل:  godot ... -- --autotest
        if OS.get_cmdline_user_args().has("--autotest"):
                var runner := AutoTestRunner.new()
                runner.target_scene = self
                add_child(runner)


func _exit_tree() -> void:
        # recompute سراسری روشن می‌ماند (صحنه‌های بعدی به آن نیاز دارند)؛
        # فقط مقیاس زمان را به حالت عادی برمی‌گردانیم.
        Engine.time_scale = 1.0


# ---------------- ساخت دنیا ----------------

func _build_world() -> void:
        var sky_mat := ProceduralSkyMaterial.new()
        sky_mat.sky_top_color = Color("0e3a4a")
        sky_mat.sky_horizon_color = Color("3aa8a0")
        sky_mat.ground_bottom_color = Color("07242b")
        sky_mat.ground_horizon_color = Color("2b8b84")
        var sky := Sky.new()
        sky.sky_material = sky_mat
        var env := Environment.new()
        env.background_mode = Environment.BG_SKY
        env.sky = sky
        env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
        env.ambient_light_energy = 1.1
        env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
        var we := WorldEnvironment.new()
        we.environment = env
        add_child(we)

        var sun := DirectionalLight3D.new()
        sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
        sun.light_energy = 1.2
        sun.shadow_enabled = true
        add_child(sun)

        var cam := Camera3D.new()
        cam.position = Vector3(0.0, 27.0, 18.0)
        cam.rotation_degrees = Vector3(-58.0, 0.0, 0.0)
        cam.fov = 58.0
        add_child(cam)

        var ground := MeshInstance3D.new()
        var pm := PlaneMesh.new()
        pm.size = Vector2(GRID_W, GRID_H) * CELL
        ground.mesh = pm
        var gm := StandardMaterial3D.new()
        gm.albedo_color = Color("2f8f83")
        gm.roughness = 1.0
        ground.material_override = gm
        add_child(ground)


func _build_obstacles() -> void:
        var origin := PathService.nav.origin
        for r in OBSTACLE_RECTS:
                for y in range(r.position.y, r.position.y + r.size.y):
                        for x in range(r.position.x, r.position.x + r.size.x):
                                PathService.nav.set_walkable(Vector2i(x, y), false)
                var box := MeshInstance3D.new()
                var bm := BoxMesh.new()
                bm.size = Vector3(r.size.x * CELL, 0.7, r.size.y * CELL)
                box.mesh = bm
                var center := origin + (Vector2(r.position) + Vector2(r.size) * 0.5) * CELL
                box.position = Vector3(center.x, 0.35, center.y)
                var om := StandardMaterial3D.new()
                om.albedo_color = GameConstants.COL_BEACH_SAND.lerp(GameConstants.COL_IVORY, randf() * 0.35)
                om.roughness = 1.0
                box.material_override = om
                add_child(box)


func _build_goal_flag(cell: Vector2i) -> void:
        var p := PathService.nav.cell_center(cell)
        _goal_flag = Node3D.new()

        var pole := MeshInstance3D.new()
        var pole_mesh := CylinderMesh.new()
        pole_mesh.top_radius = 0.035
        pole_mesh.bottom_radius = 0.05
        pole_mesh.height = 1.3
        pole.mesh = pole_mesh
        pole.position.y = 0.65
        _goal_flag.add_child(pole)

        var flag := MeshInstance3D.new()
        var fm := BoxMesh.new()
        fm.size = Vector3(0.55, 0.3, 0.03)
        flag.mesh = fm
        flag.position = Vector3(0.31, 1.05, 0.0)
        _goal_flag.add_child(flag)

        var ring := MeshInstance3D.new()
        var tm := TorusMesh.new()
        tm.inner_radius = 0.42
        tm.outer_radius = 0.55
        ring.mesh = tm
        ring.position.y = 0.04
        _goal_flag.add_child(ring)

        var gold := StandardMaterial3D.new()
        gold.albedo_color = GameConstants.COL_GOLD
        gold.emission_enabled = true
        gold.emission = GameConstants.COL_GOLD
        gold.emission_energy_multiplier = 0.35
        for child in _goal_flag.get_children():
                (child as MeshInstance3D).material_override = gold

        _goal_flag.position = Vector3(p.x, 0.0, p.y)
        add_child(_goal_flag)
        PathService.set_goal_world(p)


func _spawn_units() -> void:
        for i in UNIT_COUNT:
                var c := _random_walkable_cell(SPAWN_MIN, SPAWN_MAX)
                var center := PathService.nav.cell_center(c)
                var unit := TestUnit.new()
                unit.position = Vector3(center.x, 0.0, center.y)
                add_child(unit)


func _random_walkable_cell(min_c: Vector2i, max_c: Vector2i) -> Vector2i:
        for attempt in 100:
                var c := Vector2i(randi_range(min_c.x, max_c.x), randi_range(min_c.y, max_c.y))
                if PathService.nav.is_walkable(c):
                        return c
        return Vector2i(2, 2)


# ---------------- رابط کاربری ----------------

func _build_click_marker() -> void:
        # حلقه‌ی طلایی که بعد از هر کلیک روی نقطه‌ی «درک‌شده توسط بازی» فلاش می‌زند —
        # اگر کلیک بیرون جزیره باشد، حلقه روی لبه ظاهر می‌شود و خودش توضیح می‌دهد
        _marker = MeshInstance3D.new()
        var tm := TorusMesh.new()
        tm.inner_radius = 0.35
        tm.outer_radius = 0.5
        _marker.mesh = tm
        _marker_mat = StandardMaterial3D.new()
        _marker_mat.albedo_color = GameConstants.COL_GOLD
        _marker_mat.emission_enabled = true
        _marker_mat.emission = GameConstants.COL_GOLD
        _marker_mat.emission_energy_multiplier = 1.2
        _marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _marker.material_override = _marker_mat
        _marker.visible = false
        add_child(_marker)


func _flash_marker(p: Vector3) -> void:
        _marker.position = p
        _marker.scale = Vector3.ONE
        _marker_mat.albedo_color.a = 0.9
        _marker.visible = true
        _marker_t = 0.0


func _toast_msg(msg: String) -> void:
        if _toast == null:
                return
        _toast.text = msg
        _toast.visible = true
        _toast_t = 0.0


func _world_inside_grid(p: Vector2) -> bool:
        var o: Vector2 = PathService.nav.origin
        var s: Vector2 = PathService.nav.size_world()
        return p.x >= o.x and p.y >= o.y and p.x <= o.x + s.x and p.y <= o.y + s.y


func _build_ui() -> void:
        var layer := CanvasLayer.new()
        add_child(layer)

        var margin := MarginContainer.new()
        margin.set_anchors_preset(Control.PRESET_FULL_RECT)
        margin.add_theme_constant_override("margin_left", 16)
        margin.add_theme_constant_override("margin_right", 16)
        margin.add_theme_constant_override("margin_top", 12)
        margin.add_theme_constant_override("margin_bottom", 12)
        margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
        layer.add_child(margin)

        var vb := VBoxContainer.new()
        vb.size_flags_vertical = Control.SIZE_SHRINK_END
        vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        vb.add_theme_constant_override("separation", 6)
        margin.add_child(vb)

        _stats_label = Label.new()
        _stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _stats_label.add_theme_font_size_override("font_size", 16)
        _stats_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.9, 0.95))
        vb.add_child(_stats_label)

        var hint := Label.new()
        hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hint.add_theme_font_size_override("font_size", 18)
        hint.add_theme_color_override("font_color", GameConstants.COL_IVORY)
        if ResourceLoader.exists(FONT_FA):
                hint.add_theme_font_override("font", load(FONT_FA))
        hint.text = "%s  |  %s" % [tr("hint_move"), tr("hint_slow")]
        vb.add_child(hint)

        # پیام شناور دوزبانه‌ی بالای صفحه (نتیجه‌ی هر کلیک راست)
        _toast = Label.new()
        _toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _toast.add_theme_font_size_override("font_size", 24)
        _toast.add_theme_color_override("font_color", GameConstants.COL_GOLD)
        _toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
        _toast.add_theme_constant_override("outline_size", 8)
        if ResourceLoader.exists(FONT_FA):
                _toast.add_theme_font_override("font", load(FONT_FA))
        _toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
        _toast.offset_top = 56.0
        _toast.offset_bottom = 120.0
        _toast.offset_left = 40.0
        _toast.offset_right = -40.0
        _toast.visible = false
        layer.add_child(_toast)


func _process(delta: float) -> void:
        _ui_accum += delta
        if _ui_accum >= 0.25:
                _ui_accum = 0.0
                _refresh_stats()
        # فَید حلقه‌ی کلیک
        if _marker != null and _marker.visible:
                _marker_t += delta
                var k: float = clampf(_marker_t / 0.6, 0.0, 1.0)
                _marker_mat.albedo_color.a = 0.9 * (1.0 - k)
                var s := 1.0 + k * 1.6
                _marker.scale = Vector3(s, 1.0, s)
                if k >= 1.0:
                        _marker.visible = false
        # پنهان‌سازی پیام شناور پس از ۳ ثانیه
        _toast_t += delta
        if _toast != null and _toast.visible and _toast_t > 3.0:
                _toast.visible = false


func _refresh_stats() -> void:
        var info := PathService.debug_info()
        # سلامت میدان: اگر شمارنده‌ی محاسبه‌ها ۱ ثانیه منجمد بماند → میدان مرده است
        var computes: int = int(info["computes"])
        if computes != _last_computes:
                _last_computes = computes
                _stall = 0.0
        else:
                _stall += 0.25
        var field_state: String = "LIVE" if _stall < 1.0 else "FROZEN!!"
        var arrived := 0
        var total := 0
        for u in get_tree().get_nodes_in_group("units"):
                total += 1
                if u is TestUnit and u.is_arrived():
                        arrived += 1
        var goal: Vector2 = info["goal"]
        _stats_label.text = "build %s  |  FPS %d  |  field: %s  |  units %d  arrived %d  |  input: %s\nworker compute: %.2f ms (every %.1f s)  |  main-thread read: %.4f ms (budget %.1f ms)\ncomputes: %d  goal: (%.1f, %.1f)  time_scale: %.1f" % [
                GameConstants.BUILD_ID, Engine.get_frames_per_second(), field_state,
                total, arrived, _last_input_msg,
                info["compute_ms"], GameConstants.FIELD_RECOMPUTE_INTERVAL,
                info["read_ms"], GameConstants.MAIN_READ_BUDGET_MS,
                computes, goal.x, goal.y, _time_scale,
        ]


# ---------------- ورودی ----------------

## تشخیص خام رویدادها در _input — مستقل از InputMap تا هیچ کلیکی گم نشود.
## (اکشن‌های project.godot برای سامانه‌های بعدی همچنان تعریف شده‌اند.)
func _input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed:
                if event.button_index == MOUSE_BUTTON_RIGHT:
                        _move_goal_to_mouse(event.position)
                elif event.button_index == MOUSE_BUTTON_LEFT:
                        _last_input_msg = "left-click seen (use RIGHT-click to move flag)"
        elif event is InputEventKey and event.pressed and not event.echo:
                if event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE:
                        _toggle_slowmo()


func _toggle_slowmo() -> void:
        _time_scale = GameConstants.SLOWMO_SCALE if _time_scale == 1.0 else 1.0
        Engine.time_scale = _time_scale
        _last_input_msg = "space -> slow-mo %s" % ("ON" if _time_scale < 1.0 else "OFF")


func _move_goal_to_mouse(mouse_pos: Vector2) -> void:
        var cam := get_viewport().get_camera_3d()
        if cam == null:
                _last_input_msg = "right-click but NO CAMERA!"
                return
        if _goal_flag == null:
                _last_input_msg = "right-click but no flag!"
                return
        var from := cam.project_ray_origin(mouse_pos)
        var dir := cam.project_ray_normal(mouse_pos)
        var plane := Plane(Vector3.UP, 0.0)
        var hit = plane.intersects_ray(from, dir)
        if hit == null:
                _last_input_msg = "right-click missed ground plane (click lower, ON the island)"
                _toast_msg("کلیک به زمین نخورد — پایین‌تر و روی جزیره کلیک کن\nClick missed the ground — click lower, ON the island")
                return
        var inside := _world_inside_grid(Vector2(hit.x, hit.z))
        PathService.set_goal_world(Vector2(hit.x, hit.z))
        var g := PathService.goal_world()
        _goal_flag.position = Vector3(g.x, 0.0, g.y)
        _flash_marker(Vector3(g.x, 0.06, g.y))
        _last_input_msg = "right-click OK @ (%.1f, %.1f)" % [g.x, g.y]
        if inside:
                _toast_msg("هدف جابه‌جا شد → (%.1f, %.1f) — سربازها در راه‌اند\nGoal moved — soldiers are on the way" % [g.x, g.y])
        else:
                _toast_msg("کلیک بیرون جزیره بود → به لبه محدود شد (%.1f, %.1f)\nClick was outside the island — clamped to its edge" % [g.x, g.y])
