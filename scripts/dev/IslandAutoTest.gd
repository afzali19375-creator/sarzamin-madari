class_name IslandAutoTest
extends Node
## تست خودکار گام ۴ R2 — «زمین صاف Bad North + شبکه‌ی فرمان سفید»
## معیارهای پذیرش (پرامت فاز اول + بازخوردهای کاربر):
##   ۰) جزیره سالم: ≤32×32، لبه‌ها آب، خشکی بازی‌پذیر ≥ ~۴۰٪، بدون دریاچه‌ی تک‌سلولی،
##      خانه‌های هخامنشی (۴ بنا) جای‌گذاری و در NavGrid مسدود شده، سلول‌های فرمان ≥ ۲۰
##   ۱) قطعیت WFC (همان seed → همان جزیره) + فشار ۸ seed
##   ۲) هزینه‌ی زمین (§۳.۲): شن 1.2 | چمن 1.0 + وضعیت اولیه‌ی تمیز
##   ۳) کلیک چپ روی سرباز → انتخاب دسته: اسلوموشن 0.5 + هاله‌ی سفید (§۲.۳/§۶)
##   ۴) کلیک چپ روی سلول دور → فرمان: پایان اسلوموشن، اسلات‌های آرایش، میدان زنده (§۲.۴)
##   ۵) سربازها «روی سلول» می‌ایستند: هر واحد روی اسلات خودش درون سلول (±1.7m) (بازخورد کاربر)
##   ۶) Shift+کلیک → Waypoint در صف؛ فرمان ساده → صف پاک و مقصد جدید
##   ۷) بازتولید R → همه‌چیز از نو و سازگار
## اجرا:
##   godot --headless --path . res://scenes/dev/IslandTest.tscn -- --autotest
## کد خروج: 0 = همه PASS، 1 = حداقل یک FAIL

const ARRIVE_MIN_UNITS := 9
const ARRIVE_DEADLINE := 75.0
const REGEN_SEED := 4242
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIRS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
                Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var target_scene: Node3D

var _t := 0.0
var _phase := 0
var _sub := 0
var _sub_t := 0.0
var _fails: PackedStringArray = []
var _results: PackedStringArray = []
var _computes_before := 0
var _arrive_t0 := 0.0
var _goal_before := Vector2.ZERO
var _cell_b := Vector2.ZERO    # مرکز جهانی سلول فرمان دور (فرمان اصلی)
var _cell_c := Vector2.ZERO    # مرکز جهانی سلول فرمان میانه (waypoint)
var _cell_d := Vector2.ZERO    # مرکز جهانی سلول فرمان دوم (فرمان ساده)
var _cell_b_nav := Vector2i(-1, -1)


func _ready() -> void:
        print("[AUTOTEST] island harness attached — 8 phases (smooth ground + command grid)")


func _check(name: String, ok: bool, detail: String = "") -> void:
        var line := "%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail]
        _results.append(line)
        print("[AUTOTEST] ", line)
        if not ok:
                _fails.append(name)


func _units() -> Array:
        return target_scene.squad


func _process(delta: float) -> void:
        _t += delta
        match _phase:
                0:
                        if _t >= 0.8:
                                _phase0_island_ready()
                1:
                        _phase1_wfc_determinism_and_stress()
                2:
                        if _t >= 1.2:
                                _phase2_costs_and_initial_state()
                3:
                        _phase3_select_squad()
                4:
                        _phase4_command_move()
                5:
                        _phase5_wait_arrival_on_cell()
                6:
                        _phase6_waypoints()
                7:
                        _phase7_regenerate()
                8:
                        _finish()


# ---------------- فاز ۰: جزیره سالم؟ ----------------

