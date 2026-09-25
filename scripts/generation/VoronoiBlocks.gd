class_name VoronoiBlocks
extends Node3D
## بلوک‌های زمین — گام ۶R6 (بازخورد کاربر: «تعریف دقیق شکل هندسی بلوک‌ها»):
##
##   * بلوک‌ها شبکه‌ی شطرنجی نیستند و مستطیل/مربع هم نیستند — «چندضلعی‌های
##     نامنظم و مسطح» (Voronoi) هستند که مثل قطعات پازل، سطح جزیره را می‌سازند
##   * اضلاعِ نامساوی، زاویه‌های غیر-۹۰ درجه؛ هر بلوک از طریق «لبه‌ی مشترک» به
##     همسایه‌اش می‌چسبد — هیچ فاصله یا شبکه‌ای بین بلوک‌ها وجود ندارد
##   * رویه‌ی بالایی هر بلوک کاملاً صاف است تا سرباز رویش بایستد
##   * مرکزِ متقارن ندارند؛ برای ایستادن، هر بلوک یک «نقطه‌ی نشست» walkable دارد
##   * هر سربازِ ایستاده دقیقاً یک بلوک را تصاحب می‌کند؛ خانه هم بلوکِ خودش را
##     دارد (سایتِ ورونویِ خانه = مرکز خانه → خانه هرگز به سرباز نمی‌رسد)
##   * کلیک: پرتوِ پیکینگ زمین → نقطه‌ی برخورد → چندضلعیِ زیر نقطه (point-in-polygon)
##   * هایلایت: نور دقیقاً از «اضلاع» چندضلعیِ زیر ماوس می‌تابد — نه از وسط
##
## پیاده‌سازی: سایت‌های لرزانِ شبکه‌ای (spacing قطعی با seed) → دیاگرام ورونوی
## با برشِ نیم‌صفحه (Sutherland–Hodgman) → برشِ هر سلولِ ورونوی با سلول‌های
## NavGridِ ناحیه → قطعات محدبِ مسطح → یک مشِ vertex-colored (بدون شکاف).

const LIFT := 0.014                       # بلندی پچ روی زمین (ضد z-fight)
const OWNER_OCCUPIED := -1                # بلوکِ خانه‌ها — هرگز به سرباز نمی‌رسد

var cell_count := 0                       # تعداد بلوک‌ها (سازگاری نام قدیمی)

var _ground: IslandGround
var _nav: NavGrid
var _origin := Vector2.ZERO

## هر بلوک: {pieces: Array[PackedVector2Array], spot: Vector2, aabb: Rect2,
##           color: Color, edges: Array[Vector2] جفت‌ها, top: float}
var _blocks: Array[Dictionary] = []
var _claims: Dictionary = {}              # index → owner_id
var _command := false
var _hover_index := -1

var _patch_mesh: MeshInstance3D           # سطح بلوک‌ها (همیشه نمایان)
var _seam_mesh: MeshInstance3D            # درزِ تیره‌ی لبه‌های مشترک
var _hover_fill: MeshInstance3D
var _hover_edges: MeshInstance3D
var _seam_mat: ShaderMaterial
var _hover_fill_mat: ShaderMaterial
var _hover_edge_mat: ShaderMaterial

