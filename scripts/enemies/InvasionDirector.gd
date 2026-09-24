class_name InvasionDirector
extends Node
## کارگردان موج هجوم — گام ۶ (§۶ سند طراحی) + گام ۶R2 (بازخورد کاربر)
##
##   * ساحل فرود: سلول ساحلیِ «همسایه‌ی آبِ واقعی» — باگ قبلی همین‌جا بود:
##     هر سلولِ با همسایه‌ی غیرقابل‌عبور (حتی صخره/خانه در دل جزیره) ساحل شمرده
##     می‌شد و قایق وسط جزیره ظاهر می‌شد (بازخورد کاربر گام ۶R)
##   * گام ۶R2 — «هر دسته با قایق‌های مختلف خودش می‌آید؛ بعضی کوچک‌تر و بدون
##     بادبان، بعضی بزرگ‌تر»: هر گروه = یک «ناوگان» — دسته‌های کوچک با قایق
##     پاروییِ بی‌بادبان، متوسط با گالی، بزرگ با کشتی جنگی (گاهی + قایق همراه)
##   * گام ۶R2 — قایق‌ها از دل افق دریا (۳۲ متری) ظاهر می‌شوند و سمت ساحلِ
##     رو به دوربین شنا می‌کنند تا «از گوشه‌ی صفحه» وارد شوند
##   * گام ۶R2 — قایق‌ها هرگز برنمی‌گردند: چه مهاجمان زنده بمانند چه کشته شوند،
##     ناوگان پارک‌شده در ساحل می‌ماند
##   * هر گروه کانال FlowField خودش را دارد (۴..۷)؛ هدف = نزدیک‌ترین خانه‌ی زنده به فرود
##   * اگر خانه‌ی هدف بسوزد → گروه به نزدیک‌ترین خانه‌ی زنده بازهدف‌گیری می‌کند
##   * ترکیب پیش‌فرض: Peltast ≈ ۱/۳ + Hoplite سنگین در گروه‌های ≥ ۶ نفر، بقیه سبک
##   * مرگ سرباز پارسی با GameEvents.unit_permanently_died — اینجا فقط دشمنان

signal wave_started(group_id: int, count: int)
signal wave_cleared(group_id: int)

var ground: IslandGround
var props: IslandProps
var posts: Array[Vector2] = []          # پست دسته‌ها — برای انتخاب ساحل دور
## موقعیت دوربین (XZ جهانی) — ساحلِ «رو به دوربین» انتخاب می‌شود تا قایق از
## گوشه‌ی دید وارد شود (گام ۶R2 — صحنه این Callable را وصل می‌کند)
var cam_xz_provider: Callable = Callable()

var auto_waves := true
var wave_interval := GameConstants.WAVE_INTERVAL
var waves_spawned := 0

var boats_root: Node3D
var raiders_root: Node3D

# group_id -> {"fleet": [{"boat": EnemyBoat, "payload": {}, "landed": bool}],
#              "raiders": Array, "channel": int, "landing": Vector2,
#              "anchor": Vector2, "raid_target": Vector2,
#              "target_building": BuildingBase, "cleared": bool}
var _groups: Dictionary = {}
var _next_group := 0
var _rng := RandomNumberGenerator.new()
var _wave_accum := 0.0
var _check_accum := 0.0

const KIND_LIGHT := "light"
const KIND_HEAVY := "heavy"
const KIND_PELTAST := "peltast"


func _ready() -> void:
        _rng.randomize()
        boats_root = Node3D.new()
        boats_root.name = "EnemyBoats"
        add_child(boats_root)
        raiders_root = Node3D.new()
        raiders_root.name = "EnemyRaiders"
        add_child(raiders_root)


func setup(ground_ref: IslandGround, props_ref: IslandProps,
                squad_posts: Array[Vector2]) -> void:
        ground = ground_ref
        props = props_ref
        posts = squad_posts.duplicate()


func _process(delta: float) -> void:
        _check_accum += delta
        if _check_accum >= 0.3:
                _check_accum = 0.0
                _check_groups()
        if auto_waves:
                _wave_accum += delta
                if _wave_accum >= wave_interval:
                        _wave_accum = 0.0
                        spawn_wave()


# ---------------- موج هجوم ----------------

