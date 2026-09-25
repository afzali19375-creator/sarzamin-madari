class_name InvasionDirector
extends Node
## کارگردان موج هجوم — گام ۶ (§۶ سند طراحی) + گام ۶R2 (بازخورد کاربر)
##
##   * ساحل فرود: سلول ساحلیِ «همسایه‌ی آبِ واقعی» — باگ قبلی همین‌جا بود:
##     هر سلولِ با همسایه‌ی غیرقابل‌عبور (حتی صخره/خانه در دل جزیره) ساحل شمرده
##     می‌شد و قایق وسط جزیره ظاهر می‌شد (بازخورد کاربر گام ۶R)
##   * گام ۶R2 — «هر دسته با قایق‌های مختلف خودش می‌آید؛ بعضی کوچک‌تر و بدون
##     بادبان، بعضی بزرگ‌تر»: هر گروه = یک «ناوگان» — دسته‌های کوچک با قایق
##     پاروییِ بی‌بادبان، متوسط با گالی، بزرگ با کشتی جنگی (گاهی + قایق همراه)
##   * گام ۶R2 — قایق‌ها از دل افق دریا (۳۲ متری) ظاهر می‌شوند
##   * گام ۶R3 — «هر قایق یک نوع سرباز؛ مدیریت راحت‌تر»: هر قایق فقط یک نوع
##     مهاجم حمل می‌کند و نوع قایق با بارش معنا می‌گیرد (سبک=قایق پارویی،
##     سنگین‌های زیاد=کشتی جنگی...) — پرچمِ پُپِ قایق رنگِ نوعِ بار را نشان می‌دهد
##   * گام ۶R3 — «قایق‌ها روی هم میرن»: ظهور پلکانی از افق + جداسازی حین شنا
##     + فاصله‌ی پهلوگیری ۳ متری
##   * گام ۶R3 — «از جهات مختلف جزیره بیایند»: انتخاب ساحل با تنوع زاویه‌ای —
##     هر موج از جهتی ≥ ۵۵° دورتر از ۳ فرودِ آخر (بایاسِ «رو به دوربین» حذف شد)
##   * گام ۶R3 — «سربازها روی قایق باشند و در ساحل پیاده شوند»: مهاجم روی عرشه‌ی
##     همان قایق ظاهر می‌شود و تا نقطه‌ی پیاده‌شدنِ خودش (نزدیک همان قایق) واد می‌کند
##   * گام ۶R4 — «هر مرحله از آسان به سخت؛ در دورهای اول دسته‌های دشمن با هم
##     نیایند»: ترکیب/اندازه‌ی موج صعودی است (ascend_spec) و سقفِ گروهِ هم‌زمان
##     دورهای اول ۱ است (max_concurrent_waves)
##   * گام ۶R4 — «کشتی‌ها در مکان‌های مختلف به صورت رندوم کنار ساحل برسند»:
##     در میان واجدهای تنوع زاویه‌ای، ساحل «تصادفی» انتخاب می‌شود (نه دورترین)
##   * گام ۶R4 — قایق‌ها آهسته‌تر می‌آیند (BOAT_CRUISE_SPEED/BOAT_SPEED کم شد)
##     تا کاربر فرصت چیدن استراتژی داشته باشد
##   * گام ۶R2 — قایق‌ها هرگز برنمی‌گردند: چه مهاجمان زنده بمانند چه کشته شوند،
##     ناوگان پارک‌شده در ساحل می‌ماند
##   * گام ۶R6 — قایق = وسیله‌ی حمل‌ونقل واقعی: سربازانِ واقعی از لحظه‌ی ظهور
##     ناوگان روی عرشه‌اند (فرزند قایق) و هنگام پهلوگیری با reparent پیاده
##     می‌شوند؛ «اسپاونر ساحل» حذف شد؛ قایق پس از تخلیه دور می‌شود و ناپدید می‌گردد
##   * هر گروه کانال FlowField خودش را دارد (۴..۷)؛ هدف = نزدیک‌ترین خانه‌ی زنده به فرود
##   * اگر خانه‌ی هدف بسوزد → گروه به نزدیک‌ترین خانه‌ی زنده بازهدف‌گیری می‌کند
##   * ترکیب پیش‌فرض: Peltast ≈ ۱/۳ + Hoplite سنگین در گروه‌های ≥ ۶ نفر، بقیه سبک
##   * مرگ سرباز پارسی با GameEvents.unit_permanently_died — اینجا فقط دشمنان

signal wave_started(group_id: int, count: int)
signal wave_cleared(group_id: int)

var ground: IslandGround
var props: IslandProps
var posts: Array[Vector2] = []          # پست دسته‌ها — برای انتخاب ساحل دور
## موقعیت دوربین (XZ جهانی) — گام ۶R3: بایاس «رو به دوربین» حذف شد؛ این Callable
## فقط برای سازگاری صحنه نگه داشته شده است
var cam_xz_provider: Callable = Callable()

var auto_waves := true
var wave_interval := GameConstants.WAVE_INTERVAL
var waves_spawned := 0

var boats_root: Node3D
var raiders_root: Node3D