var _rng := RandomNumberGenerator.new()


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
        # قطعیِ کامل با seed جزیره — صحنه قبل از rebuild با set_island_seed می‌دهد
        rng.seed = _seed_value

        # ---- ۱) ناحیه: سلول‌های walkable + سلول‌های خانه‌ها (۲×۲) ----
        var region := {}
        for cy in ground.size:
                for cx in ground.size:
                        if nav.is_walkable(Vector2i(cx, cy)):
                                region[Vector2i(cx, cy)] = true
        for site in house_sites:
                for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
                        region[site + d] = true

        # ---- ۲) سایت‌های ورونوی: شبکه‌ی لرزان + مرکزِ دقیق خانه‌ها ----
        var sites: Array[Vector2] = []
        var site_spacing := GameConstants.BLOCK_SITE_SPACING
        var jitter := GameConstants.BLOCK_SITE_JITTER
        var gx0 := _origin.x
        var gy0 := _origin.y
        var gsz := float(ground.size) * nav.cell_size
        var gy := 0.0
        while gy < gsz:
                var gx := 0.0
                while gx < gsz:
                        var p := Vector2(gx0 + gx + rng.randf_range(-jitter, jitter),
                                        gy0 + gy + rng.randf_range(-jitter, jitter))
                        sites.append(p)
                        gx += site_spacing
                gy += site_spacing
        var house_centers: Array[Vector2] = []
        for site in house_sites:
                var hc := nav.origin + (Vector2(site) + Vector2(1.0, 1.0)) * nav.cell_size
                house_centers.append(hc)
                sites.append(hc)

        # ---- ۳) مالکیتِ قطعی: هر سلولِ ناحیه به نزدیک‌ترین سایت تعلق دارد؛
        # فقط سایت‌های «مالکِ» حداقل یک سلولِ ناحیه بلوک می‌شوند (ضدِ تیکه‌های ریز)
        var owners: Array[Vector2] = []
        var site_owner_flags: Dictionary = {}
        for c in region:
                var cc := nav.cell_center(c)
                var best_i := -1
                var best_d := 1e9
                for i in sites.size():
                        var d := sites[i].distance_to(cc)
                        if d < best_d:
                                best_d = d
                                best_i = i
                if best_i >= 0 and not site_owner_flags.has(best_i):
                        site_owner_flags[best_i] = true
                        owners.append(sites[best_i])
        var candidates: Array[Vector2] = owners
        # سایت‌های خانه همیشه کاندیدند (خانه = یک بلوک کامل)
        for hc in house_centers:
                if not candidates.has(hc):
                        candidates.append(hc)

        # ---- ۴) چندضلعی ورونویِ هر سایت (برش نیم‌صفحه با همسایه‌ها) ----
        var clip_r := site_spacing * 2.2
        var polys: Array = []          # index در candidates → PackedVector2Array
        for i in candidates.size():
                var site := candidates[i]
                var poly := _box_poly(site, site_spacing * 1.6)
                for j in candidates.size():
                        if i == j:
                                continue
                        var other := candidates[j]
                        if other.distance_to(site) > clip_r:
                                continue
                        var n := (other - site).normalized()
                        poly = _clip_halfplane(poly, (site + other) * 0.5, n)
                        if poly.size() < 3:
                                break
                polys.append(poly)

        # ---- ۵) برش هر چندضلعی با سلول‌های ناحیه → قطعات مسطحِ بلوک ----
        # (چون فقط سایت‌های «مالک» برش‌گرند، اجتماعِ قطعات هر سلولِ ناحیه را
        # «کامل» می‌پوشاند — هیچ شکاف یا لبه‌ی عریانی بین بلوک‌ها نمی‌ماند)
        for i in candidates.size():
                var poly: PackedVector2Array = polys[i]
                if poly.size() < 3:
                        continue
                var bb := _poly_aabb(poly).grow(1.2)
                var pieces: Array[PackedVector2Array] = []
                for c in region:
                        var cc := nav.cell_center(c)
                        if not bb.has_point(cc):
                                continue
                        var piece := _clip_square(poly, cc, nav.cell_size)
                        if piece.size() >= 3:
                                pieces.append(piece)
                if pieces.is_empty():
                        continue
                # نقطه‌ی نشست: مرکزِ سلولِ walkableِ داخل بلوک، نزدیک به centroid؛
                # پشتیبانِ ۱: نزدیک‌ترین سلولِ walkable به centroid (تا ۲.۵m)؛
                # پشتیبانِ ۲: خودِ centroid (بلوکِ فقط-خانه — اسپاتش استفاده نمی‌شود)
                var spot := _block_spot(pieces, nav, bb)
                if not nav.is_walkable(nav.world_to_cell(spot)):
                        var centroid := _pieces_centroid(pieces)
                        var wspot := _nearest_walkable_center(nav, centroid, 2.5)
                        spot = wspot if wspot != Vector2.INF else centroid
                var aabb := Rect2()
                var first := true
                for piece in pieces:
                        var pb := _poly_aabb(piece)
                        if first:
                                aabb = pb
                                first = false
                        else:
                                aabb = aabb.merge(pb)
                var col := _grass_color(rng)
                _blocks.append({"pieces": pieces, "spot": spot, "aabb": aabb,
                                "color": col, "top": _ground.height_at_world(spot),
                                "edges": []})
        cell_count = _blocks.size()

        # خانه‌ها: بلوکی که مرکزِ خانه داخلش است → اشغال دائمی
        for hc in house_centers:
                var bi := _index_at(hc)
                if bi >= 0:
                        _claims[bi] = OWNER_OCCUPIED

        _build_latches()   # لبه‌های مرزی هر بلوک (برای درز و هایلایت)
        _build_visuals()


