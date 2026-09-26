class_name VoronoiBlocks
extends Node3D
## «بلوک‌های» زمین — گام ۶R۱۲ (بازخورد کاربر: «بلوک‌ها اصلا شبیه اسکرین‌شات
## نبود»): پدهای بیضیِ سبزِ مجزا روی زمینِ خشکِ کمرنگ — دقیقاً زبان بصری
## اسکرین‌شات‌های Bad North (جزیره‌ی دوتراسه: لکه‌های چمنِ بیضی با فاصله‌های
## روشن بین‌شان).
##
##   * هر پد = یک بیضیِ نرم (rx~۱٫۵m / ry~۱٫۱m) هم‌راستای شیب زمین
##   * پدها روی شبکه‌ی لرزانِ ۳٫۲ متری روی خشکی می‌نشینند؛ فاصله‌ی حداقلی
##     بین پدها تضمین می‌شود تا هم‌پوشانی نشوند (شبکه‌ی قبلیِ ورونویِ تمام‌پوشش
##     حذف شد — «پازل» بودن مشکل بود، نه حسن)
##   * پدِ خانه: بیضیِ بزرگ‌تر زیر هر بنا — خانه دقیقاً «یک بلوک» دارد
##   * کلیک/پیکینگ: نزدیک‌ترین پد با متریکِ بیضی (تا ۱٫۳۵× — کلیکِ لبه‌ی پد هم
##     ثبت می‌شود)؛ بینِ پدها = هیچ (مثل مرجع)
##   * حالت فرمان: پدها پرنورتر می‌شوند؛ هاور = پدِ زیر ماوس روشن‌تر
##   * ثبتِ اشغال: هر سربازِ ایستاده یک پدِ آزاد را تصاحب می‌کند؛ پدِ خانه‌ها
##     از قبل اشغال است (OWNER_OCCUPIED)
##
## API عمداً سازگار با نسخه‌ی ورونوی نگه داشته شد (صحنه/تست‌ها/پrobe).

const LIFT := 0.045                       # بلندی پد روی زمین (ضد z-fight)
const OWNER_OCCUPIED := -1                # پدِ خانه‌ها — هرگز به سرباز نمی‌رسد
const PICK_TOLERANCE := 1.35              # تلورانس پیکینگ بر حسبِ شعاعِ بیضی

var cell_count := 0                       # تعداد پدها (سازگاری نام قدیمی)

var _ground: IslandGround
var _nav: NavGrid
var _origin := Vector2.ZERO

## هر پد: {center: Vector2, spot: Vector2, top: float, rx: float, ry: float,
##         rot: float, aabb: Rect2}
var _blocks: Array[Dictionary] = []
var _claims: Dictionary = {}              # index → owner_id
var _command := false
var _hover_index := -1

var _mmi: MultiMeshInstance3D             # پدها (یک draw call)
var _hover_mesh: MeshInstance3D
var _pad_mat: ShaderMaterial
var _hover_mat: ShaderMaterial

var _seed_value := 20260924


# ================= ساخت =================

func rebuild(ground: IslandGround, nav: NavGrid, house_sites: Array[Vector2i]) -> void:
        for c in get_children():
                c.free()
        _ground = ground
        _nav = nav
        _origin = nav.origin
        _blocks.clear()
        _claims.clear()
        _hover_index = -1
        _command = false

        var rng := RandomNumberGenerator.new()
        rng.seed = _seed_value

        # ---- ۱) پدهای عادی: شبکه‌ی لرزان + فاصله‌ی حداقلی ----
        var spacing := GameConstants.BLOCK_SITE_SPACING
        var jitter := GameConstants.BLOCK_SITE_JITTER * 0.6
        var gsz := float(ground.size) * nav.cell_size
        var gy := 0.0
        while gy < gsz:
                var gx := 0.0
                while gx < gsz:
                        var raw := Vector2(_origin.x + gx + rng.randf_range(-jitter, jitter),
                                        _origin.y + gy + rng.randf_range(-jitter, jitter))
                        var spot := _nearest_walkable(nav, raw, 1.1)
                        if spot != Vector2.INF and _far_enough(spot, 2.35):
                                _add_pad(spot, rng.randf_range(1.42, 1.62),
                                                rng.randf_range(1.02, 1.18),
                                                rng.randf() * PI)
                        gx += spacing
                gy += spacing

        # ---- ۲) پدِ خانه‌ها: بیضیِ بزرگ‌تر — «خانه در یک بلوک» ----
        var house_centers: Array[Vector2] = []
        for site in house_sites:
                var hc := nav.origin + (Vector2(site) + Vector2(1.0, 1.0)) * nav.cell_size
                house_centers.append(hc)
                _add_pad(hc, 1.78, 1.34, rng.randf() * PI)

        cell_count = _blocks.size()

        # خانه‌ها: پدِ خودشان → اشغال دائمی
        for hc in house_centers:
                var bi := _index_at(hc)
                if bi >= 0:
                        _claims[bi] = OWNER_OCCUPIED

        _build_visuals()


