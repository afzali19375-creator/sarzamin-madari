extends Node3D
## صحنه‌ی آزمون گام ۴ R2 — «زمین صاف Bad North + شبکه‌ی فرمان سفید»
##
## بازخوردهای کاربر که این صحنه پاسخ می‌دهد:
##   ۱) کل زمین بلوک‌بلوک نیست — زمین صاف است؛ بلوک‌ها فقط هنگام فرمان ظاهر می‌شوند
##   ۲) سلول‌های فرمان بزرگ‌ترند (۲×۲ متر) و به‌صورت «هاله‌ی سفید» می‌درخشند
##   ۳) دسته‌ی انتخابی واقعاً روی سلول فرمان می‌ایستد (آرایش ۱.۲ متری §۵)
##   ۴) آب متحرک + خانه‌های واقعی هخامنشی؛ بقیه‌ی گرافیک مینیمال (§۱۳/§۱۴)
##
## تعامل دقیقاً طبق §۲ پرامت:
##   کلیک چپ روی سرباز  → انتخاب دسته: اسلوموشن (۰.۱۵s) + هاله‌ی سفید (§۲.۳)
##   کلیک چپ روی سلول سفید → فرمان: دسته می‌رود و همان‌جا می‌ایستد (§۲.۴)
##   Shift + کلیک → Waypoint (حداکثر ۸، خط فیروزه‌ای #3AB0A0) (§۴)
##   کلیک چپ روی جای خالی / سربازِ انتخابی → لغو انتخاب (بازگشت ۰.۲s)
##   Space (نگه‌داشتن) → اسلوموشن (§۶)  |  Q/E چرخش دوربین ۳۶۰°  |  Wheel زوم
##   R جزیره‌ی جدید  |  G همان seed  |  کلیک راست = فرمان (سازگاری با عادت قبل)

enum Mode { IDLE, COMMAND }

const GRID := 32
const CELL := 1.0
const UNIT_COUNT := 10
const FONT_FA := "res://assets/fonts/Vazirmatn-Regular.ttf"
const DEFAULT_SEED := 20260924
const SELECT_PICK_PX := 46.0
const SELECT_PICK_WORLD := 1.15
const WP_REACH_ARRIVED := 8     # ≥۸ سرباز رسیده → waypoint بعدی
const SLOT_MAX_RING := 3

var mode := Mode.IDLE
var island: Dictionary = {}
var ground: IslandGround
var cmd_grid: CommandGrid
var props: IslandProps
var blocked_by_houses: Array[Vector2i] = []
var waypoints: Array[Vector2] = []
var squad: Array[TestUnit] = []
var squad_selected_fired := false   # برای تست خودکار

var _island_seed := DEFAULT_SEED
var _units_root: Node3D
var _goal_cell := Vector2i(-1, -1)

# دوربین (§۷ پرامت)
var _cam_pivot: Node3D
var _cam_arm: Node3D
var _cam: Camera3D
var _yaw := GameConstants.CAM_YAW0_DEG
var _target_height := GameConstants.CAM_HEIGHT0
var _middle_drag := false
var _keys_held := {}

# اسلوموشن (§۶ پرامت)
var _slow_select := false
var _slow_space := false

var _hover_info := {}
var _wp_wait := 0.0

var _stats_label: Label
var _toast: Label
var _toast_t := 10.0
var _ping: MeshInstance3D
var _ping_mat: StandardMaterial3D
var _ping_t := 10.0
var _wp_root: Node3D
var _wp_line: MeshInstance3D
var _ui_accum := 0.0
var _last_input_msg := "none yet"
var _last_computes := -1
var _stall := 0.0


func _ready() -> void:
        _build_environment()
        PathService.setup_grid(GRID, GRID, CELL, Vector2(-GRID, -GRID) * CELL * 0.5)
        PathService.auto_recompute = true
        _regenerate(_island_seed, false)
        _build_ui()
        if OS.get_cmdline_user_args().has("--autotest"):
                var runner := IslandAutoTest.new()
                runner.target_scene = self
                add_child(runner)