## seed قطعی — صحنه قبل از rebuild ست می‌کند
var _seed_value := 20260924
func set_island_seed(seed_value: int) -> void:
        _seed_value = seed_value


func _grass_color(rng: RandomNumberGenerator) -> Color:
        var base := GameConstants.COL_GRASS_LIGHT.lerp(GameConstants.COL_GRASS_DARK,
                        rng.randf())
        return base.lerp(Color("a8c070"), rng.randf() * 0.25)


func _box_poly(center: Vector2, half: float) -> PackedVector2Array:
        var p := PackedVector2Array()
        p.append(center + Vector2(-half, -half))
        p.append(center + Vector2(half, -half))
        p.append(center + Vector2(half, half))
        p.append(center + Vector2(-half, half))
        return p


## برش چندضلعیِ محدب با نیم‌صفحه‌ی {(p - p0)·n ≤ 0} — Sutherland–Hodgman
func _clip_halfplane(poly: PackedVector2Array, p0: Vector2, n: Vector2) -> PackedVector2Array:
        var out := PackedVector2Array()
        if poly.size() < 3:
                return out
        for i in poly.size():
                var a := poly[i]
                var b := poly[(i + 1) % poly.size()]
                var da := (a - p0).dot(n)
                var db := (b - p0).dot(n)
                if da <= 0.0:
                        out.append(a)
                if (da < 0.0 and db > 0.0) or (da > 0.0 and db < 0.0):
                        var t := da / (da - db)
                        out.append(a.lerp(b, t))
        return out


## برش چندضلعی با مربعِ سلول NavGrid (چهار نیم‌صفحه‌ی محوری)
func _clip_square(poly: PackedVector2Array, center: Vector2, cell: float) -> PackedVector2Array:
        var h := cell * 0.5
        var p := _clip_halfplane(poly, center + Vector2(-h, 0.0), Vector2(-1, 0))
        p = _clip_halfplane(p, center + Vector2(h, 0.0), Vector2(1, 0))
        p = _clip_halfplane(p, center + Vector2(0.0, -h), Vector2(0, -1))
        p = _clip_halfplane(p, center + Vector2(0.0, h), Vector2(0, 1))
        return p


func _poly_aabb(poly: PackedVector2Array) -> Rect2:
        var r := Rect2(poly[0], Vector2.ZERO)
        for i in range(1, poly.size()):
                r = r.expand(poly[i])
        return r


