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

## گام ۶R5 — سایت‌ها هم‌ترازِ شبکه‌ی فرمان‌اند (مبدا زوج) تا هر خانه دقیقاً
## «یک واحد بلوک مستطیلی» را پر کند (مرکز خانه = مرکز تایل) — بازخورد کاربر
var house_sites: Array[Vector2i] = []
var house_positions: Array[Vector3] = []
var blocked_cells: Array[Vector2i] = []
## همه‌ی بناهای جان‌دار (خانه‌ها + آتشکده) — گروه «buildings» هم می‌شوند
var buildings: Array[BuildingBase] = []

var _rng := RandomNumberGenerator.new()


## گام ۶R6 — چوب‌های شناور در آب کم‌عمق (حسِ زندگیِ محیط)
var _driftwood: Array[Node3D] = []
var _drift_t := 0.0

## ساخت روستا + پوشش؛ سلول‌های خانه‌ها را در nav مسدود می‌کند
func build(ground: IslandGround, nav: NavGrid, island: Dictionary, seed_value: int) -> void:
        for c in get_children():
                c.free()
        house_positions.clear()
        house_sites.clear()
        blocked_cells.clear()
        buildings.clear()
        _driftwood.clear()
        _rng.seed = hash("props:%d" % seed_value)

        var sites := _pick_house_sites(ground, nav)
        for i in sites.size():
                var cell00 := sites[i]
                house_sites.append(cell00)
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
        _build_islets(ground, nav, island)
        _build_driftwood(ground, nav)


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
        # گام ۶R5 — مبدا زوج (هم‌ترازی با تایل‌های ۲×۲ شبکه‌ی فرمان):
        # ۴ سلولِ سایت = دقیقاً یک تایل؛ مرکز خانه = مرکز بلوک
        for cy in range(0, ground.size - 2, 2):
                for cx in range(0, ground.size - 2, 2):
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


# ---------------- خانه Low-Poly (گام ۶R6 — سبک مرجع کاربر) ----------------
## دیوار سفید + سقف شیروانیِ قهوه‌ای/بژ + پرچمِ سرخِ مالکیت روی دَرَک

func _build_house(pos: Vector3, with_flag_extra: bool) -> void:
        var root := _make_building(pos)

        # بدنه‌ی مکعبیِ سفید — داخل بلوکِ خودش (شعاع ≤ ۰٫۹)
        var wall := MeshInstance3D.new()
        var wm := BoxMesh.new()
        wm.size = Vector3(1.25, 0.62, 1.05)
        wall.mesh = wm
        wall.position.y = 0.31
        wall.material_override = _building_mat(root, GameConstants.COL_HOUSE_WALL)
        root.add_child(wall)

        # سقف شیروانی Low-Poly (دو سطحِ قهوه‌ای + لبه‌ی بژ)
        var roof := MeshInstance3D.new()
        var rm := PrismMesh.new()
        rm.size = Vector3(1.42, 0.52, 1.22)
        roof.mesh = rm
        roof.position.y = 0.88
        roof.material_override = _building_mat(root, GameConstants.COL_HOUSE_ROOF)
        root.add_child(roof)

        # لبه‌ی بژِ سقف (تاجِ نازک روی شیروانی)
        var ridge := MeshInstance3D.new()
        var rg := BoxMesh.new()
        rg.size = Vector3(0.08, 0.09, 1.26)
        ridge.mesh = rg
        ridge.position.y = 1.15
        ridge.material_override = _building_mat(root, GameConstants.COL_HOUSE_ROOF_HI)
        root.add_child(ridge)

        # در چوبی (سمت +Z)
        var door := MeshInstance3D.new()
        var dm2 := BoxMesh.new()
        dm2.size = Vector3(0.34, 0.46, 0.08)
        door.mesh = dm2
        door.position = Vector3(0.0, 0.23, 0.55)
        door.material_override = _building_mat(root, GameConstants.COL_DOOR_WOOD)
        root.add_child(door)

        # دودکش کوچک — سیلوئتِ خواناتر
        var chimney := MeshInstance3D.new()
        var ch := BoxMesh.new()
        ch.size = Vector3(0.16, 0.42, 0.16)
        chimney.mesh = ch
        chimney.position = Vector3(0.42, 0.95, -0.3)
        chimney.material_override = _building_mat(root, GameConstants.COL_HOUSE_WALL)
        root.add_child(chimney)

        # پرچمِ مالکیت — سرخ/صورتی؛ با تصرفِ خانه رنگِ دسته می‌گیرد
        var pole := MeshInstance3D.new()
        var pm2 := CylinderMesh.new()
        pm2.top_radius = 0.015
        pm2.bottom_radius = 0.02
        pm2.height = 0.85
        pole.mesh = pm2
        pole.position = Vector3(-0.45, 1.4, -0.3)
        pole.material_override = _building_mat(root, GameConstants.COL_DOOR_WOOD)
        root.add_child(pole)

        var flag := MeshInstance3D.new()
        var fm := BoxMesh.new()
        fm.size = Vector3(0.36, 0.2, 0.02)
        flag.mesh = fm
        flag.position = Vector3(-0.29, 1.68, -0.3)
        var flm := StandardMaterial3D.new()
        flm.albedo_color = GameConstants.COL_HOUSE_FLAG
        flm.roughness = 0.8
        flag.material_override = flm
        root.register_flag_material(flm)
        root.add_child(flag)
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
## گام ۶R6: بوته/درخت تیره در لبه‌ها و حاشیه‌ی صخره‌ها؛ مانعِ بصری — نه سدِ مسیر