# group_id -> {"fleet": [{"boat": EnemyBoat, "payload": {}, "landed": bool}],
#              "raiders": Array, "channel": int, "landing": Vector2,
#              "anchor": Vector2, "raid_target": Vector2,
#              "target_building": BuildingBase, "cleared": bool}
var _groups: Dictionary = {}
var _next_group := 0
var _rng := RandomNumberGenerator.new()
var _wave_accum := 0.0
var _check_accum := 0.0
## گام ۶R3 — زاویه‌ی فرود موج‌های اخیر (نسبت به مرکز جزیره) برای تنوع جهت حمله
var _recent_angles: Array[float] = []

const KIND_LIGHT := "light"
const KIND_HEAVY := "heavy"
const KIND_PELTAST := "peltast"


func _ready() -> void:
        _rng.randomize()
        boats_root = Node3D.new()
        boats_root.name = "EnemyBoats"
        add_child(boats_root)
        raiders_root = Node3D.new()
        raiders_root.name = "EnemyRaiders"
        add_child(raiders_root)


func setup(ground_ref: IslandGround, props_ref: IslandProps,
                squad_posts: Array[Vector2]) -> void:
        ground = ground_ref
        props = props_ref
        posts = squad_posts.duplicate()


func _process(delta: float) -> void:
        _check_accum += delta
        if _check_accum >= 0.3:
                _check_accum = 0.0
                _check_groups()
        if auto_waves:
                _wave_accum += delta
                if _wave_accum >= wave_interval:
                        _wave_accum = 0.0
                        spawn_wave()


# ---------------- موج هجوم ----------------

## گزینه‌ها: {"size": int, "near": Vector2, "comp": {"light": n, "heavy": m,
##          "peltast": k}, "force": bool} → group_id (-1 = نشد)
## گام ۶R4 — اگر نه size و نه comp داده شود، موجِ «صعودی» بر اساس شماره‌ی موج
## (waves_spawned) ساخته می‌شود: دورهای اول کوچکِ تک‌نوعه و تنها گروهِ فعال.
func spawn_wave(opts: Dictionary = {}) -> int:
        var force := bool(opts.get("force", false))
        var max_c := max_concurrent_waves(waves_spawned)
        if not force and waves_active() >= max_c:
                return -1
        if ground == null or props == null:
                return -1
        var size: int = 0
        var comp: Dictionary
        if opts.has("size"):
                size = int(opts["size"])
                comp = opts.get("comp", _default_comp(size))
        elif opts.has("comp"):
                comp = opts["comp"]
                size = int(comp.get(KIND_LIGHT, 0)) + int(comp.get(KIND_HEAVY, 0)) \
                                + int(comp.get(KIND_PELTAST, 0))
        else:
                var asc := ascend_spec(waves_spawned)
                size = int(asc["size"])
                comp = asc["comp"]
        var hint: Vector2 = opts.get("near", Vector2.INF)
        var shore := _pick_shore(hint)
        var landing: Vector2 = shore["landing"]
        var water_xz: Vector2 = shore["water"]
        var channel := GameConstants.ENEMY_CHANNEL_BASE + (_next_group % 4)
        var target_building := _nearest_alive_building(landing)
        var raid_target := landing
        if target_building != null:
                raid_target = Vector2(target_building.global_position.x,
                                target_building.global_position.z)
        var group_id := _next_group
        var g_dict_scaffold: Array = []

        # ---- ناوگان: از دل افق دریا می‌آید و کنار ساحل پارک می‌ماند (گام ۶R2) ----
        var nav := PathService.nav
        var center := nav.origin + nav.size_world() * 0.5
        var outward := (water_xz - center).normalized()
        if outward == Vector2.ZERO:
                outward = Vector2.RIGHT
        var tangent := Vector2(-outward.y, outward.x)
        var fleet_spec := _build_fleet(size, comp)
        var n_boats := fleet_spec.size()
        var gid := _next_group
        _next_group += 1
        var fleet: Array = []
        var anchor0 := water_xz + outward * 1.4
        for bi in n_boats:
                var spec: Dictionary = fleet_spec[bi]
                var btype: EnemyBoat.BoatType = spec["type"]
                var off := _anchor_offset_of(btype)
                # قایق‌های ناوگان کنار هم پهلو می‌گیرند (فاصله‌ی FLEET_BOAT_GAP)
                var side := (float(bi) - float(n_boats - 1) * 0.5) \
                                * GameConstants.FLEET_BOAT_GAP
                var anchor := water_xz + outward * off + tangent * side
                # گام ۶R4fix — لنگر باید روی آب بماند: کمی به بیرون سُر می‌دهیم
                var wtries := 0
                while wtries < 8 and nav.is_walkable(nav.world_to_cell(anchor)):
                        anchor += outward * 0.3
                        wtries += 1
                if bi == 0:
                        anchor0 = anchor
                var boat := EnemyBoat.new()
                boat.boat_type = btype
                boat.capacity = _capacity_of(btype)
                boat.anchor_point = Vector3(anchor.x, 0, anchor.y)
                boat.cargo_kind = spec["kind"]
                boat.cargo_count = int(spec["load"])
                # گام ۶R6 — قایقِ رونده: جهتِ بیرون جزیره + ریشه‌ی پیاده‌شدن
                boat.outward_dir = outward
                boat.disembark_root = raiders_root
                # گام ۶R2 — ظهور از افق + گام ۶R3 — ظهور پلکانی ناوگان
                var spawn_d := GameConstants.BOAT_SPAWN_DIST \
                                + float(bi) * GameConstants.FLEET_SPAWN_STAGGER
                # position (نه global_position) — نود هنوز در درخت نیست
                boat.position = Vector3(
                                anchor.x + outward.x * spawn_d,
                                0, anchor.y + outward.y * spawn_d)
                boats_root.add_child(boat)
                # — گام ۶R6: سربازانِ واقعی «همین لحظه» سوار قایق می‌شوند —
                #   فرزندِ قایق، Riding (AI خاموش)؛ دیگر اسپاونری در ساحل نیست
                var payload: Dictionary = spec["payload"]
                var boarded: Array = []
                for kind in [KIND_LIGHT, KIND_HEAVY, KIND_PELTAST]:
                        for i in int(payload.get(kind, 0)):
                                var e2 := _create_enemy(kind)
                                if e2 != null:
                                        e2.raid_group = group_id % 4 if group_id >= 0 else 3
                                        if group_id >= 0:
                                                e2.raid_target = raid_target
                                                e2.target_house = target_building
                                        else:
                                                e2.raid_target = Vector2(anchor.x, anchor.y)
                                        if ground != null:
                                                e2.ground_provider = Callable(ground, "height_at_world")
                                        boat.board_soldier(e2)
                                        boarded.append(e2)
                fleet.append({"boat": boat, "payload": payload,
                                "landed": false, "soldiers": boarded})
                boat.landed.connect(_on_boat_landed.bind(gid))
                boat.soldier_disembarked.connect(_on_soldier_disembarked.bind(gid))
                # گام ۶R۷ — بستنِ فوریِ گروه هنگام ناپدیدیِ نهایی قایق
                boat.gone.connect(_on_boat_gone.bind(gid))
                # سربازانِ گروه = همین سوارشدگان (همان‌هایی که پیاده می‌شوند)
                for s in boarded:
                        g_dict_scaffold.append(s)

        # گام ۶R3 — ثبت جهت فرود برای تنوع زاویه‌ای موج‌های بعدی
        _remember_shore_angle(center, water_xz)

        _groups[gid] = {
                "fleet": fleet,
                "raiders": g_dict_scaffold,
                "channel": channel,
                "landing": landing,
                "anchor": anchor0,
                "raid_target": raid_target,
                "target_building": target_building,
                "comp_wanted": comp,
                "cleared": false,
        }
        waves_spawned += 1
        var total: int = int(comp.get(KIND_LIGHT, 0)) + int(comp.get(KIND_HEAVY, 0)) \
                        + int(comp.get(KIND_PELTAST, 0))
        wave_started.emit(gid, total)
        return gid