func _block_spot(pieces: Array[PackedVector2Array], nav: NavGrid, bb: Rect2) -> Vector2:
        var centroid := _pieces_centroid(pieces)
        var best := centroid
        var best_d := 1e9
        var cells := int(ceil(bb.size.length() / nav.cell_size)) + 2
        var base := nav.world_to_cell(bb.get_center())
        for dy in range(-cells, cells + 1):
                for dx in range(-cells, cells + 1):
                        var c := base + Vector2i(dx, dy)
                        if not nav.is_walkable(c):
                                continue
                        var cc := nav.cell_center(c)
                        if not _point_in_pieces(cc, pieces):
                                continue
                        var d := cc.distance_to(centroid)
                        if d < best_d:
                                best_d = d
                                best = cc
        return best


func _pieces_centroid(pieces: Array[PackedVector2Array]) -> Vector2:
        var centroid := Vector2.ZERO
        var w := 0.0
        for piece in pieces:
                var a := _poly_aabb(piece)
                centroid += a.get_center() * a.get_area()
                w += a.get_area()
        return centroid / w if w > 0.0 else centroid


func _nearest_walkable_center(nav: NavGrid, from: Vector2, max_r: float) -> Vector2:
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
                        if d < best_d:
                                best_d = d
                                best = cc
        return best


func _point_in_pieces(p: Vector2, pieces: Array[PackedVector2Array]) -> bool:
        for piece in pieces:
                var pc: PackedVector2Array = piece
                if _point_in_convex(p, pc):
                        return true
        return false


## نقطه در چندضلعیِ محدب (ترتیب پادساعتگردِ برشِ SH حفظ می‌شود)
func _point_in_convex(p: Vector2, poly: PackedVector2Array) -> bool:
        if poly.size() < 3:
                return false
        var has_pos := false
        var has_neg := false
        for i in poly.size():
                var a := poly[i]
                var b := poly[(i + 1) % poly.size()]
                var cross := (b - a).cross(p - a)
                if cross > 0.0001:
                        has_pos = true
                elif cross < -0.0001:
                        has_neg = true
                else:
                        continue
        return not (has_pos and has_neg)


func _index_at(xz: Vector2) -> int:
        for i in _blocks.size():
                var b := _blocks[i]
                if not (b["aabb"] as Rect2).has_point(xz):
                        continue
                if _point_in_pieces(xz, b["pieces"]):
                        return i
        return -1


# ================= لبه‌های مرزی (درز + هایلایت) =================

## هر ضلعِ قطعه که «یک سمتش بیرون از همین بلوک» است = لبه‌ی مرزی بلوک.
## این لبه‌ها هم درزِ تیره‌ی همیشگی‌اند و هم مسیرِ نورِ هایلایت.
func _build_latches() -> void:
        var step := 0.045
        for bi in _blocks.size():
                var edges: Array = []
                for piece in _blocks[bi]["pieces"]:
                        var pc: PackedVector2Array = piece
                        for i in pc.size():
                                var a: Vector2 = pc[i]
                                var b2: Vector2 = pc[(i + 1) % pc.size()]
                                var mid := (a + b2) * 0.5
                                var dir := (b2 - a).normalized()
                                var perp := Vector2(-dir.y, dir.x)
                                var same := 0
                                for sgn in [1.0, -1.0]:
                                        var probe: Vector2 = mid + perp * sgn * step
                                        if _index_at(probe) == bi:
                                                same += 1
                                if same < 2:
                                        edges.append([a, b2])
                _blocks[bi]["edges"] = edges


# ================= بصری‌ها =================

