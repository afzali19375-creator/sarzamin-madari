class_name IslandAutoTest
extends Node
## تست خودکار گام ۴ — معیار پذیرش جزیره‌ی WFC روی کاشی‌های قابل‌کلیک:
##   0) جزیره تولید شده (سریع، ≤32×32، لبه‌ها آب، نسبت خشکی سالم)، ۱۰ واحد روی کاشی
##   1) قطعیت WFC: همان seed → همان جزیره + فشار ۸ seed تازه (بدون تعارض بازگشتی)
##   2) همگامی NavGrid با کاشی‌ها + اتصال‌پذیری کامل خشکی (BFS)
##   3) پیکینگ واقعی بلوک‌ها: کلیک چپ → انتخاب کاشی؛ کلیک راست → فرمان به کاشیِ دور
##   4) واحدها از میان آب/صخره به کاشیِ هدف می‌رسند و «روی سقف کاشی» می‌ایستند
##   5) بازتولید (R) → جزیره‌ی تازه + همگامی دوباره + میدان زنده
## اجرا:
##   godot --headless --path . res://scenes/dev/IslandTest.tscn -- --autotest
## کد خروج: 0 = همه PASS، 1 = حداقل یک FAIL

const ARRIVE_MIN_UNITS := 9
const ARRIVE_DEADLINE := 45.0
const REGEN_SEED := 4242

var target_scene: Node3D

var _t := 0.0
var _phase := 0
var _sub := 0
var _fails: PackedStringArray = []
var _results: PackedStringArray = []
var _computes_before := 0
var _arrive_t0 := 0.0
var _cell_a := Vector2i(-1, -1)
var _cell_b := Vector2i(-1, -1)
var _goal_before := Vector2.ZERO
var _sub_t := 0.0


func _ready() -> void:
        print("[AUTOTEST] island harness attached — 6 phases (WFC + tiles + command)")


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
                        if _t >= 0.8:
                                _phase0_island_ready()
                1:
                        _phase1_wfc_determinism_and_stress()
                2:
                        if _t >= 1.2:
                                _phase2_nav_sync_and_connectivity()
                3:
                        _phase3_picking_and_command()
                4:
                        _phase4_wait_arrival()
                5:
                        _phase5_regenerate()
                6:
                        _finish()


# ---------------- فاز ۰: جزیره سالم تولید شده؟ ----------------

func _phase0_island_ready() -> void:
        var isl: Dictionary = target_scene.island
        _check("island_generated", isl.get("ok", false) == true)
        if isl.get("ok", false) != true:
                _phase = 6
                return
        _check("gen_fast", float(isl["gen_ms"]) < 2000.0, "%.1f ms" % isl["gen_ms"])
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

        var frac := float(int(isl["land_count"])) / float(size * size)
        _check("land_fraction_sane", frac >= 0.14 and frac <= 0.55, "land=%.0f%%" % (frac * 100.0))

        var info: Dictionary = PathService.debug_info()
        _check("field_published", info["has_field"] == true, "computes=%d" % info["computes"])

        var nav: NavGrid = PathService.nav
        var on_walkable := 0
        for u in _units():
                if u is TestUnit:
                        var p: Vector3 = u.global_position
                        if nav.is_walkable(nav.world_to_cell(Vector2(p.x, p.z))):
                                on_walkable += 1
        _check("unit_count_is_10", _units().size() == 10, "n=%d" % _units().size())
        _check("units_spawned_on_walkable_tiles", on_walkable == 10, "%d/10" % on_walkable)
        _phase = 1


# ---------------- فاز ۱: قطعیت و فشار سولو WFC ----------------

func _phase1_wfc_determinism_and_stress() -> void:
        var gen := WfcIsland.new()
        var a := gen.generate(777, 32)
        var b := gen.generate(777, 32)
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
                if r.get("ok", false) != true or int(r["walkable_count"]) < 100:
                        stress_ok = false
                        details += " seed%d:%s" % [s, r.get("ok", false)]
        _check("wfc_8_fresh_seeds_all_succeed", stress_ok, details)
        _phase = 2