## ترکیب پیش‌فرض §۶: پلتاست ≈ ۱/۳، سنگین از گروه ۶ نفره به بالا، بقیه سبک
func _default_comp(size: int) -> Dictionary:
        var pelt := int(ceil(size / 3.0))
        var heavy := 1 if size >= 6 else 0
        if pelt + heavy > size:
                pelt = maxi(0, size - heavy)
        var light := maxi(0, size - pelt - heavy)
        return {KIND_LIGHT: light, KIND_HEAVY: heavy, KIND_PELTAST: pelt}


## گام ۶R4 — دشواری صعودی (بازخورد کاربر: «هر مرحله از آسان به سخت باشد و
## ترجیحا در دورهای اول نباید دسته‌های سرباز دشمن با هم بیایند»):
##   موج ۰ → ۴ سبکِ خالص (یک قایق پارویی؛ یک دسته‌ی منفرد)
##   موج ۱ → ۵ نفر (سبک + ۲ پرتاب‌گر)
##   موج ۲ → ۶ نفر (+ اولین سنگین)
##   موج ۳ → ۷ نفر (۲ سنگین)
##   موج ۴ → ۸ نفر (مختلط کامل)
##   موج ۵+ → ترکیب پیش‌فرض در اندازه‌ی کامل (WAVE_SIZE_MAX)
func ascend_spec(idx: int) -> Dictionary:
        var sz: int
        var comp: Dictionary
        if idx <= 0:
                sz = 4
                comp = {KIND_LIGHT: 4, KIND_HEAVY: 0, KIND_PELTAST: 0}
        elif idx == 1:
                sz = 5
                comp = {KIND_LIGHT: 3, KIND_HEAVY: 0, KIND_PELTAST: 2}
        elif idx == 2:
                sz = 6
                comp = {KIND_LIGHT: 4, KIND_HEAVY: 1, KIND_PELTAST: 1}
        elif idx == 3:
                sz = 7
                comp = {KIND_LIGHT: 4, KIND_HEAVY: 2, KIND_PELTAST: 1}
        elif idx == 4:
                sz = 8
                comp = {KIND_LIGHT: 4, KIND_HEAVY: 2, KIND_PELTAST: 2}
        else:
                sz = GameConstants.WAVE_SIZE_MAX
                comp = _default_comp(sz)
        return {"size": sz, "comp": comp}


## گام ۶R4 — سقف گروه‌های هم‌زمان هم صعودی است: دورهای اول «فقط یک دسته»
## در صحنه باشد (تا موج قبلی پاک/پیاده نشود بعدی نمی‌آید)؛ بعداً ۲ گروه.
func max_concurrent_waves(idx: int) -> int:
        if idx <= 1:
                return 1
        return GameConstants.WAVE_MAX_CONCURRENT


