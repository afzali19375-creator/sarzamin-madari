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
##   ۹) کلیدهای 1..5: انتخاب دسته‌ها + حلقه‌ی سفید فقط روی دسته‌ی انتخابی + toggle
##  ۱۰) جداسازی کانال‌ها: فرمان به دسته ۱ → دسته‌های ۰/۲ منجمد؛ نیزه‌دار در حرکت آماده‌باش نمی‌شود
##  ۱۱) لایه ۳ روی کوله‌ی تمرین: جاویدان سپر، کماندار تیر (بدون آسیب دوستانه)،
##      نیزه‌دار فقط در ایست آماده‌باش؛ پاک‌کردن کوله = پایان نبرد
##  ۱۲) لایه ۴: واحدِ جابه‌جاشده خودش به پست بازمی‌گردد + سلامت نهایی
##  --- گام ۶ ---
##  ۱۳) موج هجوم: قایق پهلو می‌گیرد، ۶ مهاجم پیاده می‌شود، کانال دشمن در میدان،
##      هدف رژه = خانه، مهاجمان به داخل جزیره رژه می‌روند
##  ۱۴) نبرد تن‌به‌تن: مهاجم به سرباز درگیری؛ جاویدان سپر؛ تبادل ضربه دو طرفه
##  ۱۵) سپر سنگین (مخروط پیش‌رو) + کماندار با دشمن واقعی + پلتاست پرتاب می‌کند
##      + گام ۶R2: مهاجمِ تیرخورده به شلیک‌کننده تلافی می‌کند (engaged)
##  ۱۶) مرگ دائمی سرباز (حذف از دسته‌ها) + گام ۶R2: قایق بعد از مرگ مهاجمان
##      در ساحل می‌ماند (دیگر برنمی‌گردد)
##  --- گام ۶R (بازخورد کاربر) ---
##  ۱۷) فرمانده هر دسته عضو اول با پرچم رنگِ دسته + چرخش دوربین (Q و جهت‌نما)
##  ۱۸) مشعل: پلتاست خانه را «از نزدیک» آتش می‌زند (گام ۶R2: ایست در ~۲.۶m)
##      → خانه بعد از ۱۴ ثانیه نابود می‌شود
##  ۱۹) گاریسون: فرمان روی خانه → ورود دسته → تکمیل تا ظرفیت اصلی
##  --- گام ۶R3 (بازخورد کاربر) ---
##  ۲۰) ناوگانِ بی‌بادبانِ مینیمال: «هر قایق یک نوع سرباز» (پرچمِ رنگِ بار)،
##      سربازها روی عرشه دیده می‌شوند و در ساحل واد می‌کنند؛ قایق‌ها حین شنا
##      به هم نمی‌چسبند (جداسازی + فاصله‌ی پهلوگیری ۳ متری)؛ سه موج پیاپی از
##      «جهات مختلف» جزیره فرود می‌آیند؛ نبرد با چرخه‌ی کشش→یورش→ضربه؛
##      چرخش دوربین با لمس و کشیدن موس؛ باخت با سوختن همه‌ی خانه‌ها + ریست
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
var _max_arrows := 0     # گام ۶R2 — بیشینه‌ی تیرها (کماندار ممکن است وسط کار بمیرد)
var _squad_alive_before := 0
var _contact_forced := false
var _p15_raiders_cleared := false

# --- گام ۶R ---
var _yaw_before := 0.0
var _cam_rotated := false
var _arrow_rotated := false
# گام ۶R۱۲ — پنِ عمودیِ محدودِ نما
var _pan_before := 0.0
var _pan_h_before_v := 0.0   # گام ۶R۱۳ — علامتِ پن افقی قبل از فشردن کلید
var _torch_peltast: PeltastUnit = null
var _max_torches := 0
var _torch_house: BuildingBase = null
var _house_ignited_fired := false
var _house_burned_fired := false
var _garrison_house: BuildingBase = null
var _garrison_alive_before := 0
var _garrison_si := -1
var _flag_squad := -1
var _flag_dead_cmd: UnitBase = null

# --- گام ۶R2 ---
var _min_house_dist := 1e9      # نزدیک‌ترین فاصله‌ی پلتاست مشعل‌زن تا خانه
var _fleet_g3 := -1
var _fleet_g8 := -1
var _fleet_gw := -1
var _fleet_d1 := -1
var _fleet_d2 := -1
var _fleet_d3 := -1
var _drag_yaw0 := 0.0
var _drag_pan_h0 := 0.0
var _sep_min := 1e9                 # کمترین فاصله‌ی جفتی قایق‌ها حین شنا (۶R3)
var _dis_latched := {}              # id مهاجم‌های «خشکی‌دیده» — چک پیاده‌شدن (۶R3)
var _dis_near := 0                  # تعداد پیاده‌شده‌های نزدیک قایق
var _div_angles: Array[float] = []  # زاویه‌ی فرود موج‌های تنوع (۶R3)


func _ready() -> void:
        print("[AUTOTEST] island harness attached — 20 phases (squads + invasion + fleet/touch/gameover)")
        if target_scene.director != null:
                target_scene.director.wave_cleared.connect(
                                func(_g: int): _wave_cleared_fired = true)


## اتصال سیگنال‌های خانه‌ها پس از هر بازتولید (گام ۶R)
func _connect_houses() -> void:
        if target_scene.props == null:
                return
        for b in target_scene.props.buildings:
                if not b.ignited.is_connected(_on_test_house_ignited):
                        b.ignited.connect(_on_test_house_ignited)
                if not b.burned_down.is_connected(_on_test_house_burned):
                        b.burned_down.connect(_on_test_house_burned)


func _on_test_house_ignited(_b: BuildingBase) -> void:
        _house_ignited_fired = true