func _build_vegetation(ground: IslandGround, nav: NavGrid, island: Dictionary,
                house_sites: Array[Vector2i]) -> void:
        var grass_cells: Array[Vector2i] = []
        var edge_cells: Array[Vector2i] = []
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
                        if near_house:
                                continue
                        # سلولِ لبه‌ای: همسایه‌ی غیرقابل‌عبور (حاشیه‌ی جزیره/صخره)
                        var at_edge := false
                        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                                if not nav.is_walkable(c + d):
                                        at_edge = true
                                        break
                        if at_edge:
                                edge_cells.append(c)
                        else:
                                grass_cells.append(c)
        # بُر زدن قطعی
        for arr in [grass_cells, edge_cells]:
                for i in range(arr.size() - 1, 0, -1):
                        var j := _rng.randi_range(0, i)
                        var t: Vector2i = arr[i]
                        arr[i] = arr[j]
                        arr[j] = t

        # اول لبه‌ها (سبزِ تیره — حاشیه‌ی طبیعی)، بعد داخل جزیره
        var bushes := mini(11, edge_cells.size())
        for b in bushes:
                var c := edge_cells[b]
                var p := nav.cell_center(c)
                _add_bush(Vector3(p.x, ground.height_at_world(p) - 0.02, p.y), true)
        var bushes_in := mini(6, grass_cells.size())
        for b2 in bushes_in:
                var c2 := grass_cells[b2]
                var p2 := nav.cell_center(c2)
                _add_bush(Vector3(p2.x, ground.height_at_world(p2) - 0.02, p2.y), false)
        var trees := mini(4, maxi(edge_cells.size() - bushes, 0))
        for t2 in trees:
                var c3 := edge_cells[bushes + t2]
                var p3 := nav.cell_center(c3)
                _add_tree(Vector3(p3.x, ground.height_at_world(p3) - 0.02, p3.y))
        var trees_in := mini(3, maxi(grass_cells.size() - bushes_in, 0))
        for t3 in trees_in:
                var c4 := grass_cells[bushes_in + t3]
                var p4 := nav.cell_center(c4)
                _add_tree(Vector3(p4.x, ground.height_at_world(p4) - 0.02, p4.y))


func _add_bush(pos: Vector3, dark: bool) -> void:
        var b := MeshInstance3D.new()
        var m := SphereMesh.new()
        m.radius = _rng.randf_range(0.16, 0.3)
        m.height = m.radius * 1.3
        b.mesh = m
        b.position = pos + Vector3(_rng.randf_range(-0.3, 0.3), m.radius * 0.45, _rng.randf_range(-0.3, 0.3))
        b.scale = Vector3(1.0, 0.72, 1.0)
        var col := GameConstants.COL_GRASS_DARK
        if not dark:
                col = col.lerp(GameConstants.COL_GRASS_LIGHT, _rng.randf() * 0.5)
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
        canopy.material_override = _flat_mat(GameConstants.COL_GRASS_DARK.lerp(
                        GameConstants.COL_GRASS_LIGHT, _rng.randf() * 0.3))
        root.add_child(canopy)


# ---------------- جزیره‌ک‌های صخره‌ای و چوبِ شناور (گام ۶R6) ----------------
## «جزیره باید چندین توده‌ی خشکی جدا از هم داشته باشد»: توده‌های صخره‌ایِ
## غیرقابل‌عبور در دل دریا — فقط بصری (ناوبری دست‌نخورده می‌ماند)