## ساخت ناوگان از روی اندازه‌ی گروه — گام ۶R3 (بازخورد کاربر):
## «دشمن ها در هر قایق یک نوع باشند ... برای کاربر راحت تر هست مدیرتش»
## → هر قایق فقط «یک نوع» حمل می‌کند؛ نوع قایق از اندازه‌ی بارش درمی‌آید:
##   ۱..۳ → قایق پارویی | ۴..۶ → گالی | ۷..۸ → کشتی جنگی
## خروجی: [{"type": BoatType, "kind": String, "load": int, "payload": {kind: n}}]
func _build_fleet(size: int, comp: Dictionary) -> Array:
        var boats_spec: Array = []
        var remaining := size
        for kind in [KIND_LIGHT, KIND_HEAVY, KIND_PELTAST]:
                var n := mini(int(comp.get(kind, 0)), remaining)
                remaining -= n
                # شکستنِ «همین نوع» به قایق‌های همگن
                while n > 0:
                        var load: int
                        var btype: EnemyBoat.BoatType
                        if n >= 7:
                                btype = EnemyBoat.BoatType.WARSHIP
                                load = mini(n, GameConstants.CAP_WARSHIP)
                        elif n >= 4:
                                btype = EnemyBoat.BoatType.GALLEY
                                load = mini(n, GameConstants.CAP_GALLEY)
                        else:
                                btype = EnemyBoat.BoatType.ROWBOAT
                                load = mini(n, GameConstants.CAP_ROWBOAT)
                        boats_spec.append({"type": btype, "kind": kind,
                                        "load": load, "payload": {kind: load}})
                        n -= load
        # پشتیبان: اگر comp کمتر از size بود، باقی با سبک پر می‌شود
        if remaining > 0:
                boats_spec.append({"type": EnemyBoat.BoatType.ROWBOAT,
                                "kind": KIND_LIGHT, "load": remaining,
                                "payload": {KIND_LIGHT: remaining}})
        return boats_spec


func _capacity_of(btype: EnemyBoat.BoatType) -> int:
        match btype:
                EnemyBoat.BoatType.ROWBOAT:
                        return GameConstants.CAP_ROWBOAT
                EnemyBoat.BoatType.WARSHIP:
                        return GameConstants.CAP_WARSHIP
                _:
                        return GameConstants.CAP_GALLEY


func _anchor_offset_of(btype: EnemyBoat.BoatType) -> float:
        # گام ۶R4fix — قایق‌ها چسبیده‌تر به لبه‌ی ساحل پهلو می‌گیرند: با لنگرِ
        # رندومِ ساحلی، offset قبلی (۱.۱-۱.۸m به سمت آب) سلول‌های پیاده‌شدنِ
        # ۳.۸m را آب‌دار می‌کرد و مهاجمِ دُمِ صف چند متر دورتر از قایقِ خودش
        # فرود می‌آمد. بدنه‌ها کم‌ارتفاع‌اند و پهلوگیریِ نزدیک طبیعی‌تر است.
        match btype:
                EnemyBoat.BoatType.ROWBOAT:
                        return 0.4
                EnemyBoat.BoatType.WARSHIP:
                        return 0.9
                _:
                        return 0.65


## گام ۶R6 — قایق پهلو گرفت: فقط «سلول‌های پیاده‌شدن» را به خودِ قایق می‌دهیم؛
## تخلیه (reparent سربازان واقعی) را خودِ قایق در حالت DISEMBARKING انجام می‌دهد.
## «اسپاونر قدیمی» کاملاً حذف شد — سربازانی که پیاده می‌شوند همان‌هایی‌اند که
## از ابتدا سوار بودند.
func _on_boat_landed(boat: EnemyBoat, gid: int) -> void:
        if not _groups.has(gid):
                return
        var g: Dictionary = _groups[gid]
        var entry: Dictionary = {}
        for e in g["fleet"]:
                if e["boat"] == boat:
                        entry = e
                        break
        if entry.is_empty() or entry["landed"]:
                return
        entry["landed"] = true
        var need := boat.rider_count()
        if need <= 0:
                boat.start_disembark([])   # بارِ مرده → مستقیم PARKED (۶R9)
                return
        var boat_xz := Vector2(boat.global_position.x, boat.global_position.z)
        # شعاع = offset لنگر + یک سلول ساحل + حاشیه؛ پویا برای لنگرِ ضدقفل
        var cells := _walkable_cells_near(boat_xz, 3.8, need)
        if cells.size() < need:
                cells = _walkable_cells_near(boat_xz, 5.5, need)
        if cells.size() < need:
                cells = _walkable_cells_near(boat_xz, 8.0, need)
        boat.start_disembark(cells)
        # میدانِ گروه این لحظه به خانه ست می‌شود (سربازان با پیاده‌شدن فعال می‌شوند)
        PathService.set_goal_for(g["channel"], g["raid_target"])


## گام ۶R6 — هر سربازِ پیاده‌شده: وادِ ساحلِ خودش آغاز شده؛ فقط هدفِ مشعلِ گروه
## را روی او نگه می‌داریم (میدان در _on_boat_landed ست شد)
func _on_soldier_disembarked(boat: EnemyBoat, s: EnemyBase, gid: int) -> void:
        if not _groups.has(gid):
                return
        if s == null or not is_instance_valid(s):
                return
        s.target_house = _groups[gid]["target_building"]
        s.raid_target = _groups[gid]["raid_target"]


