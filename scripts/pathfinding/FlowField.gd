class_name FlowField
extends RefCounted
## میدان جریان (Flow Field) روی شبکه‌ی ناوبری.
## کاملاً «خالص» است: به درخت صحنه، Autoload یا هیچ نودی وابسته نیست
## و بنابراین امن برای اجرا داخل نخ کارگر.
##
## خروجی دو لایه دارد:
##   integration: هزینه‌ی رسیدن از هر سلول به هدف (Dijkstra با هزینه‌ی قطری)
##   flow       : بردار واحد حرکت برای هر سلول (۸ جهت + ممنوعیت بریدن گوشه)

const INF_COST := 1.0e9
const COST_STRAIGHT := 1.0
const COST_DIAG := 1.41421356
const WALL_HUG_PENALTY := 0.6  # جریمه‌ی چسبیدن به دیوار → مسیرها از دیوار فاصله می‌گیرند

# جهت‌های ۸گانه: ایندکس 0..3 قائم، 4..7 قطری
const DX: PackedInt32Array = [1, -1, 0, 0, 1, 1, -1, -1]
const DY: PackedInt32Array = [0, 0, 1, -1, 1, -1, 1, -1]

var width: int = 0
var height: int = 0
var integration: PackedFloat32Array = PackedFloat32Array()
var flow: PackedVector2Array = PackedVector2Array()

var _invalid := true

# هیپ باینری باز-استفاده‌شونده (بدون تخصیص حافظه در هر محاسبه‌ی معمول)
var _heap_node: PackedInt32Array = PackedInt32Array()
var _heap_key: PackedFloat32Array = PackedFloat32Array()
var _heap_size: int = 0
var _pop_key: float = 0.0


func setup(w: int, h: int) -> void:
	width = w
	height = h
	var n := w * h
	integration.resize(n)
	flow.resize(n)


func is_invalid() -> bool:
	return _invalid


## محاسبه‌ی کامل — از نخ کارگر صدا زده می‌شود.
## walkable: اسنپ‌شاتِ کپی‌شده (مالک انحصاری همین نخ است)؛ goal_cell: سلول هدف.
func compute(w: int, h: int, walkable: PackedByteArray, goal_cell: Vector2i) -> void:
	if w != width or h != height:
		setup(w, h)
	var g := goal_cell
	if not _in_bounds(g) or walkable[g.y * w + g.x] == 0:
		g = _nearest_walkable(walkable, goal_cell)
	_invalid = g.x < 0
	if _invalid:
		integration.fill(INF_COST)
		flow.fill(Vector2.ZERO)
		return
	_dijkstra(w, h, walkable, g)
	_compute_flow(w, h, walkable)


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


## نزدیک‌ترین سلول مجاز به نقطه‌ی درخواستی (BFS حلقه‌ای — قانون: بدون بازگشت/backtrack)
@warning_ignore("integer_division")
func _nearest_walkable(walkable: PackedByteArray, from: Vector2i) -> Vector2i:
	var start := Vector2i(clampi(from.x, 0, width - 1), clampi(from.y, 0, height - 1))
	var si := start.y * width + start.x
	if walkable[si] == 1:
		return start
	var seen := PackedByteArray()
	seen.resize(width * height)
	seen[si] = 1
	var q: Array[Vector2i] = [start]
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		for d in 8:
			var nx := c.x + DX[d]
			var ny := c.y + DY[d]
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var ni := ny * width + nx
			if seen[ni] == 1:
				continue
			seen[ni] = 1
			if walkable[ni] == 1:
				return Vector2i(nx, ny)
			q.append(Vector2i(nx, ny))
	return Vector2i(-1, -1)