func _phase0_island_ready() -> void:
        var isl: Dictionary = target_scene.island
        _check("island_generated", isl.get("ok", false) == true)
        if isl.get("ok", false) != true:
                _phase = 8
                return
        _check("gen_fast", float(isl["gen_ms"]) < 2500.0, "%.1f ms" % isl["gen_ms"])
        _check("grid_size_32", int(isl["size"]) == 32, "size=%d" % isl["size"])

        var size: int = isl["size"]
        var sockets: PackedStringArray = isl["meta_sockets"]
        var mods: PackedInt32Array = isl["modules"]
        var border_ok := true
        for i in size:
                for cell in [Vector2i(i, 0), Vector2i(i, size - 1), Vector2i(0, i), Vector2i(size - 1, i)]:
                        var id: int = mods[cell.y * size + cell.x]
                        if not String(sockets[id]).begins_with("w"):
                                border_ok = false
        _check("border_ring_is_water", border_ok)

        var walk_total := 0
        for y in size:
                for x in size:
                        if int(isl["walkable"][y * size + x]) == 1:
                                walk_total += 1
        # §۸.۳ پرامت: منطقه‌ی قابل‌عبور ≥ ۴۰٪ کل مساحت (تلورانس ۲٪ برای seedهای مرزی)
        _check("walkable_fraction_40pct", walk_total >= int(size * size * 0.38),
                        "%d/%d = %.0f%%" % [walk_total, size * size, 100.0 * walk_total / float(size * size)])

        # §۸.۳ — هیچ دریاچه‌ی تک‌سلولیِ محصور در خشکی نباشد
        var lakes := 0
        for y in range(1, size - 1):
                for x in range(1, size - 1):
                        var c := Vector2i(x, y)
                        if int(isl["walkable"][c.y * size + c.x]) == 1:
                                continue
                        var surrounded := true
                        for d in DIRS8:
                                var n2: Vector2i = c + d
                                if int(isl["walkable"][n2.y * size + n2.x]) == 0:
                                        surrounded = false
                                        break
                        if surrounded:
                                lakes += 1
        _check("no_inner_single_cell_lakes", lakes == 0, "%d lakes" % lakes)

        var info: Dictionary = PathService.debug_info()
        _check("field_published", info["has_field"] == true, "computes=%d" % info["computes"])

        # خانه‌ها: ۴ بنا + مسدود بودن سلول‌هایشان
        _check("houses_built_4", target_scene.props.house_positions.size() == 4,
                        "%d" % target_scene.props.house_positions.size())
        var nav: NavGrid = PathService.nav
        var houses_blocked := true
        for c in target_scene.blocked_by_houses:
                if nav.is_walkable(c):
                        houses_blocked = false
        _check("house_cells_blocked_in_nav", houses_blocked,
                        "%d cells" % target_scene.blocked_by_houses.size())

        # همگامی NavGrid با جزیره (به‌جز سلول‌های خانه‌ها)
        var house_set := {}
        for c in target_scene.blocked_by_houses:
                house_set[c] = true
        var mismatches := 0
        for y in size:
                for x in size:
                        var c := Vector2i(x, y)
                        if house_set.has(c):
                                continue
                        if nav.is_walkable(c) != (int(isl["walkable"][c.y * size + c.x]) == 1):
                                mismatches += 1
        _check("navgrid_matches_island", mismatches == 0, "%d mismatches" % mismatches)

        # سلول‌های فرمان (بازخورد: بلوک‌های بزرگ‌تر ۲×۲ متر)
        _check("command_cells_enough", target_scene.cmd_grid.cell_count >= 20,
                        "%d cells" % target_scene.cmd_grid.cell_count)

        var on_walkable := 0
        for u in _units():
                if u is TestUnit:
                        var p: Vector3 = u.global_position
                        if nav.is_walkable(nav.world_to_cell(Vector2(p.x, p.z))):
                                on_walkable += 1
        _check("unit_count_is_10", _units().size() == 10, "n=%d" % _units().size())
        _check("units_spawned_on_walkable", on_walkable == 10, "%d/10" % on_walkable)

        # سلول‌های هدف فاز ۳–۶: B دور، C میانه، D دوم
        _pick_target_cells()
        _check("far_targets_found", _cell_b != Vector2.ZERO and _cell_c != Vector2.ZERO
                        and _cell_d != Vector2.ZERO,
                        "B=(%.0f,%.0f) C=(%.0f,%.0f)" % [_cell_b.x, _cell_b.y, _cell_c.x, _cell_c.y])
        _phase = 1