func _exit_tree() -> void:
        Engine.time_scale = 1.0


# ---------------- تولید و بازسازی جزیره ----------------

func _regenerate(seed_value: int, announce: bool) -> void:
        _island_seed = seed_value
        var gen := WfcIsland.new()
        island = gen.generate(seed_value, GRID)
        if island.get("ok", false) != true:
                push_error("WfcIsland: generation failed for seed %d" % seed_value)
                if _stats_label != null:
                        _stats_label.text = "WFC FAILED for seed %d" % seed_value
                return
        var nav := PathService.nav
        if ground == null:
                ground = IslandGround.new()
                add_child(ground)
        ground.build(island, CELL, nav.origin)
        _apply_island_to_nav()
        # خانه‌ها بعد از اعمال walkable جزیره — سلول‌هایشان در nav مسدود می‌شود
        if props == null:
                props = IslandProps.new()
                add_child(props)
        props.build(ground, nav, island, int(island["seed_used"]))
        blocked_by_houses = props.blocked_cells.duplicate()
        if cmd_grid == null:
                cmd_grid = CommandGrid.new()
                add_child(cmd_grid)
        cmd_grid.rebuild(ground, nav)
        # ریست وضعیت فرمان
        waypoints.clear()
        _rebuild_waypoint_line()
        mode = Mode.IDLE
        _slow_select = false
        _slow_space = false
        Engine.time_scale = 1.0
        _clear_units()
        # هدف اولیه: نزدیک‌ترین سلول فرمان معتبر به مرکز خشکی
        _goal_cell = _pick_goal_cell()
        _spawn_units()
        PathService.set_goal_world(PathService.nav.cell_center(_goal_cell))
        if announce:
                _toast_msg("جزیره‌ی جدید — بذر %d (تلاش %d، %.0f ms)\nNew island — seed %d (attempt %d, %.0f ms)" % [
                        island["seed_used"], island["attempts"], island["gen_ms"],
                        island["seed_used"], island["attempts"], island["gen_ms"]])
                _last_input_msg = "regen seed=%d" % seed_value


func _apply_island_to_nav() -> void:
        var nav := PathService.nav
        nav.walkable.fill(1)
        nav.costs.fill(1.0)
        var w: PackedByteArray = island["walkable"]
        for y in GRID:
                for x in GRID:
                        var c := Vector2i(x, y)
                        if w[y * GRID + x] == 0:
                                nav.set_walkable(c, false)
                                continue
                        # §۳.۲ پرامت — هزینه‌ی زمین: چمن 1.0 | شن 1.2 | صخره‌ی کم 1.5
                        var mname := String(island["meta_names"][int(island["modules"][y * GRID + x])])
                        if mname.begins_with("sand"):
                                nav.set_cost(c, 1.2)
                        elif mname.begins_with("grass_path"):
                                nav.set_cost(c, 1.0)
        # صخره‌های کم‌ارتفاع غیرقابل‌عبورند؛ صحنه‌ی dev هزینه‌ی پیش‌فرض ۱ را نگه می‌دارد


func _clear_units() -> void:
        squad.clear()
        if _units_root == null:
                _units_root = Node3D.new()
                _units_root.name = "Units"
                add_child(_units_root)
                return
        for c in _units_root.get_children():
                c.free()


