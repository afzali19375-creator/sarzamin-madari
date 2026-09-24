extends Node3D
## صحنه‌ی آزمون گام ۴ — جزیره‌ی WFC روی شبکه‌ی کاشی قابل‌کلیک (بازخورد کاربر):
##   * کل زمین از بلوک‌های کوچک قابل‌کلیک ساخته شده (هاور + انتخاب با کلیک چپ)
##   * فرمان حرکت با کلیک راست روی کاشی — فقط «پینگِ» موقتی، بدون پرچم ماندگار
##     (پرچم طلایی صحنه‌ی قبلی فقط ابزار dev بود؛ در گام ۵ حذف قطعی می‌شود)
##
## کنترل‌ها:
##   کلیک چپ  → انتخاب کاشی
##   کلیک راست → فرمان حرکت واحدها به کاشی
##   Space     → حرکت آهسته (time_scale = 0.5)
##   R / G     → جزیره‌ی جدید با seed تازه / بازتولید همان seed

const GRID := 32
const CELL := 1.0
const UNIT_COUNT := 10
const FONT_FA := "res://assets/fonts/Vazirmatn-Regular.ttf"
const DEFAULT_SEED := 20260924

var island: Dictionary = {}
var tiles: IslandTiles

var _island_seed := DEFAULT_SEED
var _units_root: Node3D
var _goal_cell := Vector2i(-1, -1)
var _selected := Vector2i(-1, -1)
var _hover_cell := Vector2i(-1, -1)

var _stats_label: Label
var _toast: Label
var _toast_t := 10.0
var _ping: MeshInstance3D
var _ping_mat: StandardMaterial3D
var _ping_t := 10.0
var _sel_ring: MeshInstance3D
var _sel_t := 0.0
var _time_scale := 1.0
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
        if tiles == null:
                tiles = IslandTiles.new()
                add_child(tiles)
        tiles.build(island, CELL, PathService.nav.origin)
        _apply_island_to_nav()
        _clear_units()
        _selected = Vector2i(-1, -1)
        if _sel_ring != null:
                _sel_ring.visible = false
        # ابتدا هدف (نزدیک‌ترین کاشی به مرکز خشکی) — بعد اسپاون اطرافش
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
        var w: PackedByteArray = island["walkable"]
        for y in GRID:
                for x in GRID:
                        if w[y * GRID + x] == 0:
                                nav.set_walkable(Vector2i(x, y), false)


func _clear_units() -> void:
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
        var goal_center := PathService.nav.cell_center(_goal_cell)
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
        # بُر زدن قطعی با seed جزیره
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
                u.position = Vector3(center.x, tiles.top_at(c), center.y)
                u.ground_provider = Callable(tiles, "height_at_world")
                _units_root.add_child(u)
                spawned += 1


func _pick_goal_cell() -> Vector2i:
        var nav := PathService.nav
        var acc := Vector2.ZERO
        var count := 0
        for y in GRID:
                for x in GRID:
                        if nav.is_walkable(Vector2i(x, y)):
                                acc += Vector2(x, y)
                                count += 1
        if count == 0:
                return Vector2i(GRID / 2, GRID / 2)
        var centroid := acc / float(count)
        var best := Vector2i(-1, -1)
        var best_d := 1e9
        for y in GRID:
                for x in GRID:
                        var c := Vector2i(x, y)
                        if not nav.is_walkable(c):
                                continue
                        var d := (Vector2(c) - centroid).length()
                        if d < best_d:
                                best_d = d
                                best = c
        return best


func selected_cell() -> Vector2i:
        return _selected


## بازتولید برنامه‌ای جزیره (کلید R / تست خودکار) — عمومی
func regenerate(seed_value: int) -> void:
        _regenerate(seed_value, true)


# ---------------- محیط ----------------

func _build_environment() -> void:
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
        cam.position = Vector3(0.0, 30.0, 19.0)
        cam.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
        cam.fov = 55.0
        add_child(cam)

        # دریای بی‌کران زیر جزیره
        var sea := MeshInstance3D.new()
        var pm := PlaneMesh.new()
        pm.size = Vector2(260, 260)
        sea.mesh = pm
        var sm := StandardMaterial3D.new()
        sm.albedo_color = Color("0d3f52")
        sm.roughness = 0.35
        sm.metalness = 0.1
        sea.material_override = sm
        sea.position.y = -0.02
        add_child(sea)

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

        _sel_ring = MeshInstance3D.new()
        var st := TorusMesh.new()
        st.inner_radius = 0.44
        st.outer_radius = 0.56
        _sel_ring.mesh = st
        var sel_mat := StandardMaterial3D.new()
        sel_mat.albedo_color = Color("9fe3dd")
        sel_mat.emission_enabled = true
        sel_mat.emission = Color("9fe3dd")
        sel_mat.emission_energy_multiplier = 0.8
        _sel_ring.material_override = sel_mat
        _sel_ring.visible = false
        add_child(_sel_ring)


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
                tr("hint_island_move"), tr("hint_select"), tr("hint_regen"), tr("hint_slow")]
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
        var total := 0
        for u in get_tree().get_nodes_in_group("units"):
                total += 1
                if u is TestUnit and u.is_arrived():
                        arrived += 1
        var goal: Vector2 = info["goal"]
        _stats_label.text = "build %s  |  FPS %d  |  field: %s  |  units %d  arrived %d  |  input: %s\nisland seed %d  |  attempts %d  |  gen %.1f ms  |  land %d%%  |  walkable %d  |  hover (%d, %d)  |  selected (%d, %d)\ncomputes: %d  |  goal: (%.1f, %.1f)  |  time_scale: %.1f" % [
                GameConstants.BUILD_ID, Engine.get_frames_per_second(), field_state,
                total, arrived, _last_input_msg,
                island.get("seed_used", -1), island.get("attempts", -1), island.get("gen_ms", 0.0),
                int(round(100.0 * float(island.get("land_count", 0)) / float(GRID * GRID))),
                island.get("walkable_count", 0), _hover_cell.x, _hover_cell.y, _selected.x, _selected.y,
                computes, goal.x, goal.y, _time_scale,
        ]