func _build_visuals() -> void:
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var seam_st := SurfaceTool.new()
        seam_st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var seam_col := GameConstants.COL_GRASS_DARK.lerp(Color(0.13, 0.18, 0.1), 0.45)
        seam_col.a = 0.55
        for bi in _blocks.size():
                var b := _blocks[bi]
                var col: Color = b["color"]
                for piece in b["pieces"]:
                        var pc: PackedVector2Array = piece
                        for k in range(1, pc.size() - 1):
                                _patch_tri(st, pc[0], pc[k], pc[k + 1], col)
                # درز روی لبه‌های مرزی (نوارِ باریک روی زمین — شکاف نیست)
                var hw := GameConstants.BLOCK_SEAM_W * 0.5
                for e in b["edges"]:
                        var e0: Vector2 = e[0]
                        var e1: Vector2 = e[1]
                        _ribbon(seam_st, e0, e1, hw, seam_col)
        var mesh := st.commit()
        _patch_mesh = MeshInstance3D.new()
        _patch_mesh.mesh = mesh
        var mat := StandardMaterial3D.new()
        mat.vertex_color_use_as_albedo = true
        mat.roughness = 1.0
        _patch_mesh.material_override = mat
        add_child(_patch_mesh)

        var seam_mesh := seam_st.commit()
        _seam_mesh = MeshInstance3D.new()
        _seam_mesh.mesh = seam_mesh
        _seam_mat = ShaderMaterial.new()
        _seam_mat.shader = _seam_shader()
        _seam_mat.set_shader_parameter("intensity", 0.55)
        _seam_mesh.material_override = _seam_mat
        add_child(_seam_mesh)

        # هایلایت — پرشدگی خیلی ملایم + نورِ دقیقاً از اضلاع
        _hover_fill = MeshInstance3D.new()
        _hover_fill_mat = ShaderMaterial.new()
        _hover_fill_mat.shader = _hover_fill_shader()
        _hover_fill.material_override = _hover_fill_mat
        _hover_fill.visible = false
        add_child(_hover_fill)

        _hover_edges = MeshInstance3D.new()
        _hover_edge_mat = ShaderMaterial.new()
        _hover_edge_mat.shader = _edge_glow_shader()
        _hover_edges.material_override = _hover_edge_mat
        _hover_edges.visible = false
        add_child(_hover_edges)


func _patch_tri(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
        for v0 in [a, b, c]:
                var v: Vector2 = v0
                st.set_color(col)
                st.set_normal(Vector3.UP)
                st.add_vertex(Vector3(v.x, _ground.height_at_world(v) + LIFT, v.y))


func _ribbon(st: SurfaceTool, a: Vector2, b: Vector2, half_w: float, col: Color) -> void:
        var dir := (b - a).normalized()
        if dir.length() < 0.001:
                return
        var perp := Vector2(-dir.y, dir.x) * half_w
        var pts := [
                [a + perp, a - perp, b - perp],
                [a + perp, b - perp, b + perp],
        ]
        for tri in pts:
                for v0 in tri:
                        var v: Vector2 = v0
                        st.set_color(col)
                        st.set_normal(Vector3.UP)
                        st.add_vertex(Vector3(v.x, _ground.height_at_world(v) + LIFT + 0.004, v.y))


## درز — خط تیره‌ی همیشه‌نمایان روی لبه‌ی مشترک (شکافِ هندسی نیست)
func _seam_shader() -> Shader:
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform float intensity = 0.55;
uniform float pulse_speed = 1.1;
void fragment() {
        float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed);
        ALBEDO = vec3(0.16, 0.22, 0.13);
        ALPHA = intensity * pulse * 0.55;
}
"""
        return sh


## پرشدگی ملایمِ بلوکِ زیر ماوس (وسط تقریباً تاریک می‌ماند — نور از اضلاع)
func _hover_fill_shader() -> Shader:
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void fragment() {
        ALBEDO = vec3(1.0, 0.84, 0.52);
        ALPHA = 0.07;
}
"""
        return sh


## نورِ لبه‌ای — فقط نوارِ درخشان روی اضلاعِ چندضلعیِ زیر ماوس
func _edge_glow_shader() -> Shader:
        var sh := Shader.new()
        sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float intensity = 0.9;