func _spawn_units() -> void:
        var nav := PathService.nav
        var rng := RandomNumberGenerator.new()
        rng.seed = int(island["seed_used"]) * 31 + int(island["attempts"])
        var goal_center := nav.cell_center(_goal_cell)
        var cands: Array[Vector2i] = []
        var fallback: Array[Vector2i] = []
        for y in GRID:
                for x in GRID:
                        var c := Vector2i(x, y)
                        if not nav.is_walkable(c):
                                continue
                        fallback.append(c)
                        var d := (nav.cell_center(c) - goal_center).length()
                        if d >= 3.5 and d <= 14.0:
                                cands.append(c)
        if cands.size() < UNIT_COUNT:
                cands = fallback
        for i in range(cands.size() - 1, 0, -1):
                var j := rng.randi_range(0, i)
                var tmp := cands[i]
                cands[i] = cands[j]
                cands[j] = tmp
        var spawned := 0
        for c in cands:
                if spawned >= UNIT_COUNT:
                        break
                var center := nav.cell_center(c)
                var u := TestUnit.new()
                u.position = Vector3(center.x, ground.height_at_world(center), center.y)
                u.ground_provider = Callable(ground, "height_at_world")
                u.speed_mult = 1.0 - GameConstants.SPEED_VARIATION \
                                + rng.randf() * 2.0 * GameConstants.SPEED_VARIATION
                u.fidget_enabled = true
                _units_root.add_child(u)
                squad.append(u)
                spawned += 1


func _pick_goal_cell() -> Vector2i:
        # نزدیک‌ترین سلول فرمان معتبر به مرکز خشکی — همه‌چیز در مختصات «جهانی»
        # (سلول مرکزِ سلول‌فرمان باید قابل‌عبور باشد تا BFS/تست از آن شروع شود)
        var nav := PathService.nav
        var acc := Vector2.ZERO
        var count := 0
        for y in GRID:
                for x in GRID:
                        if nav.is_walkable(Vector2i(x, y)):
                                acc += nav.cell_center(Vector2i(x, y))
                                count += 1
        if count == 0:
                return Vector2i(GRID / 2, GRID / 2)
        var centroid := acc / float(count)
        var best := -1
        var best_d := 1e9
        for i in cmd_grid.cell_count:
                var info := cmd_grid.cell_info(i)
                var cc: Vector2i = nav.world_to_cell(info["center"])
                if not nav.is_walkable(cc):
                        continue
                var d: float = (info["center"] - centroid).length()
                if d < best_d:
                        best_d = d
                        best = i
        if best < 0:
                return Vector2i(GRID / 2, GRID / 2)
        var center: Vector2 = cmd_grid.cell_info(best)["center"]
        return nav.world_to_cell(center)


func regenerate(seed_value: int) -> void:
        _regenerate(seed_value, true)


# ---------------- محیط و دوربین (§۷ پرامت) ----------------

func _build_environment() -> void:
        var sky_mat := ProceduralSkyMaterial.new()
        # §۱۴ — آسمان #D4E4EC (تقریباً سفید-خاکستری) با افق مه‌آلود Bad North
        sky_mat.sky_top_color = Color("b9cdd9")
        sky_mat.sky_horizon_color = GameConstants.COL_SKY
        sky_mat.ground_bottom_color = Color("9fb4bf")
        sky_mat.ground_horizon_color = GameConstants.COL_SKY
        var sky := Sky.new()
        sky.sky_material = sky_mat
        var env := Environment.new()
        env.background_mode = Environment.BG_SKY
        env.sky = sky
        env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
        env.ambient_light_energy = 1.15
        env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
        env.fog_enabled = true
        env.fog_light_color = GameConstants.COL_SKY
        env.fog_density = 0.008
        env.fog_sky_affect = 0.2
        var we := WorldEnvironment.new()
        we.environment = env
        add_child(we)

        var sun := DirectionalLight3D.new()
        sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
        sun.light_energy = 1.15
        sun.light_color = GameConstants.COL_SUN
        sun.shadow_enabled = true
        add_child(sun)

        _cam_pivot = Node3D.new()
        add_child(_cam_pivot)
        _cam_pivot.rotation.y = deg_to_rad(_yaw)
        _cam_arm = Node3D.new()
        _cam_pivot.add_child(_cam_arm)
        _cam_arm.rotation_degrees.x = GameConstants.CAM_PITCH_DEG
        _cam = Camera3D.new()
        _cam.fov = GameConstants.CAM_FOV
        _cam.near = GameConstants.CAM_NEAR
        _cam.far = GameConstants.CAM_FAR
        _cam_arm.add_child(_cam)
        _cam.position = Vector3(0, 0, GameConstants.CAM_HEIGHT0)
        _cam.current = true

        _ping = MeshInstance3D.new()
        var tm := TorusMesh.new()
        tm.inner_radius = 0.35
        tm.outer_radius = 0.5
        _ping.mesh = tm
        _ping_mat = StandardMaterial3D.new()
        _ping_mat.albedo_color = GameConstants.COL_GOLD
        _ping_mat.emission_enabled = true
        _ping_mat.emission = GameConstants.COL_GOLD
        _ping_mat.emission_energy_multiplier = 1.2
        _ping_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _ping.material_override = _ping_mat
        _ping.visible = false
        add_child(_ping)

        # خط Waypoint (§۴ پرامت) — رنگ #3AB0A0 با Alpha 0.6
        _wp_root = Node3D.new()
        add_child(_wp_root)
        _wp_line = MeshInstance3D.new()
        var lm := StandardMaterial3D.new()
        lm.vertex_color_use_as_albedo = true
        lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _wp_line.material_override = lm
        _wp_line.visible = false
        _wp_root.add_child(_wp_line)


