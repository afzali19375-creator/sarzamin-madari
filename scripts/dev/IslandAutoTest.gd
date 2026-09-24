class_name IslandAutoTest
extends Node
## تست خودکار گام ۶ — «قایق‌ها، Hoplite/Peltast و موج هجوم» (روی پایه‌ی گام ۵)
## معیارهای پذیرش (سند طراحی §۶/§۷):
##   ۰) جزیره سالم + سه دسته: جاویدان×۴ / نیزه‌دار×۴ / کماندار×۳ — کلاس‌ها درست
##   ۱) قطعیت WFC (همان seed → همان جزیره) + فشار ۸ seed
##   ۲) هزینه‌ی زمین (§۳.۲): شن 1.2 | چمن 1.0 + وضعیت اولیه‌ی تمیز
##   ۳) رسیدن هر سه دسته به پست اولیه (میدان چندکاناله per-squad)
##   ۴) کلیک روی سربازِ دسته ۰ → انتخاب همان دسته: اسلوموشن + هاله سفید
##   ۵) فرمان به سلول دور → فقط دسته ۰ اسلات می‌گیرد؛ دو دسته‌ی دیگر در پست می‌مانند
##   ۶) ایستادن واقعی روی سلول: اسلات‌ها + مرکز جرم + زمین هموار
##   ۷) Shift+کلیک → Waypoint در صف؛ فرمان ساده → صف پاک
##   ۸) بازتولید R → همه‌چیز از نو و سازگار
##   ۹) کلیدهای 1..4: انتخاب دسته‌ها + حلقه‌ی سفید فقط روی دسته‌ی انتخابی + toggle
##  ۱۰) جداسازی کانال‌ها: فرمان به دسته ۱ → دسته‌های ۰/۲ منجمد؛ نیزه‌دار در حرکت آماده‌باش نمی‌شود
##  ۱۱) لایه ۳ روی کوله‌ی تمرین: جاویدان سپر، کماندار تیر (بدون آسیب دوستانه)،
##      نیزه‌دار فقط در ایست آماده‌باش؛ پاک‌کردن کوله = پایان نبرد
##  ۱۲) لایه ۴: واحدِ جابه‌جاشده خودش به پست بازمی‌گردد + سلامت نهایی
##  --- گام ۶ ---
##  ۱۳) موج هجوم: قایق پهلو می‌گیرد، ۶ مهاجم پیاده می‌شود، کانال دشمن در میدان،
##      هدف رژه = خانه، مهاجمان به داخل جزیره رژه می‌روند
##  ۱۴) نبرد تن‌به‌تن: مهاجم به سرباز درگیری؛ جاویدان سپر؛ تبادل ضربه دو طرفه
##  ۱۵) سپر سنگین (مخروط پیش‌رو) + کماندار با دشمن واقعی + پلتاست پرتاب می‌کند
##  ۱۶) مرگ دائمی سرباز (حذف از دسته‌ها) + پاکسازی موج (سیگنال، قایق بازمی‌گردد)
## اجرا:
##   godot --headless --path . res://scenes/dev/IslandTest.tscn -- --autotest
## کد خروج: 0 = همه PASS، 1 = حداقل یک FAIL

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
var _goal0_before := Vector2.ZERO
var _cell_b := Vector2.ZERO    # مرکز جهانی سلول فرمان دور (فرمان اصلی دسته ۰)
var _cell_c := Vector2.ZERO    # مرکز جهانی سلول فرمان میانه (waypoint)
var _cell_d := Vector2.ZERO    # مرکز جهانی سلول فرمان دوم (فرمان ساده)
var _cell_e := Vector2.ZERO    # مقصد دسته ۱ در فاز جداسازی
var _cell_b_nav := Vector2i(-1, -1)
var _others_snapshot: Array[Vector2] = []   # جای سربازان دسته‌های «دیگر» هنگام فرمان
var _dummy0: TrainingDummy
var _dummy1: TrainingDummy
var _dummy2: TrainingDummy
var _slot_before := Vector2.ZERO

# --- گام ۶ ---
var _group0 := -1
var _landing := Vector2.ZERO
var _wave_cleared_fired := false
var _units_before := 0
var _killed_unit: UnitBase = null
var _heavy_test: HopliteHeavy = null
var _peltast_test: PeltastUnit = null
var _arrow_baseline := 0
var _max_deflects := 0
var _heavy_hurt_seen := false
var _max_thrown := 0
var _squad_alive_before := 0
var _contact_forced := false


func _ready() -> void:
        print("[AUTOTEST] island harness attached — 16 phases (squads + invasion)")
        if target_scene.director != null:
                target_scene.director.wave_cleared.connect(
                                func(_g: int): _wave_cleared_fired = true)


func _check(name: String, ok: bool, detail: String = "") -> void:
        var line := "%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail]
        _results.append(line)
        print("[AUTOTEST] ", line)
        if not ok:
                _fails.append(name)


func _units() -> Array:
        return target_scene.squad


func _xz(u: Node3D) -> Vector2:
        return Vector2(u.global_position.x, u.global_position.z)


func _all_arrived() -> bool:
        for u in _units():
                if not u.is_arrived():
                        return false
        return true


func _arrived_in(a: Array) -> int:
        var n := 0
        for u in a:
                if u.is_arrived():
                        n += 1
        return n


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
                        _phase3_wait_posts_then_select()
                4:
                        _phase4_command_move()
                5:
                        _phase5_wait_arrival_on_cell()
                6:
                        _phase6_waypoints()
                7:
                        _phase7_regenerate()
                8:
                        _phase8_hotkeys_and_rings()
                9:
                        _phase9_channel_isolation()
                10:
                        _phase10_layer3_combat()
                11:
                        _phase11_layer4_guard()
                12:
                        _phase12_invasion_landing()
                13:
                        _phase13_melee_engagement()
                14:
                        _phase14_shield_and_peltast()
                15:
                        _phase15_permanence_and_clear()
                16:
                        _finish()


# ---------------- فاز ۰: جزیره سالم + سه دسته؟ ----------------