## گزینه‌ها: {"size": int, "near": Vector2, "comp": {"light": n, "heavy": m,
##          "peltast": k}, "force": bool} → group_id (-1 = نشد)
func spawn_wave(opts: Dictionary = {}) -> int:
        var force := bool(opts.get("force", false))
        if not force and waves_active() >= GameConstants.WAVE_MAX_CONCURRENT:
                return -1
        if ground == null or props == null:
                return -1
        var size: int = opts.get("size",
                        _rng.randi_range(GameConstants.WAVE_SIZE_MIN,
                        GameConstants.WAVE_SIZE_MAX))
        var hint: Vector2 = opts.get("near", Vector2.INF)
        var shore := _pick_shore(hint)
        var landing: Vector2 = shore["landing"]
        var water_xz: Vector2 = shore["water"]
        var channel := GameConstants.ENEMY_CHANNEL_BASE + (_next_group % 4)
        var target_building := _nearest_alive_building(landing)
        var raid_target := landing
        if target_building != null:
                raid_target = Vector2(target_building.global_position.x,
                                target_building.global_position.z)

        # ---- ناوگان: از دل افق دریا می‌آید و کنار ساحل پارک می‌ماند (گام ۶R2) ----
        var nav := PathService.nav
        var center := nav.origin + nav.size_world() * 0.5
        var outward := (water_xz - center).normalized()
        if outward == Vector2.ZERO:
                outward = Vector2.RIGHT
        var tangent := Vector2(-outward.y, outward.x)
        var comp: Dictionary = opts.get("comp", _default_comp(size))
        var fleet_spec := _build_fleet(size, comp)
        var n_boats := fleet_spec.size()
        var gid := _next_group
        _next_group += 1
        var fleet: Array = []
        var anchor0 := water_xz + outward * 1.4
        for bi in n_boats:
                var spec: Dictionary = fleet_spec[bi]
                var btype: EnemyBoat.BoatType = spec["type"]
                var off := _anchor_offset_of(btype)
                # قایق‌های ناوگان کنار هم پهلو می‌گیرند (فاصله‌ی FLEET_BOAT_GAP)
                var side := (float(bi) - float(n_boats - 1) * 0.5) \
                                * GameConstants.FLEET_BOAT_GAP
                var anchor := water_xz + outward * off + tangent * side
                if bi == 0:
                        anchor0 = anchor
                var boat := EnemyBoat.new()
                boat.boat_type = btype
                boat.capacity = _capacity_of(btype)
                boat.anchor_point = Vector3(anchor.x, 0, anchor.y)
                # گام ۶R2 — ظهور از افق: ۳۲ متر دورتر در دریای باز؛ کروز تند تا
                # نزدیکی ساحل و ترمز نرم برای پهلوگیری
                boat.global_position = Vector3(
                                anchor.x + outward.x * GameConstants.BOAT_SPAWN_DIST,
                                0, anchor.y + outward.y * GameConstants.BOAT_SPAWN_DIST)
                boats_root.add_child(boat)
                fleet.append({"boat": boat, "payload": spec["payload"],
                                "landed": false})
                boat.landed.connect(_on_boat_landed.bind(gid))

        _groups[gid] = {
                "fleet": fleet,
                "raiders": [],
                "channel": channel,
                "landing": landing,
                "anchor": anchor0,
                "raid_target": raid_target,
                "target_building": target_building,
                "comp_wanted": comp,
                "cleared": false,
        }
        waves_spawned += 1
        var total: int = int(comp.get(KIND_LIGHT, 0)) + int(comp.get(KIND_HEAVY, 0)) \
                        + int(comp.get(KIND_PELTAST, 0))
        wave_started.emit(gid, total)
        return gid


## ترکیب پیش‌فرض §۶: پلتاست ≈ ۱/۳، سنگین از گروه ۶ نفره به بالا، بقیه سبک
func _default_comp(size: int) -> Dictionary:
        var pelt := int(ceil(size / 3.0))
        var heavy := 1 if size >= 6 else 0
        if pelt + heavy > size:
                pelt = maxi(0, size - heavy)
        var light := maxi(0, size - pelt - heavy)
        return {KIND_LIGHT: light, KIND_HEAVY: heavy, KIND_PELTAST: pelt}