# ---------------- رابط کاربری ----------------

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
        hint.text = "%s  |  %s  |  %s  |  %s" % [
                tr("hint_select"), tr("hint_island_move"), tr("hint_regen"), tr("hint_slow")]
        vb.add_child(hint)

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


func _toast_msg(msg: String) -> void:
        if _toast == null:
                return
        _toast.text = msg
        _toast.visible = true
        _toast_t = 0.0


func _flash_ping(p: Vector3) -> void:
        _ping.position = p
        _ping.scale = Vector3.ONE
        _ping_mat.albedo_color.a = 0.9
        _ping.visible = true
        _ping_t = 0.0


func _refresh_stats() -> void:
        var info := PathService.debug_info()
        var computes: int = int(info["computes"])
        if computes != _last_computes:
                _last_computes = computes
                _stall = 0.0
        else:
                _stall += 0.25
        var field_state: String = "LIVE" if _stall < 1.0 else "FROZEN!!"
        var arrived := 0
        for u in squad:
                if u.is_arrived():
                        arrived += 1
        var goal: Vector2 = info["goal"]
        var mode_str := "COMMAND" if mode == Mode.COMMAND else "IDLE"
        _stats_label.text = "build %s  |  FPS %d  |  field: %s  |  mode: %s  |  slow: %s\nunits %d  arrived %d  slots %d  |  waypoints %d  |  input: %s\nisland seed %d  |  attempts %d  |  gen %.1f ms  |  land %d%%  |  cmd-cells %d  |  houses %d\ncomputes: %d  |  goal: (%.1f, %.1f)  |  time_scale: %.2f  |  cam h %.0f yaw %.0f" % [
                GameConstants.BUILD_ID, Engine.get_frames_per_second(), field_state, mode_str,
                ("ON" if Engine.time_scale < 0.99 else "off"),
                squad.size(), arrived, slots_assigned(), waypoints.size(), _last_input_msg,
                island.get("seed_used", -1), island.get("attempts", -1), island.get("gen_ms", 0.0),
                int(round(100.0 * float(island.get("land_count", 0)) / float(GRID * GRID))),
                cmd_grid.cell_count if cmd_grid != null else 0,
                props.house_positions.size() if props != null else 0,
                computes, goal.x, goal.y, Engine.time_scale,
                _target_height, _yaw,
        ]


# ---------------- حلقه‌ی هر فریم ----------------

