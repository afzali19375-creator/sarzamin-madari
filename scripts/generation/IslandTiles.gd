class_name IslandTiles
extends Node3D
## گام ۴ — نمای کاشی‌های جزیره: رندر با MultiMesh (یک draw call)،
## پیکینگ فیزیکی تک‌تک کاشی‌ها (همه‌ی بلوک‌ها قابل‌کلیک‌اند) و
## هایلایت هاور با تغییر رنگ نمونه‌ی همان کاشی.
##
## نگاشت مختصات دقیقاً همان NavGrid است: origin + (cell + 0.5) * cell_size.

var size := 0

var _island: Dictionary = {}
var _cell := 1.0
var _origin := Vector2.ZERO
var _mmi: MultiMeshInstance3D
var _base := PackedColorArray()
var _hover := Vector2i(-1, -1)
var _body: StaticBody3D
var _shape_to_cell: Array[Vector2i] = []
var _shape_cache: Dictionary = {}


## ساخت/بازسازی کامل کاشی‌ها از نتیجه‌ی WfcIsland (در regenerate دوباره صدا زده می‌شود)
func build(island: Dictionary, cell_size: float, world_origin: Vector2) -> void:
	for c in get_children():
		c.free()
	_island = island
	_cell = cell_size
	_origin = world_origin
	size = int(island["size"])
	_hover = Vector2i(-1, -1)
	_shape_to_cell.clear()
	_shape_cache.clear()

	var n := size * size
	var colors: Array = island["meta_colors"]
	var hsh := int(island["hash"]) % 100000
	_base = PackedColorArray()
	_base.resize(n)
	for i in n:
		# لرزش رنگی قطعی (Deterministic) برای حس ارگانیک — با hash جزیره
		var j := fposmod(sin(float(i) * 12.9898 + float(hsh) * 0.017) * 43758.5453, 1.0)
		var c: Color = colors[int(island["modules"][i])]
		_base[i] = c * (0.92 + 0.14 * j)

	# --- رندر ---
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(_cell * 0.98, 1.0, _cell * 0.98)
	mm.mesh = bm
	mm.instance_count = n
	for i in n:
		var x := i % size
		var y := int(i / float(size))
		var top := float(_island["tops"][i])
		var h := maxf(top, 0.12)
		var center := _origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * _cell
		var t := Transform3D(Basis.from_scale(Vector3(1.0, h, 1.0)), Vector3(center.x, top - h * 0.5, center.y))
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, _base[i])
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	_mmi.material_override = mat
	add_child(_mmi)

	# --- پیکینگ فیزیکی: هر کاشی یک BoxShape (اشتراک شکل بر اساس ارتفاع) ---
	_body = StaticBody3D.new()
	_body.name = "PickBody"
	for i in n:
		var x := i % size
		var y := int(i / float(size))
		var top := float(_island["tops"][i])
		var h := maxf(top, 0.12)
		var center := _origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * _cell
		var cs := CollisionShape3D.new()
		cs.shape = _shape_for(h)
		cs.position = Vector3(center.x, top - h * 0.5, center.y)
		_body.add_child(cs)
		_shape_to_cell.append(Vector2i(x, y))
	add_child(_body)


func _shape_for(h: float) -> BoxShape3D:
	var key := "%.2f" % h
	if _shape_cache.has(key):
		return _shape_cache[key]
	var sh := BoxShape3D.new()
	sh.size = Vector3(_cell * 0.98, h, _cell * 0.98)
	_shape_cache[key] = sh
	return sh


# ---------------- پرس‌وجو ----------------

func cell_at_world(xz: Vector2) -> Vector2i:
	var local := (xz - _origin) / _cell
	return Vector2i(floori(local.x), floori(local.y))


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size and cell.y < size


func _idx(cell: Vector2i) -> int:
	return cell.y * size + cell.x


func top_at(cell: Vector2i) -> float:
	if not in_bounds(cell):
		return 0.0
	return float(_island["tops"][_idx(cell)])


## ارتفاع زمین در نقطه‌ی جهانی — provider واحدها (TestUnit.ground_provider)
func height_at_world(xz: Vector2) -> float:
	return top_at(cell_at_world(xz))


func walkable_at(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	return int(_island["walkable"][_idx(cell)]) == 1


func module_name_at(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return "out"
	return String(_island["meta_names"][int(_island["modules"][_idx(cell)])])


## پرتاب پرتو از دوربین به ماوس — برخورد با خودِ بلوک‌ها (نه صفحه‌ی تخت)،
## بنابراین کاشیِ «دیده‌شده زیر نشانگر» دقیقاً همان برمی‌گردد.
func ray_pick(cam: Camera3D, mouse: Vector2) -> Dictionary:
	if cam == null or size == 0:
		return {}
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 400.0)
	var hit := space.intersect_ray(q)
	var xz := Vector2.ZERO
	if hit.is_empty():
		var ip = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
		if ip == null:
			return {}
		xz = Vector2(ip.x, ip.z)
	else:
		var p: Vector3 = hit["position"]
		xz = Vector2(p.x, p.z)
	var cell := cell_at_world(xz)
	if not in_bounds(cell):
		return {"in_island": false, "cell": cell}
	var i := _idx(cell)
	return {
		"in_island": true,
		"cell": cell,
		"walkable": int(_island["walkable"][i]) == 1,
		"top": float(_island["tops"][i]),
		"module": String(_island["meta_names"][int(_island["modules"][i])]),
	}


# ---------------- هاور ----------------

func set_hover(cell: Vector2i) -> void:
	if cell == _hover:
		return
	var mm := _mmi.multimesh if _mmi != null else null
	if mm == null:
		return
	if in_bounds(_hover):
		var oi := _idx(_hover)
		mm.set_instance_color(oi, _base[oi])
	_hover = cell
	if in_bounds(cell):
		var i := _idx(cell)
		mm.set_instance_color(i, _base[i].lerp(Color(1.0, 1.0, 1.0), 0.38))