## ساخت مهاجم بدون add_child — برای سوارشدن روی قایق (گام ۶R6)
func _create_enemy(kind: String) -> EnemyBase:
        var script: GDScript = null
        match kind:
                KIND_LIGHT:
                        script = HopliteLight
                KIND_HEAVY:
                        script = HopliteHeavy
                KIND_PELTAST:
                        script = PeltastUnit
                _:
                        return null
        return script.new()


func _landed_count(g: Dictionary) -> int:
        var n := 0
        for e in g["fleet"]:
                if e["landed"]:
                        n += 1
        return n


## ساخت یک مهاجم در نقطه (برای کارگردان و تست) — group < 0 = گروه آزمایشی مستقل
## گام ۶R3: at_y ≥ 0 = ارتفاع اولیه (عرشه‌ی قایق) + disembark = مقصد پیاده‌شدن
func spawn_enemy(kind: String, at: Vector2, group: int = -1,
                at_y: float = -1.0, disembark: Vector2 = Vector2.INF) -> EnemyBase:
        var script: GDScript = null
        match kind:
                KIND_LIGHT:
                        script = HopliteLight
                KIND_HEAVY:
                        script = HopliteHeavy
                KIND_PELTAST:
                        script = PeltastUnit
                _:
                        return null
        var nav := PathService.nav
        var pos := at
        if nav != null and at_y < 0.0 \
                        and not nav.is_walkable(nav.world_to_cell(at)):
                pos = nav.cell_center(_nearest_walkable_cell(at))
        var e: EnemyBase = script.new()
        e.raid_group = group % 4 if group >= 0 else 3
        var raid := Vector2.ZERO
        if group >= 0 and _groups.has(group):
                raid = _groups[group]["raid_target"]
                e.target_house = _groups[group]["target_building"]   # هدف مشعل
        else:
                raid = pos  # گروه آزمایشی: همان‌جا می‌ماند و واکنش می‌دهد
        e.raid_target = raid
        var y0 := 0.0
        if at_y >= 0.0:
                y0 = at_y
        elif ground != null:
                y0 = ground.height_at_world(pos)
        if ground != null:
                e.ground_provider = Callable(ground, "height_at_world")
        e.position = Vector3(pos.x, y0, pos.y)
        if disembark != Vector2.INF:
                e.disembark_target = disembark
        raiders_root.add_child(e)
        if group >= 0 and _groups.has(group):
                PathService.set_goal_for(_groups[group]["channel"], raid)
        return e


# ---------------- انتخاب ساحل و خانه ----------------