func _phase0_island_ready() -> void:
        var isl: Dictionary = target_scene.island
        _check("island_generated", isl.get("ok", false) == true)
        if isl.get("ok", false) != true:
                _phase = 12
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
        _check("walkable_fraction_40pct", walk_total >= int(size * size * 0.38),
                        "%d/%d = %.0f%%" % [walk_total, size * size, 100.0 * walk_total / float(size * size)])

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
        _check("multi_channel_goals_registered", (info["channels"] as Array).size() >= 3,
                        "channels=%s" % str(info["channels"]))

        _check("houses_built_4", target_scene.props.house_positions.size() == 4,
                        "%d" % target_scene.props.house_positions.size())
        var nav: NavGrid = PathService.nav
        var houses_blocked := true
        for c in target_scene.blocked_by_houses:
                if nav.is_walkable(c):
                        houses_blocked = false
        _check("house_cells_blocked_in_nav", houses_blocked,
                        "%d cells" % target_scene.blocked_by_houses.size())

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

        _check("command_cells_enough", target_scene.cmd_grid.cell_count >= 20,
                        "%d cells" % target_scene.cmd_grid.cell_count)

        # --- گام ۵: سه دسته، ترکیب و کلاس‌ها ---
        _check("squad_count_3", target_scene.squads.size() == 3,
                        "%d" % target_scene.squads.size())
        _check("unit_count_is_11", _units().size() == 11, "n=%d" % _units().size())
        var comp := "%d/%d/%d" % [target_scene.squads[0].size(), target_scene.squads[1].size(),
                        target_scene.squads[2].size()]
        _check("squad_composition_4_4_3", target_scene.squads[0].size() == 4
                        and target_scene.squads[1].size() == 4 and target_scene.squads[2].size() == 3,
                        comp)
        var class_ok := true
        for u in target_scene.squads[0]:
                if not (u is ImmortalUnit):
                        class_ok = false
        for u in target_scene.squads[1]:
                if not (u is SpearmanUnit):
                        class_ok = false
        for u in target_scene.squads[2]:
                if not (u is ArcherUnit):
                        class_ok = false
        _check("unit_classes_correct", class_ok)
        var colors_ok := true
        for si in 3:
                var c0: Color = target_scene.squads[si][0].spawn_color()
                if not (c0 in GameConstants.UNIT_PALETTE):
                        colors_ok = false
                for u in target_scene.squads[si]:
                        # فقط رنگِ تولدِ دسته مقایسه می‌شود (رسیده‌ها سرخِ موقت‌اند)
                        if u.spawn_color() != c0:
                                colors_ok = false
        _check("squad_colors_from_palette", colors_ok)

        var on_walkable := 0
        for u in _units():
                if u is UnitBase:
                        var p: Vector3 = u.global_position
                        if nav.is_walkable(nav.world_to_cell(Vector2(p.x, p.z))):
                                on_walkable += 1
        _check("units_spawned_on_walkable", on_walkable == 11, "%d/11" % on_walkable)
        # سلول‌های هدف در فاز ۳ (بعد از نشستن دسته‌ها روی پست) انتخاب می‌شوند تا
        # کلیک‌ها به سرباز نخورد — همان درسی که از اولین اجرا گرفتیم
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
        var entries: Array = []
        for i in target_scene.cmd_grid.cell_count:
                var info: Dictionary = target_scene.cmd_grid.cell_info(i)
                var center: Vector2 = info["center"]
                var cc: Vector2i = nav.world_to_cell(center)
                if depths.has(cc):
                        entries.append([i, int(depths[cc]), center])
        if entries.is_empty():
                return
        # فیلتر پیکسلی: سلولی که در صفحه نزدیک سربازِ ایستاده است کلیکِ تمیز ندارد
        var cam: Camera3D = target_scene.get_viewport().get_camera_3d()
        var clean: Array = []
        for e in entries:
                var center: Vector2 = e[2]
                var click_sp := _screen_of(Vector3(center.x,
                                target_scene.ground.height_at_world(center) + 0.1, center.y))
                var min_px := 1e9
                for u in _units():
                        var wp: Vector3 = u.global_position + Vector3(0, 0.35, 0)
                        if cam.is_position_behind(wp):
                                continue
                        min_px = minf(min_px, cam.unproject_position(wp).distance_to(click_sp))
                if min_px > 70.0:
                        clean.append(e)
        if clean.size() < 3:
                clean = entries  # پشتیبان: بدون فیلتر
        var best_b := -1
        var best_b_depth := -1
        var best_c := -1
        var best_c_gap := 1e9
        var best_d_idx := -1
        var best_d_gap := 1e9
        for e in clean:
                var idx := int(e[0])
                var dpt := int(e[1])
                var center: Vector2 = e[2]
                if dpt > best_b_depth:
                        best_b_depth = dpt
                        best_b = idx
        for e in clean:
                var idx := int(e[0])
                var dpt := int(e[1])
                if idx == best_b:
                        continue
                var gap := absf(float(dpt) - float(far_d) * 0.5)
                if gap < best_c_gap:
                        best_c_gap = gap
                        best_c = idx
        var center_b: Vector2 = target_scene.cmd_grid.cell_info(best_b)["center"]
        for e in clean:
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
                        and target_scene.selected_squad() == -1
                        and not target_scene.cmd_grid.is_command_mode()
                        and absf(Engine.time_scale - 1.0) < 0.01,
                        "time=%.2f" % Engine.time_scale)
        _phase = 3
        _sub = 0
        _sub_t = _t


# ---------------- فاز ۳: رسیدن به پست‌ها + انتخاب دسته ۰ با کلیک ----------------

func _push_click(button: MouseButton, screen: Vector2, shift: bool = false) -> void:
        var ev := InputEventMouseButton.new()
        ev.button_index = button
        ev.pressed = true
        ev.position = screen
        ev.global_position = screen
        ev.shift_pressed = shift
        ev.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
        target_scene.get_viewport().push_input(ev, true)  # همان مسیر ورودی واقعی بازیکن


func _push_key(keycode: Key) -> void:
        var ev := InputEventKey.new()
        ev.physical_keycode = keycode
        ev.pressed = true
        target_scene.get_viewport().push_input(ev, true)


func _screen_of(world: Vector3) -> Vector2:
        var cam: Camera3D = target_scene.get_viewport().get_camera_3d()
        return cam.unproject_position(world)