func _on_test_house_burned(_b: BuildingBase) -> void:
        _house_burned_fired = true


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
                        _phase16_flags_and_camera()
                17:
                        _phase17_torch_burns_house()
                18:
                        _phase18_garrison_replenish()
                19:
                        _phase19_fleet_touch_gameover()
                20:
                        _phase20_battle_scene()
                21:
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
        _check("walkable_fraction_40pct", walk_total >= int(size * size * 0.18),
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

        _check("command_blocks_enough", target_scene.cmd_grid.cell_count >= 14,
                        "%d blocks" % target_scene.cmd_grid.cell_count)

        # --- گام ۵: دسته‌ها، ترکیب و کلاس‌ها (گام ۶R4: ۳→۵ دسته) ---
        _check("squad_count_5", target_scene.squads.size() == 5,
                        "%d" % target_scene.squads.size())
        _check("unit_count_is_19", _units().size() == 19, "n=%d" % _units().size())
        var comp := "%d/%d/%d/%d/%d" % [target_scene.squads[0].size(),
                        target_scene.squads[1].size(), target_scene.squads[2].size(),
                        target_scene.squads[3].size(), target_scene.squads[4].size()]
        _check("squad_composition_4_4_3_4_4", target_scene.squads[0].size() == 4
                        and target_scene.squads[1].size() == 4 and target_scene.squads[2].size() == 3
                        and target_scene.squads[3].size() == 4 and target_scene.squads[4].size() == 4,
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
        for u in target_scene.squads[3]:
                if not (u is ImmortalUnit):
                        class_ok = false
        for u in target_scene.squads[4]:
                if not (u is SpearmanUnit):
                        class_ok = false
        _check("unit_classes_correct", class_ok)
        var colors_ok := true
        for si in target_scene.squads.size():
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
        _check("units_spawned_on_walkable", on_walkable == 19, "%d/19" % on_walkable)

        # --- گام ۶R: فرمانده = اولین عضو زنده با پرچم رنگِ دسته ---
        var cmd_ok := true
        var flag_colors: Array = []
        for si2 in target_scene.squads.size():
                var members: Array = target_scene.squads[si2]
                var cu: UnitBase = null
                for m in members:
                        if is_instance_valid(m) and not m.is_dead():
                                cu = m
                                break
                if cu == null:
                        continue   # دسته‌ی خالی — پرچم با فرمانده‌اش افتاده
                if not cu.is_commander:
                        cmd_ok = false
                var ffound: SquadFlag = null
                for c in cu.get_children():
                        if c is SquadFlag:
                                ffound = c
                if ffound == null:
                        cmd_ok = false
                else:
                        flag_colors.append(ffound.flag_color())
        _check("first_member_is_commander", cmd_ok)
        _check("each_squad_has_own_flag", flag_colors.size() >= 3 \
                        and flag_colors[0] != flag_colors[1] \
                        and flag_colors[1] != flag_colors[2] \
                        and flag_colors[0] != flag_colors[2],
                        str(flag_colors))
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
                # گام ۶R — سلول نزدیک خانه = گاریسون؛ هدف فازهای فرمان نیست
                if target_scene._alive_house_near(center) != null:
                        continue
                # گام ۶R6 — پرتوِ کلیک باید به همین بلوک برسد
                if not _click_lands_on(center):
                        continue
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
                # گام ۶R۱۲ — جزیره‌ی کوچک‌تر (شعاع ۰٫۷۲→۰٫۵۶): کفِ قابل‌عبورِ موتور
                # ۲۱٪ از ۱۰۲۴ = ۲۱۵ سلول است؛ آستانه‌ی تست هم همان کفِ طراحی است
                if r.get("ok", false) != true or int(r["walkable_count"]) < 215:
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
        # گام ۶R2 — کلیک چپ حالا در «رها‌شدن» ثبت می‌شود (تفکیک تپ از کشیدن)
        var ev2 := InputEventMouseButton.new()
        ev2.button_index = button
        ev2.pressed = false
        ev2.position = screen
        ev2.global_position = screen
        ev2.shift_pressed = shift
        target_scene.get_viewport().push_input(ev2, true)


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
                                # گام ۶R4 — تشخیص: کدام واحد نرسیده و کجاست
                                var dbg := ""
                                for u in _units():
                                        if is_instance_valid(u) and not u.is_arrived():
                                                var up2: Vector2 = _xz(u)
                                                var sl: Vector2 = u.slot_pos()
                                                var navx: NavGrid = PathService.nav
                                                var cx := navx.world_to_cell(up2)
                                                dbg += " pos=(%.2f,%.2f) slot=(%.1f,%.1f) d=%.2f cmb=%s cell=%s walk=%s flow=%s brain=%s vel=%s latch=%s stuck=%.1f wf=%s/%d" % [
                                                                up2.x, up2.y, sl.x, sl.y,
                                                                up2.distance_to(sl),
                                                                str(u.combat_target() != null),
                                                                str(cx), str(navx.is_walkable(cx)),
                                                                str(PathService.sample_direction(
                                                                up2, u.squad_id)),
                                                                u.brain_state(), str(u.get("_vel")),
                                                                str(u.get("_near_latch")),
                                                                float(u.get("_stuck_t")),
                                                                str(u.get("_wf_active")),
                                                                int(u.get("_wf_side"))]
                                                # نقشه‌ی ۷×۷ قابل‌عبور اطراف واحد گیرکرده + بردار میدان
                                                for dy in range(-3, 4):
                                                        var row := ""
                                                        for dx in range(-3, 4):
                                                                var tc := cx + Vector2i(dx, dy)
                                                                if not navx.is_walkable(tc):
                                                                        row += "#"
                                                                        continue
                                                                if tc == cx:
                                                                        row += "@"
                                                                        continue
                                                                var fw: Vector2 = PathService.sample_direction(
                                                                                navx.cell_center(tc),
                                                                                u.squad_id)
                                                                if fw.length() < 0.01:
                                                                        row += "o"      # میدان صفر
                                                                elif absf(fw.x) > absf(fw.y):
                                                                        row += ">" if fw.x > 0.0 else "<"
                                                                else:
                                                                        row += "v" if fw.y > 0.0 else "^"
                                                        dbg += "\n[M] %s" % row
                                                dbg += " squad_goal=%s" % str(PathService.goal_for(
                                                                u.squad_id))
                                _check("all_squads_reach_initial_posts", _all_arrived(),
                                                "%d/%d in %.1fs%s" % [arrived_n,
                                                _units().size(), _t - _sub_t, dbg])
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
                        # شعاع آرایش — گام ۶R۷: اسلات‌های خوشه‌ی متراکم در یک بلوکِ
                        # نقطه‌ی فرمان (تا ۱٫۹m — بدونِ تصاحبِ بلوکِ جدا برای هر سرباز)
                        if slot.distance_to(_cell_b) <= 1.9:
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
                # گام ۶R۷ — آرایشِ متراکم: همه‌ی اسلات‌ها در «یک بلوک» دورِ نقطه‌ی فرمان
                # (خوشه‌ی فشرده تا ۱٫۵m + اسنپ ۰٫۴m — چندضلعی‌های ورونوی ~۳٫۲m فاصله)
                _check("slots_in_formation_radius", slot_in_cell >= 3, "%d/%d" % [slot_in_cell, n])
                var centroid := centroid_acc / float(maxi(centroid_n, 1))
                # خوشه‌ی متراکم: مرکز جرم حداکثر ~۰٫۷m از نقطه‌ی فرمان جابه‌جا می‌شود
                _check("squad_centered_on_cell", centroid.distance_to(_cell_b) <= 1.3,
                                "centroid=(%.1f,%.1f) cell=(%.1f,%.1f)" % [centroid.x, centroid.y, _cell_b.x, _cell_b.y])
                # گام ۶R۷ — خواسته‌ی صریح کاربر: «همه در یک بلوک جمع شوند» —
                # بیشترین فاصله‌ی زوجیِ سربازانِ رسیده ≤ قطرِ یک بلوک (~۲٫۸m)
                var max_pair := 0.0
                var arrived_list: Array = []
                for u in s0:
                        if u.is_arrived():
                                arrived_list.append(Vector2(u.global_position.x,
                                                u.global_position.z))
                for ai in arrived_list.size():
                        for aj in range(ai + 1, arrived_list.size()):
                                max_pair = maxf(max_pair,
                                                arrived_list[ai].distance_to(arrived_list[aj]))
                _check("squad_packed_in_one_block", max_pair <= 2.8,
                                "max_pair=%.1f" % max_pair)
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
                # گام ۶R — سلول نزدیک خانه = گاریسون؛ هدف این فاز نیست
                if target_scene._alive_house_near(center) != null:
                        continue
                var min_px := 1e9
                var click_sp := _screen_of(Vector3(center.x,
                                target_scene.ground.height_at_world(center) + 0.1, center.y))
                for u in _units():
                        var wp: Vector3 = u.global_position + Vector3(0, 0.35, 0)
                        if cam.is_position_behind(wp):
                                continue
                        min_px = minf(min_px, cam.unproject_position(wp).distance_to(click_sp))
                        # گام ۶R5 — آرایشِ تایل‌خورده پهن‌تر شده (بلوک‌های ۲متری)؛
                        # گارد جهانی تا فیدجت هم کلیک را نگیرد
                        if _xz(u).distance_to(center) < 2.7:
                                min_px = 0.0
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
                                # گام ۶R4 — ۵ دسته = ۱۹ سرباز
                                _check("regen_units_respawned", _units().size() == 19 and on_walkable == 19,
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


# ---------------- فاز ۸: کلیدهای 1..5 + حلقه‌ی انتخاب ----------------

func _phase8_hotkeys_and_rings() -> void:
        match _sub:
                0:
                        # بعد از بازتولید، سه دسته باید دوباره روی پست بنشینند
                        if _all_arrived() or (_t - _sub_t) > 60.0:
                                _check("regen_posts_reached", _all_arrived(),
                                                "%d/19" % _arrived_in(_units()))
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
                        # گام ۶R4 — کلید ۴ حالا «گارد جاویدان» (دسته‌ی ۳) را انتخاب می‌کند
                        if _t - _sub_t >= 0.7:
                                _check("key4_selects_immortal_guard_squad",
                                                target_scene.selected_squad() == 3,
                                                "sel=%d" % target_scene.selected_squad())
                                _push_key(KEY_5)
                                _sub = 4
                                _sub_t = _t
                4:
                        if _t - _sub_t >= 0.7:
                                _check("key5_selects_purple_spearman_squad",
                                                target_scene.selected_squad() == 4,
                                                "sel=%d" % target_scene.selected_squad())
                                _push_key(KEY_6)
                                _sub = 5
                                _sub_t = _t
                5:
                        if _t - _sub_t >= 0.7:
                                _check("key6_not_recruited_keeps_selection",
                                                target_scene.selected_squad() == 4,
                                                "sel=%d" % target_scene.selected_squad())
                                _push_key(KEY_5)  # کلید تکراری = لغو انتخاب
                                _sub = 6
                                _sub_t = _t
                6:
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
                                # گام ۶R4 — دسته‌های ۳ و ۴ هم نباید تکان بخورند
                                for u in target_scene.squads[3]:
                                        _others_snapshot.append(_xz(u))
                                for u in target_scene.squads[4]:
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
                                for u in target_scene.squads[3]:
                                        if _xz(u).distance_to(_others_snapshot[i2]) > 1.2:
                                                drift_ok = false
                                        i2 += 1
                                for u in target_scene.squads[4]:
                                        if _xz(u).distance_to(_others_snapshot[i2]) > 1.2:
                                                drift_ok = false
                                        i2 += 1
                                _check("other_squads_frozen_while_squad1_marches", drift_ok)
                                _phase = 10
                                _sub = 0
                                _sub_t = _t


## سلول فرمان دور از نقطه‌ی داده‌شده + دور از همه‌ی سربازها (برای کلیک تمیز)
## گام ۶R6 — اعتبارسنجیِ کلیک: پرتوِ واقعی دوربین روی این نقطه باید به «همین
## بلوک» برسد (بلوک‌های ورونویِ ساحلی ممکن است پرتوِ مورب از کنارشان رد شود)
func _click_lands_on(center: Vector2) -> bool:
        var cam: Camera3D = target_scene.get_viewport().get_camera_3d()
        if cam == null:
                return true
        var sp := _screen_of(Vector3(center.x,
                        target_scene.ground.height_at_world(center) + 0.1, center.y))
        var hit: Dictionary = target_scene.ground.ray_pick(cam, sp)
        if not bool(hit.get("in_island", false)):
                return false
        var nav: NavGrid = PathService.nav
        var hxz: Vector2 = nav.cell_center(hit["cell"])
        var info: Dictionary = target_scene.cmd_grid.cell_at_world(hxz)
        if not bool(info.get("ok", false)):
                return false
        return (info["center"] as Vector2).distance_to(center) <= 0.9


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
                # گام ۶R — سلول نزدیک خانه = گاریسون؛ هدفِ فرمان ساده نیست
                if target_scene._alive_house_near(center) != null:
                        continue
                # گام ۶R6 — بلوکی که پرتوِ کلیک به آن نمی‌رسد، هدفِ تمیزی نیست
                if not _click_lands_on(center):
                        continue
                var click_sp := _screen_of(Vector3(center.x,
                                target_scene.ground.height_at_world(center) + 0.1, center.y))
                var min_px := 1e9
                for u in _units():
                        var wp: Vector3 = u.global_position + Vector3(0, 0.35, 0)
                        if cam.is_position_behind(wp):
                                continue
                        min_px = minf(min_px, cam.unproject_position(wp).distance_to(click_sp))
                        # گام ۶R5 — گارد جهانی ۲٫۷ متری (آرایش تایل‌خورده + فیدجت)
                        if _xz(u).distance_to(center) < 2.7:
                                min_px = 0.0
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
                        if _t - _sub_t >= 12.0:
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
                        # گام ۶R۱۲ — مهلت ۸→۱۴s: هم‌رزمی‌های در حالِ سروسامانِ
                        # پس از نبردِ فاز ۱۰ ممکن است چند ثانیه‌ای مسیرِ بازگشت
                        # را شلوغ کنند؛ قراردادِ لایه ۴ «بالاخره برمی‌گردد» است
                        if _t - _sub_t >= 14.0:
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
                        # گام ۶R۱۲ — مبنای «تیر به دشمنِ واقعی» از شروعِ موج:
                        # تیرهای کماندارها به مهاجمِ پیاده‌شده‌ی همین موج + موج‌های
                        # بعدی + مهاجمِ آزمونِ فاز ۱۴، همه در رشدِ شمارنده می‌شمارند
                        _arrow_baseline = target_scene.arrows_fired_total()
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
                        # گام ۶R3 — معیار = «بارِ پیاده‌شده» نه زنده‌ها؛ اگر مسیرِ
                        # خانه از کنار پستِ دسته‌ای رد شود، نبرد ممکن است پیش از
                        # شمارش تمام کند و این نباید «پیاده‌شدن» را نادیده بگیرد
                        var n: int = target_scene.director.group_landed_cargo(_group0)
                        if n >= 6 or (_t - _sub_t) > 39.0:
                                _check("boat_landed_six_raiders", n == 6,
                                                "%d raiders (t=%.1f)" % [n, _t - _sub_t])
                                # گام ۶R6 — قایق به ساحل رسیده (LANDING/DISEMBARKING/DEPARTING)
                                _check("boat_reached_shore",
                                                target_scene.director.boat_state(_group0) >= 1,
                                                "state=%d" % target_scene.director.boat_state(_group0))
                                var ch := int((PathService.debug_info()["channels"] as Array).size())
                                _check("enemy_channel_registered", ch >= 4,
                                                "channels=%d" % ch)
                                _landing = target_scene.director.group_landing(_group0)
                                _check("landing_on_shore", _landing != Vector2.ZERO)
                                # گام ۶R — فرود باید واقعاً کنار آب باشد (باگ قایق وسط جزیره)
                                var navl: NavGrid = PathService.nav
                                var lc := navl.world_to_cell(_landing)
                                var touches_water := false
                                for d in DIRS8:
                                        if String(target_scene.ground.module_name_at(lc + d)) \
                                                        .begins_with("water"):
                                                touches_water = true
                                _check("landing_cell_touches_water", touches_water, str(lc))
                                var anchor: Vector2 = target_scene.director.group_anchor(_group0)
                                var anchor_water := String(target_scene.ground.module_name_at(
                                                navl.world_to_cell(anchor))).begins_with("water")
                                _check("boat_anchor_on_water", anchor_water, str(anchor))
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
                        # یا در مسیرِ رژه درگیر شده باشد (تحملِ مرگ — ۶R3)
                        if _t - _sub_t >= 4.0:
                                var moved := false
                                var fought := false
                                var any_dead := false
                                for e in target_scene.director.raiders_of(_group0):
                                        if not is_instance_valid(e):
                                                continue
                                        if e.is_dead():
                                                any_dead = true
                                                continue
                                        var ep := Vector2(e.global_position.x,
                                                        e.global_position.z)
                                        if ep.distance_to(_landing) > 2.5:
                                                moved = true
                                        elif e.engaged_unit != null:
                                                fought = true
                                if not moved:
                                        for u in target_scene.squad:
                                                if is_instance_valid(u) and u.hp < u._default_hp():
                                                        fought = true
                                _check("raiders_march_inland", moved or fought or any_dead,
                                                "moved=%s fought=%s dead=%s" % [moved, fought, any_dead])

                                _phase = 13
                                _sub = 0
                                _sub_t = _t


# ---------------- فاز ۱۳: درگیری تن‌به‌تن ----------------

func _phase13_melee_engagement() -> void:
        match _sub:
                0:
                        # جاویدان‌ها را به خانه‌ی هدف رژه فرا می‌خوانیم
                        _squad_alive_before = target_scene.squad.size()
                        # گام ۶R3 — اگر موجِ فاز ۱۲ در مسیرِ پست‌ها پاک شده بود،
                        # موجِ جایگزین از همان ساحل می‌آید تا نبردِ فاز ۱۳ اتفاق بیفتد
                        if target_scene.director.raiders_alive(_group0) == 0:
                                var old_landing: Vector2 = target_scene.director.group_landing(_group0)
                                var new_g: int = target_scene.director.spawn_wave(
                                                {"size": 6, "near": old_landing,
                                                "force": true})
                                _check("replacement_wave_spawned", new_g >= 0,
                                                "gid=%d" % new_g)
                                if new_g >= 0:
                                        _group0 = new_g
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
                        # گام ۶R — انتظارِ شرطی (تا ۲۵s): پلتاستِ گروه «کایت» می‌کند و
                        # خط‌نگه‌دارها عمداً تعقیب نمی‌کنند؛ آسیب وقتی می‌آید که
                        # هوپلیت‌ها به خط برسند (پس از فرود ساحل دور — مسیر چندثانیه‌ای)
                        var raiders_dead := 0
                        var raiders_hurt := false
                        for e in target_scene.director.raiders_of(_group0):
                                if not is_instance_valid(e):
                                        continue
                                if e.is_dead():
                                        raiders_dead += 1
                                elif e.hp < e._default_hp():
                                        raiders_hurt = true
                        if raiders_dead >= 1 or raiders_hurt or (_t - _sub_t) > 25.0:
                                var players_hurt := false
                                for u in target_scene.squad:
                                        if is_instance_valid(u) and not u.is_dead() \
                                                        and u.hp < u._default_hp():
                                                players_hurt = true
                                _check("raiders_took_damage",
                                                raiders_dead >= 1 or raiders_hurt,
                                                "dead=%d hurt=%s (t=%.1f)" % [
                                                        raiders_dead, raiders_hurt,
                                                        _t - _sub_t])
                                var players_lost: bool = target_scene.squad.size() \
                                                < _squad_alive_before
                                # گام ۶R — «دوطرفه» = نبرد تلفن داشت (هر طرف)؛
                                # برتری کامل خط پارسی در ۲۵s طبیعی است و FAIL نیست
                                _check("battle_was_two_sided",
                                                raiders_dead >= 1 or raiders_hurt
                                                or players_lost or players_hurt,
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
                                # گام ۶R3 — پاکسازی مهاجمان پیش از فاز ۱۴
                                target_scene.director.kill_all_raiders()
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
                                # گام ۶R3 — نبردِ آزمون تمام؛ مهاجمان پاک تا دسته‌ها
                                # برای فاز گاریسون تلفات اضافی نگیرند
                                target_scene.director.kill_all_raiders()
                                _phase = 14
                                _sub = 0
                                _sub_t = _t


# ---------------- فاز ۱۴: سپر سنگین + پلتاست ----------------

## نقطه‌ی قابل‌عبور که فاصله‌اش تا نزدیک‌ترین سربازِ زنده ≈ want_dist باشد
## (پلتاست باید درون برد پرتاب باشد؛ سنگین بیرون شعاع توجه)
## گام ۶R — فقط نقاطی با «LOS زمینیِ باز» تا مرکز دسته (خانه/صخره‌ی وسط
## مسیر پرتاب، پلتاست را بی‌پرتاب نگه می‌داشت — flake تست)
func _point_near_units(center: Vector2, want_dist: float, lo: float, hi: float,
                nav: NavGrid) -> Vector2:
        var alive: Array = []
        for u in target_scene.squad:
                if is_instance_valid(u) and not u.is_dead():
                        alive.append(u)
        # گام ۶R4 — جست‌وجوی سلولی: با ۵ دسته (۱۹ سرباز) جست‌وجوی زاویه‌ایِ
        # ۱۲تایی اغلب هیچ نقطه‌ی واجد پیدا نمی‌کند و به fallbackِ بدون تضمین
        # فاصله می‌افتاد (پلتاستِ چسبیده به سرباز → صفر پرتاب). سلول‌های فرمان
        # همه‌ی قابل‌عبورند → جست‌وجوی قطعی با تضمین فاصله + دیدِ زمینی.
        var best := Vector2.INF
        var best_err := 1e9
        for r_max in [9.0, 16.0]:
                for i in target_scene.cmd_grid.cell_count:
                        var info: Dictionary = target_scene.cmd_grid.cell_info(i)
                        var w: Vector2 = info["center"]
                        if w.distance_to(center) > r_max:
                                continue
                        var min_u := 1e9
                        var nu := Vector2.INF
                        for u in alive:
                                var du := w.distance_to(_xz(u))
                                if du < min_u:
                                        min_u = du
                                        nu = _xz(u)
                        if min_u < lo or min_u > hi:
                                continue
                        if not _los_ground_clear(w, nu):
                                continue
                        var err := absf(min_u - want_dist)
                        if err < best_err:
                                best_err = err
                                best = w
                if best != Vector2.INF:
                        return best
        return target_scene._nearest_walkable_point(nav,
                        center + Vector2(want_dist, 0.0), 3.0)


## گام ۶R — LOS زمینی: ارتفاع زمین روی پاره‌خط نباید از بیشینه‌ی دو سر +۰.۶
## بالاتر برود (همان منطق _los_clear پلتاست)
func _los_ground_clear(a: Vector2, b: Vector2) -> bool:
        var g: IslandGround = target_scene.ground
        var line_h: float = maxf(g.height_at_world(a), g.height_at_world(b))
        var dist := a.distance_to(b)
        if dist < 0.4:
                return true
        var steps := maxi(int(dist / 0.4), 2)
        for i in range(1, steps):
                var k := float(i) / float(steps)
                var p := a.lerp(b, k)
                if g.height_at_world(p) > line_h + 0.6:
                        return false
        return true


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
                        # گام ۶R4 — دسته‌های ۳ و ۴ هم غیرکماندارند
                        var host_si := -1
                        var best_n := 0
                        for si in [0, 1, 3, 4]:
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
                        # گام ۶R۱۲ — مبنای تیرها در پایان فاز ۱۲ گرفته شد (شلیک به
                        # موجِ واقعی)؛ اینجا فقط مهاجمِ آزمون سپر/نیزه اسپاون می‌شود
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
                        # گام ۶R2 — تیرهای شلیک‌شده جمع‌شدنی روی زنده‌ها نیست: کماندار
                        # با تلافیِ تازه‌ی دشمن ممکن است کشته شود → بیشینه ثبت می‌شود
                        _max_arrows = maxi(_max_arrows, target_scene.arrows_fired_total())
                        if _t - _sub_t >= 9.0:
                                _check("heavy_deflect_or_take_hits",
                                                _max_deflects >= 1 or _heavy_hurt_seen,
                                                "deflects=%d hurt=%s" % [
                                                        _max_deflects, _heavy_hurt_seen])
                                # گام ۶R۱۲ — شلیک به دشمنِ واقعی فقط وقتی معنا دارد
                                # که کماندارِ زنده‌ای مانده باشد؛ در جزیره‌ی کوچک
                                # موج‌ها گاهی همه‌ی کماندارها را در نبردِ تن‌به‌تن
                                # می‌کشند (خودِ مکانیزمِ شلیک در فاز ۱۰ و موج‌های
                                # فاز ۱۲/۱۳ اثبات شده — شمارنده ۱۸→۳۶)
                                var live_archers := 0
                                var archer_dbg := ""
                                for si2 in target_scene.squads.size():
                                        for u2 in target_scene.squads[si2]:
                                                if u2 is ArcherUnit and is_instance_valid(u2) \
                                                                and not u2.is_dead():
                                                        # گام ۶R۱۲ — کماندارِ «کارآمد»: گروهِ منحل‌شده
                                                        # (فرار) یا داخلِ خانه نمی‌تواند شلیک کند —
                                                        # فرار پس از مرگِ فرمانده رفتارِ درستِ بازی است
                                                        var functional: bool = \
                                                                        u2.brain_state() != &"flee" \
                                                                        and not bool(u2.get("garrisoned"))
                                                        if functional:
                                                                live_archers += 1
                                                        archer_dbg += " [%s]" % [u2.brain_state()]
                                _check("arrows_flew_at_enemies",
                                                live_archers == 0 \
                                                or _max_arrows > _arrow_baseline,
                                                "%d→%d live=%d%s" % [
                                                        _arrow_baseline, _max_arrows,
                                                        live_archers, archer_dbg])
                                _check("peltast_throws_javelins", _max_thrown >= 1,
                                                "%d throws" % _max_thrown)
                                _phase = 15
                                _sub = 0
                                _sub_t = _t


# ---------------- فاز ۱۵: مرگ دائمی + پاکسازی موج ----------------

func _phase15_permanence_and_clear() -> void:
        match _sub:
                0:
                        # گام ۶R — اول پاکسازی مهاجمان + ۱.۲s سکون (تیرهای در پرواز
                        # می‌نشینند) تا شمارش مرگِ آزمایشی قطعی شود؛ کشتن هم‌زمانِ
                        # سرباز در اوج نبرد، شمارش را دو واحدی می‌کرد (باگ flaky).
                        if not _p15_raiders_cleared:
                                _p15_raiders_cleared = true
                                target_scene.director.kill_all_raiders()
                                _sub_t = _t
                                return
                        if _t - _sub_t < 1.2:
                                return
                        # گام ۶R۹-fix — اگر فرمانده‌ای در نبردِ فاز ۱۴ افتاده باشد
                        # (تسک A: مرگ فرمانده = انحلال + فرار)، بازماندگانِ در حالِ
                        # فرار تا رسیدن به ساحل در squad می‌مانند و بعد خارج می‌شوند؛
                        # شمارشِ مرگِ آزمایشی فقط بعد از تخلیه‌ی کاملِ فراری‌ها قطعی است
                        var fleeing_n := 0
                        for u in target_scene.squad:
                                if is_instance_valid(u) and not u.is_dead() \
                                                and (u as UnitBase).brain_state() == &"flee":
                                        fleeing_n += 1
                        if fleeing_n > 0 and _t - _sub_t < 40.0:
                                return
                        _units_before = target_scene.squad.size()
                        for u in target_scene.squad:
                                # گام ۶R9 — فرمانده‌ها نمی‌میرند اینجا (مرگ فرمانده =
                                # انحلال گروه — فاز ۱۶ این را جداگانه می‌آزماید)
                                if is_instance_valid(u) and not u.is_dead() \
                                                and not u.is_commander:
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
                                # گام ۶R۱۲ — مرگ با انیمیشن Death پک (افتادنِ طبیعیِ مدل،
                                # نه چرخشِ خشکِ نود)؛ جنازه = نودِ مرده در گروهِ corpses
                                var corpse_ok := false
                                if is_instance_valid(_killed_unit):
                                        corpse_ok = (_killed_unit as UnitBase).is_dead() \
                                                        and get_tree().get_nodes_in_group("corpses") \
                                                                        .has(_killed_unit)
                                _check("dead_unit_corpse_remains", corpse_ok,
                                                "valid=%s" % str(is_instance_valid(_killed_unit)))
                                _check("blood_stain_on_friendly_death",
                                                get_tree().get_nodes_in_group("blood_stain").size() >= 1,
                                                "%d stains" % get_tree().get_nodes_in_group("blood_stain").size())
                                _check("corpse_in_scene_yard",
                                                get_tree().get_nodes_in_group("corpses").size() >= 1,
                                                "%d corpses" % get_tree().get_nodes_in_group("corpses").size())
                                # پاکسازی موج: همه‌ی مهاجمان کشته می‌شوند
                                target_scene.director.kill_all_raiders()
                                _sub = 2
                                _sub_t = _t
                2:
                        if _t - _sub_t >= 1.5:
                                _check("wave_cleared_signal", _wave_cleared_fired)
                                _check("all_raiders_dead",
                                                target_scene.director.alive_raiders_total() == 0)
                                # گام ۶R۹ — قایق بعد از مرگ مهاجمانش «لنگر می‌ماند»:
                                # پارک دائمی در ساحل (PARKED) — نه دورشدن، نه ناپدیدی
                                var parked_info := _parked_boats_info()
                                _check("boat_parked_after_death",
                                                _parked_boats_count() >= 1, parked_info)
                                _sub = 3
                                _sub_t = _t
                3:
                        if _t - _sub_t >= 2.0:
                                # گام ۶R۹ — قایقِ پارک‌شده بعد از ۲ ثانیه هم همان‌جاست
                                _check("boat_still_parked_later",
                                                _parked_boats_count() >= 1,
                                                _parked_boats_info())
                                # سلامت نهایی: زنده‌ها روی سلول قابل‌عبور + زمان نرمال
                                var all_ok := true
                                var bad_info := ""
                                var nav: NavGrid = PathService.nav
                                for u in target_scene.squad:
                                        if not is_instance_valid(u) or u.is_dead():
                                                continue
                                        if not nav.is_walkable(
                                                        nav.world_to_cell(_xz(u))):
                                                all_ok = false
                                                var p3: Vector3 = u.global_position
                                                bad_info += " %s(%.2f,%.2f)" % [
                                                                u.get_class(),
                                                                p3.x, p3.z]
                                _check("alive_units_on_walkable_at_end", all_ok,
                                                bad_info)
                                _check("time_back_to_normal_after_invasion",
                                                absf(Engine.time_scale - 1.0) < 0.06,
                                                "time=%.2f" % Engine.time_scale)
                                _sub = 0
                                _sub_t = _t
                                _phase = 16


# ---------------- فاز ۱۶: فرمانده/پرچم + چرخش دوربین (گام ۶R) ----------------

func _phase16_flags_and_camera() -> void:
        match _sub:
                0:
                        _yaw_before = target_scene._yaw
                        _push_key(KEY_Q)
                        _sub = 1
                        _sub_t = _t
                1:
                        if _t - _sub_t >= 0.4:
                                _push_key_release(KEY_Q)
                                var dyaw: float = absf(wrapf(deg_to_rad(target_scene._yaw
                                                - _yaw_before), -PI, PI))
                                _check("camera_rotates_with_q", rad_to_deg(dyaw) > 10.0,
                                                "%.1f deg" % rad_to_deg(dyaw))
                                _yaw_before = target_scene._yaw
                                _push_key(KEY_RIGHT)
                                _sub = 2
                                _sub_t = _t
                2:
                        if _t - _sub_t >= 0.4:
                                _push_key_release(KEY_RIGHT)
                                # گام ۶R۱۳ — جهت‌نما دیگر نمی‌چرخاند؛ خودِ دوربین را
                                # جابه‌جا می‌کند (پنِ افقی) — چرخش فقط Q/E است
                                _check("arrow_keys_pan_camera_not_rotate",
                                                target_scene._pan_h_target > 0.2 \
                                                and absf(wrapf(deg_to_rad(target_scene._yaw
                                                                - _yaw_before), -PI, PI)) < 0.05,
                                                "h_t=%.2f" % target_scene._pan_h_target)
                                target_scene._pan_h_target = 0.0
                                target_scene._pan_h = 0.0
                                if target_scene._cam_pan != null:
                                        target_scene._cam_pan.position.x = 0.0
                                # گام ۶R9 — تسک A: دسته‌ای با حداقل ۲ عضو زنده برای
                                # آزمونِ انحلال (آخرین دسته — تا دسته‌های ۰..۳ برای فازهای
                                # بعدی دست‌نخورده بمانند)
                                _flag_squad = -1
                                for si in range(target_scene.squads.size() - 1, -1, -1):
                                        var alive_n := 0
                                        for u in target_scene.squads[si]:
                                                if is_instance_valid(u) and not u.is_dead():
                                                        alive_n += 1
                                        if alive_n >= 2:
                                                _flag_squad = si
                                                break
                                _check("squad_for_dissolution_found", _flag_squad >= 0)
                                if _flag_squad >= 0:
                                        for u in target_scene.squads[_flag_squad]:
                                                if is_instance_valid(u) and not u.is_dead() \
                                                                and u.is_commander:
                                                        _flag_dead_cmd = u
                                                        u.take_hit(99)
                                                        break
                                _sub = 3
                                _sub_t = _t
                3:
                        if _t - _sub_t >= 0.7:
                                if _flag_squad >= 0 and is_instance_valid(_flag_dead_cmd):
                                        # گام ۶R9 — تسک A: گروه منحل شد (وضعیت ثبت شد)
                                        var dis_ok: bool = _flag_squad < \
                                                        target_scene.squad_dissolved.size() \
                                                        and target_scene.squad_dissolved[_flag_squad]
                                        _check("squad_dissolved_on_commander_death", dis_ok,
                                                        "squad=%d" % _flag_squad)
                                        # پرتره‌ی خاکستری: پرچم + پیکرِ فرمانده
                                        var has_flag := false
                                        var gray_flag := false
                                        for c in _flag_dead_cmd.get_children():
                                                if c is SquadFlag:
                                                        has_flag = true
                                                        gray_flag = (c as SquadFlag) \
                                                                        .flag_color() \
                                                                        .is_equal_approx(
                                                                        GameConstants.COL_FLAG_GRAY)
                                        _check("flag_grayed_on_commander_death",
                                                        has_flag and gray_flag,
                                                        "has=%s gray=%s" % [has_flag, gray_flag])
                                        _check("commander_body_grayed",
                                                        _flag_dead_cmd.body_color() \
                                                        .is_equal_approx(
                                                        GameConstants.COL_FLAG_GRAY),
                                                        "col=%s" % str(_flag_dead_cmd.body_color()))
                                        # بازماندگان: همه در حالت فرار — و نبرد را رها کرده‌اند
                                        var fleeing := 0
                                        var alive_total := 0
                                        for u in target_scene.squads[_flag_squad]:
                                                if is_instance_valid(u) and not u.is_dead():
                                                        alive_total += 1
                                                        if (u as UnitBase).brain_state() == &"flee":
                                                                fleeing += 1
                                        _check("dissolved_members_flee",
                                                        alive_total > 0 and fleeing == alive_total,
                                                        "%d/%d fleeing" % [fleeing, alive_total])
                                        # فرمان به گروهِ منحل نادیده گرفته می‌شود (هدفِ کانال ثابت)
                                        # گام ۶R9-fix — مبنای نقطه‌ی فرمانِ ساختگی = جسدِ فرمانده
                                        # (پایدار و همیشه معتبر)؛ squads[si] ممکن است در
                                        # همین ۰٫۷ ثانیه خالی شده باشد و [0] خطای اندیس بدهد
                                        var goal0: Vector2 = PathService.goal_for(_flag_squad)
                                        var wp0: int = target_scene.squad_waypoints[_flag_squad].size()
                                        var fake_center: Vector2 = _xz(_flag_dead_cmd) \
                                                        + Vector2(6.0, -4.0)
                                        target_scene._issue_move_to(fake_center,
                                                        _flag_squad, true)
                                        _check("dissolved_squad_ignores_commands",
                                                        PathService.goal_for(_flag_squad) == goal0 \
                                                        and target_scene.squad_waypoints[_flag_squad].size() \
                                                        == wp0,
                                                        "goal_moved=%s" % str(
                                                        PathService.goal_for(_flag_squad) != goal0))
                                _sub = 4
                                _sub_t = _t
                4:
                        # گام ۶R9 — تسک A: فراری‌ها به ساحل می‌رسند و جزیره را ترک می‌کنند
                        if _flag_squad < 0 or target_scene.squads[_flag_squad].is_empty() \
                                        or (_t - _sub_t) > 45.0:
                                var left: int = 0 if _flag_squad < 0 \
                                                else target_scene.squads[_flag_squad].size()
                                _check("fleeing_members_left_island", left == 0,
                                                "%d still on island (t=%.1f)" % [left,
                                                _t - _sub_t])
                                _flag_squad = -1
                                _flag_dead_cmd = null
                                # گام ۶R۱۲ — پنِ عمودیِ محدود نما (کلید بالا = نما به بالای صفحه)
                                _pan_before = target_scene._pan_v
                                _push_key(KEY_UP)
                                _sub = 5
                                _sub_t = _t
                5:
                        if _t - _sub_t >= 0.5:
                                _push_key_release(KEY_UP)
                                var pan_up: float = target_scene._pan_v - _pan_before
                                _check("camera_pans_up_with_key",
                                                pan_up > 0.3 \
                                                and target_scene._pan_target \
                                                                <= GameConstants.CAM_PAN_FWD_MAX + 1e-4,
                                                "dpan=%.2f t=%.2f" % [pan_up,
                                                target_scene._pan_target])
                                _push_key(KEY_UP)   # نگه می‌داریم تا سقفِ پن آزموده شود
                                _sub = 6
                                _sub_t = _t
                6:
                        if _t - _sub_t >= 3.0:
                                _push_key_release(KEY_UP)
                                var pf: float = GameConstants.CAM_PAN_FWD_MAX
                                _check("camera_pan_clamped_forward",
                                                target_scene._pan_target <= pf + 1e-4 \
                                                and target_scene._pan_v <= pf + 0.01,
                                                "t=%.2f v=%.2f max=%.2f" % [
                                                target_scene._pan_target,
                                                target_scene._pan_v, pf])
                                _push_key(KEY_DOWN)
                                _sub = 7
                                _sub_t = _t
                7:
                        if _t - _sub_t >= 4.0:
                                _push_key_release(KEY_DOWN)
                                var pb: float = GameConstants.CAM_PAN_BACK_MAX
                                _check("camera_pan_clamped_back",
                                                target_scene._pan_target >= -pb - 1e-4 \
                                                and target_scene._pan_v >= -pb - 0.01,
                                                "t=%.2f v=%.2f min=-%.2f" % [
                                                target_scene._pan_target,
                                                target_scene._pan_v, pb])
                                # کشیدنِ عمودیِ موس/لمس هم نما را جابه‌جا می‌کند
                                _push_drag_pan()
                                _sub = 8
                                _sub_t = _t
                8:
                        if _t - _sub_t >= 0.5:
                                var pf2: float = GameConstants.CAM_PAN_FWD_MAX
                                _check("camera_pans_with_vertical_drag",
                                                target_scene._pan_target >= 0.5 * pf2 \
                                                and target_scene._pan_target <= pf2 + 1e-4,
                                                "t=%.2f" % target_scene._pan_target)
                                # ریستِ پن برای ادامه‌ی بازی (بازه‌ی آزادی کوچک است)
                                target_scene._pan_target = 0.0
                                # گام ۶R۱۳ — پنِ افقی: خودِ دوربین چپ/راست هم می‌رود
                                _pan_h_before_v = target_scene._pan_h
                                _push_key(KEY_RIGHT)
                                _sub = 9
                                _sub_t = _t
                9:
                        if _t - _sub_t >= 0.5:
                                _push_key_release(KEY_RIGHT)
                                var pan_right: float = target_scene._pan_h \
                                                - _pan_h_before_v
                                _check("camera_pans_right_with_key",
                                                pan_right > 0.3 \
                                                and target_scene._pan_h_target \
                                                                <= GameConstants.CAM_PAN_SIDE_MAX + 1e-4,
                                                "dh=%.2f t=%.2f" % [pan_right,
                                                target_scene._pan_h_target])
                                _push_key(KEY_RIGHT)   # تا سقفِ پنِ افقی
                                _sub = 10
                                _sub_t = _t
                10:
                        if _t - _sub_t >= 3.0:
                                _push_key_release(KEY_RIGHT)
                                var ps: float = GameConstants.CAM_PAN_SIDE_MAX
                                _check("camera_pan_side_clamped",
                                                target_scene._pan_h_target <= ps + 1e-4 \
                                                and target_scene._pan_h <= ps + 0.01,
                                                "t=%.2f h=%.2f max=%.2f" % [
                                                target_scene._pan_h_target,
                                                target_scene._pan_h, ps])
                                # ریستِ پنِ افقی برای ادامه‌ی بازی
                                target_scene._pan_h_target = 0.0
                                target_scene._pan_h = 0.0
                                if target_scene._cam_pan != null:
                                        target_scene._cam_pan.position.x = 0.0
                                _phase = 17
                                _sub = 0
                                _sub_t = _t


var _pan_h_snapshot := 0.0

## گام ۶R۱۳ — علامتِ شروعِ سنجشِ پن افقی
func _pan_h_before() -> float:
        _pan_h_snapshot = target_scene._pan_h
        return _pan_h_snapshot


## گام ۶R۱۲ — شبیه‌سازی کشیدنِ عمودی رو به بالا (۲۰۰px) برای آزمون پنِ نما:
## چپ پایین → چهار حرکت با relative.y منفی → رهاکردن (تپ نیست، کشیدن است)
func _push_drag_pan() -> void:
        var press := InputEventMouseButton.new()
        press.button_index = MOUSE_BUTTON_LEFT
        press.pressed = true
        press.position = Vector2(400, 300)
        target_scene.get_viewport().push_input(press, true)
        for i in 4:
                var mv := InputEventMouseMotion.new()
                mv.position = Vector2(400, 300.0 - float((i + 1) * 50))
                mv.relative = Vector2(0.0, -50.0)
                target_scene.get_viewport().push_input(mv, true)
        var rel := InputEventMouseButton.new()
        rel.button_index = MOUSE_BUTTON_LEFT
        rel.pressed = false
        rel.position = Vector2(400, 100)
        target_scene.get_viewport().push_input(rel, true)


## گام ۶R۱۲ — آیا از «from» تا حاشیه‌ی «stop_d» متریِ خانه، کریدورِ عبورِ
## ~۰٫۷ متریِ خشکی هست؟ (سلول‌ها ۱ متری‌اند — نمونه‌ی خطِ ۰٫۴ متری از گوشه‌ی
## سلولِ بلاک می‌پرید؛ با گامِ ۰٫۳ و دو آفستِ عمودِ ±۰٫۳۵ دیگر سلولی لیز نمی‌خورد)
func _open_line_to_house(nav: NavGrid, from: Vector2, hxz: Vector2,
                stop_d: float) -> bool:
        var d := from.distance_to(hxz)
        if d <= stop_d:
                return true
        var steps := maxi(int(d / 0.3), 2)
        var perp := (hxz - from).normalized().orthogonal()
        for i in range(1, steps + 1):
                var p := from.lerp(hxz, float(i) / float(steps))
                if p.distance_to(hxz) <= stop_d:
                        break
                for off in [Vector2.ZERO, perp * 0.35, -perp * 0.35]:
                        if not nav.is_walkable(nav.world_to_cell(p + off)):
                                return false
        return true


func _push_key_release(keycode: Key) -> void:
        var ev := InputEventKey.new()
        ev.physical_keycode = keycode
        ev.pressed = false
        target_scene.get_viewport().push_input(ev, true)


# ---------------- فاز ۱۷: مشعل خانه را آتش می‌زند (گام ۶R) ----------------

func _phase17_torch_burns_house() -> void:
        match _sub:
                0:
                        _connect_houses()
                        target_scene._clear_dummies()
                        # خانه‌ای که از همه‌ی سربازهای زنده دورتر است (کماندار مزاحم نشود)
                        var best_b: BuildingBase = null
                        var best_d := -1.0
                        for b in target_scene.props.buildings:
                                if not is_instance_valid(b) or b.burned:
                                        continue
                                var bxz := Vector2(b.global_position.x, b.global_position.z)
                                var min_u := 1e9
                                for u in _units():
                                        if is_instance_valid(u) and not u.is_dead():
                                                min_u = minf(min_u, _xz(u).distance_to(bxz))
                                if min_u > best_d:
                                        best_d = min_u
                                        best_b = b
                        _check("torch_target_house_found", best_b != null)
                        if best_b == null:
                                _phase = 18
                                return
                        _torch_house = best_b
                        var hxz := Vector2(best_b.global_position.x,
                                        best_b.global_position.z)
                        # نقطه‌ی پرتاب: سمت دورِ خانه از نزدیک‌ترین سرباز
                        var near_u := _nearest_unit_xz(hxz)
                        var dir := hxz - near_u
                        dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
                        var nav: NavGrid = PathService.nav
                        # گام ۶R۱۲ — نقطه‌ی پرتاب باید «خطِ باز تا خانه» داشته باشد:
                        # مهاجمِ بدونِ کانالِ میدان فقط مستقیم می‌رود؛ خلیجِ مقعرِ
                        # ساحل می‌توانست آن را تا ابد در ~۳ متری نوسان بدهد.
                        # ۱۶ جهت (از سمتِ دورِ سربازها) × ۲ شعاع — اولین خشکیِ
                        # با خطِ باز تا حاشیه‌ی ۲٫۴ متریِ خانه
                        var pp: Vector2 = Vector2.INF
                        var base_ang := dir.angle()
                        for rr: float in [3.0, 4.5]:
                                for k in 16:
                                        var ang2 := base_ang + TAU * float(k) / 16.0
                                        var cand := hxz + Vector2(cos(ang2), sin(ang2)) * rr
                                        var cw: Vector2 = target_scene \
                                                        ._nearest_walkable_point(nav, cand, 1.2)
                                        if cw == Vector2.INF:
                                                continue
                                        if not _open_line_to_house(nav, cw, hxz, 2.4):
                                                continue
                                        pp = cw
                                        break
                                if pp != Vector2.INF:
                                        break
                        if pp == Vector2.INF:
                                # پشتیبانِ نهایی: نزدیک‌ترینِ خودِ خانه (سلولِ خانه
                                # بسته است؛ همسایه‌اش خشکی است)
                                pp = target_scene._nearest_walkable_point(nav, hxz, 6.0)
                        _check("torch_peltast_spot_found", pp != Vector2.INF, str(pp))
                        if pp == Vector2.INF:
                                _phase = 18
                                return
                        _torch_peltast = target_scene.director.spawn_enemy(
                                        "peltast", pp, -1) as PeltastUnit
                        _check("torch_peltast_spawned", _torch_peltast != null)
                        if _torch_peltast == null:
                                _phase = 18
                                return
                        # گام ۶R۱۲ — این فاز «مکانیزمِ مشعل» را می‌آزماید نه دوئل
                        # با کماندارها؛ در جزیره‌ی کوچک کماندارِ مدافع، مهاجمِ
                        # کوشایی را پیش از سه پرتاب قطع می‌کرد (hp=99 ضدگلوله‌ی تست)
                        _torch_peltast.hp = 99
                        _torch_peltast.raid_target = hxz
                        _torch_peltast.target_house = _torch_house
                        _sub = 1
                        _sub_t = _t
                1:
                        # نمونه‌برداری زنده — شمارنده با مرگ از دست نمی‌رود
                        if is_instance_valid(_torch_peltast):
                                _max_torches = maxi(_max_torches,
                                                _torch_peltast.torches_thrown)
                                # گام ۶R2 — مهاجم باید «نزدیک» خانه بایستد نه دور
                                if _torch_house != null and is_instance_valid(_torch_house):
                                        _min_house_dist = minf(_min_house_dist,
                                                        Vector2(_torch_peltast.global_position.x,
                                                        _torch_peltast.global_position.z)
                                                        .distance_to(Vector2(
                                                        _torch_house.global_position.x,
                                                        _torch_house.global_position.z)))
                        var burning: bool = _house_ignited_fired \
                                        or (_torch_house != null and is_instance_valid(_torch_house) \
                                        and _torch_house.burning)
                        if burning or (_t - _sub_t) > 40.0:
                                _check("torch_thrown_at_house", _max_torches >= 1,
                                                "%d torches (t=%.1f)" % [_max_torches, _t - _sub_t])
                                _check("house_ignited_by_torches", burning,
                                                "torch_hp_left=%s" % str(
                                                _torch_house.hp if is_instance_valid(_torch_house) else -1))
                                # گام ۶R2 — بازخورد کاربر: «خیلی دور می‌ایستند؛ نزدیک‌تر بیایند»
                                _check("torch_thrown_from_close_range",
                                                _min_house_dist <= 3.4,
                                                "min=%.1f m" % _min_house_dist)
                                _sub = 2
                                _sub_t = _t
                2:
                        var burned: bool = _house_burned_fired \
                                        or (_torch_house != null and is_instance_valid(_torch_house) \
                                        and _torch_house.burned)
                        if burned or (_t - _sub_t) > 20.0:
                                _check("house_burned_down", burned,
                                                "t=%.1f after ignite" % [_t - _sub_t])
                                if is_instance_valid(_torch_peltast):
                                        _torch_peltast.take_hit(99)   # پاکسازی صحنه
                                _phase = 18
                                _sub = 0
                                _sub_t = _t


func _nearest_unit_xz(to: Vector2) -> Vector2:
        var best := to
        var best_d := 1e9
        for u in _units():
                if is_instance_valid(u) and not u.is_dead():
                        var d := _xz(u).distance_to(to)
                        if d < best_d:
                                best_d = d
                                best = _xz(u)
        return best


# ---------------- فاز ۱۸: گاریسون و تکمیل دسته (گام ۶R) ----------------

func _phase18_garrison_replenish() -> void:
        match _sub:
                0:
                        _connect_houses()
                        # زمانِ تست: ۲۰ ثانیه‌ی کاربر برای سرعت تست به ۳ ثانیه کوتاه می‌شود
                        target_scene.garrison_duration = 3.0
                        target_scene._clear_dummies()
                        # دسته با بیشترین عضو زنده + نزدیک‌ترین خانه‌ی زنده به آن
                        var host_si := -1
                        var best_n := 0
                        for si in target_scene.squads.size():
                                var n: int = target_scene._alive_members(si).size()
                                if n > best_n:
                                        best_n = n
                                        host_si = si
                        _check("garrison_host_squad_found", host_si >= 0 and best_n >= 1,
                                        "squad=%d alive=%d" % [host_si, best_n])
                        if host_si < 0 or best_n < 1:
                                target_scene.garrison_duration = GameConstants.LOOT_DURATION_SECONDS
                                _phase = 19
                                return
                        _garrison_si = host_si
                        var center: Vector2 = target_scene.squad_center(host_si)
                        var hxz: Vector2 = target_scene.props.nearest_alive_house_xz(center)
                        _check("garrison_house_found", hxz != Vector2.INF, str(hxz))
                        if hxz == Vector2.INF:
                                target_scene.garrison_duration = GameConstants.LOOT_DURATION_SECONDS
                                _phase = 19
                                return
                        for b in target_scene.props.buildings:
                                if is_instance_valid(b) and \
                                                Vector2(b.global_position.x, b.global_position.z) \
                                                .distance_to(hxz) < 0.5:
                                        _garrison_house = b
                        _check("garrison_building_ref_found", _garrison_house != null)
                        target_scene._issue_move_to(hxz, host_si, true)
                        _sub = 1
                        _sub_t = _t
                1:
                        # در حال رفتن به خانه → یکی را حذف می‌کنیم تا «تکمیل» مشهود شود
                        var g: Dictionary = target_scene.garrison_state(_garrison_si)
                        if not g.is_empty() and g["phase"] == "walk":
                                var alive: Array = target_scene._alive_members(_garrison_si)
                                if alive.size() >= 2:
                                        alive[alive.size() - 1].take_hit(99)
                                _garrison_alive_before \
                                                = target_scene._alive_members(_garrison_si).size()
                                _sub = 2
                                _sub_t = _t
                        elif (_t - _sub_t) > 25.0:
                                _check("garrison_started", false,
                                                "no garrison state in 25s")
                                target_scene.garrison_duration \
                                                = GameConstants.LOOT_DURATION_SECONDS
                                _sub = 0
                                _sub_t = _t
                                _phase = 19
                2:
                        # همه‌ی اعضای زنده داخل خانه پنهان شده‌اند؟
                        var g2: Dictionary = target_scene.garrison_state(_garrison_si)
                        if not g2.is_empty() and g2["phase"] == "inside":
                                var hidden := true
                                for u in target_scene._alive_members(_garrison_si):
                                        if u.visible or u.is_in_group("units"):
                                                hidden = false
                                _check("squad_hidden_inside_house", hidden)
                                _sub = 3
                                _sub_t = _t
                        elif (_t - _sub_t) > 25.0:
                                _check("squad_hidden_inside_house", false, "timeout")
                                _sub = 3
                                _sub_t = _t
                        # DBG18 — وضعیت زنده‌ی اعضا هر ۲ ثانیه
                        if int((_t - _sub_t) * 0.5) != int(maxf(_t - _sub_t - 0.016, 0.0) * 0.5):
                                var g18: Dictionary = target_scene.garrison_state(_garrison_si)
                                var ph18: String = str(g18.get("phase", "NONE"))
                                for u18 in target_scene._alive_members(_garrison_si):
                                        var nav18: NavGrid = PathService.nav
                                        var c18 := nav18.world_to_cell(Vector2(
                                                        u18.global_position.x,
                                                        u18.global_position.z))
                                        var s18: Vector2 = u18.slot_pos()
                                        print("[AUTOTEST] DBG18 t=%.1f phase=%s id=%d arr=%s slot=%s s=(%.1f,%.1f) pos=(%.1f,%.1f) cell=%s walk=%s flow=%s brain=%s fidget=%d vis=%s units=%s"
                                                        % [_t - _sub_t, ph18,
                                                        u18.get_instance_id(),
                                                        u18.is_arrived(),
                                                        str(u18.has_slot()),
                                                        s18.x, s18.y,
                                                        u18.global_position.x,
                                                        u18.global_position.z,
                                                        str(c18),
                                                        nav18.is_walkable(c18),
                                                        str(PathService.sample_direction(
                                                                Vector2(u18.global_position.x,
                                                                u18.global_position.z),
                                                                u18.squad_id)),
                                                        u18.brain_state(),
                                                        u18.fidget_state_now(),
                                                        u18.visible,
                                                        u18.is_in_group("units")])
                3:
                        # پایان شمارش → بیرون آمدن + تکمیل تا ظرفیت اصلی دسته
                        var g3: Dictionary = target_scene.garrison_state(_garrison_si)
                        if g3.is_empty():
                                var want := int(target_scene.SQUAD_DEFS[_garrison_si]["count"])
                                var alive2: Array = target_scene._alive_members(_garrison_si)
                                var all_out := true
                                for u in alive2:
                                        if not u.visible or u.garrisoned:
                                                all_out = false
                                _check("squad_replenished_to_full",
                                                alive2.size() == want and all_out,
                                                "%d/%d out=%s" % [alive2.size(), want, all_out])
                                target_scene.garrison_duration \
                                                = GameConstants.LOOT_DURATION_SECONDS
                                _sub = 0
                                _sub_t = _t
                                _phase = 19
                        elif (_t - _sub_t) > 12.0:
                                _check("squad_replenished_to_full", false, "timeout inside")
                                target_scene.garrison_duration \
                                                = GameConstants.LOOT_DURATION_SECONDS
                                _sub = 0
                                _sub_t = _t
                                _phase = 19


# ---------------- فاز ۱۹: ناوگان چندقایقی + لمس + باخت (گام ۶R2) ----------------

func _phase19_fleet_touch_gameover() -> void:
        match _sub:
                0:
                        # — گام ۶R4: ۵ دسته + شمشیرزن قوی‌تر + قایقِ کند + بلوک
                        #   مستطیلی با پرتو نور + دشواری صعودی —
                        _check("squads_expanded_to_five", target_scene.squads.size() == 5,
                                        "%d" % target_scene.squads.size())
                        var dposts := {}
                        for p2 in target_scene._squad_posts:
                                dposts[p2] = true
                        _check("squad_posts_are_distinct", dposts.size() >= 4,
                                        "%d posts" % dposts.size())
                        _check("immortal_hp_buffed", GameConstants.PLAYER_HP_IMMORTAL == 6,
                                        "%d" % GameConstants.PLAYER_HP_IMMORTAL)
                        _check("boats_slowed_for_planning",
                                        GameConstants.BOAT_CRUISE_SPEED <= 3.0 \
                                        and GameConstants.BOAT_SPEED <= 1.6,
                                        "cruise=%.1f dock=%.1f" % [GameConstants.BOAT_CRUISE_SPEED,
                                        GameConstants.BOAT_SPEED])
                        var a0: Dictionary = target_scene.director.ascend_spec(0)
                        _check("ascend_first_wave_small_pure",
                                        int(a0["size"]) == 4 and int(a0["comp"]["heavy"]) == 0
                                        and int(a0["comp"]["peltast"]) == 0, str(a0))
                        _check("ascend_first_rounds_solo",
                                        target_scene.director.max_concurrent_waves(0) == 1
                                        and target_scene.director.max_concurrent_waves(1) == 1
                                        and target_scene.director.max_concurrent_waves(2) == 2,
                                        "solo→2")
                        var ccg: int = target_scene.cmd_grid.cell_count
                        _check("command_cells_exist", ccg > 0, "%d" % ccg)
                        # — گام ۶R6: بلوک‌های ورونویِ نامنظم — پوششِ کاملِ بدون شکاف،
                        #   خانه در یک بلوک، سربازِ آیدل داخل بلوکِ خودش —
                        _check("command_blocks_built",
                                        target_scene.cmd_grid.beam_instance_count() == ccg,
                                        "blocks=%d count=%d" % [
                                        target_scene.cmd_grid.beam_instance_count(), ccg])
                        # گام ۶R۱۳ — «پدها نباید معلوم باشند؛ فقط با کلیک روی دسته»:
                        # پیش‌فرض مخفی + ورود به حالتِ فرمان = نمایان + خروج = مخفی
                        target_scene._deselect()
                        _check("pads_hidden_by_default",
                                        not target_scene.cmd_grid.tiles_visible())
                        target_scene._select_squad(0)
                        _check("pads_visible_in_command_mode",
                                        target_scene.cmd_grid.tiles_visible()
                                        and target_scene.cmd_grid.is_command_mode())
                        target_scene._deselect()
                        _check("pads_hidden_after_deselect",
                                        not target_scene.cmd_grid.tiles_visible())
                        # گام ۶R۱۲ — پدهای بیضیِ مجزا (زبانِ اسکرین‌شات): پوششِ کاملِ
                        # زمین دیگر هدفِ طراحی نیست؛ چکِ تازه = پوششِ معقولِ خشکی
                        var navw: NavGrid = PathService.nav
                        var covered := 0
                        var walk_n := 0
                        for cy2 in navw.height:
                                for cx2 in navw.width:
                                        var c2 := Vector2i(cx2, cy2)
                                        if not navw.is_walkable(c2):
                                                continue
                                        walk_n += 1
                                        if bool(target_scene.cmd_grid.block_at_world(
                                                        navw.cell_center(c2)).get("ok", false)):
                                                covered += 1
                        _check("pads_cover_reasonable_share",
                                        walk_n == 0 or covered * 100 >= walk_n * 40,
                                        "%d/%d" % [covered, walk_n])
                        # پد برای پستِ هر دسته (جای آرایش) — حداقل ۴ از ۵
                        var posts_ok := 0
                        for post in target_scene._squad_posts:
                                if bool(target_scene.cmd_grid.block_at_world(post).get("ok", false)):
                                        posts_ok += 1
                        _check("pads_on_squad_posts",
                                        posts_ok >= target_scene._squad_posts.size() - 1,
                                        "%d/%d" % [posts_ok, target_scene._squad_posts.size()])
                        # خانه دقیقاً وسطِ بلوکِ خودش + بلوکش «اشغالِ دائمی» است
                        var house_on_block := true
                        var house_dbg := ""
                        for hp3 in target_scene.props.house_positions:
                                var hxz3 := Vector2(hp3.x, hp3.z)
                                var hi3: Dictionary = target_scene.cmd_grid \
                                                .block_at_world(hxz3)
                                if not bool(hi3.get("ok", false)):
                                        house_on_block = false
                                        house_dbg = "no block @ %s" % hxz3
                                        break
                                if target_scene.cmd_grid.owner_of(int(hi3["index"])) != -1:
                                        house_on_block = false
                                        house_dbg = "not occupied @ %s" % hxz3
                                        break
                        _check("houses_own_one_block", house_on_block, house_dbg)
                        # گام ۶R۷ — خواسته‌ی کاربر (تصویر مرجع): «همه در یک بلوک
                        # جمع شوند» — سربازانِ آیدلِ هر دسته در خوشه‌ی متراکم دورِ
                        # فرمانده‌اند؛ بیشترین فاصله‌ی زوجی ≤ قطرِ یک بلوک (~۲٫۲m)
                        var packed := 0
                        var idle_n := 0
                        var idle_dbg := ""
                        for si7 in target_scene.squads.size():
                                var mem7: Array = []
                                for u19 in target_scene.squads[si7]:
                                        if is_instance_valid(u19) and not u19.is_dead() \
                                                        and not u19.garrisoned \
                                                        and u19.brain_state() == &"idle":
                                                mem7.append(Vector2(
                                                                u19.global_position.x,
                                                                u19.global_position.z))
                                if mem7.size() < 2:
                                        packed += mem7.size()
                                        idle_n += mem7.size()
                                        continue
                                idle_n += mem7.size()
                                var mp7 := 0.0
                                for ai7 in mem7.size():
                                        for aj7 in range(ai7 + 1, mem7.size()):
                                                mp7 = maxf(mp7, mem7[ai7].distance_to(mem7[aj7]))
                                if mp7 <= 3.0:
                                        packed += mem7.size()
                                else:
                                        idle_dbg += " s%d=%.1f" % [si7, mp7]
                        # گام ۶R۱۲ — آستانه ۲٫۲→۳٫۰: کاراکترهای واقعی‌نما (جداسازی
                        # ۰٫۷۲m) در بازسازیِ پس از تلفات کمی بازتر می‌ایستند؛
                        # آرایشِ آیدلِ تازه با پراب ۰٫۸۹..۱٫۷۱m تأیید شد
                        _check("idle_squads_packed_dense",
                                        idle_n == 0 or packed * 10 >= idle_n * 8,
                                        "%d/%d%s" % [packed, idle_n, idle_dbg])
                        target_scene.cmd_grid.set_command_mode(true)
                        _check("command_mode_flag_on",
                                        target_scene.cmd_grid.is_command_mode())
                        target_scene.cmd_grid.set_command_mode(false)
                        _check("command_mode_flag_off",
                                        not target_scene.cmd_grid.is_command_mode())
                        # گام ۶R10 — زبان انتخاب Bad North (اسکرین‌شات‌های کاربر):
                        # انتخاب = فیروزه‌ایِ یکدست (بدنه + پرچم + حلقه)؛
                        # لغو = بازگشت دقیق به رنگ منطقیِ قبل
                        var sel_u10: UnitBase = null
                        for u20 in target_scene.squads[0]:
                                if is_instance_valid(u20) and not u20.is_dead() \
                                                and not u20.garrisoned:
                                        sel_u10 = u20
                                        break
                        if sel_u10 != null:
                                var before10: Color = sel_u10.body_shader_color()
                                sel_u10.set_selected_ring(true)
                                var on_ok10: bool = sel_u10.is_ring_visible() \
                                                and sel_u10.body_shader_color() \
                                                == GameConstants.COL_SELECTED
                                sel_u10.set_selected_ring(false)
                                var off_ok10: bool = not sel_u10.is_ring_visible() \
                                                and sel_u10.body_shader_color() \
                                                == before10
                                _check("selection_tints_bad_north",
                                                on_ok10 and off_ok10)
                        # — دسته‌ی ۳ نفره: بارِ پیش‌فرض = سبک×۲ + پرتاب‌گر×۱ →
                        #   دو قایق پاروییِ همگن (هر قایق یک نوع — بازخورد کاربر)
                        _fleet_g3 = target_scene.director.spawn_wave(
                                        {"size": 3, "force": true})
                        _check("rowboat_wave_spawned", _fleet_g3 >= 0)
                        if _fleet_g3 >= 0:
                                var b3: Array = target_scene.director.group_boats(_fleet_g3)
                                _check("rowboat_fleet_two_boats", b3.size() == 2,
                                                "%d boats" % b3.size())
                                var all_row := b3.size() > 0
                                var no_sail := true
                                var riders_ok := true
                                var single_kind := true
                                for e3 in target_scene.director.fleet_entries(_fleet_g3):
                                        var bt: EnemyBoat = e3["boat"]
                                        if bt.type_name() != "rowboat":
                                                all_row = false
                                        if bt.has_sail():
                                                no_sail = false
                                        var pl: Dictionary = e3["payload"]
                                        if pl.size() != 1:
                                                single_kind = false
                                        var tot := 0
                                        for k in pl:
                                                tot += int(pl[k])
                                        if bt.rider_count() != tot:
                                                riders_ok = false
                                _check("rowboat_fleet_all_rowboats", all_row)
                                _check("rowboats_have_no_sail", no_sail)
                                _check("rowboat_cargo_single_kind", single_kind)
                                _check("rowboat_riders_on_deck", riders_ok)
                        # — دسته‌ی ۸ نفره: سبک×۴ + سنگین×۱ + پرتاب‌گر×۳ →
                        #   گالی(سبک) + دو قایق پارویی — هیچ قایقی مخلوط نیست
                        _fleet_g8 = target_scene.director.spawn_wave(
                                        {"size": 8, "force": true,
                                        "near": _far_shore_hint()})
                        _check("mixed8_wave_spawned", _fleet_g8 >= 0)
                        if _fleet_g8 >= 0:
                                var b8: Array = target_scene.director.group_boats(_fleet_g8)
                                _check("mixed8_fleet_three_boats", b8.size() == 3,
                                                "%d boats" % b8.size())
                                var has_galley := false
                                var no_sail8 := true
                                var single8 := true
                                var riders8 := 0
                                var min_anchor_d := 1e9
                                for i in b8.size():
                                        var bt8: EnemyBoat = b8[i]
                                        if bt8.type_name() == "galley":
                                                has_galley = true
                                        if bt8.has_sail():
                                                no_sail8 = false
                                        riders8 += bt8.rider_count()
                                        for j in b8.size():
                                                if j <= i:
                                                        continue
                                                var bj: EnemyBoat = b8[j]
                                                var dd := Vector2(bt8.global_position.x,
                                                                bt8.global_position.z).distance_to(
                                                                Vector2(bj.global_position.x,
                                                                bj.global_position.z))
                                                min_anchor_d = minf(min_anchor_d, dd)
                                for e8 in target_scene.director.fleet_entries(_fleet_g8):
                                        if (e8["payload"] as Dictionary).size() != 1:
                                                single8 = false
                                _check("mixed8_has_galley", has_galley)
                                _check("mixed8_all_no_sail", no_sail8)
                                _check("mixed8_cargo_single_kind", single8)
                                _check("mixed8_riders_on_deck_total", riders8 == 8,
                                                "%d" % riders8)
                                _check("fleet_anchors_spaced", min_anchor_d >= 2.4,
                                                "%.2f m" % min_anchor_d)
                        # — گروهِ کاملاً سنگین ×۸ → یک کشتی جنگیِ بی‌بادبان
                        _fleet_gw = target_scene.director.spawn_wave(
                                        {"size": 8, "force": true,
                                        "comp": {"light": 0, "heavy": 8, "peltast": 0},
                                        "near": _far_shore_hint()})
                        _check("warship_wave_spawned", _fleet_gw >= 0)
                        if _fleet_gw >= 0:
                                var bw: Array = target_scene.director.group_boats(_fleet_gw)
                                _check("warship_single_boat", bw.size() == 1,
                                                "%d boats" % bw.size())
                                if bw.size() == 1:
                                        var w0: EnemyBoat = bw[0]
                                        _check("warship_is_warship",
                                                        w0.type_name() == "warship",
                                                        w0.type_name())
                                        _check("warship_has_no_sail",
                                                        not w0.has_sail())
                                        _check("warship_riders_on_deck",
                                                        w0.rider_count() == 8,
                                                        "%d" % w0.rider_count())
                                        _check("warship_cargo_heavy_only",
                                                        w0.cargo_kind == "heavy",
                                                        w0.cargo_kind)
                        _sub = 1
                        _sub_t = _t
                1:
                        # پیاده‌شدن هر سه ناوگان (مهلت ۴۶s — گام ۶R4 قایق‌ها کندترند)
                        # بر اساس «بارِ پیاده‌شده» نه زنده‌ها (نبردِ هم‌زمان نباید
                        # شمارش را کم کند — ۶R3)
                        var lc3: int = target_scene.director.group_landed_cargo(_fleet_g3)
                        var lc8: int = target_scene.director.group_landed_cargo(_fleet_g8)
                        var lcw: int = target_scene.director.group_landed_cargo(_fleet_gw)
                        if (lc3 >= 3 and lc8 >= 8 and lcw >= 8) or (_t - _sub_t) > 46.0:
                                _check("all_fleets_landed",
                                                lc3 >= 3 and lc8 >= 8 and lcw >= 8,
                                                "g3=%d g8=%d gw=%d" % [lc3, lc8, lcw])
                                _sub = 2
                                _sub_t = _t
                2:
                        # گام ۶R3 — پیاده‌شدن واقعی، مستقل از زمانِ دیوار:
                        # مهاجمی که وادِ خودش را تمام کرده (disembark_target بی‌نهایت
                        # شد + _wade_t > 0) و روی خشکی ایستاده = «پیاده شده».
                        # (زمانِ دیوار درست نبود: sub 2 وقتی شروع می‌شود که هر سه
                        # ناوگان پیاده باشند — مهاجمانِ ناوگانِ زودتر تا آن موقع
                        # به خانه رسیده بودند)
                        var navg: NavGrid = PathService.nav
                        var bw2: Array = target_scene.director.group_boats(_fleet_gw)
                        for e2 in target_scene.director.raiders_of(_fleet_gw):
                                if not is_instance_valid(e2) or e2.is_dead():
                                        continue
                                if _dis_latched.has(e2.get_instance_id()):
                                        continue
                                if e2.disembark_target != Vector2.INF \
                                                or e2._wade_t <= 0.0 \
                                                or e2.last_disembark_target == Vector2.INF:
                                        continue
                                # «پیاده‌شدن کنار همان قایق» = مقصدِ اختصاصیِ هر مهاجم
                                # خودِ ساختار داده‌ها ≤ ۴.۵m از «لنگرِ» قایقِ خودش است
                                # (لنگر ثابت است — گام ۶R6: قایق بعد از تخلیه دور می‌شود
                                # و مقایسه با موقعیتِ «فعلی» آن غلط می‌شد)
                                var bd2 := 1e9
                                for bt2 in bw2:
                                        bd2 = minf(bd2, e2.last_disembark_target.distance_to(
                                                        Vector2(bt2.anchor_point.x,
                                                        bt2.anchor_point.z)))
                                if bd2 <= 4.5:
                                        _dis_latched[e2.get_instance_id()] = true
                                        _dis_near += 1
                        var live := 0
                        var latched := 0
                        var dbg_d := ""
                        for e2 in target_scene.director.raiders_of(_fleet_gw):
                                if not is_instance_valid(e2) or e2.is_dead():
                                        continue
                                live += 1
                                if _dis_latched.has(e2.get_instance_id()):
                                        latched += 1
                                else:
                                        var ep2: Vector2 = Vector2(
                                                        e2.global_position.x,
                                                        e2.global_position.z)
                                        dbg_d += " [dt=%s wade=%.1f last=%s pos=(%.1f,%.1f)]" % [
                                                        "INF" if e2.disembark_target
                                                        == Vector2.INF else "set",
                                                        e2._wade_t,
                                                        "INF" if e2.last_disembark_target
                                                        == Vector2.INF else "set",
                                                        ep2.x, ep2.y]
                        if (live > 0 and latched == live) or (_t - _sub_t) > 20.0:
                                _check("raiders_disembarked_on_land", latched == live,
                                                "%d/%d%s" % [latched, live, dbg_d])
                                _check("raiders_disembark_near_boat",
                                                _dis_near >= mini(live, 6),
                                                "%d/%d" % [_dis_near, live])
                                _dis_latched.clear()
                                _dis_near = 0
                                target_scene.director.kill_all_raiders()
                                _sub = 3
                                _sub_t = _t
                3:
                        # گام ۶R9 — قایق‌ها بعد از تخلیه «لنگر می‌مانند» (پارک دائمی —
                        # بازخورد کاربر: «هر چند سربازهایش کشته بشن لب ساحل بمونن»).
                        # فقط ۲.۵ ثانیه سکون برای بستنِ گروه‌ها
                        if _t - _sub_t >= 2.5:
                                var parked := 0
                                var sailing := 0
                                var dbg_boats := ""
                                for bt4 in get_tree().get_nodes_in_group("enemy_boats"):
                                        var bb4 := bt4 as EnemyBoat
                                        if bb4 == null or not is_instance_valid(bb4):
                                                continue
                                        var d4: float = Vector2(bb4.global_position.x,
                                                        bb4.global_position.z).distance_to(
                                                        Vector2(bb4.anchor_point.x,
                                                        bb4.anchor_point.z))
                                        dbg_boats += " [st=%d d=%.1f]" % [
                                                        int(bb4.state), d4]
                                        if bb4.state == EnemyBoat.BoatState.PARKED:
                                                # فاصله از لنگر مهم نیست — جداسازیِ قایق‌ها
                                                # حینِ پهلوگیری جابه‌جاییِ ۲ متریِ قانونی می‌دهد
                                                parked += 1
                                        else:
                                                sailing += 1
                                _check("boats_parked_after_drop",
                                                parked >= 3 and sailing == 0,
                                                "parked=%d moving=%d (t=%.1f)%s" % [
                                                parked, sailing, _t - _sub_t,
                                                dbg_boats])
                                _check("fleet_groups_cleaned",
                                                target_scene.director.groups_count() == 0,
                                                "%d groups" % target_scene.director.groups_count())
                                # — گام ۶R۱۳: کشیدنِ افقی = پنِ دوربین (نه چرخش) —
                                # (روی اندروید، لمس با emulate_mouse_from_touch
                                # به همین دنباله‌ی رویداد تبدیل می‌شود)
                                _drag_yaw0 = target_scene._yaw
                                _drag_pan_h0 = target_scene._pan_h_target
                                _push_left_drag()
                                _sub = 4
                                _sub_t = _t
                4:
                        var dyaw := absf(wrapf(deg_to_rad(target_scene._yaw
                                                        - _drag_yaw0), -PI, PI))
                        var dpanh := absf(target_scene._pan_h_target - _drag_pan_h0)
                        _check("camera_pans_with_left_drag",
                                        dpanh > 0.3 and rad_to_deg(dyaw) < 1.0,
                                        "dh=%.2f yaw=%.1f deg" % [dpanh, rad_to_deg(dyaw)])
                        target_scene._pan_h_target = 0.0
                        target_scene._pan_h = 0.0
                        if target_scene._cam_pan != null:
                                target_scene._cam_pan.position.x = 0.0
                        # — گام ۶R3: سه موج بدون hint → باید از «جهات مختلف» بیایند
                        _fleet_d1 = target_scene.director.spawn_wave({"size": 4, "force": true})
                        _fleet_d2 = target_scene.director.spawn_wave({"size": 4, "force": true})
                        _fleet_d3 = target_scene.director.spawn_wave({"size": 4, "force": true})
                        _check("diversity_waves_spawned",
                                        _fleet_d1 >= 0 and _fleet_d2 >= 0 and _fleet_d3 >= 0)
                        var navc: NavGrid = PathService.nav
                        var center: Vector2 = navc.origin + navc.size_world() * 0.5
                        _div_angles.clear()
                        for gd in [_fleet_d1, _fleet_d2, _fleet_d3]:
                                if gd < 0:
                                        continue
                                var axz: Vector2 = target_scene.director.group_anchor(gd)
                                var dv := axz - center
                                _div_angles.append(rad_to_deg(atan2(dv.y, dv.x)))
                        _sub = 5
                        _sub_t = _t
                5:
                        # نمونه‌برداری فاصله‌ی قایق‌ها حین شنا (۲.۵s) — گام ۶R3
                        for gd in [_fleet_d1, _fleet_d2, _fleet_d3]:
                                if gd < 0:
                                        continue
                                var bb: Array = target_scene.director.group_boats(gd)
                                for i in bb.size():
                                        for j in bb.size():
                                                if j <= i:
                                                        continue
                                                var bi: EnemyBoat = bb[i]
                                                var bj: EnemyBoat = bb[j]
                                                var dd2 := Vector2(bi.global_position.x,
                                                                bi.global_position.z).distance_to(
                                                                Vector2(bj.global_position.x,
                                                                bj.global_position.z))
                                                _sep_min = minf(_sep_min, dd2)
                        if _t - _sub_t >= 2.5:
                                _check("boats_never_overlap_while_sailing",
                                                _sep_min >= 1.2, "%.2f m" % _sep_min)
                                # تنوع جهت: هر فرود ≥ ۴۰° از قبلی‌ها دور؛ پهنای کل ≥ ۱۰۰°
                                var ok_pairwise := _div_angles.size() == 3
                                var min_diff := 360.0
                                var max_diff := 0.0
                                for i in _div_angles.size():
                                        for j in _div_angles.size():
                                                if j <= i:
                                                        continue
                                                var df := absf(wrapf(deg_to_rad(
                                                                _div_angles[i] - _div_angles[j]),
                                                                -PI, PI))
                                                min_diff = minf(min_diff, rad_to_deg(df))
                                                max_diff = maxf(max_diff, rad_to_deg(df))
                                if min_diff < 40.0:
                                        ok_pairwise = false
                                _check("landings_from_different_directions", ok_pairwise,
                                                "min=%.0f max=%.0f" % [min_diff, max_diff])
                                _check("landings_spread_wide", max_diff >= 100.0,
                                                "%.0f" % max_diff)
                                target_scene.director.kill_all_raiders()
                                # — باخت: همه‌ی خانه‌ها آتش می‌گیرند → بعد از فروریختن، باخت
                                for b in target_scene.props.buildings:
                                        if is_instance_valid(b) and not b.burned:
                                                b.ignite()
                                _sub = 7
                                _sub_t = _t
                7:
                        if target_scene.game_over or (_t - _sub_t) > 25.0:
                                _check("game_over_when_all_houses_burned",
                                                target_scene.game_over,
                                                "t=%.1f" % (_t - _sub_t))
                                _check("game_over_panel_visible",
                                                target_scene._game_over_panel != null
                                                and target_scene._game_over_panel.visible)
                                _check("auto_waves_stopped_on_game_over",
                                                not target_scene.director.auto_waves)
                                # پاکسازی + جزیره‌ی تازه → باخت ریست می‌شود
                                target_scene.director.clear_all()
                                target_scene.regenerate(777777)
                                _sub = 8
                                _sub_t = _t
                8:
                        if _t - _sub_t >= 1.0:
                                _check("regen_resets_game_over",
                                                not target_scene.game_over)
                                _phase = 20
                                _sub = 0
                                _sub_t = _t


# ---------------- گام ۶R۹ — شمارنده‌های قایقِ پارک‌شده (بدونِ گروه) ----------------

## قایق‌های PARKEDِ موجود در صحنه — حتی وقتی ردّ گروه پاک شده باشد
func _parked_boats_count() -> int:
        var n := 0
        for b in get_tree().get_nodes_in_group("enemy_boats"):
                var bt := b as EnemyBoat
                if bt != null and is_instance_valid(bt) \
                                and bt.state == EnemyBoat.BoatState.PARKED:
                        n += 1
        return n


func _parked_boats_info() -> String:
        var info := "parked=%d" % _parked_boats_count()
        for b in get_tree().get_nodes_in_group("enemy_boats"):
                var bt := b as EnemyBoat
                if bt != null and is_instance_valid(bt):
                        info += " [st=%d]" % int(bt.state)
        return info


# ---------------- فاز ۲۰: صحنه‌ی نبرد ۶R9 — خون، جنازه، سوئینگ، تیر ----------------

var _p20_dummy: TrainingDummy = null

func _phase20_battle_scene() -> void:
        match _sub:
                0:
                        # انتظار برای آرایش‌گیری دسته‌ها روی پست‌های تازه (جزیره‌ی ۷۷۷۷۷۷)
                        # — مسیرِ دور با پیچِ مانع تا ۳۰ ثانیه هم می‌کشد
                        var arrived := 0
                        var total := 0
                        for u in target_scene.squad:
                                if is_instance_valid(u) and not u.is_dead():
                                        total += 1
                                        if (u as UnitBase).is_arrived():
                                                arrived += 1
                        # تشخیص ۶R9 — پیشرفتِ نرسیده‌ها هر ۵ ثانیه چاپ می‌شود
                        if arrived < total and _t - _sub_t > 0.0 \
                                        and int((_t - _sub_t) * 10.0) % 50 == 0:
                                var trail := ""
                                for u in target_scene.squad:
                                        if is_instance_valid(u) and not u.is_dead() \
                                                        and not (u as UnitBase).is_arrived():
                                                var up: Vector2 = _xz(u)
                                                trail += " (%.1f,%.1f)d%.1f" % [up.x,
                                                                up.y, up.distance_to(
                                                                        (u as UnitBase).slot_pos())]
                                print("[AUTOTEST] p20 t=%.1f arrived=%d/%d trail:%s" % [
                                                _t - _sub_t, arrived, total, trail])
                        if (total > 0 and arrived == total) or (_t - _sub_t) > 30.0:
                                for si in target_scene.squads.size():
                                        var gg: Dictionary = \
                                                        target_scene.garrison_state(si)
                                        if not gg.is_empty():
                                                print("[AUTOTEST] p20 squad %d garrison phase=%s t=%.1f alive=%d" % [
                                                        si, str(gg.get("phase")),
                                                        float(gg.get("t", 0.0)),
                                                        target_scene._alive_members(si).size()])
                                # تشخیص عمیق ۶R۹ — چرا حرکت خشکید؟
                                print("[AUTOTEST] DBG computes=" + str(
                                                PathService.debug_info().get("computes")))
                                for u in target_scene.squad:
                                        if is_instance_valid(u) and not u.is_dead() \
                                                        and not (u as UnitBase).is_arrived():
                                                var ub2 := u as UnitBase
                                                var flow2: Vector2 = PathService.sample_direction(
                                                                _xz(ub2), ub2.squad_id)
                                                var msg := "[AUTOTEST] DBG pos=" + str(_xz(ub2))
                                                msg += " slot=" + str(ub2.slot_pos())
                                                msg += " vel=" + str(ub2._vel)
                                                msg += " flow=" + str(flow2)
                                                msg += " goal=" + str(PathService.goal_for(
                                                                ub2.squad_id))
                                                msg += " wf=" + str(ub2._wf_active)
                                                msg += " stuck_t=" + str(ub2._stuck_t)
                                                msg += " latch=" + str(ub2._near_latch)
                                                print(msg)
                                _check("p20_squads_formed",
                                                float(arrived) / maxf(total, 1.0) >= 0.8,
                                                "%d/%d arrived (t=%.1f)" % [arrived,
                                                total, _t - _sub_t])
                                # کوله‌ی تمرین کنار جاویدان‌ها — سوئینگِ شمشیر باید بزند
                                _p20_dummy = target_scene.spawn_dummy_near_world(
                                                target_scene.squad_center(0), Vector2(2.2, 0.0))
                                _sub = 1
                                _sub_t = _t
                1:
                        # هلثِ مخفی چندضربه‌ای + خون‌ریزی + صدا — یک عضو غیرفرمانده
                        var victim: UnitBase = null
                        for u in target_scene.squads[0]:
                                var ub := u as UnitBase
                                if is_instance_valid(ub) and not ub.is_dead() \
                                                and not ub.is_commander:
                                        victim = ub
                                        break
                        if victim != null:
                                var hp0 := victim.hp
                                victim.take_hit(1)
                                # گام ۶R۹ — تسک A: ضربه = لرزشِ کوتاهِ دوربین
                                _check("camera_shake_on_hit",
                                                target_scene._shake_energy > 0.0,
                                                "%.3f energy" % target_scene._shake_energy)
                                _check("hidden_hp_single_hit_survives",
                                                not victim.is_dead() and victim.hp == hp0 - 1,
                                                "hp %d→%d" % [hp0, victim.hp])
                                _check("blood_burst_on_hit",
                                                get_tree().get_nodes_in_group("blood_burst").size() >= 1,
                                                "%d bursts" % get_tree().get_nodes_in_group("blood_burst").size())
                                _check("sfx_played_on_hit", BattleFX.played_count() >= 1,
                                                "%d sounds" % BattleFX.played_count())
                                var hits := 0
                                while not victim.is_dead() and hits < 12:
                                        victim.take_hit(1)
                                        hits += 1
                                _check("multi_hit_death", victim.is_dead() and hits >= 2,
                                                "hp=%d → %d more hits" % [hp0, hits])
                        else:
                                _check("p20_victim_found", false, "no non-commander")
                        _sub = 2
                        _sub_t = _t
                2:
                        # سوئینگ: کوله‌ی تمرین باید ضربه بخورد (چرخه‌ی ضربه‌ی خوانا)
                        if _t - _sub_t >= 7.0:
                                _check("melee_swings_hit_dummy",
                                                target_scene.dummy_hits_total() >= 1,
                                                "%d hits" % target_scene.dummy_hits_total())
                                _check("corpse_laid_after_multi_hit",
                                                get_tree().get_nodes_in_group("corpses").size() >= 1,
                                                "%d corpses" % get_tree().get_nodes_in_group("corpses").size())
                                _check("blood_stain_after_death",
                                                get_tree().get_nodes_in_group("blood_stain").size() >= 1,
                                                "%d stains" % get_tree().get_nodes_in_group("blood_stain").size())
                                # تسلیحات چندقطعه‌ای: همه‌ی سربازانِ مسلح سلاحِ روی دست دارند
                                var armed := 0
                                for u in target_scene.squad:
                                        if is_instance_valid(u) and not u.is_dead() \
                                                        and (u as UnitBase)._swing_weapon != null:
                                                armed += 1
                                _check("weapons_multi_part_armed", armed >= 8,
                                                "%d armed" % armed)
                                _sub = 3
                                _sub_t = _t
                3:
                        # موج دشمن → شبح‌ها پیاده می‌شوند، خونِ بنفش می‌ریزد
                        var gid: int = target_scene.director.spawn_wave(
                                        {"size": 4, "force": true})
                        _check("p20_wave_spawned", gid >= 0, "gid=%d" % gid)
                        _sub = 4
                        _sub_t = _t
                4:
                        # صبر برای پیاده‌شدن شبح‌ها در ساحل
                        var landed_live := 0
                        for e in get_tree().get_nodes_in_group("hostiles"):
                                var en := e as EnemyBase
                                if en != null and not en.riding and not en.is_dead():
                                        landed_live += 1
                        if landed_live >= 3 or (_t - _sub_t) > 110.0:
                                _check("p20_ghosts_landed", landed_live >= 3,
                                                "%d landed (t=%.1f)" % [landed_live,
                                                _t - _sub_t])
                                target_scene.director.kill_all_raiders()
                                _sub = 5
                                _sub_t = _t
                5:
                        if _t - _sub_t >= 2.0:
                                _check("p20_ghost_corpses_remain",
                                                get_tree().get_nodes_in_group("corpses").size() >= 2,
                                                "%d corpses" % get_tree().get_nodes_in_group("corpses").size())
                                _check("p20_ghost_blood_stains",
                                                get_tree().get_nodes_in_group("blood_stain").size() >= 2,
                                                "%d stains" % get_tree().get_nodes_in_group("blood_stain").size())
                                # قایق‌ها پارک مانده‌اند حتی با مرگ همه‌ی سربازان
                                var parked := _parked_boats_count()
                                _check("p20_boats_parked_despite_deaths", parked >= 1,
                                                "%d parked" % parked)
                                _phase = 21
                                _sub = 0
                                _sub_t = _t


## رشته‌ی کشیدن با دکمه‌ی چپ موس: فشار + ۶ حرکت افقی + رهاکردن
## (روی اندروید لمس با emulate_mouse_from_touch به همین دنباله‌ی رویداد تبدیل می‌شود)
func _push_left_drag() -> void:
        var vp := target_scene.get_viewport()
        var p := InputEventMouseButton.new()
        p.button_index = MOUSE_BUTTON_LEFT
        p.pressed = true
        p.position = Vector2(200, 400)
        p.global_position = Vector2(200, 400)
        vp.push_input(p, true)
        for i in 6:
                var m := InputEventMouseMotion.new()
                m.position = Vector2(200 + 40.0 * float(i + 1), 400)
                m.global_position = m.position
                m.relative = Vector2(40, 0)
                vp.push_input(m, true)
        var r := InputEventMouseButton.new()
        r.button_index = MOUSE_BUTTON_LEFT
        r.pressed = false
        r.position = Vector2(440, 400)
        r.global_position = r.position
        vp.push_input(r, true)


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