## سلول ساحلیِ واقعی: قابل‌عبور با همسایه‌ی «آب» (نه صخره/خانه!).
## خروجی: {"landing": مرکز سلول ساحلی, "water": مرکز سلول آبِ همسایه}
## گام ۶R3 — «باید از جهت ها مختلف جزیره بیایند»: انتخاب با «تنوع زاویه‌ای» —
## هر فرود باید ≥ SHORE_DIVERSITY_MIN_DEG از زاویه‌ی ۳ فرودِ آخر فاصله داشته
## باشد؛ در میان واجدها، دورتر از پست‌ها ترجیح دارد. بایاسِ «رو به دوربین»
## حذف شد (ریشه‌ی «همه از یک طرف می‌آیند» همین بود).
func _pick_shore(hint: Vector2 = Vector2.INF) -> Dictionary:
        var nav := PathService.nav
        var center := nav.origin + nav.size_world() * 0.5
        var shores: Array = []   # [Vector2i landing_cell, Vector2i water_cell]
        for cy in nav.height:
                for cx in nav.width:
                        var c := Vector2i(cx, cy)
                        if not nav.is_walkable(c):
                                continue
                        var w := _water_neighbor(c)
                        if w != Vector2i(-1, -1):
                                shores.append([c, w])
        if shores.is_empty():
                # جزیره‌ی بدون ساحل آب (عملاً غیرممکن) — رفتار قدیمی به‌عنوان پشتیبان
                var mid := Vector2i(nav.width / 2, nav.height / 2)
                return {"landing": nav.cell_center(mid), "water": nav.cell_center(mid)}
        if hint != Vector2.INF:
                var best: Array = shores[0]
                var best_d := 1e9
                for s in shores:
                        var d: float = nav.cell_center(s[0]).distance_to(hint)
                        if d < best_d:
                                best_d = d
                                best = s
                # گام ۶R4 — ساحلِ زیرِ قایق‌های موجود اشغال است؛ نزدیک‌ترین ساحلِ
                # «آزاد» به hint ترجیح دارد تا دو ناوگان روی یک نقطه نریزند
                # + گام ۶R4 — فیلتر «ساحل پهن»: spit یک‌سلولی پیاده‌شدنِ ۸ نفره
                # را به شعاع ۶.۵m می‌برد (مهاجم دور از قایق خودش فرود می‌آید).
                # بین ساحل‌های آزادِ پهن، نزدیک‌ترین به hint.
                var free_wide_best: Array = []
                var free_wide_d := 1e9
                var free_best: Array = []
                var free_d := 1e9
                for s in shores:
                        if _shore_taken(s):
                                continue
                        var df: float = nav.cell_center(s[0]).distance_to(hint)
                        if df < free_d:
                                free_d = df
                                free_best = s
                        if _shore_capacity(s[0]) < SHORE_MIN_CELLS:
                                continue
                        if df < free_wide_d:
                                free_wide_d = df
                                free_wide_best = s
                if not free_wide_best.is_empty():
                        return {"landing": nav.cell_center(free_wide_best[0]),
                                        "water": nav.cell_center(free_wide_best[1])}
                if not free_best.is_empty():
                        return {"landing": nav.cell_center(free_best[0]),
                                        "water": nav.cell_center(free_best[1])}
                return {"landing": nav.cell_center(best[0]),
                                "water": nav.cell_center(best[1])}
        # امتیاز هر ساحل: (دوربودن از پست‌ها، تنوع زاویه‌ای با موج‌های اخیر)
        var scored: Array = []
        for s in shores:
                var cc := nav.cell_center(s[0])
                var min_d := 1e9
                for p in posts:
                        min_d = minf(min_d, cc.distance_to(p))
                var ang := _shore_angle_deg(center, nav.cell_center(s[1]))
                var div := 180.0
                for ra in _recent_angles:
                        div = minf(div, absf(wrapf(ang - ra, -180.0, 180.0)))
                scored.append({"far": min_d, "div": div, "s": s})
        # اول واجدهای تنوع ≥ حداقل؛ اگر هیچ، بیشترین تنوع
        var eligible: Array = []
        for sc in scored:
                if sc["div"] >= GameConstants.SHORE_DIVERSITY_MIN_DEG:
                        eligible.append(sc)
        if eligible.is_empty():
                scored.sort_custom(func(a, b): return a["div"] > b["div"])
                var div_top: float = scored[0]["div"]
                for sc in scored:
                        if sc["div"] >= div_top - 1.0:
                                eligible.append(sc)
        # گام ۶R4 — «کشتی‌ها باید در مکان های مختلف به صورت رندوم کنار ساحل
        # برسند»: در میان واجدهای تنوع زاویه‌ای، «انتخاب کاملاً تصادفی» (قبلاً
        # دورترین‌ها به پست‌ها ترجیح داشتند و نقاط فرود تکراری می‌شد)
        # + ساحلِ اشغال‌شده‌ی قایق‌های موجود کنار گذاشته می‌شود
        # + فیلتر «ساحل پهن» (ظرفیت پیاده‌شدن نزدیک قایق) — اگر ساحلِ پهنی
        #   در میان واجدها بود، spitهای باریک کنار گذاشته می‌شوند
        var free_eligible: Array = []
        for sc in eligible:
                if not _shore_taken(sc["s"]):
                        free_eligible.append(sc)
        if not free_eligible.is_empty():
                eligible = free_eligible
        var wide_eligible: Array = []
        for sc in eligible:
                if _shore_capacity(sc["s"][0]) >= SHORE_MIN_CELLS:
                        wide_eligible.append(sc)
        if not wide_eligible.is_empty():
                eligible = wide_eligible
        var pick: Dictionary = eligible[_rng.randi_range(0, eligible.size() - 1)]
        return {"landing": nav.cell_center(pick["s"][0]),
                        "water": nav.cell_center(pick["s"][1])}


## گام ۶R4 — ظرفیت پیاده‌شدن ساحل: تعداد سلول‌های قابل‌عبور در ۴mِ سلولِ فرود.
## ساحلِ پهن = ۸ مهاجمِ کشتی جنگی می‌توانند در ۳.۸mِ قایق پخش شوند.
const SHORE_MIN_CELLS := 10

func _shore_capacity(c: Vector2i) -> int:
        var nav := PathService.nav
        var cc := nav.cell_center(c)
        var n := 0
        for dy in range(-5, 6):
                for dx in range(-5, 6):
                        var t := c + Vector2i(dx, dy)
                        if nav.is_walkable(t) \
                                        and nav.cell_center(t).distance_to(cc) <= 4.0:
                                n += 1
        return n


## گام ۶R4 — آیا این ساحل در تصرف قایقی هست (پارک‌شده یا در راه)؟
## ریشه‌ی «دو ناوگان روی یک ساحل»: انتخاب رندوم بدون اطلاع از اشغال فعلی
func _shore_taken(s: Array) -> bool:
        var nav := PathService.nav
        var cc := nav.cell_center(s[0])
        for b in get_tree().get_nodes_in_group("enemy_boats"):
                var ob := b as EnemyBoat
                if ob == null or not ob.is_inside_tree():
                        continue
                if Vector2(ob.global_position.x, ob.global_position.z) \
                                .distance_to(cc) < GameConstants.SHORE_OCCUPY_RADIUS:
                        return true
                if Vector2(ob.anchor_point.x, ob.anchor_point.z) \
                                .distance_to(cc) < GameConstants.SHORE_OCCUPY_RADIUS:
                        return true
        return false


## زاویه‌ی ساحل نسبت به مرکز جزیره (درجه، −۱۸۰..۱۸۰)
func _shore_angle_deg(center: Vector2, at: Vector2) -> float:
        var d := at - center
        if d.length() < 0.001:
                return 0.0
        return rad_to_deg(atan2(d.y, d.x))


## ثبت جهت فرود موج (حافظه‌ی ۳ موجِ آخر — SHORE_RECENT_MAX)
func _remember_shore_angle(center: Vector2, water_xz: Vector2) -> void:
        _recent_angles.append(_shore_angle_deg(center, water_xz))
        while _recent_angles.size() > GameConstants.SHORE_RECENT_MAX:
                _recent_angles.pop_front()