func _process(delta: float) -> void:
        # دلتای واقعی (بدون اثر time_scale) برای هموارسازی اسلوموشن و دوربین
        var raw := delta / maxf(Engine.time_scale, 0.05)

        # §۶ — اسلوموشن با Tween: ورود 0.15s، بازگشت 0.2s
        var target := GameConstants.SLOWMO_SCALE if (_slow_select or _slow_space) else 1.0
        var dur := GameConstants.SLOWMO_IN_SECONDS if target < Engine.time_scale \
                        else GameConstants.SLOWMO_OUT_SECONDS
        Engine.time_scale = move_toward(Engine.time_scale, target, raw / dur)

        # §۷ — چرخش دوربین Q/E (نگه‌داشتن) + زوم نرم
        if _keys_held.get(KEY_Q, false):
                _yaw -= GameConstants.CAM_ROTATE_SPEED * raw
        if _keys_held.get(KEY_E, false):
                _yaw += GameConstants.CAM_ROTATE_SPEED * raw
        _cam_pivot.rotation.y = deg_to_rad(_yaw)
        _cam.position.z = move_toward(_cam.position.z, _target_height,
                        GameConstants.CAM_ZOOM_SPEED * raw)

        _ui_accum += delta
        if _ui_accum >= 0.25:
                _ui_accum = 0.0
                _refresh_stats()

        # فَید پینگ فرمان
        if _ping != null and _ping.visible:
                _ping_t += delta
                var k: float = clampf(_ping_t / 0.6, 0.0, 1.0)
                _ping_mat.albedo_color.a = 0.9 * (1.0 - k)
                var s := 1.0 + k * 1.6
                _ping.scale = Vector3(s, 1.0, s)
                if k >= 1.0:
                        _ping.visible = false

        # هاور: فقط در حالت فرمان، روی سلول‌های سفید
        if cmd_grid != null and ground != null and ground.size > 0:
                if mode == Mode.COMMAND:
                        var cam := get_viewport().get_camera_3d()
                        if cam != null:
                                var hit := ground.ray_pick(cam, get_viewport().get_mouse_position())
                                if bool(hit.get("in_island", false)):
                                        _hover_info = cmd_grid.hover_at_world(_xz_of_hit(hit))
                                else:
                                        _hover_info = cmd_grid.hover_at_world(Vector2(1e6, 1e6))
                else:
                        _hover_info = {}
                        cmd_grid.hover_at_world(Vector2(1e6, 1e6))

        # پیشروی Waypoint: رسیدن دسته → 0.2s انتظار → مقصد بعدی (§۴.۳)
        if not waypoints.is_empty():
                var arrived := 0
                for u in squad:
                        if u.is_arrived():
                                arrived += 1
                if arrived >= WP_REACH_ARRIVED:
                        _wp_wait += delta
                        if _wp_wait >= GameConstants.WAYPOINT_WAIT:
                                _wp_wait = 0.0
                                waypoints.pop_front()
                                if not waypoints.is_empty():
                                        _issue_move_to(waypoints[0])
                                _rebuild_waypoint_line()
                else:
                        _wp_wait = 0.0

        # پیام شناور
        _toast_t += delta
        if _toast != null and _toast.visible and _toast_t > 3.0:
                _toast.visible = false


func _xz_of_hit(hit: Dictionary) -> Vector2:
        var c: Vector2i = hit["cell"]
        var center := PathService.nav.cell_center(c)
        return center


# ---------------- ورودی (§۲ پرامت) ----------------