## ساخت ناوگان از روی اندازه‌ی گروه — قایق بزرگ‌تر برای دسته‌ی بزرگ‌تر
## (بازخورد کاربر گام ۶R2: «چند نوع قایق؛ بعضی کوچک‌تر و بدون بادبان»)
## خروجی: [{"type": BoatType, "load": int, "payload": {kind: n}}]
func _build_fleet(size: int, comp: Dictionary) -> Array:
        # لیست سربازها به‌صورت مخلوط (سبک/سنگین/پلتاست در همه‌ی قایق‌ها پخش شوند)
        var counts := {
                KIND_LIGHT: int(comp.get(KIND_LIGHT, 0)),
                KIND_HEAVY: int(comp.get(KIND_HEAVY, 0)),
                KIND_PELTAST: int(comp.get(KIND_PELTAST, 0)),
        }
        var roster: Array = []
        var guard := 0
        while roster.size() < size and guard < 200:
                guard += 1
                for kind in [KIND_LIGHT, KIND_HEAVY, KIND_PELTAST]:
                        if int(counts[kind]) > 0:
                                roster.append(kind)
                                counts[kind] -= 1
        # انتخاب قایق‌ها: ≥۹ → کشتی جنگی + قایق همراه | ۷..۸ → کشتی جنگی |
        # ۴..۶ → گالی | ۱..۳ → قایق پارویی کوچک (بدون بادبان)
        var boats_spec: Array = []
        var remaining := roster.size()
        while remaining > 0:
                if remaining >= 9:
                        boats_spec.append({"type": EnemyBoat.BoatType.WARSHIP,
                                        "load": 6})
                        remaining -= 6
                elif remaining >= 7:
                        boats_spec.append({"type": EnemyBoat.BoatType.WARSHIP,
                                        "load": remaining})
                        remaining = 0
                elif remaining >= 4:
                        boats_spec.append({"type": EnemyBoat.BoatType.GALLEY,
                                        "load": remaining})
                        remaining = 0
                else:
                        boats_spec.append({"type": EnemyBoat.BoatType.ROWBOAT,
                                        "load": remaining})
                        remaining = 0
        # توزیع سربازها بین قایق‌های ناوگان (به ترتیب لیست مخلوط)
        var idx := 0
        for bi in boats_spec.size():
                var payload := {}
                for li in int(boats_spec[bi]["load"]):
                        var kind: String = roster[idx]
                        idx += 1
                        payload[kind] = int(payload.get(kind, 0)) + 1
                boats_spec[bi]["payload"] = payload
        return boats_spec


func _capacity_of(btype: EnemyBoat.BoatType) -> int:
        match btype:
                EnemyBoat.BoatType.ROWBOAT:
                        return GameConstants.CAP_ROWBOAT
                EnemyBoat.BoatType.WARSHIP:
                        return GameConstants.CAP_WARSHIP
                _:
                        return GameConstants.CAP_GALLEY


func _anchor_offset_of(btype: EnemyBoat.BoatType) -> float:
        match btype:
                EnemyBoat.BoatType.ROWBOAT:
                        return 1.1
                EnemyBoat.BoatType.WARSHIP:
                        return 1.8
                _:
                        return 1.4


func _on_boat_landed(boat: EnemyBoat, gid: int) -> void:
        if not _groups.has(gid):
                return
        var g: Dictionary = _groups[gid]
        var entry: Dictionary = {}
        for e in g["fleet"]:
                if e["boat"] == boat:
                        entry = e
                        break
        if entry.is_empty() or entry["landed"]:
                return
        entry["landed"] = true
        # سربازهای هر قایق نزدیک همان قایق پیاده می‌شوند — هر قایق حلقه‌ی خودش
        var landing: Vector2 = g["landing"]
        var payload: Dictionary = entry["payload"]
        var need := 0
        for k in payload:
                need += int(payload[k])
        var cells := _walkable_cells_near(landing,
                        2.0 + 1.5 * float(_landed_count(g)), need + 6)
        var k2 := 0
        for kind in [KIND_LIGHT, KIND_HEAVY, KIND_PELTAST]:
                for i in int(payload.get(kind, 0)):
                        var at: Vector2 = landing
                        if k2 < cells.size():
                                at = cells[k2]
                        k2 += 1
                        var e2 := spawn_enemy(kind, at, gid)
                        if e2 != null:
                                g["raiders"].append(e2)