# ---------------- فاز ۲: همگامی NavGrid + اتصال‌پذیری ----------------

func _phase2_nav_sync_and_connectivity() -> void:
        var isl: Dictionary = target_scene.island
        var size: int = isl["size"]
        var nav: NavGrid = PathService.nav
        var w: PackedByteArray = isl["walkable"]
        var mismatches := 0
        for y in size:
                for x in size:
                        if nav.is_walkable(Vector2i(x, y)) != (w[y * size + x] == 1):
                                mismatches += 1
        _check("navgrid_matches_tiles", mismatches == 0, "%d mismatches" % mismatches)

        # اتصال‌پذیری خشکی از سلول هدف (BFS روی خود NavGrid)
        var start := nav.world_to_cell(PathService.goal_world())
        var q: Array[Vector2i] = []
        var seen := {}
        if nav.is_walkable(start):
                q.append(start)
                seen[start] = true
        var head := 0
        var max_depth := 0
        while head < q.size():
                var c: Vector2i = q[head]
                head += 1
                for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                        var n2: Vector2i = c + d
                        if nav.is_walkable(n2) and not seen.has(n2):
                                seen[n2] = true
                                q.append(n2)
        var walk_total := 0
        for y in size:
                for x in size:
                        if nav.is_walkable(Vector2i(x, y)):
                                walk_total += 1
        _check("land_fully_connected", seen.size() == walk_total and walk_total >= 100,
                        "%d/%d reachable" % [seen.size(), walk_total])

        # انتخاب کاشی‌های هدف فاز ۳: A = میانه‌ی عمق، B = دورترین نقطه‌ی قابل‌عبور
        if q.size() > 0:
                var depths := {}
                var q2: Array[Vector2i] = [start]
                depths[start] = 0
                var h2 := 0
                while h2 < q2.size():
                        var c: Vector2i = q2[h2]
                        h2 += 1
                        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                                var n2: Vector2i = c + d
                                if nav.is_walkable(n2) and not depths.has(n2):
                                        depths[n2] = depths[c] + 1
                                        q2.append(n2)
                var far_d := 0
                for v in depths.values():
                        far_d = maxi(far_d, int(v))
                for c in depths:
                        if int(depths[c]) == far_d:
                                _cell_b = c
                        elif int(depths[c]) == int(far_d * 0.6) and _cell_a == Vector2i(-1, -1) and c != _cell_b:
                                _cell_a = c
                if _cell_a == Vector2i(-1, -1):
                        _cell_a = start
        _check("far_targets_found", _cell_a != Vector2i(-1, -1) and _cell_b != Vector2i(-1, -1),
                        "A=%s B=%s" % [_cell_a, _cell_b])
        _phase = 3
        _sub = 0


# ---------------- فاز ۳: پیکینگ بلوک + فرمان ----------------

func _push_click(button: MouseButton, screen: Vector2) -> void:
        var ev := InputEventMouseButton.new()
        ev.button_index = button
        ev.pressed = true
        ev.position = screen
        ev.global_position = screen
        ev.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
        target_scene.get_viewport().push_input(ev, true)  # همان مسیر ورودی واقعی بازیکن


func _unproject_of_cell(cell: Vector2i) -> Vector2:
        var cam: Camera3D = target_scene.get_viewport().get_camera_3d()
        var nav: NavGrid = PathService.nav
        var world := nav.cell_center(cell)
        var top: float = target_scene.tiles.top_at(cell)
        return cam.unproject_position(Vector3(world.x, top, world.y))


