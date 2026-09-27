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

## گام ۶R۱۵ — ماسکِ یال‌های حرکت (bit: 1=E، 2=W، 4=S، 8=N؛ پیش‌فرض ۱۵):
## پرتگاهِ دوبلکس «گره‌ها» را نمی‌بندد (سرباز باید بتواند روی لبه‌ی سقف
## بایستد) — فقط «عبورِ» بین دو سطح قطع می‌شود، مگر از مسیرِ شیب.
const EDGE_E := 1
const EDGE_W := 2
const EDGE_S := 4
const EDGE_N := 8
const EDGE_ALL := 15
var edge_ok: PackedInt32Array = PackedInt32Array()

## هزینه‌ی عبور از هر سلول (§۳.۲ پرامت فاز اول):
##   چمن 1.0 | شن ساحل 1.2 | صخره‌ی کم‌ارتفاع 1.5 | آب/صخره بلند = غیرقابل‌عبور
var costs: PackedFloat32Array = PackedFloat32Array()


func setup(w: int, h: int, cell: float, world_origin: Vector2) -> void:
        width = w
        height = h
        cell_size = cell
        origin = world_origin
        walkable.resize(w * h)
        walkable.fill(1)
        costs.resize(w * h)
        costs.fill(1.0)
        edge_ok.resize(w * h)
        edge_ok.fill(EDGE_ALL)


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


func set_cost(c: Vector2i, value: float) -> void:
        if in_bounds(c):
                costs[idx(c)] = maxf(value, 0.05)


func cost_at(c: Vector2i) -> float:
        if not in_bounds(c):
                return 1.0
        return costs[idx(c)]


## ماسکِ یالِ سلول — بیرونِ گرید = هیچ
func edge_mask_at(c: Vector2i) -> int:
        if not in_bounds(c):
                return 0
        return edge_ok[idx(c)]


## گام ۶R۱۵b — سطحِ سلول برای میدانِ جریان (۰ پایین/۱ سقف/۲ شیب)
var level_field: PackedInt32Array = PackedInt32Array()

func set_level_field(lv: PackedInt32Array) -> void:
        level_field = lv


func snapshot_level_field() -> PackedInt32Array:
        return level_field.duplicate()


func set_edge_mask(c: Vector2i, mask: int) -> void:
        if in_bounds(c):
                edge_ok[idx(c)] = mask & EDGE_ALL


## قطعِ یالِ دوطرفه‌ی a↔b (a و b همسایه‌ی ۴جهته)
func cut_edge(a: Vector2i, b: Vector2i) -> void:
        if not in_bounds(a) or not in_bounds(b):
                return
        var d := b - a
        if d == Vector2i(1, 0):
                edge_ok[idx(a)] &= ~EDGE_E
                edge_ok[idx(b)] &= ~EDGE_W
        elif d == Vector2i(-1, 0):
                edge_ok[idx(a)] &= ~EDGE_W
                edge_ok[idx(b)] &= ~EDGE_E
        elif d == Vector2i(0, 1):
                edge_ok[idx(a)] &= ~EDGE_S
                edge_ok[idx(b)] &= ~EDGE_N
        elif d == Vector2i(0, -1):
                edge_ok[idx(a)] &= ~EDGE_N
                edge_ok[idx(b)] &= ~EDGE_S


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


func snapshot_costs() -> PackedFloat32Array:
        return costs.duplicate()


func snapshot_edge_ok() -> PackedInt32Array:
        return edge_ok.duplicate()