## برای تست: زاویه‌های فرود اخیر
func recent_shore_angles() -> Array[float]:
        return _recent_angles.duplicate()


## همسایه‌ی آبِ واقعی سلول (با نام ماژول آب — نه هر غیرقابل‌عبوری)
func _water_neighbor(c: Vector2i) -> Vector2i:
        for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
                        Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
                var n2: Vector2i = c + d
                if String(ground.module_name_at(n2)).begins_with("water"):
                        return n2
        return Vector2i(-1, -1)


## نزدیک‌ترین بنای زنده (نسوخته) — هدف مشعل مهاجمان
func _nearest_alive_building(from: Vector2) -> BuildingBase:
        if props == null:
                return null
        var best: BuildingBase = null
        var best_d := 1e9
        for b in props.buildings:
                if not is_instance_valid(b) or b.burned:
                        continue
                var bxz := Vector2(b.global_position.x, b.global_position.z)
                var d := bxz.distance_to(from)
                if d < best_d:
                        best_d = d
                        best = b
        return best


func _nearest_walkable_cell(from: Vector2) -> Vector2i:
        var nav := PathService.nav
        var base := nav.world_to_cell(from)
        if nav.is_walkable(base):
                return base
        for r in range(1, 6):
                for dy in range(-r, r + 1):
                        for dx in range(-r, r + 1):
                                var c := base + Vector2i(dx, dy)
                                if nav.is_walkable(c):
                                        return c
        return base


func _walkable_cells_near(center: Vector2, radius: float, want: int) -> Array[Vector2]:
        var nav := PathService.nav
        var cells := int(ceil(radius / nav.cell_size))
        var base := nav.world_to_cell(center)
        var out: Array[Vector2] = []
        var dists: Array = []
        for dy in range(-cells, cells + 1):
                for dx in range(-cells, cells + 1):
                        var c := base + Vector2i(dx, dy)
                        if not nav.is_walkable(c):
                                continue
                        var cc := nav.cell_center(c)
                        dists.append([cc.distance_to(center), cc])
        dists.sort_custom(func(a, b): return a[0] < b[0])
        for d in dists:
                out.append(d[1])
                if out.size() >= want:
                        break
        return out


# ---------------- چرخه‌ی عمر گروه ----------------

## قایق‌های زنده‌ی ناوگان — آزادشده‌ها حذف می‌شوند (اختصاصِ freed به متغیر
## تایپ‌دار در Godot 4 خطاست)
func _live_fleet(g: Dictionary) -> Array:
        var out: Array = []
        for e in g.get("fleet", []):
                var b = e.get("boat")
                if b != null and is_instance_valid(b) and b is EnemyBoat:
                        out.append(b)
        return out


func _all_landed(g: Dictionary) -> bool:
        for e in g.get("fleet", []):
                if not e["landed"]:
                        return false
        return true


## گام ۶R۷ — ناپدیدیِ نهاییِ قایق: ردِ ناوگان همان لحظه پاک می‌شود و گروه
## بلافاصله (نه در تیک ۰٫۳ ثانیه‌ای بعدی) قابلِ بستن است
func _on_boat_gone(boat: EnemyBoat, gid: int) -> void:
        if not _groups.has(gid):
                return
        for e in _groups[gid]["fleet"]:
                if e.get("boat") == boat:
                        e["boat"] = null
        _check_groups()


func _check_groups() -> void:
        var dead_ids: Array = []
        for gid in _groups:
                var g: Dictionary = _groups[gid]
                # گام ۶R9 — قایق‌ها دیگر نمی‌روند (پارک دائمی در ساحل)؛ گروه
                # وقتی بسته می‌شود که «همه پیاده شده باشند» و «مهاجمان مرده باشند» —
                # قایقِ پارک‌شده مانعِ بستن گروه و آزادشدن ردّ ناوگان نیست
                if _dead_raiders(g) and _all_landed(g):
                        # سیگنالِ پاکسازی موج قبل از بستنِ گروه از دست نمی‌رود
                        if not g["cleared"] and not g["raiders"].is_empty():
                                g["cleared"] = true
                                wave_cleared.emit(gid)
                        dead_ids.append(gid)
                        continue
                if g["cleared"]:
                        continue
                _retarget_if_burned(gid, g)
                # مهاجمان کشته شوند یا زنده بمانند، قایق لنگر مانده —
                # «پاکسازی موج» فقط سیگنال گزارشی است.
                if not g["raiders"].is_empty() and raiders_alive(gid) == 0 \
                                and _all_landed(g):
                        g["cleared"] = true
                        wave_cleared.emit(gid)
        for gid in dead_ids:
                _groups.erase(gid)


## گام ۶R6 — آیا همه‌ی مهاجمانِ گروه مرده‌اند؟ (سربازِ سوارِ قایق = زنده)
func _dead_raiders(g: Dictionary) -> bool:
        for e in g.get("raiders", []):
                if is_instance_valid(e) and not e.is_dead():
                        return false
        return true