## seed قطعی — صحنه قبل از rebuild ست می‌کند
func set_island_seed(seed_value: int) -> void:
        _seed_value = seed_value


func _add_pad(center: Vector2, rx: float, ry: float, rot: float) -> void:
        var spot := _nearest_walkable(_nav, center, 1.1)
        if spot == Vector2.INF:
                spot = center
        var aabb := Rect2(center - Vector2(rx, ry), Vector2(rx, ry) * 2.0).grow(0.2)
        _blocks.append({
                "center": center, "spot": spot,
                "top": _ground.height_at_world(spot),
                "rx": rx, "ry": ry, "rot": rot, "aabb": aabb,
        })


func _far_enough(p: Vector2, min_d: float) -> bool:
        for b in _blocks:
                if (b["center"] as Vector2).distance_to(p) < min_d:
                        return false
        return true


func _nearest_walkable(nav: NavGrid, from: Vector2, max_r: float) -> Vector2:
        var cells := int(ceil(max_r / nav.cell_size))
        var base := nav.world_to_cell(from)
        var best := Vector2.INF
        var best_d := max_r
        for dy in range(-cells, cells + 1):
                for dx in range(-cells, cells + 1):
                        var c := base + Vector2i(dx, dy)
                        if not nav.is_walkable(c):
                                continue
                        var cc := nav.cell_center(c)
                        var d := cc.distance_to(from)
                        if d <= best_d:
                                best_d = d
                                best = cc
        return best


# ================= متریک بیضی =================

## فاصله‌ی نرمال‌شده از مرکز پد (۱٫۰ = روی لبه؛ داخل < ۱٫۰)
func _pad_norm(i: int, xz: Vector2) -> float:
        var b := _blocks[i]
        var d := xz - (b["center"] as Vector2)
        var c := cos(float(b["rot"]))
        var s := sin(float(b["rot"]))
        var lx := (d.x * c + d.y * s) / float(b["rx"])
        var ly := (-d.x * s + d.y * c) / float(b["ry"])
        return sqrt(lx * lx + ly * ly)


## پدِ زیر نقطه (دقیقاً داخل بیضی) — برای مالکیت
func _index_at(xz: Vector2) -> int:
        for i in _blocks.size():
                if not (_blocks[i]["aabb"] as Rect2).has_point(xz):
                        continue
                if _pad_norm(i, xz) <= 1.0:
                        return i
        return -1


## نزدیک‌ترین پد با تلورانس (کلیکِ لبه‌ی پد هم می‌گیرد)
func _nearest_index(xz: Vector2, tol: float) -> int:
        var best := -1
        var best_n := tol
        for i in _blocks.size():
                if not (_blocks[i]["aabb"] as Rect2).grow(0.8).has_point(xz):
                        continue
                var n := _pad_norm(i, xz)
                if n < best_n:
                        best_n = n
                        best = i
        return best


# ================= بصری‌ها =================