func _build_islets(ground: IslandGround, nav: NavGrid, island: Dictionary) -> void:
        var water_cells: Array[Vector2i] = []
        var isize := int(island["size"])
        for cy in isize:
                for cx in isize:
                        var c := Vector2i(cx, cy)
                        if String(ground.module_name_at(c)).begins_with("water"):
                                water_cells.append(c)
        if water_cells.is_empty():
                return
        var placed: Array[Vector2] = []
        var want := 3
        var guard := 0
        while placed.size() < want and guard < 60:
                guard += 1
                var c := water_cells[_rng.randi_range(0, water_cells.size() - 1)]
                var p := nav.cell_center(c)
                # فقط آبِ دور از ساحل (جلوگیری از چسبیدن به جزیره/قایق‌ها)
                var near_shore := false
                for dy in range(-3, 4):
                        for dx in range(-3, 4):
                                if nav.is_walkable(c + Vector2i(dx, dy)):
                                        near_shore = true
                if near_shore:
                        continue
                var far := true
                for q in placed:
                        if p.distance_to(q) < 7.0:
                                far = false
                                break
                if not far:
                        continue
                placed.append(p)
                _add_islet(p, ground)


func _add_islet(at: Vector2, ground: IslandGround) -> void:
        var root := Node3D.new()
        root.position = Vector3(at.x, IslandGround.SEA_Y, at.y)
        add_child(root)
        var h := _rng.randf_range(0.55, 1.15)
        var rock := MeshInstance3D.new()
        var rm := CylinderMesh.new()
        rm.top_radius = _rng.randf_range(0.3, 0.55)
        rm.bottom_radius = _rng.randf_range(0.8, 1.2)
        rm.height = h
        rm.radial_segments = 6        # Low-Poly
        rock.mesh = rm
        rock.position.y = h * 0.35
        rock.rotation.y = _rng.randf() * TAU
        rock.material_override = _flat_mat(
                        GameConstants.COL_ISLET.lerp(GameConstants.COL_CLIFF_DARK,
                        _rng.randf() * 0.4))
        root.add_child(rock)
        # کلاهکِ سبزِ کوچک روی بعضی جزیره‌ک‌ها
        if _rng.randf() < 0.6:
                var cap := MeshInstance3D.new()
                var cm := SphereMesh.new()
                cm.radius = rm.top_radius * 0.95
                cm.height = cm.radius * 0.8
                cap.mesh = cm
                cap.position.y = h * 0.35 + h * 0.5
                cap.material_override = _flat_mat(GameConstants.COL_GRASS_DARK)
                root.add_child(cap)


## چند تکه چوب شکسته در آب کم‌عمقِ اطراف جزیره — با تکانِ ملایم موج
func _build_driftwood(ground: IslandGround, nav: NavGrid) -> void:
        var shallow: Array[Vector2i] = []
        for cy in ground.size:
                for cx in ground.size:
                        var c := Vector2i(cx, cy)
                        if not String(ground.module_name_at(c)).begins_with("water"):
                                continue
                        # آب کم‌عمق = همسایه‌ی ساحل
                        var near_shore := false
                        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                                if nav.is_walkable(c + d):
                                        near_shore = true
                                        break
                        if near_shore:
                                shallow.append(c)
        for i in range(shallow.size() - 1, 0, -1):
                var j := _rng.randi_range(0, i)
                var t := shallow[i]
                shallow[i] = shallow[j]
                shallow[j] = t
        for k in mini(6, shallow.size()):
                var c2 := shallow[k]
                var p := nav.cell_center(c2)
                var log := Node3D.new()
                log.position = Vector3(p.x + _rng.randf_range(-0.2, 0.2),
                                IslandGround.SEA_Y + 0.02,
                                p.y + _rng.randf_range(-0.2, 0.2))
                add_child(log)
                var wood := MeshInstance3D.new()
                var wm := BoxMesh.new()
                wm.size = Vector3(_rng.randf_range(0.5, 0.9), 0.08, 0.12)
                wood.mesh = wm
                wood.rotation.y = _rng.randf() * TAU
                wood.rotation.z = _rng.randf_range(-0.12, 0.12)
                wood.material_override = _flat_mat(GameConstants.COL_DRIFTWOOD)
                log.add_child(wood)
                _driftwood.append(log)


## تکانِ ملایم چوب‌های شناور روی موج — حسِ زندگیِ دریا
func _process(delta: float) -> void:
        _drift_t += delta
        for i in _driftwood.size():
                var w := _driftwood[i]
                if not is_instance_valid(w):
                        continue
                var ph := float(i) * 1.7
                w.position.y = IslandGround.SEA_Y + 0.02 + sin(_drift_t * 1.4 + ph) * 0.03
                w.rotation.x = sin(_drift_t * 1.1 + ph) * 0.05


func _flat_mat(c: Color) -> StandardMaterial3D:
        var m := StandardMaterial3D.new()
        m.albedo_color = c
        m.roughness = 1.0
        return m