func _landed_count(g: Dictionary) -> int:
        var n := 0
        for e in g["fleet"]:
                if e["landed"]:
                        n += 1
        return n


## ساخت یک مهاجم در نقطه (برای کارگردان و تست) — group < 0 = گروه آزمایشی مستقل
func spawn_enemy(kind: String, at: Vector2, group: int = -1) -> EnemyBase:
        var script: GDScript = null
        match kind:
                KIND_LIGHT:
                        script = HopliteLight
                KIND_HEAVY:
                        script = HopliteHeavy
                KIND_PELTAST:
                        script = PeltastUnit
                _:
                        return null
        var nav := PathService.nav
        var pos := at
        if nav != null and not nav.is_walkable(nav.world_to_cell(at)):
                pos = nav.cell_center(_nearest_walkable_cell(at))
        var e: EnemyBase = script.new()
        e.raid_group = group % 4 if group >= 0 else 3
        var raid := Vector2.ZERO
        if group >= 0 and _groups.has(group):
                raid = _groups[group]["raid_target"]
                e.target_house = _groups[group]["target_building"]   # هدف مشعل
        else:
                raid = pos  # گروه آزمایشی: همان‌جا می‌ماند و واکنش می‌دهد
        e.raid_target = raid
        if ground != null:
                e.ground_provider = Callable(ground, "height_at_world")
                e.position = Vector3(pos.x, ground.height_at_world(pos), pos.y)
        else:
                e.position = Vector3(pos.x, 0.0, pos.y)
        raiders_root.add_child(e)
        if group >= 0 and _groups.has(group):
                PathService.set_goal_for(_groups[group]["channel"], raid)
        return e


# ---------------- انتخاب ساحل و خانه ----------------

## سلول ساحلیِ واقعی: قابل‌عبور با همسایه‌ی «آب» (نه صخره/خانه!).
## خروجی: {"landing": مرکز سلول ساحلی, "water": مرکز سلول آبِ همسایه}
## دورترین به پست‌ها یا نزدیک‌ترین به hint
## گام ۶R2 — در حالت خودکار، ساحلِ «رو به دوربین» ترجیح دارد تا قایق از
## افقِ پیدای صفحه وارد شود (بازخورد کاربر: «از گوشه صفحه وارد بشوند»)
func _pick_shore(hint: Vector2 = Vector2.INF) -> Dictionary:
        var nav := PathService.nav
        var center := nav.origin + nav.size_world() * 0.5
        var shores: Array = []   # [Vector2i landing_cell, Vector2i water_cell]
        for cy in nav.height:
                for cx in nav.width:
                        var c := Vector2i(cx, cy)
                        if not nav.is_walkable(c):
                                continue
                        var w := _water_neighbor(c)
                        if w != Vector2i(-1, -1):
                                shores.append([c, w])
        if shores.is_empty():
                # جزیره‌ی بدون ساحل آب (عملاً غیرممکن) — رفتار قدیمی به‌عنوان پشتیبان
                var mid := Vector2i(nav.width / 2, nav.height / 2)
                return {"landing": nav.cell_center(mid), "water": nav.cell_center(mid)}
        var best: Array = shores[0]
        if hint != Vector2.INF:
                var best_d := 1e9
                for s in shores:
                        var d: float = nav.cell_center(s[0]).distance_to(hint)
                        if d < best_d:
                                best_d = d
                                best = s
                return {"landing": nav.cell_center(best[0]),
                                "water": nav.cell_center(best[1])}
        # کاندیداهای دورتر از همه‌ی پست‌ها → ۶ تای برتر → انتخاب rng
        var scored: Array = []
        for s in shores:
                var cc := nav.cell_center(s[0])
                var min_d := 1e9
                for p in posts:
                        min_d = minf(min_d, cc.distance_to(p))
                scored.append([min_d, s])
        scored.sort_custom(func(a, b): return a[0] > b[0])
        var top := scored.slice(0, mini(6, scored.size()))
        var pick: Array = top[_rng.randi_range(0, top.size() - 1)][1]
        # گام ۶R2 — بین ۶ کاندیدای برتر، ساحل‌هایی که «رو به دوربین»اند
        # (جهت دریای پشت جزیره از دید دوربین) اولویت دارند
        if cam_xz_provider.is_valid():
                var cam_xz: Vector2 = cam_xz_provider.call()
                var view_dir := center - cam_xz
                if view_dir.length() > 1.0:
                        view_dir = view_dir.normalized()
                        var visible: Array = []
                        for t in top:
                                var s: Array = t[1]
                                var oc := (nav.cell_center(s[1]) - center).normalized()
                                if oc.dot(view_dir) > 0.3:
                                        visible.append(t)
                        if not visible.is_empty():
                                pick = visible[_rng.randi_range(0,
                                                visible.size() - 1)][1]
        return {"landing": nav.cell_center(pick[0]),
                        "water": nav.cell_center(pick[1])}