uniform float pulse_speed = 4.0;
void fragment() {
        float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
        ALBEDO = vec3(1.0, 0.86, 0.54);
        ALPHA = intensity * pulse;
}
"""
        return sh


# ================= حالت فرمان و هاور =================

func set_command_mode(on: bool) -> void:
        _command = on
        if _seam_mat != null:
                _seam_mat.set_shader_parameter("intensity", 0.8 if on else 0.55)
        if not on:
                _clear_hover()


func is_command_mode() -> bool:
        return _command


func _clear_hover() -> void:
        _hover_index = -1
        if _hover_fill != null:
                _hover_fill.visible = false
        if _hover_edges != null:
                _hover_edges.visible = false


func hover_at_world(xz: Vector2) -> Dictionary:
        var info := block_at_world(xz)
        if not bool(info.get("ok", false)):
                _clear_hover()
                return info
        var idx := int(info["index"])
        if idx != _hover_index:
                _hover_index = idx
                _rebuild_hover(idx)
        return info


func _rebuild_hover(idx: int) -> void:
        var b := _blocks[idx]
        # پرشدگی ملایم
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for piece in b["pieces"]:
                var pc: PackedVector2Array = piece
                for k in range(1, pc.size() - 1):
                        _patch_tri(st, pc[0], pc[k], pc[k + 1], Color.WHITE)
        var fm := st.commit()
        _hover_fill.mesh = fm
        _hover_fill.visible = fm != null
        # نوار نور روی اضلاع
        var st2 := SurfaceTool.new()
        st2.begin(Mesh.PRIMITIVE_TRIANGLES)
        var hw := GameConstants.BLOCK_SEAM_W * 0.75
        for e in b["edges"]:
                _ribbon(st2, e[0], e[1], hw, Color.WHITE)
        var em := st2.commit()
        _hover_edges.mesh = em
        _hover_edges.visible = em != null


# ================= پرس‌وجو (سازگار با API قبلی CommandGrid) =================

## چندضلعیِ زیر نقطه‌ی جهانی — خروجی سازگار با cell_at_world قبلی
func block_at_world(xz: Vector2) -> Dictionary:
        if _ground == null or cell_count == 0 or _nav == null:
                return {"ok": false}
        var i := _index_at(xz)
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
        return _patch_mesh != null and _patch_mesh.visible


func beam_instance_count() -> int:
        return cell_count


# ================= ثبتِ اشغال بلوک (هر سرباز = یک بلوک) =================

## نزدیک‌ترین بلوکِ «آزاد» به نقطه — خروجی: نقطه‌ی نشستِ بلوکِ تصاحب‌شده
## (سرباز آیدل دقیقاً داخل چندضلعیِ بلوکِ خودش می‌ایستد)
## گام ۶R6 — from_xz: موقعیتِ سرباز؛ بلوک‌هایی که مسیرِ مستقیمِ باز به سرباز
## دارند ارجح‌اند (ضدِ اسلاتِ آن‌طرفِ خانه/صخره — همان درسِ گاریسونِ گام ۶R)
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
        # گام ۶R6 — پاس دوم با شعاع دوبرابر: کنارِ خانه‌ها بلوکِ آزادِ نزدیک کم است
        # (تکمیلِ گاریسون) — تا بلوکِ آزادِ در دسترس پیدا شود
        if pick < 0 and max_r < 5.0:
                return claim_unique_block(xz, owner_id, max_r * 2.0, from_xz)
        if pick < 0:
                return xz
        _claims[pick] = owner_id
        return _blocks[pick]["spot"]


## بلوکِ claimedِ یک مالک — برای تست «سرباز داخل بلوکِ خودش»
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


## آزادسازی همه به‌جز بلوک‌های خانه‌ها (بازتولید جزیره)
func release_all_claims() -> void:
        var dead: Array = []
        for i in _claims:
                if int(_claims[i]) != OWNER_OCCUPIED:
                        dead.append(i)
        for i in dead:
                _claims.erase(i)


## برای تست خودکار: تعداد بلوک‌های اشغال‌شده توسط سربازان (بدون خانه‌ها)
func claim_count() -> int:
        var n := 0
        for i in _claims:
                if int(_claims[i]) != OWNER_OCCUPIED:
                        n += 1
        return n