func _phase3_picking_and_command() -> void:
        match _sub:
                0:
                        # کلیک چپ روی کاشی A → باید «انتخاب» شود (پیکینگ واقعی بلوک)
                        _push_click(MOUSE_BUTTON_LEFT, _unproject_of_cell(_cell_a))
                        _check("left_click_selects_tile", target_scene.selected_cell() == _cell_a,
                                        "selected=%s want=%s" % [target_scene.selected_cell(), _cell_a])
                        _sub = 1
                1:
                        # کلیک راست روی کاشیِ دور B → فرمان حرکت به همان کاشی
                        _goal_before = PathService.goal_world()
                        _computes_before = int(PathService.debug_info()["computes"])
                        _push_click(MOUSE_BUTTON_RIGHT, _unproject_of_cell(_cell_b))
                        var g := PathService.goal_world()
                        var want := PathService.nav.cell_center(_cell_b)
                        _check("right_click_commands_tile", g.distance_to(want) <= 0.6 \
                                        and g.distance_to(_goal_before) > 5.0,
                                        "goal=(%.1f,%.1f) want=(%.1f,%.1f)" % [g.x, g.y, want.x, want.y])
                        _sub = 2
                        _sub_t = _t
                2:
                        # میدان باید برای مقصد جدید بازمحاسبه شود (نخ کارگر زنده)
                        if _t - _sub_t >= 0.6:
                                var computes_now: int = int(PathService.debug_info()["computes"])
                                _check("field_recomputed_for_new_goal", computes_now > _computes_before,
                                                "before=%d now=%d" % [_computes_before, computes_now])
                                _phase = 4
                                _arrive_t0 = _t


# ---------------- فاز ۴: رسیدن به کاشی دور ----------------

func _phase4_wait_arrival() -> void:
        var want := PathService.nav.cell_center(_cell_b)
        var arrived := 0
        var on_top := 0
        for u in _units():
                if u is TestUnit and u.is_arrived():
                        arrived += 1
                        var p: Vector3 = u.global_position
                        if Vector2(p.x, p.z).distance_to(want) <= 1.5:
                                var ground_y: float = target_scene.tiles.height_at_world(Vector2(p.x, p.z))
                                if absf(p.y - ground_y) <= 0.25:
                                        on_top += 1
        if arrived >= ARRIVE_MIN_UNITS or (_t - _arrive_t0) > ARRIVE_DEADLINE:
                _check("units_reach_FAR_tile", arrived >= ARRIVE_MIN_UNITS,
                                "%d/%d in %.1fs" % [arrived, _units().size(), _t - _arrive_t0])
                _check("units_stand_on_tile_tops", on_top >= 8, "%d/%d at ground height" % [on_top, _units().size()])
                _phase = 5
                _sub = 0


# ---------------- فاز ۵: بازتولید جزیره (کلید R به‌صورت برنامه‌ای) ----------------

func _phase5_regenerate() -> void:
        match _sub:
                0:
                        target_scene.regenerate(REGEN_SEED)
                        _sub = 1
                        _sub_t = _t
                1:
                        if _t - _sub_t >= 0.5:
                                var isl: Dictionary = target_scene.island
                                _check("regen_new_island", isl.get("ok", false) == true \
                                                and int(isl["seed_used"]) == REGEN_SEED,
                                                "seed=%s attempts=%s" % [isl.get("seed_used", -1), isl.get("attempts", -1)])
                                var nav: NavGrid = PathService.nav
                                var size: int = int(isl["size"])
                                var w: PackedByteArray = isl["walkable"]
                                var mismatches := 0
                                for y in size:
                                        for x in size:
                                                if nav.is_walkable(Vector2i(x, y)) != (w[y * size + x] == 1):
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
                                _computes_before = int(PathService.debug_info()["computes"])
                                _sub = 2
                                _sub_t = _t
                2:
                        if _t - _sub_t >= 0.7:
                                var computes_now: int = int(PathService.debug_info()["computes"])
                                _check("regen_field_alive", computes_now > _computes_before,
                                                "before=%d now=%d" % [_computes_before, computes_now])
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