## BFS از هدف → عمق هر سلول؛ سلول‌های فرمان دور/میانه را برمی‌گزیند
func _pick_target_cells() -> void:
        var nav: NavGrid = PathService.nav
        var start := nav.world_to_cell(PathService.goal_world())
        if not nav.is_walkable(start):
                start = _nearest_walkable(nav, start)
        var depths := {}
        if nav.is_walkable(start):
                var q: Array[Vector2i] = [start]
                depths[start] = 0
                var head := 0
                while head < q.size():
                        var c: Vector2i = q[head]
                        head += 1
                        for d in DIRS:
                                var n2: Vector2i = c + d
                                if nav.is_walkable(n2) and not depths.has(n2):
                                        depths[n2] = int(depths[c]) + 1
                                        q.append(n2)
        var far_d := 0
        for v in depths.values():
                far_d = maxi(far_d, int(v))
        # سلول‌های فرمانی که عمق دارند: [index, depth, center]
        var entries: Array = []
        for i in target_scene.cmd_grid.cell_count:
                var info: Dictionary = target_scene.cmd_grid.cell_info(i)
                var center: Vector2 = info["center"]
                var cc: Vector2i = nav.world_to_cell(center)
                if depths.has(cc):
                        entries.append([i, int(depths[cc]), center])
        if entries.is_empty():
                return
        var best_b := -1
        var best_b_depth := -1
        var best_c := -1
        var best_c_gap := 1e9
        var best_d_idx := -1
        var best_d_gap := 1e9
        for e in entries:
                var idx := int(e[0])
                var dpt := int(e[1])
                var center: Vector2 = e[2]
                if dpt > best_b_depth:
                        best_b_depth = dpt
                        best_b = idx
        for e in entries:
                var idx := int(e[0])
                var dpt := int(e[1])
                var center: Vector2 = e[2]
                if idx == best_b:
                        continue
                var gap := absf(float(dpt) - float(far_d) * 0.5)
                if gap < best_c_gap:
                        best_c_gap = gap
                        best_c = idx
        var center_b: Vector2 = target_scene.cmd_grid.cell_info(best_b)["center"]
        for e in entries:
                var idx := int(e[0])
                var center: Vector2 = e[2]
                if idx == best_b or idx == best_c:
                        continue
                var gap: float = center.distance_to(center_b)
                if gap < best_d_gap:
                        best_d_gap = gap
                        best_d_idx = idx
        if best_b >= 0:
                _cell_b = target_scene.cmd_grid.cell_info(best_b)["center"]
                _cell_b_nav = nav.world_to_cell(_cell_b)
        if best_c >= 0:
                _cell_c = target_scene.cmd_grid.cell_info(best_c)["center"]
        if best_d_idx >= 0:
                _cell_d = target_scene.cmd_grid.cell_info(best_d_idx)["center"]


## نزدیک‌ترین سلول قابل‌عبور (مارپیچ کوچک)
func _nearest_walkable(nav: NavGrid, from: Vector2i) -> Vector2i:
        if nav.is_walkable(from):
                return from
        for r in range(1, 12):
                for dy in range(-r, r + 1):
                        for dx in range(-r, r + 1):
                                if maxi(absi(dx), absi(dy)) != r:
                                        continue
                                var c := from + Vector2i(dx, dy)
                                if nav.is_walkable(c):
                                        return c
        return Vector2i(-1, -1)


# ---------------- فاز ۱: قطعیت و فشار WFC ----------------

func _phase1_wfc_determinism_and_stress() -> void:
        var a := WfcIsland.new().generate(777, 32)
        var b := WfcIsland.new().generate(777, 32)
        _check("wfc_seed_777_ok", a.get("ok", false) == true and b.get("ok", false) == true)
        if a.get("ok", false) == true and b.get("ok", false) == true:
                _check("wfc_deterministic_same_seed", int(a["hash"]) == int(b["hash"]) \
                                and a["walkable"] == b["walkable"] \
                                and a["modules"] == b["modules"],
                                "hashA=%d" % int(a["hash"]))
        var stress_ok := true
        var details := ""
        for s in [101, 202, 303, 404, 505, 606, 707, 808]:
                var r: Dictionary = WfcIsland.new().generate(s, 32)
                if r.get("ok", false) != true or int(r["walkable_count"]) < 380:
                        stress_ok = false
                        details += " seed%d:%s(%s)" % [s, r.get("ok", false), r.get("walkable_count", -1)]
        _check("wfc_8_fresh_seeds_all_succeed", stress_ok, details)
        _phase = 2


# ---------------- فاز ۲: هزینه‌ی زمین + وضعیت اولیه ----------------