## همسایه‌ی آبِ واقعی سلول (با نام ماژول آب — نه هر غیرقابل‌عبوری)
func _water_neighbor(c: Vector2i) -> Vector2i:
        for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
                        Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
                var n2: Vector2i = c + d
                if String(ground.module_name_at(n2)).begins_with("water"):
                        return n2
        return Vector2i(-1, -1)


## نزدیک‌ترین بنای زنده (نسوخته) — هدف مشعل مهاجمان
func _nearest_alive_building(from: Vector2) -> BuildingBase:
        if props == null:
                return null
        var best: BuildingBase = null
        var best_d := 1e9
        for b in props.buildings:
                if not is_instance_valid(b) or b.burned:
                        continue
                var bxz := Vector2(b.global_position.x, b.global_position.z)
                var d := bxz.distance_to(from)
                if d < best_d:
                        best_d = d
                        best = b
        return best


func _nearest_walkable_cell(from: Vector2) -> Vector2i:
        var nav := PathService.nav
        var base := nav.world_to_cell(from)
        if nav.is_walkable(base):
                return base
        for r in range(1, 6):
                for dy in range(-r, r + 1):
                        for dx in range(-r, r + 1):
                                var c := base + Vector2i(dx, dy)
                                if nav.is_walkable(c):
                                        return c
        return base


func _walkable_cells_near(center: Vector2, radius: float, want: int) -> Array[Vector2]:
        var nav := PathService.nav
        var cells := int(ceil(radius / nav.cell_size))
        var base := nav.world_to_cell(center)
        var out: Array[Vector2] = []
        var dists: Array = []
        for dy in range(-cells, cells + 1):
                for dx in range(-cells, cells + 1):
                        var c := base + Vector2i(dx, dy)
                        if not nav.is_walkable(c):
                                continue
                        var cc := nav.cell_center(c)
                        dists.append([cc.distance_to(center), cc])
        dists.sort_custom(func(a, b): return a[0] < b[0])
        for d in dists:
                out.append(d[1])
                if out.size() >= want:
                        break
        return out


# ---------------- چرخه‌ی عمر گروه ----------------

## قایق‌های زنده‌ی ناوگان — آزادشده‌ها حذف می‌شوند (اختصاصِ freed به متغیر
## تایپ‌دار در Godot 4 خطاست)
func _live_fleet(g: Dictionary) -> Array:
        var out: Array = []
        for e in g.get("fleet", []):
                var b = e.get("boat")
                if b != null and is_instance_valid(b) and b is EnemyBoat:
                        out.append(b)
        return out


func _all_landed(g: Dictionary) -> bool:
        for e in g.get("fleet", []):
                if not e["landed"]:
                        return false
        return true


func _check_groups() -> void:
        var dead_ids: Array = []
        for gid in _groups:
                var g: Dictionary = _groups[gid]
                if _live_fleet(g).is_empty():
                        # ناوگان آزاد شده (فقط با بازتولید جزیره/پاکسازی) → گروه بسته
                        dead_ids.append(gid)
                        continue
                if g["cleared"]:
                        continue
                _retarget_if_burned(gid, g)
                # گام ۶R2 — قایق‌ها هرگز برنمی‌گردند (بازخورد کاربر): مهاجمان
                # کشته شوند یا زنده بمانند، ناوگان پارک‌شده در ساحل می‌ماند.
                # «پاکسازی موج» فقط سیگنال گزارشی است.
                if not g["raiders"].is_empty() and raiders_alive(gid) == 0 \
                                and _all_landed(g):
                        g["cleared"] = true
                        wave_cleared.emit(gid)
        for gid in dead_ids:
                _groups.erase(gid)