func _input(event: InputEvent) -> void:
        if event is InputEventMouseButton:
                if event.pressed:
                        match event.button_index:
                                MOUSE_BUTTON_LEFT:
                                        _on_left_click(event)
                                MOUSE_BUTTON_RIGHT:
                                        _on_right_click(event)
                                MOUSE_BUTTON_MIDDLE:
                                        _middle_drag = true
                                MOUSE_BUTTON_WHEEL_UP:
                                        _target_height = clampf(_target_height - GameConstants.CAM_ZOOM_SPEED,
                                                        GameConstants.CAM_MIN_HEIGHT, GameConstants.CAM_MAX_HEIGHT)
                                MOUSE_BUTTON_WHEEL_DOWN:
                                        _target_height = clampf(_target_height + GameConstants.CAM_ZOOM_SPEED,
                                                        GameConstants.CAM_MIN_HEIGHT, GameConstants.CAM_MAX_HEIGHT)
                elif event.button_index == MOUSE_BUTTON_MIDDLE:
                        _middle_drag = false
        elif event is InputEventMouseMotion and _middle_drag:
                _yaw += event.relative.x * 0.35
        elif event is InputEventKey:
                if event.pressed and not event.echo:
                        _keys_held[event.physical_keycode] = true
                        match event.physical_keycode:
                                KEY_R:
                                        _regenerate(randi(), true)
                                KEY_G:
                                        _regenerate(_island_seed, true)
                                KEY_1, KEY_2, KEY_3, KEY_4:
                                        # §۲.۱ — میان‌بر انتخاب جوخه 1..4 (فعلاً یک دسته)
                                        _select_squad()
                                KEY_SPACE:
                                        _slow_space = true  # نگه‌داشتن Space = اسلوموشن (§۶)
                elif not event.pressed:
                        _keys_held[event.physical_keycode] = false
                        if event.physical_keycode == KEY_SPACE:
                                _slow_space = false  # §۶.۲ — رها کردن Space = پایان اسلوموشن


func _on_left_click(event: InputEventMouseButton) -> void:
        var u := _unit_at_screen(event.position)
        if u != null:
                if mode == Mode.COMMAND:
                        _deselect()  # کلیک دوباره روی دسته‌ی انتخابی = لغو
                else:
                        _select_squad()
                return
        var cam := get_viewport().get_camera_3d()
        var hit := ground.ray_pick(cam, event.position)
        if mode != Mode.COMMAND:
                _last_input_msg = "left-click: no squad selected"
                _toast_msg("اول سربازها را انتخاب کن (کلیک چپ روی دسته)\nFirst select the squad (left-click on it)")
                return
        if hit.is_empty() or not bool(hit["in_island"]):
                _deselect()
                _last_input_msg = "left-click empty → deselect"
                return
        var xz := _xz_of_hit(hit)
        var info := cmd_grid.cell_at_world(xz)
        if bool(info.get("ok", false)):
                if event.shift_pressed:
                        _add_waypoint(info["center"])
                else:
                        waypoints.clear()
                        waypoints.append(info["center"])
                        _issue_move_to(info["center"])
                        _rebuild_waypoint_line()
        else:
                _last_input_msg = "cell invalid (%d,%d)" % [hit["cell"].x, hit["cell"].y]
                _toast_msg("سربازها آنجا نمی‌توانند بایستند\nUnits cannot stand there")


func _on_right_click(event: InputEventMouseButton) -> void:
        # سازگاری با عادت قبلی: راست‌کلیک = انتخاب و فرمان
        if mode != Mode.COMMAND:
                if _unit_at_screen(event.position) != null:
                        _select_squad()
                else:
                        _last_input_msg = "right-click: no squad selected"
                        _toast_msg("اول سربازها را انتخاب کن (کلیک چپ روی دسته)\nFirst select the squad (left-click on it)")
                return
        var cam := get_viewport().get_camera_3d()
        var hit := ground.ray_pick(cam, event.position)
        if hit.is_empty() or not bool(hit["in_island"]):
                _deselect()
                return
        var info := cmd_grid.cell_at_world(_xz_of_hit(hit))
        if bool(info.get("ok", false)):
                waypoints.clear()
                waypoints.append(info["center"])
                _issue_move_to(info["center"])
                _rebuild_waypoint_line()
        else:
                _last_input_msg = "cell invalid (right-click)"
                _toast_msg("سربازها آنجا نمی‌توانند بایستند\nUnits cannot stand there")


# ---------------- انتخاب دسته و فرمان (§۲.۳ / §۲.۴) ----------------

func _select_squad() -> void:
        mode = Mode.COMMAND
        _slow_select = true  # §۶ — اسلوموشن هنگام انتخاب
        cmd_grid.set_command_mode(true)  # هاله‌ی سفید ظاهر می‌شود
        squad_selected_fired = true
        GameEvents.squad_selected.emit(_units_root)
        _last_input_msg = "squad selected → slow-mo + white grid"
        _toast_msg("دسته انتخاب شد — زمان کند شد؛ روی یکی از سلول‌های سفید کلیک کن\nSquad selected — time slowed; click a white cell")


