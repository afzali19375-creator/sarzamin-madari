class_name IslandProps
extends Node3D
## خانه‌ها و پوشش جزیره — بازخورد کاربر: «خانه‌ها طراحی واقعی دارند» (§۹ پرامت)
##
##   * خانه‌ی گنبددار: دیوار #E8D9B8 + کاشی گنبد #3AB0A0 + در چوبی #6B4A2E
##   * بادگیر #D4B483 روی یکی از خانه‌ها | آتشکده‌ی سنگی #C4B5A0 (چک‌پوینت آینده)
##   * خانه‌ها ۲×۲ سلول NavGrid را اشغال و مسدود می‌کنند (واحدها دورشان می‌پیچند)
##   * گام ۶R: هر بنا BuildingBase است — جان دارد، با مشعل آتش می‌گیرد، می‌سوزد
##   * بوته/درخت مینیمال سبک Bad North — مانع ناوبری نیستند
##   * چیدمان قطعی با seed جزیره (بازتولید = همان روستا)

const HOUSE_SITES := 4          # ۳ خانه‌ی گنبددار + ۱ آتشکده
const SITE_MIN_DIST := 4.6      # فاصله‌ی حداقلی بین خانه‌ها (§۹.۱: ≥ 2 متر)
const SITE_HALF := 1            # نیم‌اندازه‌ی سایت: ۲×۲ سلول NavGrid

var house_positions: Array[Vector3] = []
var blocked_cells: Array[Vector2i] = []
## همه‌ی بناهای جان‌دار (خانه‌ها + آتشکده) — گروه «buildings» هم می‌شوند
var buildings: Array[BuildingBase] = []

var _rng := RandomNumberGenerator.new()


## ساخت روستا + پوشش؛ سلول‌های خانه‌ها را در nav مسدود می‌کند
func build(ground: IslandGround, nav: NavGrid, island: Dictionary, seed_value: int) -> void:
        for c in get_children():
                c.free()
        house_positions.clear()
        blocked_cells.clear()
        buildings.clear()
        _rng.seed = hash("props:%d" % seed_value)

        var sites := _pick_house_sites(ground, nav)
        for i in sites.size():
                var cell00 := sites[i]
                _stamp_site_blocked(nav, cell00)
                var center := nav.origin + (Vector2(cell00) + Vector2(1.0, 1.0)) * nav.cell_size
                var y := ground.height_at_world(center) - 0.03
                var pos := Vector3(center.x, y, center.y)
                house_positions.append(pos)
                if i < 3:
                        _build_house(pos, i == 0)
                else:
                        _build_fire_temple(pos)
        _build_vegetation(ground, nav, island, sites)


## نزدیک‌ترین بنای زنده (نسوخته) — برای هدف مشعل دشمن و اشغال خودی
func nearest_alive_house_xz(from: Vector2) -> Vector2:
        var best := Vector2.INF
        var best_d := 1e9
        for b in buildings:
                if not is_instance_valid(b) or b.burned:
                        continue
                var bxz := Vector2(b.global_position.x, b.global_position.z)
                var d := bxz.distance_to(from)
                if d < best_d:
                        best_d = d
                        best = bxz
        return best


# ---------------- انتخاب سایت خانه‌ها ----------------

func _pick_house_sites(ground: IslandGround, nav: NavGrid) -> Array[Vector2i]:
        var cands: Array[Vector2i] = []
        for cy in range(SITE_HALF, ground.size - SITE_HALF - 1, 2):
                for cx in range(SITE_HALF, ground.size - SITE_HALF - 1, 2):
                        var ok := true
                        for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
                                var c2 := Vector2i(cx, cy) + d
                                if not nav.is_walkable(c2):
                                        ok = false
                                        break
                                if not String(ground.module_name_at(c2)).begins_with("grass"):
                                        ok = false
                                        break
                        if ok:
                                cands.append(Vector2i(cx, cy))
        # بُر زدن قطعی + انتخاب حریصانه با فاصله‌ی حداقلی
        for i in range(cands.size() - 1, 0, -1):
                var j := _rng.randi_range(0, i)
                var t := cands[i]
                cands[i] = cands[j]
                cands[j] = t
        var picked: Array[Vector2i] = []
        for p in cands:
                if picked.size() >= HOUSE_SITES:
                        break
                var far := true
                for q in picked:
                        var pc := nav.cell_center(p)
                        var qc := nav.cell_center(q)
                        if pc.distance_to(qc) < SITE_MIN_DIST:
                                far = false
                                break
                if far:
                        picked.append(p)
        return picked