func _process(delta: float) -> void:
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
        # نبض حلقه‌ی انتخاب
        if _sel_ring != null and _sel_ring.visible:
                _sel_t += delta
                _sel_ring.scale = Vector3.ONE * (1.0 + 0.07 * sin(_sel_t * 5.0))
        # هاور روی کاشی‌ها
        if tiles != null and tiles.size > 0:
                var cam := get_viewport().get_camera_3d()
                if cam != null:
                        var hit := tiles.ray_pick(cam, get_viewport().get_mouse_position())
                        var c := Vector2i(-1, -1)
                        if bool(hit.get("in_island", false)):
                                c = hit["cell"]
                        tiles.set_hover(c)
                        _hover_cell = c
        # پیام شناور
        _toast_t += delta
        if _toast != null and _toast.visible and _toast_t > 3.0:
                _toast.visible = false


# ---------------- ورودی ----------------

func _input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed:
                if event.button_index == MOUSE_BUTTON_RIGHT:
                        _command_to_mouse(event.position)
                elif event.button_index == MOUSE_BUTTON_LEFT:
                        _select_at_mouse(event.position)
        elif event is InputEventKey and event.pressed and not event.echo:
                if event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE:
                        _toggle_slowmo()
                elif event.physical_keycode == KEY_R or event.keycode == KEY_R:
                        _regenerate(randi(), true)
                elif event.physical_keycode == KEY_G or event.keycode == KEY_G:
                        _regenerate(_island_seed, true)


func _toggle_slowmo() -> void:
        _time_scale = GameConstants.SLOWMO_SCALE if _time_scale == 1.0 else 1.0
        Engine.time_scale = _time_scale
        _last_input_msg = "space -> slow-mo %s" % ("ON" if _time_scale < 1.0 else "OFF")


func _select_at_mouse(mouse: Vector2) -> void:
        var cam := get_viewport().get_camera_3d()
        var hit := tiles.ray_pick(cam, mouse)
        if hit.is_empty() or not bool(hit["in_island"]):
                _last_input_msg = "left-click missed island"
                _toast_msg("کلیک به جزیره نخورد — روی یکی از کاشی‌ها کلیک کن\nClick missed the island — click on a tile")
                return
        var cell: Vector2i = hit["cell"]
        var mod_name: String = hit["module"]
        if bool(hit["walkable"]):
                _selected = cell
                var center := PathService.nav.cell_center(cell)
                _sel_ring.position = Vector3(center.x, float(hit["top"]) + 0.06, center.y)
                _sel_ring.visible = true
                _sel_t = 0.0
                _last_input_msg = "selected (%d, %d) %s" % [cell.x, cell.y, mod_name]
                _toast_msg("کاشی (%d, %d) انتخاب شد — %s\nTile (%d, %d) selected — %s" % [
                        cell.x, cell.y, mod_name, cell.x, cell.y, mod_name])
        else:
                _last_input_msg = "tile (%d, %d) not selectable" % [cell.x, cell.y]
                _toast_msg("این کاشی قابل انتخاب نیست — %s\nNot selectable — %s" % [mod_name, mod_name])


func _command_to_mouse(mouse: Vector2) -> void:
        var cam := get_viewport().get_camera_3d()
        var hit := tiles.ray_pick(cam, mouse)
        if hit.is_empty() or not bool(hit["in_island"]):
                _last_input_msg = "right-click missed island"
                _toast_msg("کلیک به جزیره نخورد — روی یکی از کاشی‌ها کلیک کن\nClick missed the island — click on a tile")
                return
        var cell: Vector2i = hit["cell"]
        if not bool(hit["walkable"]):
                _last_input_msg = "blocked (%d, %d) %s" % [cell.x, cell.y, hit["module"]]
                _toast_msg("واحدها آنجا نمی‌توانند بایستند — %s\nUnits cannot stand there — %s" % [hit["module"], hit["module"]])
                return
        var center := PathService.nav.cell_center(cell)
        PathService.set_goal_world(center)
        _flash_ping(Vector3(center.x, float(hit["top"]) + 0.06, center.y))
        _last_input_msg = "move -> (%d, %d)" % [cell.x, cell.y]
        _toast_msg("واحدها به کاشی (%d, %d) می‌روند\nUnits are moving to tile (%d, %d)" % [
                cell.x, cell.y, cell.x, cell.y])
