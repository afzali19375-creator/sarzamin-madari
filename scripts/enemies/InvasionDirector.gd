class_name InvasionDirector
extends Node
## کارگردان موج هجوم — گام ۶ (§۶ سند طراحی)
##
##   * ساحل فرود: سلول ساحلیِ قابل‌عبور؛ پیش‌فرض = دورترین به پست دسته‌ها
##     (از کاندیداهای برتر انتخاب قطعی با rng) — برای تست، نقطه‌ی hint دستی
##   * قایق از دل دریا پهلو می‌گیرد و لنگر می‌ماند؛ مهاجمان روی ساحل پیاده می‌شوند
##   * هر گروه کانال FlowField خودش را دارد (۴..۷)؛ هدف = نزدیک‌ترین خانه به فرود
##   * ترکیب پیش‌فرض: Peltast ≈ ۱/۳ + Hoplite سنگین در گروه‌های ≥ ۶ نفر، بقیه سبک
##   * پاکسازی موج: همه‌ی مهاجمان مرده → قایق برمی‌گردد (§۶: لنگر برای بازگشت)
##   * مرگ سرباز پارسی با GameEvents.unit_permanently_died — اینجا فقط دشمنان

signal wave_started(group_id: int, count: int)
signal wave_cleared(group_id: int)

var ground: IslandGround
var props: IslandProps
var posts: Array[Vector2] = []          # پست دسته‌ها — برای انتخاب ساحل دور

var auto_waves := true
var wave_interval := GameConstants.WAVE_INTERVAL
var waves_spawned := 0

var boats_root: Node3D
var raiders_root: Node3D

# group_id -> {"boat": EnemyBoat, "raiders": Array, "channel": int,
#              "landing": Vector2, "raid_target": Vector2, "cleared": bool}
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
        if not force and boats_active() >= GameConstants.WAVE_MAX_CONCURRENT:
                return -1
        if ground == null or props == null:
                return -1
        var size: int = opts.get("size",
                        _rng.randi_range(GameConstants.WAVE_SIZE_MIN,
                        GameConstants.WAVE_SIZE_MAX))
        var hint: Vector2 = opts.get("near", Vector2.INF)
        var landing := _pick_landing(hint)
        var channel := GameConstants.ENEMY_CHANNEL_BASE + (_next_group % 4)
        var raid_target := _nearest_house_xz(landing)

        # قایق: از دل دریا (امتداد جهت مرکز→ساحل) پهلو می‌گیرد
        var nav := PathService.nav
        var center := nav.origin + nav.size_world() * 0.5
        var outward := (landing - center).normalized()
        var boat := EnemyBoat.new()
        boat.anchor_point = Vector3(landing.x, 0, landing.y) \
                        - Vector3(outward.x, 0, outward.y) * 1.1
        boat.retreat_point = Vector3(landing.x, 0, landing.y) \
                        - Vector3(outward.x, 0, outward.y) * 16.0
        boat.global_position = Vector3(landing.x, 0, landing.y) \
                        - Vector3(outward.x, 0, outward.y) * 13.0
        boats_root.add_child(boat)

        var comp: Dictionary = opts.get("comp", _default_comp(size))
        var gid := _next_group
        _next_group += 1
        _groups[gid] = {
                "boat": boat,
                "raiders": [],
                "channel": channel,
                "landing": landing,
                "raid_target": raid_target,
                "comp_wanted": comp,
                "cleared": false,
        }
        boat.landed.connect(_on_boat_landed.bind(gid))
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


func _on_boat_landed(boat: EnemyBoat, gid: int) -> void:
        if not _groups.has(gid):
                return
        var g: Dictionary = _groups[gid]
        if not g["raiders"].is_empty():
                return
        var comp: Dictionary = g.get("comp_wanted", _default_comp(GameConstants.WAVE_SIZE_MIN))
        var landing: Vector2 = g["landing"]
        var cells := _walkable_cells_near(landing, 3.0, 15)
        var k := 0
        for kind in [KIND_LIGHT, KIND_HEAVY, KIND_PELTAST]:
                for i in int(comp.get(kind, 0)):
                        var at: Vector2 = landing
                        if k < cells.size():
                                at = cells[k]
                        k += 1
                        var e := spawn_enemy(kind, at, gid)
                        if e != null:
                                g["raiders"].append(e)


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