func _stamp_site_blocked(nav: NavGrid, cell00: Vector2i) -> void:
        for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
                nav.set_walkable(cell00 + d, false)
                blocked_cells.append(cell00 + d)


# ---------------- خانه‌ی گنبددار هخامنشی ----------------

func _build_house(pos: Vector3, with_windcatcher: bool) -> void:
        var root := _make_building(pos)

        # بدنه‌ی استوانه‌ای با دیوار گچی
        var wall := MeshInstance3D.new()
        var wm := CylinderMesh.new()
        wm.top_radius = 0.95
        wm.bottom_radius = 1.05
        wm.height = 0.85
        wall.mesh = wm
        wall.position.y = 0.42
        wall.material_override = _building_mat(root, GameConstants.COL_DOME_WALL)
        root.add_child(wall)

        # گنبد کاشی فیروزه‌ای
        var dome := MeshInstance3D.new()
        var dm := SphereMesh.new()
        dm.radius = 0.95
        dm.height = 0.85
        dome.mesh = dm
        dome.position.y = 0.85
        dome.material_override = _building_mat(root, GameConstants.COL_DOME_TILE)
        root.add_child(dome)

        # نوک طلایی کوچک گنبد
        var tip := MeshInstance3D.new()
        var tm := SphereMesh.new()
        tm.radius = 0.07
        tm.height = 0.14
        tip.mesh = tm
        tip.position.y = 1.28
        tip.material_override = _building_mat(root, GameConstants.COL_GOLD)
        root.add_child(tip)

        # در چوبی (سمت +Z)
        var door := MeshInstance3D.new()
        var dm2 := BoxMesh.new()
        dm2.size = Vector3(0.34, 0.52, 0.08)
        door.mesh = dm2
        door.position = Vector3(0.0, 0.26, 1.0)
        door.material_override = _building_mat(root, GameConstants.COL_DOOR_WOOD)
        root.add_child(door)

        # بادگیر — امضای معماری ایرانی (روی یکی از خانه‌ها)
        if with_windcatcher:
                var wc := MeshInstance3D.new()
                var wc_mesh := BoxMesh.new()
                wc_mesh.size = Vector3(0.44, 1.55, 0.44)
                wc.mesh = wc_mesh
                wc.position = Vector3(-0.55, 1.1, -0.35)
                wc.material_override = _building_mat(root, GameConstants.COL_WINDCATCHER)
                root.add_child(wc)
                var cap := MeshInstance3D.new()
                var cap_mesh := BoxMesh.new()
                cap_mesh.size = Vector3(0.5, 0.1, 0.5)
                cap.mesh = cap_mesh
                cap.position = Vector3(-0.55, 1.9, -0.35)
                cap.material_override = _building_mat(root, GameConstants.COL_TILE_PATTERN)
                root.add_child(cap)
        # چرخش قطعی خانه برای تنوع
        root.rotation.y = _rng.randf() * TAU


## آتشکده‌ی سنگی (چک‌پوینت گام‌های بعد) — مکعب ساده با پیش‌کمره‌ی بالا
func _build_fire_temple(pos: Vector3) -> void:
        var root := _make_building(pos)

        var body := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(1.5, 0.95, 1.5)
        body.mesh = bm
        body.position.y = 0.47
        body.material_override = _building_mat(root, GameConstants.COL_FIRETEMPLE)
        root.add_child(body)

        var top := MeshInstance3D.new()
        var tm := BoxMesh.new()
        tm.size = Vector3(1.1, 0.5, 1.1)
        top.mesh = tm
        top.position.y = 1.18
        top.material_override = _building_mat(root,
                        GameConstants.COL_FIRETEMPLE.lerp(Color.WHITE, 0.12))
        root.add_child(top)

        var door := MeshInstance3D.new()
        var dm := BoxMesh.new()
        dm.size = Vector3(0.36, 0.55, 0.08)
        door.mesh = dm
        door.position = Vector3(0.0, 0.28, 0.76)
        door.material_override = _building_mat(root, GameConstants.COL_DOOR_WOOD)
        root.add_child(door)
        root.rotation.y = _rng.randf() * TAU


