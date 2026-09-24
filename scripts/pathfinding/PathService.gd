extends Node
## سرویس سراسری مسیریابی (Autoload) — مالک NavGrid و FlowFieldThread.
## واحدها فقط با این سرویس کار می‌کنند و هرگز مستقیم به نخ کارگر دست نمی‌زنند.
##
## ریتم به‌روزرسانی: هر 0.2 ثانیه (قانون سند طراحی) یک اسنپ‌شات تازه به
## نخ پایدار پست می‌شود؛ درخواست‌های فوری (تغییر هدف) بین همین تیک‌ها
## بلافاصله ارسال و در کارگر «هم‌دسته» (coalesce) می‌شوند.

const RECOMPUTE_INTERVAL := GameConstants.FIELD_RECOMPUTE_INTERVAL

var nav: NavGrid
var field_thread: FlowFieldThread
var auto_recompute := true

var _grid_ready := false
var _last_goal_world := Vector2.ZERO
var _accum := 0.0
var _last_read_ms := 0.0


func setup_grid(w: int, h: int, cell_size: float, world_origin: Vector2) -> void:
        if _grid_ready and nav != null and nav.width == w and nav.height == h:
                return
        if field_thread != null and field_thread.is_started():
                field_thread.stop()
        nav = NavGrid.new()
        nav.setup(w, h, cell_size, world_origin)
        field_thread = FlowFieldThread.new()
        field_thread.start(w, h)
        _grid_ready = true


func is_ready() -> bool:
        return _grid_ready


## تعیین هدف از نخ اصلی (کلیک کاربر و...)
func set_goal_world(world_xz: Vector2) -> void:
        if not _grid_ready:
                return
        _last_goal_world = nav.clamp_to_grid(world_xz)
        _post_compute()
        GameEvents.goal_changed.emit(_last_goal_world)


func goal_world() -> Vector2:
        return _last_goal_world


## خواندن جهت جریان در یک نقطه — هزینه‌ی نخ اصلی اندازه‌گیری و ثبت می‌شود
func sample_direction(world_xz: Vector2) -> Vector2:
        if not _grid_ready:
                return Vector2.ZERO
        var t0 := Time.get_ticks_usec()
        var d := field_thread.sample_direction(world_xz, nav)
        _last_read_ms = float(Time.get_ticks_usec() - t0) / 1000.0
        return d


func clamp_to_grid(world_xz: Vector2) -> Vector2:
        if not _grid_ready:
                return world_xz
        return nav.clamp_to_grid(world_xz)


func debug_info() -> Dictionary:
        return {
                "ready": _grid_ready,
                "has_field": field_thread.has_field() if field_thread != null else false,
                "compute_ms": field_thread.last_compute_ms() if field_thread != null else 0.0,
                "read_ms": _last_read_ms,
                "computes": field_thread.compute_count() if field_thread != null else 0,
                "goal": _last_goal_world,
        }


func _process(delta: float) -> void:
        if not _grid_ready or not auto_recompute:
                return
        # Watchdog خودترمیم: اگر کارگر به هر دلیلی مرد، بلافاصله دوباره بالا می‌آید
        # تا «قفل شدن میدان» هرگز بیشتر از یک تیک طول نکشد.
        if field_thread != null and field_thread.is_started() and not field_thread.is_alive():
                push_warning("PathService: worker thread died — restarting")
                field_thread.stop()
                field_thread.start(nav.width, nav.height)
        _accum += delta
        if _accum >= RECOMPUTE_INTERVAL:
                _accum = 0.0
                _post_compute()


func _post_compute() -> void:
        # اسنپ‌شات همیشه در نخ اصلی گرفته می‌شود — هیچ اشتراک حافظه‌ای با کارگر نیست
        field_thread.request_compute(nav.world_to_cell(_last_goal_world), nav.snapshot_walkable())


func _exit_tree() -> void:
        # هنگام خروج از بازی، نخ پایدار به‌درستی متوقف می‌شود
        if field_thread != null and field_thread.is_started():
                field_thread.stop()