## سلول ساحلی: قابل‌عبور با همسایه‌ی غیرقابل‌عبور (آب). دورترین به پست‌ها یا نزدیک‌ترین به hint
func _pick_landing(hint: Vector2 = Vector2.INF) -> Vector2:
        var nav := PathService.nav
        var shores: Array[Vector2i] = []
        for cy in nav.height:
                for cx in nav.width:
                        var c := Vector2i(cx, cy)
                        if not nav.is_walkable(c):
                                continue
                        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
                                        Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1),
                                        Vector2i(1, -1), Vector2i(-1, 1)]:
                                if not nav.is_walkable(c + d):
                                        shores.append(c)
                                        break
        if shores.is_empty():
                return nav.cell_center(Vector2i(nav.width / 2, nav.height / 2))
        var best_c: Vector2i = shores[0]
        if hint != Vector2.INF:
                var best_d := 1e9
                for c in shores:
                        var d: float = nav.cell_center(c).distance_to(hint)
                        if d < best_d:
                                best_d = d
                                best_c = c
                return nav.cell_center(best_c)
        # کاندیداهای دورتر از همه‌ی پست‌ها → ۶ تای برتر → انتخاب rng
        var scored: Array = []
        for c in shores:
                var cc := nav.cell_center(c)
                var min_d := 1e9
                for p in posts:
                        min_d = minf(min_d, cc.distance_to(p))
                scored.append([min_d, c])
        scored.sort_custom(func(a, b): return a[0] > b[0])
        var top := scored.slice(0, mini(6, scored.size()))
        var pick: Array = top[_rng.randi_range(0, top.size() - 1)]
        return nav.cell_center(pick[1])


func _nearest_house_xz(from: Vector2) -> Vector2:
        var best := from
        var best_d := 1e9
        for hp in props.house_positions:
                var hxz := Vector2(hp.x, hp.z)
                var d := hxz.distance_to(from)
                if d < best_d:
                        best_d = d
                        best = hxz
        if best_d >= 1e9:
                # جزیره‌ی بی‌خانه — مرکز خشکی
                var nav := PathService.nav
                best = nav.origin + nav.size_world() * 0.5
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

## قایقِ زنده‌ی گروه — آزادشده → null (اختصاصِ freed به متغیر تایپ‌دار در Godot 4 خطاست)
func _live_boat(g: Dictionary) -> EnemyBoat:
        var b = g.get("boat")
        if b != null and is_instance_valid(b) and b is EnemyBoat:
                return b
        return null


func _check_groups() -> void:
        var dead_ids: Array = []
        for gid in _groups:
                var g: Dictionary = _groups[gid]
                var boat := _live_boat(g)
                if boat == null:
                        # قایق آزاد شده (بازگشت کامل) → گروه بسته است
                        dead_ids.append(gid)
                        continue
                if g["cleared"]:
                        continue
                if raiders_alive(gid) == 0 \
                                and boat.state == EnemyBoat.BoatState.ANCHORED:
                        g["cleared"] = true
                        boat.depart()
                        wave_cleared.emit(gid)
        for gid in dead_ids:
                _groups.erase(gid)


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


func boat_state(gid: int) -> int:
        if not _groups.has(gid):
                return -1
        var boat := _live_boat(_groups[gid])
        if boat == null:
                return -1
        return int(boat.state)


func boats_active() -> int:
        var n := 0
        for gid in _groups:
                if _live_boat(_groups[gid]) != null:
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


## برای تست: کشتن همه‌ی مهاجمان زنده (گروه‌ها پاکسازی می‌شوند)
func kill_all_raiders() -> int:
        var n := 0
        for e in get_tree().get_nodes_in_group("hostiles"):
                if e is EnemyBase and not e.is_dead():
                        (e as EnemyBase).take_hit(99)
                        n += 1
        return n