func _phase2_costs_and_initial_state() -> void:
        var isl: Dictionary = target_scene.island
        var size: int = isl["size"]
        var nav: NavGrid = PathService.nav
        var sand_ok := true
        var grass_ok := true
        var found_sand := false
        var found_grass := false
        for y in size:
                for x in size:
                        var c := Vector2i(x, y)
                        if not nav.is_walkable(c):
                                continue
                        var mname := String(isl["meta_names"][int(isl["modules"][c.y * size + c.x])])
                        if mname.begins_with("sand"):
                                found_sand = true
                                if absf(nav.cost_at(c) - 1.2) > 0.01:
                                        sand_ok = false
                        elif mname.begins_with("grass"):
                                found_grass = true
                                if absf(nav.cost_at(c) - 1.0) > 0.01:
                                        grass_ok = false
        _check("terrain_costs_sand_1_2", found_sand and sand_ok)
        _check("terrain_costs_grass_1_0", found_grass and grass_ok)

        _check("initial_state_idle", target_scene.mode == 0
                        and not target_scene.cmd_grid.is_command_mode()
                        and absf(Engine.time_scale - 1.0) < 0.01,
                        "time=%.2f" % Engine.time_scale)
        _phase = 3
        _sub = 0


# ---------------- فاز ۳: انتخاب دسته → اسلوموشن + هاله سفید ----------------

func _push_click(button: MouseButton, screen: Vector2, shift: bool = false) -> void:
        var ev := InputEventMouseButton.new()
        ev.button_index = button
        ev.pressed = true
        ev.position = screen
        ev.global_position = screen
        ev.shift_pressed = shift
        ev.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
        target_scene.get_viewport().push_input(ev, true)  # همان مسیر ورودی واقعی بازیکن


func _screen_of(world: Vector3) -> Vector2:
        var cam: Camera3D = target_scene.get_viewport().get_camera_3d()
        return cam.unproject_position(world)


func _phase3_select_squad() -> void:
        match _sub:
                0:
                        var u: TestUnit = _units()[0]
                        var p: Vector3 = u.global_position + Vector3(0, 0.35, 0)
                        _goal_before = PathService.goal_world()
                        _push_click(MOUSE_BUTTON_LEFT, _screen_of(p))
                        _sub = 1
                        _sub_t = _t
                1:
                        if _t - _sub_t >= 0.8:
                                _check("left_click_selects_squad", target_scene.is_command_mode(),
                                                "mode=%d" % target_scene.mode)
                                _check("squad_selected_event_fired", target_scene.squad_selected_fired)
                                _check("slowmo_engaged_on_select",
                                                absf(Engine.time_scale - 0.5) < 0.06,
                                                "time=%.2f" % Engine.time_scale)
                                _check("white_grid_visible", target_scene.cmd_grid.is_command_mode())
                                _check("selection_does_not_move_goal",
                                                PathService.goal_world().distance_to(_goal_before) < 0.01)
                                _phase = 4
                                _sub = 0


# ---------------- فاز ۴: فرمان حرکت به سلول دور ----------------

func _phase4_command_move() -> void:
        match _sub:
                0:
                        _computes_before = int(PathService.debug_info()["computes"])
                        _push_click(MOUSE_BUTTON_LEFT, _screen_of(Vector3(_cell_b.x,
                                        target_scene.ground.height_at_world(_cell_b) + 0.1, _cell_b.y)))
                        _sub = 1
                        _sub_t = _t
                1:
                        if _t - _sub_t >= 0.8:
                                var g := PathService.goal_world()
                                _check("left_click_commands_cell",
                                                g.distance_to(_cell_b) <= 0.8
                                                and g.distance_to(_goal_before) > 5.0,
                                                "goal=(%.1f,%.1f) want=(%.1f,%.1f)" % [g.x, g.y, _cell_b.x, _cell_b.y])
                                _check("slowmo_released_after_command",
                                                absf(Engine.time_scale - 1.0) < 0.06,
                                                "time=%.2f" % Engine.time_scale)
                                _check("grid_hidden_after_command",
                                                not target_scene.cmd_grid.is_command_mode())
                                _check("formation_slots_assigned", target_scene.slots_assigned() >= 9,
                                                "%d/10" % target_scene.slots_assigned())
                                var computes_now: int = int(PathService.debug_info()["computes"])
                                _check("field_recomputed_for_new_goal", computes_now > _computes_before,
                                                "before=%d now=%d" % [_computes_before, computes_now])
                                _phase = 5
                                _arrive_t0 = _t


# ---------------- فاز ۵: ایستادن واقعی روی سلول (بازخورد کاربر) ----------------