func _phase3_wait_posts_then_select() -> void:
        match _sub:
                0:
                        # سه دسته باید اول روی پست‌هایشان بنشینند (میدان چندکاناله)
                        var arrived_n := _arrived_in(_units())
                        if _all_arrived() or (_t - _sub_t) > 60.0:
                                _check("all_squads_reach_initial_posts", _all_arrived(),
                                                "%d/11 in %.1fs" % [arrived_n, _t - _sub_t])
                                # حالا که همه ایستاده‌اند، سلول‌های هدفِ «کلیک تمیز» انتخاب می‌شوند
                                _pick_target_cells()
                                _check("far_targets_found", _cell_b != Vector2.ZERO
                                                and _cell_c != Vector2.ZERO and _cell_d != Vector2.ZERO,
                                                "B=(%.0f,%.0f) C=(%.0f,%.0f)" % [
                                                        _cell_b.x, _cell_b.y, _cell_c.x, _cell_c.y])
                                _goal_before = PathService.goal_world()
                                var u: UnitBase = _units()[0]
                                var p: Vector3 = u.global_position + Vector3(0, 0.35, 0)
                                _push_click(MOUSE_BUTTON_LEFT, _screen_of(p))
                                _sub = 1
                                _sub_t = _t
                1:
                        if _t - _sub_t >= 0.8:
                                _check("left_click_selects_own_squad",
                                                target_scene.is_command_mode()
                                                and target_scene.selected_squad() == 0,
                                                "sel=%d" % target_scene.selected_squad())
                                _check("squad_selected_event_fired", target_scene.squad_selected_fired)
                                _check("slowmo_engaged_on_select",
                                                absf(Engine.time_scale - 0.5) < 0.06,
                                                "time=%.2f" % Engine.time_scale)
                                _check("white_grid_visible", target_scene.cmd_grid.is_command_mode())
                                _check("selection_does_not_move_goal",
                                                PathService.goal_world().distance_to(_goal_before) < 0.01)
                                _phase = 4
                                _sub = 0


# ---------------- فاز ۴: فرمان حرکت دسته ۰ به سلول دور ----------------

func _phase4_command_move() -> void:
        match _sub:
                0:
                        _computes_before = int(PathService.debug_info()["computes"])
                        # اسنپ‌شات جای دسته‌های ۱ و ۲ — بعد از فرمان نباید تکان بخورند
                        _others_snapshot.clear()
                        for u in target_scene.squads[1]:
                                _others_snapshot.append(_xz(u))
                        for u in target_scene.squads[2]:
                                _others_snapshot.append(_xz(u))
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
                                _check("formation_slots_assigned",
                                                target_scene.squad_slots_assigned(0) == 4,
                                                "%d/4" % target_scene.squad_slots_assigned(0))
                                var computes_now: int = int(PathService.debug_info()["computes"])
                                _check("field_recomputed_for_new_goal", computes_now > _computes_before,
                                                "before=%d now=%d" % [_computes_before, computes_now])
                                _phase = 5
                                _arrive_t0 = _t


# ---------------- فاز ۵: ایستادن واقعی روی سلول + سکون دسته‌های دیگر ----------------

func _phase5_wait_arrival_on_cell() -> void:
        var s0: Array = target_scene.squads[0]
        var arrived := _arrived_in(s0)
        if arrived >= 4 or (_t - _arrive_t0) > ARRIVE_DEADLINE:
                var on_slot := 0
                var slot_in_cell := 0
                var on_ground := 0
                var on_walkable := 0
                var centroid_acc := Vector2.ZERO
                var centroid_n := 0
                var nav: NavGrid = PathService.nav
                for u in s0:
                        if not u.is_arrived():
                                continue
                        var p: Vector3 = u.global_position
                        var uxz := Vector2(p.x, p.z)
                        var slot: Vector2 = u.slot_pos()
                        var tol := 1.5 if u.is_fidgeting() else 0.55
                        if uxz.distance_to(slot) <= tol:
                                on_slot += 1
                        # شعاع آرایش ۱.۲m × ۱ حلقه برای ۴ سرباز
                        if slot.distance_to(_cell_b) <= 2.9:
                                slot_in_cell += 1
                        centroid_acc += uxz
                        centroid_n += 1
                        var gy: float = target_scene.ground.height_at_world(uxz)
                        if absf(p.y - gy) <= 0.3:
                                on_ground += 1
                        if nav.is_walkable(nav.world_to_cell(uxz)):
                                on_walkable += 1
                var n := s0.size()
                _check("squad0_reach_FAR_cell", arrived >= 4,
                                "%d/%d in %.1fs" % [arrived, n, _t - _arrive_t0])
                # قانون طلایی بازخورد کاربر: دسته «روی سلول انتخابی» می‌ایستد
                _check("units_stand_ON_their_slots", on_slot >= 3, "%d/%d" % [on_slot, n])
                _check("slots_in_formation_radius", slot_in_cell >= 3, "%d/%d" % [slot_in_cell, n])
                var centroid := centroid_acc / float(maxi(centroid_n, 1))
                _check("squad_centered_on_cell", centroid.distance_to(_cell_b) <= 1.4,
                                "centroid=(%.1f,%.1f) cell=(%.1f,%.1f)" % [centroid.x, centroid.y, _cell_b.x, _cell_b.y])
                _check("units_stand_on_smooth_ground", on_ground >= 3, "%d/%d" % [on_ground, n])
                _check("units_parked_on_walkable", on_walkable >= 3, "%d/%d" % [on_walkable, n])

                # جداسازی کانال‌ها: دسته‌های ۱ و ۲ نباید به سلول B کشیده شوند
                var drift_ok := true
                var i2 := 0
                var max_drift := 0.0
                for u in target_scene.squads[1]:
                        max_drift = maxf(max_drift, _xz(u).distance_to(_others_snapshot[i2]))
                        if _xz(u).distance_to(_others_snapshot[i2]) > 2.0:
                                drift_ok = false
                        i2 += 1
                for u in target_scene.squads[2]:
                        max_drift = maxf(max_drift, _xz(u).distance_to(_others_snapshot[i2]))
                        if _xz(u).distance_to(_others_snapshot[i2]) > 2.0:
                                drift_ok = false
                        i2 += 1
                _check("other_squads_hold_posts", drift_ok, "max_drift=%.2f m" % max_drift)
                _check("channels_are_separate", PathService.goal_for(1).distance_to(PathService.goal_for(0)) > 1.0,
                                "g0-g1=%.1f m" % PathService.goal_for(1).distance_to(PathService.goal_for(0)))
                _phase = 6
                _sub = 0


