class_name FlowFieldThread
extends RefCounted
## نخ پایدار (Persistent Thread) برای محاسبه‌ی FlowField — قانون آهنین سند طراحی:
## «ThreadPool ممنوع؛ یک Thread دائمی + Mutex + Semaphore»
##
## الگوی انتشار دوگانه (Double Buffer):
##   - نخ اصلی: فقط «درخواست» می‌فرستد و از بافر «منتشرشده» می‌خواند.
##   - نخ کارگر: در بافر «کار» محاسبه می‌کند و زیر قفل، دو بافر را جابه‌جا می‌کند.
## بنابراین خواندنِ جهت‌ها در هر فریم هرگز با نوشتنِ کارگر رقابت نمی‌کند
## و هزینه‌ی نخ اصلی در حد چند میکروثانیه می‌ماند (بودجه‌ی سند: < 0.5ms).
##
## چرخه‌ی عمر: start() → request_compute() ... → stop()

var _thread: Thread
var _mutex: Mutex
var _sem: Semaphore
var _running := false
var _started := false

var _w := 0
var _h := 0
var _work: FlowField
var _published: FlowField

# پستِ درخواست (زیر قفل) — اسنپ‌شات walkable از نخ اصلی کپی می‌شود
var _pending_goal := Vector2i(-1, -1)
var _pending_walk := PackedByteArray()
var _has_request := false

# آمار منتشرشده (زیر قفل)
var _published_goal := Vector2i(-1, -1)
var _published_invalid := true
var _compute_ms := 0.0
var _compute_count := 0


func start(w: int, h: int) -> void:
        if _started:
                return
        _w = w
        _h = h
        # ⚠️ هر دو بافر از ابتدا ساخته می‌شوند — اگر «منتشرشده» null بماند،
        # بعد از اولین جابه‌جایی، بافرِ کار null می‌شود و نخ کارگر در درخواست
        # بعدی می‌میرد (باگ واقعی: «پرچم می‌آید ولی سربازها به سمتش نمی‌روند»)
        _work = FlowField.new()
        _work.setup(w, h)
        _published = FlowField.new()
        _published.setup(w, h)  # تا اولین محاسبه: is_invalid → has_field() == false
        _mutex = Mutex.new()
        _sem = Semaphore.new()
        _thread = Thread.new()
        _running = true
        _started = true
        _thread.start(_worker_loop)


func stop() -> void:
        if not _started:
                return
        _mutex.lock()
        _running = false
        _mutex.unlock()
        _sem.post()  # بیدار کردن کارگر تا فلگ توقف را ببیند
        if _thread.is_started():
                _thread.wait_to_finish()
        _started = false


func is_started() -> bool:
        return _started


## آیا نخ کارگر زنده است؟ (برای watchdog خودترمیم PathService)
func is_alive() -> bool:
        return _started and _thread != null and _thread.is_alive()


## درخواست محاسبه — فقط از نخ اصلی.
## walkable_snapshot را فراخوان (نخ اصلی) از NavGrid کپی می‌کند؛
## بدین ترتیب هیچ حافظه‌ی مشترکی بین دو نخ باقی نمی‌ماند.
func request_compute(goal_cell: Vector2i, walkable_snapshot: PackedByteArray) -> void:
        if not _started:
                return
        _mutex.lock()
        _pending_goal = goal_cell
        _pending_walk = walkable_snapshot
        _has_request = true
        _mutex.unlock()
        _sem.post()


## جهت واحد در یک نقطه‌ی جهانی — فقط نخ اصلی، هزینه: چند میکروثانیه
func sample_direction(world_xz: Vector2, nav: NavGrid) -> Vector2:
        var f: FlowField = null
        _mutex.lock()
        f = _published
        _mutex.unlock()
        if f == null or nav == null:
                return Vector2.ZERO
        var c := nav.world_to_cell(world_xz)
        if not nav.in_bounds(c):
                return Vector2.ZERO
        return f.flow[c.y * f.width + c.x]


func has_field() -> bool:
        _mutex.lock()
        # بافر خالیِ اولیه هنوز «میدان» نیست — باید حداقل یک محاسبه منتشر شده باشد
        var has := _published != null and not _published.is_invalid()
        _mutex.unlock()
        return has


func last_compute_ms() -> float:
        _mutex.lock()
        var v := _compute_ms
        _mutex.unlock()
        return v


func compute_count() -> int:
        _mutex.lock()
        var v := _compute_count
        _mutex.unlock()
        return v


# ---------------- حلقه‌ی نخ کارگر ----------------

func _worker_loop() -> void:
        while true:
                _sem.wait()  # خواب عمیق تا درخواست بعدی — صفر مصرف CPU
                _mutex.lock()
                if not _running:
                        _mutex.unlock()
                        break
                var has := _has_request
                _has_request = false
                var goal := _pending_goal
                var walk := _pending_walk
                _mutex.unlock()
                if has and walk.size() == _w * _h:
                        # محافظ دفاعی: کارگر هرگز نباید به‌خاطر بافر null بمیرد
                        if _work == null or _work.width != _w or _work.height != _h:
                                _work = FlowField.new()
                                _work.setup(_w, _h)
                        var t0 := Time.get_ticks_usec()
                        _work.compute(_w, _h, walk, goal)
                        var ms := float(Time.get_ticks_usec() - t0) / 1000.0
                        _mutex.lock()
                        _compute_ms = ms
                        _compute_count += 1
                        # جابه‌جایی بافرها: نتیجه‌ی تازه «منتشر» می‌شود، بافر قدیمی می‌شود «کارِ» بعدی
                        var tmp := _published
                        _published = _work
                        _work = tmp
                        _published_goal = goal
                        _published_invalid = _published.is_invalid()
                        _mutex.unlock()