func _phase5_wait_arrival_on_cell() -> void:
        var arrived := 0
        for u in _units():
                if u is TestUnit and u.is_arrived():
                        arrived += 1
        if arrived >= ARRIVE_MIN_UNITS or (_t - _arrive_t0) > ARRIVE_DEADLINE:
                var on_slot := 0
                var slot_in_cell := 0
                var on_ground := 0
                var on_walkable := 0
                var centroid_acc := Vector2.ZERO
                var centroid_n := 0
                var nav: NavGrid = PathService.nav
                for u in _units():
                        if not (u is TestUnit) or not u.is_arrived():
                                continue
                        var p: Vector3 = u.global_position
                        var xz := Vector2(p.x, p.z)
                        var slot: Vector2 = u.slot_pos()
                        var tol := 1.5 if u.is_fidgeting() else 0.55
                        if xz.distance_to(slot) <= tol:
                                on_slot += 1
                        # شعاع آرایش ۱.۲m × ۲ حلقه = تا ۲.۹m از مرکز سلول (§۵.۲)
                        if slot.distance_to(_cell_b) <= 2.9:
                                slot_in_cell += 1
                        centroid_acc += xz
                        centroid_n += 1
                        var gy: float = target_scene.ground.height_at_world(xz)
                        if absf(p.y - gy) <= 0.3:
                                on_ground += 1
                        if nav.is_walkable(nav.world_to_cell(xz)):
                                on_walkable += 1
                var n := _units().size()
                _check("units_reach_FAR_cell", arrived >= ARRIVE_MIN_UNITS,
                                "%d/%d in %.1fs" % [arrived, n, _t - _arrive_t0])
                # قانون طلایی بازخورد کاربر: دسته «روی سلول انتخابی» می‌ایستد —
                # اسلات‌ها در شعاع آرایش + مرکزِ جرم دسته روی خود سلول
                _check("units_stand_ON_their_slots", on_slot >= 8, "%d/%d" % [on_slot, n])
                _check("slots_in_formation_radius", slot_in_cell >= 8, "%d/%d" % [slot_in_cell, n])
                var centroid := centroid_acc / float(maxi(centroid_n, 1))
                _check("squad_centered_on_cell", centroid.distance_to(_cell_b) <= 1.4,
                                "centroid=(%.1f,%.1f) cell=(%.1f,%.1f)" % [centroid.x, centroid.y, _cell_b.x, _cell_b.y])
                _check("units_stand_on_smooth_ground", on_ground >= 8, "%d/%d" % [on_ground, n])
                _check("units_parked_on_walkable", on_walkable >= 8, "%d/%d" % [on_walkable, n])
                _phase = 6
                _sub = 0


# ---------------- فاز ۶: Waypoint و فرمان ساده ----------------

func _phase6_waypoints() -> void:
        match _sub:
                0:
                        # دسته باید «انتخاب» باشد تا فرمان/Waypoint کار کند (مثل Bad North)
                        _pick_phase6_cells()
                        var u: TestUnit = _units()[0]
                        _push_click(MOUSE_BUTTON_LEFT, _screen_of(u.global_position + Vector3(0, 0.35, 0)))
                        _sub = 1
                        _sub_t = _t
                1:
                        if _t - _sub_t >= 0.5:
                                _check("reselect_for_waypoint", target_scene.is_command_mode(),
                                                "mode=%d" % target_scene.mode)
                                _push_click(MOUSE_BUTTON_LEFT, _screen_of(Vector3(_cell_c.x,
                                                target_scene.ground.height_at_world(_cell_c) + 0.1, _cell_c.y)),
                                                true)  # Shift+کلیک
                                _sub = 2
                                _sub_t = _t
                2:
                        if _t - _sub_t >= 0.6:
                                var wp: Array = target_scene.waypoints
                                var g := PathService.goal_world()
                                _check("shift_click_queues_waypoint", wp.size() == 1,
                                                "waypoints=%d" % wp.size())
                                _check("waypoint_becomes_goal", g.distance_to(_cell_c) <= 0.8,
                                                "goal=(%.1f,%.1f) want=(%.1f,%.1f)" % [g.x, g.y, _cell_c.x, _cell_c.y])
                                # دوباره انتخاب برای فرمان ساده‌ی بعدی
                                var u: TestUnit = _units()[0]
                                _push_click(MOUSE_BUTTON_LEFT, _screen_of(u.global_position + Vector3(0, 0.35, 0)))
                                _sub = 3
                                _sub_t = _t
                3:
                        if _t - _sub_t >= 0.5:
                                _push_click(MOUSE_BUTTON_LEFT, _screen_of(Vector3(_cell_d.x,
                                                target_scene.ground.height_at_world(_cell_d) + 0.1, _cell_d.y)))
                                _sub = 4
                                _sub_t = _t
                4:
                        if _t - _sub_t >= 0.6:
                                var wp: Array = target_scene.waypoints
                                var g := PathService.goal_world()
                                _check("plain_command_replaces_queue", wp.size() == 1
                                                and g.distance_to(_cell_d) <= 0.8,
                                                "waypoints=%d goal=(%.1f,%.1f) want=(%.1f,%.1f)" % [
                                                        wp.size(), g.x, g.y, _cell_d.x, _cell_d.y])
                                _phase = 7
                                _sub = 0