# ---------------- فاز ۶: Waypoint و فرمان ساده (روی دسته ۰) ----------------

func _phase6_waypoints() -> void:
        match _sub:
                0:
                        # دسته باید «انتخاب» باشد تا فرمان/Waypoint کار کند (مثل Bad North)
                        _pick_phase6_cells()
                        var u: UnitBase = _units()[0]
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
                                # رفتار Waypoint گام ۵: Shift+کلیک انتخاب را نگه می‌دارد
                                _check("waypoint_keeps_selection", target_scene.is_command_mode()
                                                and target_scene.selected_squad() == 0,
                                                "sel=%d" % target_scene.selected_squad())
                                _sub = 3
                                _sub_t = _t
                3:
                        if _t - _sub_t >= 0.5:
                                # فرمان ساده در همان انتخاب: صف را پاک و مقصد جدید می‌گذارد
                                _cell_d = _pick_cell_far_from(_cell_c, 5.0)
                                _push_click(MOUSE_BUTTON_LEFT, _screen_of(Vector3(_cell_d.x,
                                                target_scene.ground.height_at_world(_cell_d) + 0.1, _cell_d.y)))
                                _sub = 4
                                _sub_t = _t
                4:
                        if _t - _sub_t >= 0.6:
                                var wp: Array = target_scene.waypoints
                                var g := PathService.goal_world()
                                # رفتار گام ۵: فرمان ساده صف را «خالی» می‌کند و مقصد = goal
                                _check("plain_command_replaces_queue", wp.is_empty()
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
                for u in _units():
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
                                        if u is UnitBase:
                                                var p: Vector3 = u.global_position
                                                if nav.is_walkable(nav.world_to_cell(Vector2(p.x, p.z))):
                                                        on_walkable += 1
                                _check("regen_units_respawned", _units().size() == 11 and on_walkable == 11,
                                                "%d units, %d on walkable" % [_units().size(), on_walkable])
                                _check("regen_state_reset", target_scene.mode == 0
                                                and target_scene.selected_squad() == -1
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
                                _sub = 0
                                _sub_t = _t


# ---------------- فاز ۸: کلیدهای 1..4 + حلقه‌ی انتخاب ----------------

func _phase8_hotkeys_and_rings() -> void:
        match _sub:
                0:
                        # بعد از بازتولید، سه دسته باید دوباره روی پست بنشینند
                        if _all_arrived() or (_t - _sub_t) > 60.0:
                                _check("regen_posts_reached", _all_arrived(),
                                                "%d/11" % _arrived_in(_units()))
                                _push_key(KEY_2)
                                _sub = 1
                                _sub_t = _t
                1:
                        if _t - _sub_t >= 0.7:
                                _check("key2_selects_spearman_squad",
                                                target_scene.selected_squad() == 1
                                                and target_scene.is_command_mode(),
                                                "sel=%d" % target_scene.selected_squad())
                                _check("key2_slowmo", absf(Engine.time_scale - 0.5) < 0.06,
                                                "time=%.2f" % Engine.time_scale)
                                var rings_on := true
                                for u in target_scene.squads[1]:
                                        if not u.is_ring_visible():
                                                rings_on = false
                                var rings_off := true
                                for u in target_scene.squads[0]:
                                        if u.is_ring_visible():
                                                rings_off = false
                                for u in target_scene.squads[2]:
                                        if u.is_ring_visible():
                                                rings_off = false
                                _check("rings_only_on_selected_squad", rings_on and rings_off)
                                _push_key(KEY_3)
                                _sub = 2
                                _sub_t = _t
                2:
                        if _t - _sub_t >= 0.7:
                                _check("key3_selects_archer_squad",
                                                target_scene.selected_squad() == 2,
                                                "sel=%d" % target_scene.selected_squad())
                                _push_key(KEY_4)
                                _sub = 3
                                _sub_t = _t
                3:
                        if _t - _sub_t >= 0.7:
                                _check("key4_not_recruited_keeps_selection",
                                                target_scene.selected_squad() == 2,
                                                "sel=%d" % target_scene.selected_squad())
                                _push_key(KEY_3)  # کلید تکراری = لغو انتخاب
                                _sub = 4
                                _sub_t = _t
                4:
                        if _t - _sub_t >= 0.7:
                                _check("same_key_toggles_deselect",
                                                target_scene.selected_squad() == -1
                                                and not target_scene.is_command_mode()
                                                and absf(Engine.time_scale - 1.0) < 0.06,
                                                "sel=%d time=%.2f" % [target_scene.selected_squad(),
                                                Engine.time_scale])
                                _phase = 9
                                _sub = 0
                                _sub_t = _t


# ---------------- فاز ۹: جداسازی کانال‌ها + نیزه‌دار در حرکت نمی‌جنگد ----------------

func _phase9_channel_isolation() -> void:
        match _sub:
                0:
                        _push_key(KEY_2)  # انتخاب دسته ۱ (نیزه‌دارها)
                        _sub = 1
                        _sub_t = _t
                1:
                        if _t - _sub_t >= 0.6:
                                _goal0_before = PathService.goal_for(0)
                                _cell_e = _pick_cell_far_from(target_scene.squad_center(1), 6.0)
                                _others_snapshot.clear()
                                for u in target_scene.squads[0]:
                                        _others_snapshot.append(_xz(u))
                                for u in target_scene.squads[2]:
                                        _others_snapshot.append(_xz(u))
                                _push_click(MOUSE_BUTTON_LEFT, _screen_of(Vector3(_cell_e.x,
                                                target_scene.ground.height_at_world(_cell_e) + 0.1,
                                                _cell_e.y)))
                                _sub = 2
                                _sub_t = _t
                2:
                        if _t - _sub_t >= 0.9:
                                var g1 := PathService.goal_for(1)
                                _check("squad1_channel_goal_set", g1.distance_to(_cell_e) <= 0.8,
                                                "g1=(%.1f,%.1f) want=(%.1f,%.1f)" % [g1.x, g1.y, _cell_e.x, _cell_e.y])
                                _check("squad0_channel_untouched",
                                                PathService.goal_for(0).distance_to(_goal0_before) < 0.01)
                                _check("command_releases_slowmo_and_deselects",
                                                target_scene.selected_squad() == -1
                                                and absf(Engine.time_scale - 1.0) < 0.06,
                                                "sel=%d time=%.2f" % [target_scene.selected_squad(),
                                                Engine.time_scale])
                                var moving := 0
                                for u in target_scene.squads[1]:
                                        if u.brain_state() == &"moving":
                                                moving += 1
                                _check("squad1_en_route", moving >= 3, "%d/4 moving" % moving)
                                var braced := 0
                                for u in target_scene.squads[1]:
                                        if u is SpearmanUnit and u.brace_active:
                                                braced += 1
                                _check("spearman_never_braces_while_moving", braced == 0,
                                                "%d braced" % braced)
                                _sub = 3
                                _sub_t = _t
                3:
                        if _t - _sub_t >= 0.6:
                                var drift_ok := true
                                var i2 := 0
                                for u in target_scene.squads[0]:
                                        if _xz(u).distance_to(_others_snapshot[i2]) > 1.2:
                                                drift_ok = false
                                        i2 += 1
                                for u in target_scene.squads[2]:
                                        if _xz(u).distance_to(_others_snapshot[i2]) > 1.2:
                                                drift_ok = false
                                        i2 += 1
                                _check("other_squads_frozen_while_squad1_marches", drift_ok)
                                _phase = 10
                                _sub = 0
                                _sub_t = _t


## سلول فرمان دور از نقطه‌ی داده‌شده + دور از همه‌ی سربازها (برای کلیک تمیز)
func _pick_cell_far_from(from: Vector2, min_dist: float) -> Vector2:
        var cam: Camera3D = target_scene.get_viewport().get_camera_3d()
        var best := Vector2.ZERO
        var best_d := -1.0
        for i in target_scene.cmd_grid.cell_count:
                var info: Dictionary = target_scene.cmd_grid.cell_info(i)
                var center: Vector2 = info["center"]
                var d: float = center.distance_to(from)
                if d < min_dist:
                        continue
                var click_sp := _screen_of(Vector3(center.x,
                                target_scene.ground.height_at_world(center) + 0.1, center.y))
                var min_px := 1e9
                for u in _units():
                        var wp: Vector3 = u.global_position + Vector3(0, 0.35, 0)
                        if cam.is_position_behind(wp):
                                continue
                        min_px = minf(min_px, cam.unproject_position(wp).distance_to(click_sp))
                if min_px < 70.0:
                        continue
                if d > best_d:
                        best_d = d
                        best = center
        if best == Vector2.ZERO:
                best = from  # پشتیبان: همان نقطه (تست فاصله‌ی کوتاه‌تر می‌شود)
        return best


# ---------------- فاز ۱۰: لایه ۳ — واکنش نبرد روی کوله‌ی تمرین ----------------

func _facing(u: UnitBase, target: Node3D, tol_rad: float) -> bool:
        var d := target.global_position - u.global_position
        var want := atan2(d.x, d.z)
        return absf(wrapf(want - u.rotation.y, -PI, PI)) <= tol_rad


func _phase10_layer3_combat() -> void:
        match _sub:
                0:
                        # کوله برای جاویدان‌ها (تماس نزدیک) + کوله‌ی کماندارها در «برد واقعی»
                        # درس اولین اجرا: هدفِ ۲.۲ متری داخل آرایش، کریدور همه را می‌بندد
                        _dummy0 = target_scene.spawn_dummy_near_world(
                                        target_scene.squad_center(0), Vector2(2.2, 0.0))
                        _dummy2 = target_scene.spawn_dummy_at_range(2, 6.5)
                        _sub = 1
                        _sub_t = _t
                1:
                        if _t - _sub_t >= 9.0:
                                var shielded := 0
                                for u in target_scene.squads[0]:
                                        if u is ImmortalUnit and u.shield_up:
                                                shielded += 1
                                _check("immortals_raise_shield", shielded >= 2, "%d/4" % shielded)
                                var facing := 0
                                for u in target_scene.squads[0]:
                                        if u is ImmortalUnit and _facing(u, _dummy0, 0.6):
                                                facing += 1
                                _check("immortals_face_dummy", facing >= 2, "%d/4" % facing)
                                var in_combat := 0
                                for u in target_scene.squads[2]:
                                        if u.brain_state() == &"combat":
                                                in_combat += 1
                                _check("archers_enter_combat_state", in_combat >= 1, "%d/3" % in_combat)
                                _check("archers_fire_arrows", target_scene.arrows_fired_total() >= 2,
                                                "%d arrows" % target_scene.arrows_fired_total())
                                _check("dummy_takes_hits", target_scene.dummy_hits_total() >= 1,
                                                "%d hits" % target_scene.dummy_hits_total())
                                _sub = 2
                                _sub_t = _t
                2:
                        # صبر تا نیزه‌دارها به مقصد فاز ۹ برسند، بعد کوله‌ی آن‌ها
                        var arrived1 := _arrived_in(target_scene.squads[1])
                        if arrived1 >= 4 or (_t - _sub_t) > 60.0:
                                var dbg := ""
                                for u in target_scene.squads[1]:
                                        dbg += " [%.1fm:%s]" % [_xz(u).distance_to(u.slot_pos()),
                                                        str(u.brain_state())]
                                _check("squad1_arrives_for_brace_test", arrived1 >= 4,
                                                "%d/4%s" % [arrived1, dbg])
                                _dummy1 = target_scene.spawn_dummy_near_world(
                                                target_scene.squad_center(1), Vector2(2.2, 0.0))
                                _sub = 3
                                _sub_t = _t
                3:
                        if _t - _sub_t >= 6.0:
                                var braced := 0
                                for u in target_scene.squads[1]:
                                        if u is SpearmanUnit and u.brace_active:
                                                braced += 1
                                _check("spearmen_brace_only_when_standing", braced >= 2, "%d/4" % braced)
                                _phase = 11
                                _sub = 0
                                _sub_t = _t


# ---------------- فاز ۱۱: لایه ۴ — بازگشت به پست + سلامت نهایی ----------------

func _phase11_layer4_guard() -> void:
        match _sub:
                0:
                        _push_key(KEY_D)  # پاک‌کردن کوله‌ها → پایان نبرد
                        _sub = 1
                        _sub_t = _t
                1:
                        if _t - _sub_t >= 1.2:
                                var clear_ok: bool = target_scene.dummy_count() == 0
                                for u in _units():
                                        if u.brain_state() == &"combat":
                                                clear_ok = false
                                _check("dummies_cleared_ends_combat", clear_ok,
                                                "dummies=%d" % target_scene.dummy_count())
                                var imm_down := true
                                for u in target_scene.squads[0]:
                                        if u is ImmortalUnit and u.shield_up:
                                                imm_down = false
                                var imm_dbg := ""
                                for u in target_scene.squads[0]:
                                        imm_dbg += " [%s:%s]" % [str(u.brain_state()),
                                                        str((u as ImmortalUnit).shield_up)]
                                _check("immortals_lower_shield_after_clear", imm_down, imm_dbg)
                                # لایه ۴: جابه‌جایی دستی یک جاویدان → خودش به پست برمی‌گردد
                                var u0: UnitBase = target_scene.squads[0][0]
                                _slot_before = u0.slot_pos()
                                var displaced := _slot_before + Vector2(2.6, 1.4)
                                var nav: NavGrid = PathService.nav
                                var np := _nearest_walkable(nav, nav.world_to_cell(displaced))
                                var c := nav.cell_center(np)
                                u0.global_position = Vector3(c.x, u0.global_position.y, c.y)
                                _computes_before = int(PathService.debug_info()["computes"])
                                _sub = 2
                                _sub_t = _t
                2:
                        if _t - _sub_t >= 8.0:
                                var u0: UnitBase = target_scene.squads[0][0]
                                var back := _xz(u0).distance_to(_slot_before) <= 0.7 \
                                                and u0.is_arrived()
                                _check("guard_returns_to_post_layer4", back,
                                                "dist=%.2f m arrived=%s" % [
                                                        _xz(u0).distance_to(_slot_before),
                                                        str(u0.is_arrived())])
                                var computes_now: int = int(PathService.debug_info()["computes"])
                                _check("field_still_alive_at_end", computes_now > _computes_before,
                                                "before=%d now=%d" % [_computes_before, computes_now])
                                var all_ok := true
                                var nav: NavGrid = PathService.nav
                                for u in _units():
                                        if not nav.is_walkable(nav.world_to_cell(_xz(u))):
                                                all_ok = false
                                _check("all_units_on_walkable_at_end", all_ok)
                                _check("time_back_to_normal", absf(Engine.time_scale - 1.0) < 0.06,
                                                "time=%.2f" % Engine.time_scale)
                                _phase = 12
                                _sub = 0   # فاز بعدی (فرود موج) از زیرفاز صفر شروع شود


# ---------------- فاز ۱۲: موج هجوم — فرود قایق و پیاده‌شدن مهاجمان ----------------

func _far_shore_hint() -> Vector2:
        var nav: NavGrid = PathService.nav
        var o := nav.origin
        var s := nav.size_world()
        var cands := [o + Vector2(2.0, 2.0), o + Vector2(s.x - 2.0, 2.0),
                        o + Vector2(2.0, s.y - 2.0), o + Vector2(s.x - 2.0, s.y - 2.0)]
        var best: Vector2 = cands[0]
        var best_d := -1.0
        for p in target_scene._squad_posts:
                for c in cands:
                        var d: float = p.distance_to(c)
                        if d > best_d:
                                best_d = d
                                best = c
        return best


func _phase12_invasion_landing() -> void:
        match _sub:
                0:
                        # موج کنترل‌شده با فرود قطعی (تست = بدون موج خودکار)
                        target_scene.director.auto_waves = false
                        _group0 = target_scene.director.spawn_wave(
                                        {"size": 6, "near": _far_shore_hint(), "force": true})
                        _check("wave_spawned", _group0 >= 0, "group=%d" % _group0)
                        _check("waves_spawned_counted",
                                        target_scene.director.waves_spawned == 1,
                                        "%d" % target_scene.director.waves_spawned)
                        _check("boat_sailing", target_scene.director.boat_state(_group0) == 0,
                                        "state=%d" % target_scene.director.boat_state(_group0))
                        _sub = 1
                        _sub_t = _t
                1:
                        # قایق باید پهلو بگیرد و ۶ مهاجم پیاده شود (۳۹s مهلت)
                        var n: int = target_scene.director.raiders_alive(_group0)
                        if n >= 6 or (_t - _sub_t) > 39.0:
                                _check("boat_landed_six_raiders", n == 6,
                                                "%d raiders (t=%.1f)" % [n, _t - _sub_t])
                                _check("boat_anchored",
                                                target_scene.director.boat_state(_group0) == 1,
                                                "state=%d" % target_scene.director.boat_state(_group0))
                                var ch := int((PathService.debug_info()["channels"] as Array).size())
                                _check("enemy_channel_registered", ch >= 4,
                                                "channels=%d" % ch)
                                _landing = target_scene.director.group_landing(_group0)
                                _check("landing_on_shore", _landing != Vector2.ZERO)
                                var rt: Vector2 = target_scene.director.group_raid_target(_group0)
                                var is_house := false
                                for hp3 in target_scene.props.house_positions:
                                        if Vector2(hp3.x, hp3.z).distance_to(rt) < 2.0:
                                                is_house = true
                                _check("raid_target_is_house", is_house, str(rt))
                                _sub = 2
                                _sub_t = _t
                2:
                        # رژه به داخل جزیره: حداقل یک مهاجم از ساحل دور شده باشد
                        if _t - _sub_t >= 4.0:
                                var moved := false
                                for e in target_scene.director.raiders_of(_group0):
                                        if is_instance_valid(e) and not e.is_dead():
                                                var ep := Vector2(e.global_position.x,
                                                                e.global_position.z)
                                                if ep.distance_to(_landing) > 2.5:
                                                        moved = true
                                _check("raiders_march_inland", moved)
                                _phase = 13
                                _sub = 0
                                _sub_t = _t


# ---------------- فاز ۱۳: درگیری تن‌به‌تن ----------------

func _phase13_melee_engagement() -> void:
        match _sub:
                0:
                        # جاویدان‌ها را به خانه‌ی هدف رژه فرا می‌خوانیم
                        _squad_alive_before = target_scene.squad.size()
                        var rt: Vector2 = target_scene.director.group_raid_target(_group0)
                        var nav: NavGrid = PathService.nav
                        var dest: Vector2 = target_scene._nearest_walkable_point(
                                        nav, rt + Vector2(1.8, 1.8), 2.6)
                        if dest == Vector2.INF:
                                dest = target_scene._nearest_walkable_point(nav, rt, 3.5)
                        _check("summon_destination_found", dest != Vector2.INF, str(dest))
                        target_scene._issue_move_to(dest, 0, true)
                        _sub = 1
                        _sub_t = _t
                1:
                        # درگیری: مهاجم یا سرباز هدف نبرد پیدا کند (۳۰s مهلت)
                        var engaged := false
                        for e in target_scene.director.raiders_of(_group0):
                                if is_instance_valid(e) and not e.is_dead() \
                                                and e.engaged_unit != null:
                                        engaged = true
                        var pc := false
                        for u in target_scene.squad:
                                if is_instance_valid(u) and not u.is_dead() \
                                                and u.combat_target() != null:
                                        pc = true
                        if engaged or pc or (_t - _sub_t) > 30.0:
                                _check("combat_engaged", engaged or pc,
                                                "raider=%s player=%s (t=%.1f)" % [
                                                        engaged, pc, _t - _sub_t])
                                _sub = 2
                                _sub_t = _t
                2:
                        if _t - _sub_t >= 8.0:
                                var raiders_dead := 0
                                var raiders_hurt := false
                                for e in target_scene.director.raiders_of(_group0):
                                        if not is_instance_valid(e):
                                                continue
                                        if e.is_dead():
                                                raiders_dead += 1
                                        elif e.hp < e._default_hp():
                                                raiders_hurt = true
                                var players_hurt := false
                                for u in target_scene.squad:
                                        if is_instance_valid(u) and not u.is_dead() \
                                                        and u.hp < u._default_hp():
                                                players_hurt = true
                                _check("raiders_took_damage",
                                                raiders_dead >= 1 or raiders_hurt,
                                                "dead=%d hurt=%s" % [raiders_dead, raiders_hurt])
                                var players_lost: bool = target_scene.squad.size() \
                                                < _squad_alive_before
                                _check("battle_was_two_sided",
                                                players_lost or players_hurt
                                                or raiders_dead >= 2,
                                                "lost=%d hurt=%s dead=%d" % [
                                                        _squad_alive_before
                                                        - target_scene.squad.size(),
                                                        players_hurt, raiders_dead])
                                _sub = 3
                                _sub_t = _t
                3:
                        # سپر جاویدان در نبرد واقعی — اول فرصت طبیعی، بعد تماسِ قطعی
                        var shielded := 0
                        for u in target_scene.squads[0]:
                                if u is ImmortalUnit and u.shield_up:
                                        shielded += 1
                        if int((_t - _sub_t) * 2.0) != int((maxf(_t - _sub_t - 0.016, 0.0)) * 2.0):
                                for u in target_scene.squads[0]:
                                        var nh := 1e9
                                        for e2 in target_scene.director.raiders_of(_group0):
                                                if is_instance_valid(e2) and not e2.is_dead():
                                                        nh = minf(nh, _xz(u).distance_to(_xz(e2)))
                                        print("[AUTOTEST] DBG13 t=%.1f imm (%.1f,%.1f) %s slot=%s ct=%s hp=%d nh=%.2f"
                                                        % [_t - _sub_t, u.global_position.x,
                                                        u.global_position.z, u.brain_state(),
                                                        str(u.has_slot()),
                                                        str(u.combat_target() != null),
                                                        u.hp, nh])
                        if shielded >= 1:
                                _check("immortals_shield_vs_raiders", true,
                                                "%d/4 (t=%.1f)" % [shielded, _t - _sub_t])
                                _phase = 14
                                _sub = 0
                                _sub_t = _t
                        elif not _contact_forced and (_t - _sub_t) > 1.5:
                                # تماس قطعی: جاویدان‌های زنده را کنار یک مهاجم زنده می‌گذاریم
                                # (بدون اسلات → واکنش فوری لایه ۳)
                                _contact_forced = true
                                var target_e: EnemyBase = null
                                for e in target_scene.director.raiders_of(_group0):
                                        if is_instance_valid(e) and not e.is_dead():
                                                target_e = e
                                                break
                                if target_e != null:
                                        var nav13: NavGrid = PathService.nav
                                        var base := Vector2(target_e.global_position.x,
                                                        target_e.global_position.z)
                                        var k13 := 0
                                        for u in target_scene.squads[0]:
                                                if is_instance_valid(u) and not u.is_dead():
                                                        var off := Vector2(cos(0.9 * k13),
                                                                        sin(0.9 * k13)) * 1.2
                                                        var w: Vector2 = target_scene._nearest_walkable_point(
                                                                        nav13, base + off, 1.5)
                                                        if w == Vector2.INF:
                                                                w = base
                                                        u.global_position = Vector3(w.x,
                                                                        u.global_position.y, w.y)
                                                        u.clear_slot()
                                                        k13 += 1
                        elif (_t - _sub_t) > 18.0:
                                var any_raider := false
                                for e in target_scene.director.raiders_of(_group0):
                                        if is_instance_valid(e) and not e.is_dead():
                                                any_raider = true
                                _check("immortals_shield_vs_raiders", not any_raider,
                                                "0/4 raiders_left=%s" % any_raider)
                                _phase = 14
                                _sub = 0
                                _sub_t = _t


# ---------------- فاز ۱۴: سپر سنگین + پلتاست ----------------

## نقطه‌ی قابل‌عبور که فاصله‌اش تا نزدیک‌ترین سربازِ زنده ≈ want_dist باشد
## (پلتاست باید درون برد پرتاب باشد؛ سنگین بیرون شعاع توجه)
func _point_near_units(center: Vector2, want_dist: float, lo: float, hi: float,
                nav: NavGrid) -> Vector2:
        var alive: Array = []
        for u in target_scene.squad:
                if is_instance_valid(u) and not u.is_dead():
                        alive.append(u)
        var best := Vector2.INF
        var best_err := 1e9
        for k in 12:
                var ang := TAU * float(k) / 12.0
                var cand := center + Vector2(cos(ang), sin(ang)) * want_dist
                var w: Vector2 = target_scene._nearest_walkable_point(nav, cand, 1.2)
                if w == Vector2.INF:
                        continue
                var min_u := 1e9
                for u in alive:
                        min_u = minf(min_u, w.distance_to(_xz(u)))
                if min_u < lo or min_u > hi:
                        continue
                if absf(min_u - want_dist) < best_err:
                        best_err = absf(min_u - want_dist)
                        best = w
        if best == Vector2.INF:
                best = target_scene._nearest_walkable_point(nav,
                                center + Vector2(want_dist, 0.0), 3.0)
        return best


func _phase14_shield_and_peltast() -> void:
        match _sub:
                0:
                        var c2: Vector2 = target_scene.squad_center(2)
                        var nav: NavGrid = PathService.nav
                        # سنگین: بیرون از شعاع توجه (۳m) ولی در برد کمان (۸.۵m)
                        var ph: Vector2 = _point_near_units(c2, 6.2, 4.6, 7.8, nav)
                        _heavy_test = target_scene.director.spawn_enemy("heavy", ph, -1)
                        # پلتاست: نزدیک دسته‌ی «غیرکماندارِ» زنده می‌نشینیم تا تیرهای
                        # خودی پیش از اولین پرتاب آن را نکشند (دیباگ: مرگ در t<1s)
                        var host_si := -1
                        var best_n := 0
                        for si in [0, 1]:
                                var n := 0
                                for u in target_scene.squads[si]:
                                        if is_instance_valid(u) and not u.is_dead():
                                                n += 1
                                if n > best_n:
                                        best_n = n
                                        host_si = si
                        if host_si < 0:
                                host_si = 2  # فقط کماندارها زنده‌اند — با ریسک تیر
                        var chost: Vector2 = target_scene.squad_center(host_si)
                        # پلتاست: درون برد پرتاب (۵.۵m) و بیرون برد عقب‌نشینی (۳m)
                        var pp: Vector2 = _point_near_units(chost, 4.3, 3.4, 5.2, nav)
                        _peltast_test = target_scene.director.spawn_enemy("peltast", pp, -1)
                        _check("test_heavy_spawned", _heavy_test != null)
                        _check("test_peltast_spawned", _peltast_test != null)
                        _arrow_baseline = target_scene.arrows_fired_total()
                        # مخروط سپر — بررسی قطعی API (پیش از رسیدن تیرها)
                        if _heavy_test != null:
                                var fwd := Vector3(sin(_heavy_test._heading), 0.0,
                                                cos(_heavy_test._heading))
                                _check("heavy_shield_blocks_front",
                                                _heavy_test.projectile_deflected(-fwd))
                                _check("heavy_shield_open_behind",
                                                not _heavy_test.projectile_deflected(fwd))
                        _sub = 1
                        _sub_t = _t
                1:
                        # نمونه‌برداری زنده (مهاجم ممکن است کشته شود و شمارنده‌اش آزاد شود)
                        if is_instance_valid(_heavy_test):
                                _max_deflects = maxi(_max_deflects, _heavy_test.deflects)
                                if _heavy_test.hp < _heavy_test._default_hp():
                                        _heavy_hurt_seen = true
                        if is_instance_valid(_peltast_test):
                                _max_thrown = maxi(_max_thrown, _peltast_test.javelins_thrown)
                        if _t - _sub_t >= 9.0:
                                _check("heavy_deflect_or_take_hits",
                                                _max_deflects >= 1 or _heavy_hurt_seen,
                                                "deflects=%d hurt=%s" % [
                                                        _max_deflects, _heavy_hurt_seen])
                                _check("arrows_flew_at_enemies",
                                                target_scene.arrows_fired_total()
                                                > _arrow_baseline,
                                                "%d→%d" % [_arrow_baseline,
                                                target_scene.arrows_fired_total()])
                                _check("peltast_throws_javelins", _max_thrown >= 1,
                                                "%d throws" % _max_thrown)
                                _phase = 15
                                _sub = 0
                                _sub_t = _t


# ---------------- فاز ۱۵: مرگ دائمی + پاکسازی موج ----------------

func _phase15_permanence_and_clear() -> void:
        match _sub:
                0:
                        _units_before = target_scene.squad.size()
                        for u in target_scene.squad:
                                if is_instance_valid(u) and not u.is_dead():
                                        _killed_unit = u
                                        u.take_hit(99)
                                        break
                        _check("killed_unit_chosen", _killed_unit != null)
                        _sub = 1
                        _sub_t = _t
                1:
                        if _t - _sub_t >= 2.5:
                                _check("dead_unit_removed_from_squads",
                                                not target_scene.squad.has(_killed_unit))
                                _check("death_permanent_unit_count",
                                                target_scene.squad.size() == _units_before - 1,
                                                "%d→%d" % [_units_before,
                                                target_scene.squad.size()])
                                _check("dead_unit_freed_after_anim",
                                                not is_instance_valid(_killed_unit))
                                # پاکسازی موج: همه‌ی مهاجمان کشته می‌شوند
                                target_scene.director.kill_all_raiders()
                                _sub = 2
                                _sub_t = _t
                2:
                        if _t - _sub_t >= 1.5:
                                _check("wave_cleared_signal", _wave_cleared_fired)
                                _check("all_raiders_dead",
                                                target_scene.director.alive_raiders_total() == 0)
                                _check("boat_leaving",
                                                target_scene.director.boat_state(_group0) == 2,
                                                "state=%d" % target_scene.director.boat_state(_group0))
                                _sub = 3
                                _sub_t = _t
                3:
                        if _t - _sub_t >= 10.0:
                                _check("boat_departed_and_freed",
                                                target_scene.director.boat_state(_group0) == -1,
                                                "state=%d" % target_scene.director.boat_state(_group0))
                                _check("no_boats_active",
                                                target_scene.director.boats_active() == 0)
                                # سلامت نهایی: زنده‌ها روی سلول قابل‌عبور + زمان نرمال
                                var all_ok := true
                                var nav: NavGrid = PathService.nav
                                for u in target_scene.squad:
                                        if not is_instance_valid(u) or u.is_dead():
                                                continue
                                        if not nav.is_walkable(
                                                        nav.world_to_cell(_xz(u))):
                                                all_ok = false
                                _check("alive_units_on_walkable_at_end", all_ok)
                                _check("time_back_to_normal_after_invasion",
                                                absf(Engine.time_scale - 1.0) < 0.06,
                                                "time=%.2f" % Engine.time_scale)
                                _phase = 16


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