## Dijkstra با هیپ باینری + جریمه‌ی دیوار + ممنوعیت بریدن گوشه
@warning_ignore("integer_division")
func _dijkstra(w: int, h: int, walkable: PackedByteArray, goal: Vector2i) -> void:
	var n := w * h
	integration.fill(INF_COST)
	if _heap_node.size() < n * 8 + 16:
		_heap_node.resize(n * 8 + 16)
		_heap_key.resize(n * 8 + 16)
	_heap_size = 0
	var gi := goal.y * w + goal.x
	integration[gi] = 0.0
	_heap_push(gi, 0.0)
	while _heap_size > 0:
		var ci := _heap_pop()
		if _pop_key > integration[ci]:
			continue  # ورودی کهنه‌ی هیپ
		var cost := integration[ci]
		var cx := ci % w
		var cy := (ci - cx) / w
		for d in 8:
			var diag := d >= 4
			var nx := cx + DX[d]
			var ny := cy + DY[d]
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni := ny * w + nx
			if walkable[ni] == 0:
				continue
			if diag:
				# ممنوعیت بریدن گوشه: هر دو همسایه‌ی قائمِ قطر باید آزاد باشند
				var o1 := cy * w + nx
				var o2 := ny * w + cx
				if walkable[o1] == 0 or walkable[o2] == 0:
					continue
			var nc := cost + (COST_DIAG if diag else COST_STRAIGHT)
			if _near_wall(w, h, walkable, nx, ny):
				nc += WALL_HUG_PENALTY
			if nc < integration[ni]:
				integration[ni] = nc
				_heap_push(ni, nc)


## آیا سلول (x,y) به دیوار یا لبه چسبیده است؟
func _near_wall(w: int, h: int, walkable: PackedByteArray, x: int, y: int) -> bool:
	return (x == 0 or walkable[y * w + x - 1] == 0) \
			or (x == w - 1 or walkable[y * w + x + 1] == 0) \
			or (y == 0 or walkable[(y - 1) * w + x] == 0) \
			or (y == h - 1 or walkable[(y + 1) * w + x] == 0)


## ساخت بردارهای جریان: هر سلول به همسایه‌ای اشاره می‌کند که کمترین هزینه را دارد
@warning_ignore("integer_division")
func _compute_flow(w: int, h: int, walkable: PackedByteArray) -> void:
	for y in h:
		for x in w:
			var ci := y * w + x
			var best_i := -1
			var best_c := integration[ci]
			for d in 8:
				var diag := d >= 4
				var nx := x + DX[d]
				var ny := y + DY[d]
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var ni := ny * w + nx
				if walkable[ni] == 0:
					continue
				if diag:
					var o1 := y * w + nx
					var o2 := ny * w + x
					if walkable[o1] == 0 or walkable[o2] == 0:
						continue
				if integration[ni] < best_c:
					best_c = integration[ni]
					best_i = ni
			if best_i >= 0:
				var bx := best_i % w
				var by := (best_i - bx) / w
				flow[ci] = Vector2(float(bx - x), float(by - y)).normalized()
			else:
				flow[ci] = Vector2.ZERO


# ---------------- هیپ باینری ----------------

func _heap_push(node: int, key: float) -> void:
	if _heap_size >= _heap_node.size():
		var nn := _heap_node.duplicate()
		nn.resize(_heap_node.size() * 2)
		_heap_node = nn
		var nk := _heap_key.duplicate()
		nk.resize(_heap_key.size() * 2)
		_heap_key = nk
	var i := _heap_size
	_heap_size += 1
	_heap_node[i] = node
	_heap_key[i] = key
	while i > 0:
		var p := (i - 1) >> 1
		if _heap_key[p] <= _heap_key[i]:
			break
		_heap_swap(i, p)
		i = p


func _heap_pop() -> int:
	var top := _heap_node[0]
	_pop_key = _heap_key[0]
	_heap_size -= 1
	if _heap_size > 0:
		_heap_node[0] = _heap_node[_heap_size]
		_heap_key[0] = _heap_key[_heap_size]
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < _heap_size and _heap_key[l] < _heap_key[m]:
				m = l
			if r < _heap_size and _heap_key[r] < _heap_key[m]:
				m = r
			if m == i:
				break
			_heap_swap(i, m)
			i = m
	return top


func _heap_swap(a: int, b: int) -> void:
	var tn := _heap_node[a]
	_heap_node[a] = _heap_node[b]
	_heap_node[b] = tn
	var tk := _heap_key[a]
	_heap_key[a] = _heap_key[b]
	_heap_key[b] = tk
