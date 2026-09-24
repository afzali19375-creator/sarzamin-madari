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

# گام ۵ — میدان چندکاناله: هر دسته (squad_id) میدان جریان خودش را دارد.
# الگوی دو-بافر به ازای هر کانال حفظ می‌شود؛ نخ پایدارِ واحد باقی می‌ماند.
var _work_fields: Dictionary = {}       # channel -> FlowField (بافر کار)
var _published_fields: Dictionary = {}  # channel -> FlowField (بافر منتشرشده)

# پستِ درخواست (زیر قفل) — آخرین درخواستِ هر کانال نگه داشته می‌شود (coalesce)
# ساختار: channel -> {"goal": Vector2i, "walk": PackedByteArray, "costs": PackedFloat32Array}
var _pending: Dictionary = {}
var _has_request := false

# آمار منتشرشده (زیر قفل)
var _compute_ms := 0.0
var _compute_count := 0


func start(w: int, h: int) -> void:
        if _started:
                return
        _w = w
        _h = h
        # ⚠️ بافر کارِ هر کانال از ابتدا ساخته می‌شود — بافر null هرگز به کارگر
        # داده نمی‌شود (باگ واقعی: «پرچم می‌آید ولی سربازها به سمتش نمی‌روند»)
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
## walkable_snapshot / cost_snapshot را فراخوان (نخ اصلی) از NavGrid کپی می‌کند؛
## بدین ترتیب هیچ حافظه‌ی مشترکی بین دو نخ باقی نمی‌ماند.
## channel: شناسه‌ی دسته (squad_id) — کانال ۰ همان هدف سراسریِ سازگار با گام‌های قبل است.
## درخواست‌های هم‌کانال coalesce می‌شوند؛ کانال‌های مختلف در یک بیداریِ کارگر همه محاسبه می‌شوند.
func request_compute(goal_cell: Vector2i, walkable_snapshot: PackedByteArray,
                cost_snapshot: PackedFloat32Array = PackedFloat32Array(),
                channel: int = 0) -> void:
        if not _started:
                return
        _mutex.lock()
        _pending[channel] = {"goal": goal_cell, "walk": walkable_snapshot,
                        "costs": cost_snapshot}
        _has_request = true
        _mutex.unlock()
        _sem.post()


## جهت واحد در یک نقطه‌ی جهانی — فقط نخ اصلی، هزینه: چند میکروثانیه
func sample_direction(world_xz: Vector2, nav: NavGrid, channel: int = 0) -> Vector2:
        var f: FlowField = null
        _mutex.lock()
        f = _published_fields.get(channel)
        _mutex.unlock()
        if f == null or nav == null:
                return Vector2.ZERO
        var c := nav.world_to_cell(world_xz)
        if not nav.in_bounds(c):
                return Vector2.ZERO
        return f.flow[c.y * f.width + c.x]


func has_field() -> bool:
        _mutex.lock()
        # حداقل یک کانال میدانِ معتبر منتشر کرده باشد
        var has := false
        for k in _published_fields:
                var f: FlowField = _published_fields[k]
                if f != null and not f.is_invalid():
                        has = true
                        break
        _mutex.unlock()
        return has


## آیا کانال مشخصی میدانِ منتشرشده دارد؟ (گام ۵)
func has_channel(channel: int) -> bool:
        _mutex.lock()
        var f: FlowField = _published_fields.get(channel)
        var ok := f != null and not f.is_invalid()
        _mutex.unlock()
        return ok


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
                var jobs: Dictionary = _pending
                _pending = {}
                _mutex.unlock()
                if has and not jobs.is_empty():
                        _run_jobs(jobs)


## اجرای همه‌ی درخواست‌های جمع‌شده — محاسبه بیرون از قفل، انتشار زیر قفل
func _run_jobs(jobs: Dictionary) -> void:
        for channel in jobs:
                var job: Dictionary = jobs[channel]
                var walk: PackedByteArray = job["walk"]
                if walk.size() != _w * _h:
                        continue
                var goal: Vector2i = job["goal"]
                var costs: PackedFloat32Array = job["costs"]
                _mutex.lock()
                var work: FlowField = _work_fields.get(channel)
                _mutex.unlock()
                # محافظ دفاعی: کارگر هرگز نباید به‌خاطر بافر null بمیرد
                if work == null or work.width != _w or work.height != _h:
                        work = FlowField.new()
                        work.setup(_w, _h)
                var t0 := Time.get_ticks_usec()
                work.compute(_w, _h, walk, goal, costs)
                var ms := float(Time.get_ticks_usec() - t0) / 1000.0
                _mutex.lock()
                _compute_ms = ms
                _compute_count += 1
                # جابه‌جایی بافرِ همین کانال: نتیجه‌ی تازه «منتشر» می‌شود،
                # بافر قدیمی می‌شود «کارِ» بعدیِ همان کانال
                var published: FlowField = _published_fields.get(channel)
                _published_fields[channel] = work
                if published != null and published.width == _w and published.height == _h:
                        _work_fields[channel] = published
                else:
                        var nw := FlowField.new()
                        nw.setup(_w, _h)
                        _work_fields[channel] = nw
                _mutex.unlock()