func _pad_shader() -> Shader:
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_opaque;
uniform float intensity = 0.62;
uniform vec3 edge_tint = vec3(0.33, 0.49, 0.25);
void fragment() {
        vec2 p = UV - vec2(0.5);
        float d = length(p * 2.0);
        float a = 1.0 - smoothstep(0.82, 1.0, d);
        // دو-تُن: مرکزِ روشن‌تر، حاشیه‌ی تیره‌تر — لکه‌ی چمنِ زنده
        vec3 col = COLOR.rgb * mix(1.06, 0.82, smoothstep(0.25, 1.0, d));
        col = mix(col, edge_tint, smoothstep(0.86, 1.0, d) * 0.45);
        ALBEDO = col;
        ALPHA = a * intensity;
}
"""
        return sh


func _build_visuals() -> void:
        var pm := PlaneMesh.new()
        pm.size = Vector2(2.0, 2.0)
        pm.subdivide_width = 0
        pm.subdivide_depth = 0
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.use_colors = true
        mm.mesh = pm
        mm.instance_count = maxi(_blocks.size(), 1)
        var rng := RandomNumberGenerator.new()
        rng.seed = _seed_value + 77
        for i in _blocks.size():
                mm.set_instance_transform(i, _pad_transform(_blocks[i]))
                var base := GameConstants.COL_PAD_LIGHT.lerp(
                                GameConstants.COL_PAD_DARK, rng.randf())
                mm.set_instance_color(i, base)
        _mmi = MultiMeshInstance3D.new()
        _mmi.multimesh = mm
        _pad_mat = ShaderMaterial.new()
        _pad_mat.shader = _pad_shader()
        _pad_mat.set_shader_parameter("intensity", 0.62)
        _mmi.material_override = _pad_mat
        _mmi.visible = not _blocks.is_empty()
        add_child(_mmi)

        # هاور — همان بیضی پرنورتر روی پدِ زیر ماوس
        _hover_mesh = MeshInstance3D.new()
        _hover_mesh.mesh = pm
        _hover_mat = ShaderMaterial.new()
        _hover_mat.shader = _pad_shader()
        _hover_mat.set_shader_parameter("intensity", 1.15)
        _hover_mesh.material_override = _hover_mat
        _hover_mesh.visible = false
        add_child(_hover_mesh)


## ترنسفورم هم‌راستا با شیب زمین (تیلت) + lift — الگوی CommandGrid
func _pad_transform(b: Dictionary) -> Transform3D:
        var center: Vector2 = b["center"]
        var rx: float = b["rx"]
        var ry: float = b["ry"]
        var h00 := _ground.height_at_world(center + Vector2(-rx, -ry))
        var h10 := _ground.height_at_world(center + Vector2(rx, -ry))
        var h01 := _ground.height_at_world(center + Vector2(-rx, ry))
        var h11 := _ground.height_at_world(center + Vector2(rx, ry))
        var dx := Vector3(2.0 * rx, h10 - h00, 0.0)
        var dz := Vector3(0.0, h11 - h01, 2.0 * ry)
        var n := dx.cross(dz).normalized()
        if n.y < 0.0:
                n = -n
        var x_axis := Vector3(1, 0, 0) - n * n.x
        x_axis = x_axis.normalized() if x_axis.length() > 0.001 else Vector3(1, 0, 0)
        var z_axis := x_axis.cross(n).normalized()
        var basis := Basis(x_axis, n, z_axis)
        basis = basis.rotated(n, float(b["rot"]))
        var mid_h := _ground.height_at_world(center)
        return Transform3D(basis,
                        Vector3(center.x, mid_h + LIFT, center.y)) \
                        .scaled_local(Vector3(b["rx"], 1.0, b["ry"]))


# ================= حالت فرمان و هاور =================

func set_command_mode(on: bool) -> void:
        _command = on
        if _pad_mat != null:
                _pad_mat.set_shader_parameter("intensity", 0.9 if on else 0.62)
        if not on:
                _clear_hover()


func is_command_mode() -> bool:
        return _command


func _clear_hover() -> void:
        _hover_index = -1
        if _hover_mesh != null:
                _hover_mesh.visible = false


func hover_at_world(xz: Vector2) -> Dictionary:
        var info := block_at_world(xz)
        if not bool(info.get("ok", false)):
                _clear_hover()
                return info
        var idx := int(info["index"])
        if idx != _hover_index:
                _hover_index = idx
                _hover_mesh.transform = _pad_transform(_blocks[idx])
                _hover_mesh.visible = true
        return info


# ================= پرس‌وجو (سازگار با API قبلی) =================

## پدِ زیر نقطه‌ی جهانی — با تلورانسِ لبه (کلیکِ حاشیه‌ی پد هم ثبت می‌شود)
func block_at_world(xz: Vector2) -> Dictionary:
        if _ground == null or cell_count == 0 or _nav == null:
                return {"ok": false}
        var i := _nearest_index(xz, PICK_TOLERANCE)
        if i < 0:
                return {"ok": false}
        var b := _blocks[i]
        return {"ok": true, "index": i, "center": b["spot"], "top": b["top"]}


func cell_at_world(xz: Vector2) -> Dictionary:
        return block_at_world(xz)


func cell_info(index: int) -> Dictionary:
        if index < 0 or index >= _blocks.size():
                return {}
        var b := _blocks[index]
        return {"cc": Vector2i(index, 0), "center": b["spot"], "top": b["top"]}


func tiles_visible() -> bool:
        return _mmi != null and _mmi.visible


func beam_instance_count() -> int:
        if _mmi == null or _mmi.multimesh == null:
                return 0
        return int(_mmi.multimesh.instance_count)


# ================= ثبتِ اشغال پد (هر سرباز = یک بلوک) =================

## نزدیک‌ترین پدِ «آزاد» به نقطه — خروجی: نقطه‌ی نشستِ پدِ تصاحب‌شده
## گام ۶R6 — from_xz: پدهایی که مسیرِ مستقیمِ باز به سرباز دارند ارجح‌اند
func claim_unique_block(xz: Vector2, owner_id: int, max_r := 2.2,
                from_xz := Vector2.INF) -> Vector2:
        release_owner(owner_id)
        if _nav == null or cell_count == 0:
                return xz
        var best := -1
        var best_d := max_r
        var best_clear := -1
        var best_clear_d := max_r
        for i in _blocks.size():
                if _claims.has(i):
                        continue
                var spot: Vector2 = _blocks[i]["spot"]
                if not _nav.is_walkable(_nav.world_to_cell(spot)):
                        continue
                var d := spot.distance_to(xz)
                if d >= best_d and d >= best_clear_d:
                        continue
                var clear := from_xz != Vector2.INF and _straight_clear(from_xz, spot)
                if clear:
                        if d < best_clear_d:
                                best_clear_d = d
                                best_clear = i
                if d < best_d:
                        best_d = d
                        best = i
        var pick := best_clear if best_clear >= 0 else best
        # پاس دوم با شعاع دوبرابر: کنارِ خانه‌ها پدِ آزادِ نزدیک کم است
        if pick < 0 and max_r < 5.0:
                return claim_unique_block(xz, owner_id, max_r * 2.0, from_xz)
        if pick < 0:
                return xz
        _claims[pick] = owner_id
        return _blocks[pick]["spot"]


## پدِ claimedِ یک مالک — برای تست «سرباز داخل بلوکِ خودش»
func spot_of_owner(owner_id: int) -> Vector2:
        for i in _claims:
                if int(_claims[i]) == owner_id:
                        return _blocks[i]["spot"]
        return Vector2.INF


## پاره‌خطِ مستقیمِ بدون سلولِ بلاک (نمونه‌برداری ۰٫۳۵m — قرارداد گاریسون)
func _straight_clear(a: Vector2, b: Vector2) -> bool:
        var dist := a.distance_to(b)
        if dist < 0.3:
                return true
        var steps := maxi(int(dist / 0.35), 2)
        for i in range(1, steps + 1):
                var k := float(i) / float(steps)
                var p := a.lerp(b, k)
                if not _nav.is_walkable(_nav.world_to_cell(p)):
                        return false
        return true


## سازگاری با فراخوانی قدیمی صحنه
func claim_unique_tile(xz: Vector2, owner_id: int, max_r := 2.2,
                from_xz := Vector2.INF) -> Vector2:
        return claim_unique_block(xz, owner_id, max_r, from_xz)


func owner_of(index: int) -> int:
        return int(_claims.get(index, -2))


func owner_at_world(xz: Vector2) -> int:
        var i := _index_at(xz)
        return int(_claims.get(i, -2)) if i >= 0 else -2


func release_owner(owner_id: int) -> void:
        var dead: Array = []
        for i in _claims:
                if int(_claims[i]) == owner_id:
                        dead.append(i)
        for i in dead:
                _claims.erase(i)


## آزادسازی همه به‌جز پدهای خانه‌ها (بازتولید جزیره)
func release_all_claims() -> void:
        var dead: Array = []
        for i in _claims:
                if int(_claims[i]) != OWNER_OCCUPIED:
                        dead.append(i)
        for i in dead:
                _claims.erase(i)


## برای تست خودکار: تعداد پدهای اشغال‌شده توسط سربازان (بدون خانه‌ها)
func claim_count() -> int:
        var n := 0
        for i in _claims:
                if int(_claims[i]) != OWNER_OCCUPIED:
                        n += 1
        return n