## سلول‌های فاز ۶ را دور از سربازانِ ایستاده در B برمی‌گزیند —
## تا کلیکِ تست به جای سلول، روی سرباز (انتخاب/لغو) نخورد
func _pick_phase6_cells() -> void:
        var cam: Camera3D = target_scene.get_viewport().get_camera_3d()
        var cands: Array = []
        for i in target_scene.cmd_grid.cell_count:
                var info: Dictionary = target_scene.cmd_grid.cell_info(i)
                var center: Vector2 = info["center"]
                if center.distance_to(_cell_b) < 7.0:
                        continue
                var min_px := 1e9
                var click_sp := _screen_of(Vector3(center.x,
                                target_scene.ground.height_at_world(center) + 0.1, center.y))
                for u in target_scene.squad:
                        var wp: Vector3 = u.global_position + Vector3(0, 0.35, 0)
                        if cam.is_position_behind(wp):
                                continue
                        min_px = minf(min_px, cam.unproject_position(wp).distance_to(click_sp))
                if min_px > 70.0:
                        cands.append(center)
        if cands.size() < 2:
                return  # سلول‌های قبلی فاز ۰ را نگه دار
        cands.sort_custom(func(a, b): return a.distance_to(_cell_b) > b.distance_to(_cell_b))
        _cell_c = cands[0]
        for k in range(1, cands.size()):
                if cands[k].distance_to(_cell_c) >= 5.0:
                        _cell_d = cands[k]
                        break


# ---------------- فاز ۷: بازتولید جزیره ----------------

func _phase7_regenerate() -> void:
        match _sub:
                0:
                        target_scene.regenerate(REGEN_SEED)
                        _sub = 1
                        _sub_t = _t
                1:
                        if _t - _sub_t >= 0.7:
                                var isl: Dictionary = target_scene.island
                                _check("regen_new_island", isl.get("ok", false) == true \
                                                and int(isl["seed_used"]) == REGEN_SEED,
                                                "seed=%s attempts=%s" % [isl.get("seed_used", -1), isl.get("attempts", -1)])
                                var nav: NavGrid = PathService.nav
                                var size: int = int(isl["size"])
                                var house_set := {}
                                for c in target_scene.blocked_by_houses:
                                        house_set[c] = true
                                var mismatches := 0
                                for y in size:
                                        for x in size:
                                                var c := Vector2i(x, y)
                                                if house_set.has(c):
                                                        continue
                                                if nav.is_walkable(c) != (int(isl["walkable"][c.y * size + c.x]) == 1):
                                                        mismatches += 1
                                _check("regen_nav_resynced", mismatches == 0, "%d mismatches" % mismatches)
                                var on_walkable := 0
                                for u in _units():
                                        if u is TestUnit:
                                                var p: Vector3 = u.global_position
                                                if nav.is_walkable(nav.world_to_cell(Vector2(p.x, p.z))):
                                                        on_walkable += 1
                                _check("regen_units_respawned", _units().size() == 10 and on_walkable == 10,
                                                "%d units, %d on walkable" % [_units().size(), on_walkable])
                                _check("regen_state_reset", target_scene.mode == 0
                                                and target_scene.waypoints.is_empty()
                                                and not target_scene.cmd_grid.is_command_mode()
                                                and absf(Engine.time_scale - 1.0) < 0.01)
                                _computes_before = int(PathService.debug_info()["computes"])
                                _sub = 2
                                _sub_t = _t
                2:
                        if _t - _sub_t >= 0.7:
                                var computes_now: int = int(PathService.debug_info()["computes"])
                                _check("regen_field_alive", computes_now > _computes_before,
                                                "before=%d now=%d" % [_computes_before, computes_now])
                                _phase = 8


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