## اگر خانه‌ی هدف گروه سوخت → نزدیک‌ترین خانه‌ی زنده؛ میدان و مهاجمان به‌روز می‌شوند
func _retarget_if_burned(gid: int, g: Dictionary) -> void:
        if raiders_alive(gid) == 0:
                return
        var tb = g.get("target_building")
        if tb != null and is_instance_valid(tb) and not tb.burned:
                return
        var centroid := Vector2.ZERO
        var n := 0
        for e in g["raiders"]:
                if is_instance_valid(e) and not e.is_dead():
                        centroid += Vector2(e.global_position.x, e.global_position.z)
                        n += 1
        if n == 0:
                return
        var nb := _nearest_alive_building(centroid / float(n))
        g["target_building"] = nb
        var raid: Vector2 = g["raid_target"]
        if nb != null:
                raid = Vector2(nb.global_position.x, nb.global_position.z)
        g["raid_target"] = raid
        PathService.set_goal_for(g["channel"], raid)
        for e in g["raiders"]:
                if is_instance_valid(e) and not e.is_dead():
                        e.raid_target = raid
                        e.target_house = nb


## مهاجمانِ زنده‌ی یک گروه
func raiders_alive(gid: int) -> int:
        if not _groups.has(gid):
                return 0
        var n := 0
        for e in _groups[gid]["raiders"]:
                if is_instance_valid(e) and not e.is_dead():
                        n += 1
        return n


func raiders_of(gid: int) -> Array:
        return _groups.get(gid, {}).get("raiders", [])


func group_raid_target(gid: int) -> Vector2:
        return _groups.get(gid, {}).get("raid_target", Vector2.ZERO)


func group_landing(gid: int) -> Vector2:
        return _groups.get(gid, {}).get("landing", Vector2.ZERO)


## نقطه‌ی لنگر گروه (روی آب کنار ساحل — قایق اول ناوگان) — گام ۶R
func group_anchor(gid: int) -> Vector2:
        return _groups.get(gid, {}).get("anchor", Vector2.ZERO)


## قایق‌های زنده‌ی گروه — برای تست ناوگان (گام ۶R2)
func group_boats(gid: int) -> Array:
        if not _groups.has(gid):
                return []
        return _live_fleet(_groups[gid])


## وضعیت قایق گروه (قایق اول ناوگان): 0=در حال شنا 1=لنگر -1=بدون قایق
func boat_state(gid: int) -> int:
        if not _groups.has(gid):
                return -1
        var fleet := _live_fleet(_groups[gid])
        if fleet.is_empty():
                return -1
        return int((fleet[0] as EnemyBoat).state)


func boats_active() -> int:
        var n := 0
        for gid in _groups:
                n += _live_fleet(_groups[gid]).size()
        return n


## تعداد «گروه»های فعال برای سقف WAVE_MAX_CONCURRENT (گام ۶R2):
## گروهی که مهاجم زنده دارد یا هنوز قایقش در راه است؛ ناوگانِ پارک‌شده‌ی
## مهاجمانِ مرده مانع موج تازه نمی‌شود (قایق‌ها که برنمی‌گردند)
func waves_active() -> int:
        var n := 0
        for gid in _groups:
                if raiders_alive(gid) > 0 or not _all_landed(_groups[gid]):
                        n += 1
        return n


func alive_raiders_total() -> int:
        var n := 0
        for e in get_tree().get_nodes_in_group("hostiles"):
                if e is EnemyBase and not e.is_dead():
                        n += 1
        return n


func groups_count() -> int:
        return _groups.size()


## پاکسازی کامل (بازتولید جزیره / پایان صحنه)
func clear_all() -> void:
        for c in boats_root.get_children():
                c.free()
        for c in raiders_root.get_children():
                c.free()
        _groups.clear()
        waves_spawned = 0
        _wave_accum = 0.0


## برای تست: کشتن همه‌ی مهاجمان زنده (قایق‌ها در ساحل می‌مانند — گام ۶R2)
func kill_all_raiders() -> int:
        var n := 0
        for e in get_tree().get_nodes_in_group("hostiles"):
                if e is EnemyBase and not e.is_dead():
                        (e as EnemyBase).take_hit(99)
                        n += 1
        return n
