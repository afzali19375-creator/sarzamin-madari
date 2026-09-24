class_name NavGrid
extends RefCounted
## شبکه‌ی ناوبری مربعی روی صفحه‌ی XZ (دنیای سه‌بعدی، حرکت افقی).
## فقط نخ اصلی آن را می‌نویسد؛ نخ کارگر فقط «اسنپ‌شات» کپی‌شده را می‌خواند.

var width: int = 0
var height: int = 0
var cell_size: float = 1.0
## مختصات جهانی گوشه‌ی سلول (0,0) — روی صفحه‌ی XZ
var origin: Vector2 = Vector2.ZERO

## 1 = قابل عبور، 0 = مانع
var walkable: PackedByteArray = PackedByteArray()


func setup(w: int, h: int, cell: float, world_origin: Vector2) -> void:
	width = w
	height = h
	cell_size = cell
	origin = world_origin
	walkable.resize(w * h)
	walkable.fill(1)


func size_world() -> Vector2:
	return Vector2(width, height) * cell_size


func idx(c: Vector2i) -> int:
	return c.y * width + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func is_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and walkable[idx(c)] == 1


func set_walkable(c: Vector2i, value: bool) -> void:
	if in_bounds(c):
		walkable[idx(c)] = 1 if value else 0


## تبدیل مختصات جهانی (XZ) به سلول — فقط نخ اصلی
func world_to_cell(world_xz: Vector2) -> Vector2i:
	var local := (world_xz - origin) / cell_size
	return Vector2i(floori(local.x), floori(local.y))


## مرکز جهانی یک سلول — فقط نخ اصلی
func cell_center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell_size


## محدود کردن یک نقطه‌ی جهانی به داخل شبکه (با حاشیه)
func clamp_to_grid(world_xz: Vector2, margin: float = 0.3) -> Vector2:
	var min_v := origin + Vector2(margin, margin)
	var max_v := origin + size_world() - Vector2(margin, margin)
	return world_xz.clamp(min_v, max_v)


## کپی امن برای ارسال به نخ کارگر (بدون اشتراک حافظه)
func snapshot_walkable() -> PackedByteArray:
	return walkable.duplicate()