func _deselect() -> void:
        mode = Mode.IDLE
        _slow_select = false  # §۶.۲ — لغو انتخاب = پایان اسلوموشن (۰.۲s)
        cmd_grid.set_command_mode(false)
        _last_input_msg = "deselected"


## فرمان حرکت به مرکز سلول: اسلات‌های آرایش + هدف FlowField + پینگ موقتی
func _issue_move_to(center: Vector2) -> void:
        _assign_slots(center)
        PathService.set_goal_world(center)
        var y := ground.height_at_world(center)
        _flash_ping(Vector3(center.x, y + 0.08, center.y))
        _last_input_msg = "move -> (%.1f, %.1f) slots %d" % [center.x, center.y, slots_assigned()]
        _toast_msg("دسته به سلول می‌رود و همان‌جا می‌ایستند\nSquad moving — they will stand on the cell")
        # فرمان صادر شد → پایان حالت فرمان و اسلوموشن (رفتار Bad North)
        _deselect()


func _add_waypoint(center: Vector2) -> void:
        if waypoints.size() >= GameConstants.WAYPOINT_MAX:
                _toast_msg("حداکثر نقاط مسیر: %d\nMax waypoints: %d" % [
                        GameConstants.WAYPOINT_MAX, GameConstants.WAYPOINT_MAX])
                return
        if waypoints.is_empty():
                _issue_move_to(center)  # اولین waypoint بلافاصله فعال می‌شود
        waypoints.append(center)
        _rebuild_waypoint_line()
        _last_input_msg = "waypoint %d added" % waypoints.size()


## اسلات‌های آرایش ۱.۲ متری دور مرکز سلول (§۵.۲) — فقط روی سلول‌های قابل‌عبور
func _assign_slots(center: Vector2) -> void:
        var nav := PathService.nav
        var slots: Array[Vector2] = [center]
        var ring := 1
        while slots.size() < UNIT_COUNT and ring <= SLOT_MAX_RING:
                var r := GameConstants.FORMATION_SPACING * float(ring)
                var per := 6 * ring
                for k in per:
                        var ang := TAU * float(k) / float(per) + 0.4 * float(ring)
                        var p := center + Vector2(cos(ang), sin(ang)) * r
                        var np := _nearest_walkable_point(nav, p, 1.3)
                        if np != Vector2.INF:
                                slots.append(np)
                                if slots.size() >= UNIT_COUNT:
                                        break
                ring += 1
        # تضمین: همیشه به اندازه‌ی سربازها اسلات داریم
        var guard := 0
        while slots.size() < UNIT_COUNT and guard < 60:
                var ang := _rng_scene() * TAU
                var rr := 1.2 + float(guard % 3) * 1.2
                var np := _nearest_walkable_point(nav, center + Vector2(cos(ang), sin(ang)) * rr, 1.6)
                slots.append(np if np != Vector2.INF else center)
                guard += 1
        # اختصاص حریصانه: هر اسلات به نزدیک‌ترین سربازِ آزاد
        var used := {}
        for s in slots:
                var best := -1
                var best_d := 1e9
                for i in squad.size():
                        if used.has(i):
                                continue
                        var d := _unit_xz(squad[i]).distance_to(s)
                        if d < best_d:
                                best_d = d
                                best = i
                if best >= 0:
                        squad[best].set_slot(s)
                        used[best] = true


var _scene_rng := RandomNumberGenerator.new()

func _rng_scene() -> float:
        _scene_rng.randomize()
        return _scene_rng.randf()