## بنای جان‌دار: در گروه «buildings» + ثبت در buildings
func _make_building(pos: Vector3) -> BuildingBase:
        var b := BuildingBase.new()
        b.position = pos
        add_child(b)
        b.add_to_group("buildings")
        buildings.append(b)
        return b


## ماتریال یکتا برای مش‌های بنا + ثبت در BuildingBase برای ذغالی‌شدن
func _building_mat(b: BuildingBase, c: Color) -> StandardMaterial3D:
        var m := _flat_mat(c)
        b.register_material(m)
        return m


# ---------------- پوشش گیاهی مینیمال (سبک Bad North) ----------------

func _build_vegetation(ground: IslandGround, nav: NavGrid, island: Dictionary,
                house_sites: Array[Vector2i]) -> void:
        var grass_cells: Array[Vector2i] = []
        var isize := int(island["size"])
        for cy in isize:
                for cx in isize:
                        var c := Vector2i(cx, cy)
                        if not nav.is_walkable(c):
                                continue
                        if not String(ground.module_name_at(c)).begins_with("grass"):
                                continue
                        var p := nav.cell_center(c)
                        var near_house := false
                        for s in house_sites:
                                if p.distance_to(nav.cell_center(s)) < 2.6:
                                        near_house = true
                                        break
                        if not near_house:
                                grass_cells.append(c)
        # بُر زدن قطعی
        for i in range(grass_cells.size() - 1, 0, -1):
                var j := _rng.randi_range(0, i)
                var t := grass_cells[i]
                grass_cells[i] = grass_cells[j]
                grass_cells[j] = t

        var bushes := mini(16, grass_cells.size())
        for b in bushes:
                var c := grass_cells[b]
                var p := nav.cell_center(c)
                _add_bush(Vector3(p.x, ground.height_at_world(p) - 0.02, p.y))
        var trees := mini(7, grass_cells.size() - bushes)
        for t2 in trees:
                var c := grass_cells[bushes + t2]
                var p := nav.cell_center(c)
                _add_tree(Vector3(p.x, ground.height_at_world(p) - 0.02, p.y))


func _add_bush(pos: Vector3) -> void:
        var b := MeshInstance3D.new()
        var m := SphereMesh.new()
        m.radius = _rng.randf_range(0.16, 0.3)
        m.height = m.radius * 1.3
        b.mesh = m
        b.position = pos + Vector3(_rng.randf_range(-0.3, 0.3), m.radius * 0.45, _rng.randf_range(-0.3, 0.3))
        b.scale = Vector3(1.0, 0.72, 1.0)
        var col := GameConstants.COL_GRASS_DARK.lerp(GameConstants.COL_GRASS_LIGHT, _rng.randf())
        b.material_override = _flat_mat(col)
        add_child(b)


func _add_tree(pos: Vector3) -> void:
        var root := Node3D.new()
        root.position = pos
        add_child(root)
        var trunk := MeshInstance3D.new()
        var tm := CylinderMesh.new()
        tm.top_radius = 0.05
        tm.bottom_radius = 0.08
        tm.height = 0.4
        trunk.mesh = tm
        trunk.position.y = 0.2
        trunk.material_override = _flat_mat(GameConstants.COL_DOOR_WOOD)
        root.add_child(trunk)
        var canopy := MeshInstance3D.new()
        var cm := SphereMesh.new()
        cm.radius = _rng.randf_range(0.26, 0.4)
        cm.height = cm.radius * 1.7
        canopy.mesh = cm
        canopy.position.y = 0.4 + cm.radius * 0.6
        canopy.material_override = _flat_mat(GameConstants.COL_GRASS_DARK.lerp(GameConstants.COL_GRASS_LIGHT, _rng.randf() * 0.5))
        root.add_child(canopy)


func _flat_mat(c: Color) -> StandardMaterial3D:
        var m := StandardMaterial3D.new()
        m.albedo_color = c
        m.roughness = 1.0
        return m