## اگر خانه‌ی هدف گروه سوخت → نزدیک‌ترین خانه‌ی زنده؛ میدان و مهاجمان به‌روز می‌شوند
func _retarget_if_burned(gid: int, g: Dictionary) -> void:
        if raiders_alive(gid) == 0:
                return
        var tb = g.get("target_building")
        if tb != null and is_instance_valid(tb) and not tb.burned:
                return
        var centroid := Vector2.ZERO
        var n := 0
        for e in g["raiders"]:
                if is_instance_valid(e) and not e.is_dead():
                        centroid += Vector2(e.global_position.x, e.global_position.z)
                        n += 1
        if n == 0:
                return
        var nb := _nearest_alive_building(centroid / float(n))
        g["target_building"] = nb
        var raid: Vector2 = g["raid_target"]
        if nb != null:
                raid = Vector2(nb.global_position.x, nb.global_position.z)
        g["raid_target"] = raid
        PathService.set_goal_for(g["channel"], raid)
        for e in g["raiders"]:
                if is_instance_valid(e) and not e.is_dead():
                        e.raid_target = raid
                        e.target_house = nb


## مهاجمانِ زنده‌ی یک گروه
func raiders_alive(gid: int) -> int:
        if not _groups.has(gid):
                return 0
        var n := 0
        for e in _groups[gid]["raiders"]:
                if is_instance_valid(e) and not e.is_dead():
                        n += 1
        return n


func raiders_of(gid: int) -> Array:
        return _groups.get(gid, {}).get("raiders", [])


func group_raid_target(gid: int) -> Vector2:
        return _groups.get(gid, {}).get("raid_target", Vector2.ZERO)


func group_landing(gid: int) -> Vector2:
        return _groups.get(gid, {}).get("landing", Vector2.ZERO)


## نقطه‌ی لنگر گروه (روی آب کنار ساحل — قایق اول ناوگان) — گام ۶R
func group_anchor(gid: int) -> Vector2:
        return _groups.get(gid, {}).get("anchor", Vector2.ZERO)


## قایق‌های زنده‌ی گروه — برای تست ناوگان (گام ۶R2)
func group_boats(gid: int) -> Array:
        if not _groups.has(gid):
                return []
        return _live_fleet(_groups[gid])


## گام ۶R3 — بارِ هر قایقِ زنده‌ی گروه: [{"boat", "payload", "landed"}]
## برای تستِ «هر قایق یک نوع سرباز»
func fleet_entries(gid: int) -> Array:
        if not _groups.has(gid):
                return []
        return _groups[gid]["fleet"]


## گام ۶R3 — بارِ پیاده‌شده‌ی گروه (مجموع payload قایق‌های پهلوگرفته) —
## برخلاف raiders_alive با مرگِ مهاجمان کم نمی‌شود؛ برای تستِ «همه پیاده شدند»
func group_landed_cargo(gid: int) -> int:
        if not _groups.has(gid):
                return 0
        var n := 0
        for e in _groups[gid]["fleet"]:
                if e["landed"]:
                        var pl: Dictionary = e["payload"]
                        for k in pl:
                                n += int(pl[k])
        return n


## وضعیت قایق گروه (قایق اول ناوگان): 0=در حال شنا 1=لنگر -1=بدون قایق
func boat_state(gid: int) -> int:
        if not _groups.has(gid):
                return -1
        var fleet := _live_fleet(_groups[gid])
        if fleet.is_empty():
                return -1
        return int((fleet[0] as EnemyBoat).state)


func boats_active() -> int:
        var n := 0
        for gid in _groups:
                n += _live_fleet(_groups[gid]).size()
        return n


## تعداد «گروه»های فعال برای سقف WAVE_MAX_CONCURRENT (گام ۶R2):
## گروهی که مهاجم زنده دارد یا هنوز قایقش در راه است؛ ناوگانِ پارک‌شده‌ی
## مهاجمانِ مرده مانع موج تازه نمی‌شود (قایق‌ها که برنمی‌گردند)
func waves_active() -> int:
        var n := 0
        for gid in _groups:
                if raiders_alive(gid) > 0 or not _all_landed(_groups[gid]):
                        n += 1
        return n


func alive_raiders_total() -> int:
        var n := 0
        for e in get_tree().get_nodes_in_group("hostiles"):
                if e is EnemyBase and not e.is_dead():
                        n += 1
        return n


func groups_count() -> int:
        return _groups.size()


## پاکسازی کامل (بازتولید جزیره / پایان صحنه)
func clear_all() -> void:
        for c in boats_root.get_children():
                c.free()
        for c in raiders_root.get_children():
                c.free()
        _groups.clear()
        waves_spawned = 0
        _wave_accum = 0.0


## برای تست: کشتن همه‌ی مهاجمان زنده — گام ۶R6: سربازانِ «سوارِ قایق» هم
## کشته می‌شوند (خارج از گروه hostiles‌اند ولی عضوِ گروهِ موج‌اند)
func kill_all_raiders() -> int:
        var n := 0
        var seen := {}
        for gid in _groups:
                for e in _groups[gid]["raiders"]:
                        if is_instance_valid(e) and not e.is_dead() \
                                        and not seen.has(e.get_instance_id()):
                                seen[e.get_instance_id()] = true
                                (e as EnemyBase).take_hit(99)
                                n += 1
        for e in get_tree().get_nodes_in_group("hostiles"):
                if e is EnemyBase and not (e as EnemyBase).is_dead() \
                                and not seen.has(e.get_instance_id()):
                        seen[e.get_instance_id()] = true
                        (e as EnemyBase).take_hit(99)
                        n += 1
        return n