func _nearest_walkable_point(nav: NavGrid, p: Vector2, max_r: float) -> Vector2:
        var cells := int(ceil(max_r / nav.cell_size))
        var base := nav.world_to_cell(p)
        var best := Vector2.INF
        var best_d := max_r
        for dy in range(-cells, cells + 1):
                for dx in range(-cells, cells + 1):
                        var c := base + Vector2i(dx, dy)
                        if not nav.is_walkable(c):
                                continue
                        var cc := nav.cell_center(c)
                        var d := cc.distance_to(p)
                        if d <= best_d:
                                best_d = d
                                best = cc
        return best


func _unit_xz(u: Node3D) -> Vector2:
        return Vector2(u.global_position.x, u.global_position.z)


func _squad_center_xz() -> Vector2:
        if squad.is_empty():
                return Vector2.ZERO
        var acc := Vector2.ZERO
        for u in squad:
                acc += _unit_xz(u)
        return acc / float(squad.size())


## انتخاب واحد با ماوس: نزدیک‌ترین سرباز در ۴۶ پیکسل یا ۱.۱۵ متر
func _unit_at_screen(screen: Vector2) -> TestUnit:
        var cam := get_viewport().get_camera_3d()
        if cam == null:
                return null
        var best: TestUnit = null
        var best_px := SELECT_PICK_PX
        for u in squad:
                var wp: Vector3 = u.global_position + Vector3(0, 0.35, 0)
                if cam.is_position_behind(wp):
                        continue
                var sp := cam.unproject_position(wp)
                var d := sp.distance_to(screen)
                if d < best_px:
                        best_px = d
                        best = u
        if best != null:
                return best
        # پشتیبان: فاصله‌ی جهانی (کلیک نزدیک پای سرباز)
        var hit := ground.ray_pick(cam, screen)
        if bool(hit.get("in_island", false)):
                var xz := _xz_of_hit(hit)
                var best_world := SELECT_PICK_WORLD
                for u in squad:
                        var d := _unit_xz(u).distance_to(xz)
                        if d < best_world:
                                best_world = d
                                best = u
        return best


# ---------------- خط Waypoint (§۴.۲: #3AB0A0، Alpha 0.6، ضخامت 0.1m) ----------------

func _rebuild_waypoint_line() -> void:
        for c in _wp_root.get_children():
                if c != _wp_line:
                        c.free()
        if waypoints.size() < 1:
                _wp_line.visible = false
                return
        _wp_line.visible = true
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var col := GameConstants.COL_WAYPOINT
        col.a = 0.6
        var half_w := 0.05  # ضخامت 0.1 متر
        var prev := _squad_center_xz()
        for w in waypoints:
                var a3 := Vector3(prev.x, ground.height_at_world(prev) + 0.12, prev.y)
                var b2 := w
                var b3 := Vector3(b2.x, ground.height_at_world(b2) + 0.12, b2.y)
                var dir := Vector3(b3.x - a3.x, 0.0, b3.z - a3.z)
                if dir.length() > 0.05:
                        dir = dir.normalized()
                        var perp := Vector3(-dir.z, 0.0, dir.x) * half_w
                        _ribbon_quad(st, a3 + perp, a3 - perp, b3 + perp, b3 - perp, col)
                # نشانگر نقطه
                var mk := MeshInstance3D.new()
                var sm := SphereMesh.new()
                sm.radius = 0.09
                sm.height = 0.18
                mk.mesh = sm
                mk.position = b3
                var mm := StandardMaterial3D.new()
                mm.albedo_color = GameConstants.COL_WAYPOINT
                mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                mk.material_override = mm
                _wp_root.add_child(mk)
                prev = b2
        var mesh := st.commit()
        if mesh != null:
                _wp_line.mesh = mesh
        else:
                _wp_line.visible = false


func _ribbon_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
                col: Color) -> void:
        for v in [a, b, c, a, c, d]:
                st.set_color(col)
                st.set_normal(Vector3.UP)
                st.add_vertex(v)


# ---------------- API برای تست خودکار ----------------

func is_command_mode() -> bool:
        return mode == Mode.COMMAND


func slots_assigned() -> int:
        var n := 0
        for u in squad:
                if u.has_slot():
                        n += 1
        return n
