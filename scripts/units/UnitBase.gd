class_name UnitBase
extends Node3D
## پایه‌ی همه‌ی واحدهای نبرد «سرزمین مادری» — معماری رفتار ۴ لایه (سند طراحی §۴):
##
##   لایه ۱ — حرکت پایه: FlowField «چندکاناله» به سمت اسلات آرایش خودش
##            (سرعت 3±5%، شتاب 8، چرخش 360°/s — §۵ پرامت فاز اول)
##   لایه ۲ — Fidget: وقتی بیکار است وول می‌خورد (2–5s → قدم 0.4–0.8m به مدت 0.3–0.8s)
##   لایه ۳ — واکنش نبرد: دشمن در شعاع → رفتار کلاس (در زیرکلاس‌ها override)
##   لایه ۴ — AI مستقل: بدون فرمان → بازگشت به پست (گام ۵)؛ گام ۶+: دفاع از خانه/
##            عقب‌نشینی به قایق (در زیرکلاس‌ها توسعه می‌یابد)
##
## اولویت هر فریم: لایه ۳ > لایه ۱/۲. قانون آهنین کلاس‌ها در زیرکلاس اعمال می‌شود
## (مثلاً «نیزه‌دار هنگام حرکت نمی‌جنگد»).
##
## گام ۵ — هر دسته کانال جریان خودش را دارد: sample_direction(pos, squad_id).

const ARRIVE_RADIUS := 1.0        # حالت بدون اسلات (صحنه‌ی FlowFieldTest)
const SLOT_ARRIVE_RADIUS := 0.45  # رسیدن واقعی روی اسلات آرایش
const DIRECT_STEER_RADIUS := 1.6  # نزدیک هدفِ جریان، flow صفر است → مستقیم
const SLOT_STEER_RADIUS := 2.2    # نزدیک اسلات → مستقیم به اسلات خودش
## گام ۶R12 — «سربازها توی هم فشرده می‌شدن»: شعاع جداسازی با کاراکترهای
## واقعی‌نما هم‌قد شده (بدنه‌ی پهن‌تر از چینیِ قبلی)
const SEPARATION_DIST := 0.72

# ---------------- شناسه و کانال (گام ۵) ----------------
## کانال میدان جریان این واحد = شناسه‌ی دسته (0..3)
var squad_id := 0
## رنگ دسته (پالت هخامنشی) — اگر ست نشود، تصادفی از پالت
var squad_color := Color(0, 0, 0, 0)

# ---------------- لایه ۱: حرکت ----------------
## §۵.۱ — هر سرباز سرعت کمی متفاوت دارد (0.95× تا 1.05×)
var speed_mult := 1.0

## صحنه این را به IslandGround.height_at_world وصل می‌کند تا واحد روی زمینِ
## هموار بایستد (بدون آن: y = 0 مثل صحنه‌ی FlowFieldTest)
var ground_provider: Callable = Callable()
var _y_smooth := 0.0

## اسلات آرایش (جهانی XZ). «رسیدن» = ایستادن روی اسلات.
var _slot := Vector2.ZERO
var _has_slot := false

var _vel := Vector2.ZERO
var _arrived := false
var _bob_t := 0.0
var _heading := 0.0

## گام ۶R4 — پادزهرِ گیرِ گوشهٔ مقعر: ساعتِ بی‌پیشرفتیِ خالص + پیروی از دیوار
var _stuck_t := 0.0
var _best_gd := 1e9       # بهترین فاصله تا هدف از آخرین ریست — لرزشِ خُرد، پیشرفت نیست
var _near_latch := false  # وارد حبابِ هدایتِ مستقیم شده → تا رسیدن/دوریِ زیاد مستقیم
var _wf_active := false   # پیروی از دیوار فعال (bug-style) — دورزدنِ متعهدِ برآمدگی
var _wf_side := 1         # سمتِ دورزدن؛ در انتخابِ اول، هر دو سمت سنجیده می‌شوند
var _wf_t := 0.0          # عمرِ دورزدنِ فعلی (s)
var _wf_best_gd := 1e9    # بهترین فاصله در طولِ دورزدن — معیارِ خروج

# ---------------- لایه ۲: Fidget ----------------
var fidget_enabled := true
var _fidget_timer := 0.0
var _fidget_state := 0  # 0=ایست 1=خارج‌شدن 2=بازگشت
var _fidget_from := Vector2.ZERO
var _fidget_to := Vector2.ZERO
var _fidget_t := 0.0
var _fidget_dur := 0.5
var _rng := RandomNumberGenerator.new()

# ---------------- لایه ۳: واکنش نبرد ----------------
var _scan_accum := 0.0
var _combat_target: Node3D = null
var _in_combat := false      # فلگ صریح — freed == null در Godot 4 گول نمی‌زند
var _shoot_cooldown := 0.0
var _strike_cd := 0.0
var _striking := false       # گام ۶R3 — در چرخه‌ی ضربه (کشش→یورش→ضربه)

## ---------------- سلامت و مرگ (گام ۶ — قانون آهنین §۷: مرگ دائمی) ----------------
## صفر عدد و نوار سلامت روی صفحه (§۱۰) — فقط فلش سفیدِ ضربه و افتادن هنگام مرگ
var hp := 3
var dead := false
var _flash_t := 10.0
var _flashing := false
var _flash_restore := Color.WHITE

## گام ۶R9 — پاشش خون و لکه؛ سربازِ خودی سرخِ تیره می‌ریزد
var _blood_color: Color = Color("7c1610")

# ---------------- گام ۶R9 — محورِ دست و سبکِ سوئینگ ----------------
## سلاح‌ها فرزندِ این پیوت‌اند؛ چرخه‌ی ضربه همین را می‌چرخاند تا سوئینگِ
## شمشیر/یورشِ نیزه واقعاً «دیده شود» (بازخورد کاربر)
enum SwingStyle { NONE, SWORD_SLASH, THRUST }
var _hand: Node3D
var _swing_style := SwingStyle.NONE
## سلاحِ در دست — زیرکلاس‌ها روی _hand می‌سازند
var _swing_weapon: Node3D

# گام ۶R9 — تسک A: فرارِ اضطراری (انحلال گروه با مرگ فرمانده) —
# عضوِ بی‌فرمانده دیگر نمی‌جنگد؛ فقط به نزدیک‌ترین ساحل می‌دود و جزیره را ترک می‌کند
var _fleeing := false
var _flee_goal := Vector2.ZERO
var _flee_t := 0.0   # گام ۶R9-fix — عمرِ فرار؛ زیرِ FLEE_MIN_TIME محو نمی‌شود

# گام ۶R — وضعیت پرهیز از مانع (تعهد سمتِ چرخش، ضد نوسان حدی)
var _avoid_side := 0     # 0=غیرفعال | ‎+۱‎=پادساعتگرد | ‎−۱‎=ساعتگرد
var _avoid_hold := 0.0   # ثانیه‌ی باقی‌مانده‌ی تعهد

# ---------------- گام ۶R — فرمانده و گاریسون ----------------
## فرمانده دسته = عضو اول؛ پرچم رنگِ دسته را حمل می‌کند (SquadFlag را صحنه وصل می‌کند)
var is_commander := false
## داخل خانه پنهان است (گاریسون): دیداری خاموش، خارج از گروه «units»، بدون لایه‌ها
var garrisoned := false

# ---------------- بصری ----------------
var _spawn_color: Color
var _base_color: Color
var _body: Node3D
var _ring: MeshInstance3D
## کاراکتر Low-Poly واقعی — گام ۶R۱۲: پک Quaternius (CC0) با انیمیشن اسکلتی کامل
## (Idle/Walk/حمله/ضربه/مرگ) — بازخورد: «کیفیت کاراکترها خوب نیست»
var _model: CharacterModel


func _ready() -> void:
        add_to_group("units")
        hp = _default_hp()
        _bob_t = randf() * TAU
        _y_smooth = global_position.y
        _heading = rotation.y

        if squad_color.a > 0.0:
                _spawn_color = squad_color
        else:
                _spawn_color = GameConstants.UNIT_PALETTE.pick_random()
        _base_color = _spawn_color

        # رسیدن موقتی است: با جابه‌جایی پرچم باید دوباره راه بیفتد
        # (رفع باگ «گیر کردن در آیدل بعد از رسیدن») — فقط برای کانال ۰/بدون اسلات
        GameEvents.goal_changed.connect(_on_goal_changed)

        # گام ۶R۱۲ — کاراکتر اسکلتی Quaternius با انیمیشن کامل؛ تینتِ ۴۲٪ رنگ دسته
        # روی پالت کاراکتر (قابل‌تفکیک از دور، شکل کاراکتر زیر رنگ گم نمی‌شود)
        _model = CharacterModel.new()
        _model.setup(_model_kind(), _spawn_color, 0.42, _model_special())
        add_child(_model)
        _body = _model.body_root()

        # حلقه‌ی انتخاب (فقط دسته‌ی انتخابی — الگوی Bad North)
        _ring = MeshInstance3D.new()
        var ring_mesh := CylinderMesh.new()
        ring_mesh.top_radius = 0.42
        ring_mesh.bottom_radius = 0.42
        ring_mesh.height = 0.02
        _ring.mesh = ring_mesh
        _ring.position.y = 0.03
        var ring_mat := StandardMaterial3D.new()
        ring_mat.albedo_color = Color(1, 1, 1, 0.35)
        ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _ring.material_override = ring_mat
        _ring.visible = false
        add_child(_ring)

        # تجهیزات اختصاصی کلاس (سپر/نیزه/کمان — در زیرکلاس‌ها)
        # گام ۶R9 — پیوتِ دستِ راست: سلاح فرزندِ این است تا با ضربه سوئینگ کند
        _hand = Node3D.new()
        _hand.position = Vector3(0.15, 0.5, 0.1)
        add_child(_hand)
        _build_gear()

        # گام ۶R — نشان فرمانده: سربند طلایی (پرچم را صحنه وصل می‌کند)
        if is_commander:
                var band := MeshInstance3D.new()
                var bm := TorusMesh.new()
                bm.inner_radius = 0.11
                bm.outer_radius = 0.16
                bm.rings = 10
                bm.ring_segments = 5
                band.mesh = bm
                # گام ۶R12 — سرِ کاراکتر واقعی‌نما (قد ۰٫۸۲) نه قدِ چینیِ قبلی
                band.position.y = 0.88
                var gm := StandardMaterial3D.new()
                gm.albedo_color = GameConstants.COL_GOLD
                gm.metallic = 0.5
                gm.roughness = 0.35
                band.material_override = gm
                add_child(band)

        _fidget_timer = _rng.randf_range(GameConstants.FIDGET_INTERVAL_MIN,
                        GameConstants.FIDGET_INTERVAL_MAX)


## هوک بصری زیرکلاس‌ها — بین ساخت تنه و شروع Fidget
func _build_gear() -> void:
        pass


## نقشِ کاراکتر این یونیت — زیرکلاس‌ها override می‌کنند:
##   warrior=جاویدان | viking=نیزه‌دار | ranger=کماندار (پک Quaternius)
func _model_kind() -> StringName:
        return &"warrior"


## تینتِ ویژه‌ی گره‌های مدل (مثلاً سپر فیروزه‌ای جاویدان) — زیرکلاس‌ها override
func _model_special() -> Dictionary:
        return {}


# ---------------- سلامت، ضربه و مرگ دائمی (گام ۶) ----------------

## جان پایه — زیرکلاس‌ها override می‌کنند
func _default_hp() -> int:
        return 3


func is_dead() -> bool:
        return dead


## ضربه (تیر/نیزه/پرتاب) — فلش سفید کوتاه؛ مرگ فقط با رسیدن صفر
## گام ۶R2 — پارامتر «attacker» برای هم‌امایی با EnemyBase (تلافی دشمن)
## گام ۶R4 — لگدِ کوچکِ ضربه‌خوردگی (حسِ برخوردِ تن‌به‌تن)
func take_hit(dmg: int = 1, from_dir: Vector3 = Vector3.ZERO,
                _attacker: Node3D = null) -> void:
        if dead:
                return
        hp -= dmg
        _flash_hit()
        # گام ۶R11 — انیمیشن ضربه‌خوردنِ اسکلتی (Hit_A پک)
        if _model != null:
                _model.play_hit()
        _knockback(from_dir)
        # گام ۶R9 — خون‌ریزی: پاشش در سینه‌ی سرباز + صدای برخورد
        BattleFX.blood_burst(get_parent(), global_position + Vector3(0, 0.45, 0),
                        from_dir, _blood_color)
        BattleFX.play_sfx(get_tree(), &"hit")
        # گام ۶R9 — تسک A: لرزشِ کوتاهِ دوربین با هر ضربه (نزدیک = شدیدتر)
        GameEvents.world_shake.emit(0.10, global_position)
        if hp <= 0:
                die()


## گام ۶R4 — پس‌زنی کوتاه در جهت ضربه؛ فقط اگر سلول بعدی قابل‌عبور باشد
## (ضدِ پرتاب به آب/صخره — الگوی پس‌زنیِ EnemyBase در گام ۶R3)
func _knockback(from_dir: Vector3) -> void:
        if from_dir.length() < 0.01:
                return
        var nav := PathService.nav
        if nav == null:
                return
        var np := Vector2(position.x, position.z) \
                        + Vector2(from_dir.x, from_dir.z).normalized() \
                        * GameConstants.MELEE_KNOCKBACK
        if nav.is_walkable(nav.world_to_cell(np)):
                position.x = np.x
                position.z = np.y


func _flash_hit() -> void:
        _flash_restore = _base_color
        # گام ۶R11 — فلشِ سفید داخل CharacterModel (متریال موقتاً سفید، خودش
        # بازیابی می‌کند) — شیدرِ فلشِ چینی حذف شد
        if _model != null:
                _model.flash_white()
        _flash_t = 0.0
        _flashing = true


func die() -> void:
        if dead:
                return
        dead = true
        _in_combat = false
        _combat_target = null
        _combat_end()
        remove_from_group("units")
        set_selected_ring(false)
        # قانون آهنین سند طراحی §۷: مرگ دائمی است — هرگز برنمی‌گردد
        GameEvents.unit_permanently_died.emit(self)
        set_process(false)
        # گام ۶R9 — فلشِ در جریان روی جسد نمی‌ماند (مدل خودش بازیابی می‌کند)
        _flashing = false
        # گام ۶R9 — خون: لکه‌ی دائمی جای سقوط + صدای افتادن
        var gy := position.y
        if ground_provider.is_valid():
                gy = float(ground_provider.call(Vector2(position.x, position.z)))
        BattleFX.blood_stain(get_parent(), Vector2(position.x, position.z), gy,
                        _blood_color)
        BattleFX.play_sfx(get_tree(), &"fall", -6.0)
        # گام ۶R12 — مرگ با انیمیشن Death واقعیِ پک (افتادنِ طبیعی؛ نه چرخش
        # خشکِ کلِ نود) — آخرین فریمِ افتادن روی زمین می‌ماند (جنازه‌ی دائمی)
        if _model != null:
                _model.play_death()
        add_to_group("corpses")
        GameEvents.corpse_laid.emit(self)
        # گام ۶R9 — تسک A: افتادنِ سرباز = تکونِ محسوس‌ترِ دوربین
        GameEvents.world_shake.emit(0.28, global_position)


## ضربه‌ی تن‌به‌تن — true = ضربه آغاز شد (خنک‌شدن تمام). جهتِ ضربه به هدف می‌رود
## گام ۶R2 — شلیک‌کننده هم پاس می‌شود تا دشمنِ تلافی‌گر بداند چه کسی زده
## گام ۶R3 (بازخورد: «نبرد خیلی ابتداییه») — چرخه‌ی ضربه‌ی خوانا:
##   کشش به عقب (STRIKE_WINDUP) → یورش (STRIKE_LUNGE) → لحظه‌ی ضربه → بازگشت
##   + آهنگ ضربه ±۱۵٪ پراکنده تا ضربه‌ها هم‌زمان و ماشینی نشوند
func _try_strike(delta: float, cooldown: float, hostile: Node3D, dmg: int = 1,
                reach: float = -1.0) -> bool:
        _strike_cd = maxf(0.0, _strike_cd - delta)
        if _strike_cd > 0.0 or _striking:
                return false
        if not hostile.has_method("take_hit") or (hostile.has_method("is_dead") \
                        and hostile.is_dead()):
                return false
        _strike_cd = cooldown \
                        * (1.0 + randf_range(-GameConstants.CADENCE_VARIANCE,
                        GameConstants.CADENCE_VARIANCE))
        var r := reach
        if r < 0.0:
                r = _dist_xz_to(hostile)
        _striking = true
        _strike_windup_fx()
        # گام ۶R3 — weakref: اگر هدف تا لحظه‌ی ضربه آزاد شود، bind خطا نمی‌دهد
        # و _striking گیر نمی‌کند (باگ فاز ۱۳: «Cannot convert argument 1»)
        var wr: WeakRef = weakref(hostile)
        var tw := create_tween()
        tw.tween_interval(GameConstants.STRIKE_WINDUP + GameConstants.STRIKE_LUNGE)
        tw.tween_callback(_strike_land.bind(wr, dmg, r))
        return true


## لحظه‌ی ضربه — هدف و برد در اوجِ یورش اعتبارسنجی می‌شوند
func _strike_land(wr: WeakRef, dmg: int, reach: float) -> void:
        _striking = false
        var hostile: Node3D = null
        if wr != null:
                hostile = wr.get_ref() as Node3D
        if hostile == null or not is_instance_valid(hostile):
                return
        if hostile.has_method("is_dead") and hostile.is_dead():
                return
        if _dist_xz_to(hostile) > reach + 0.8:
                return
        var dir := hostile.global_position - global_position
        dir.y = 0.0
        hostile.take_hit(dmg,
                        dir.normalized() if dir.length() > 0.001 else Vector3.ZERO, self)
        # گام ۶R11 — انیمیشن حمله‌ی اسکلتی (شمشیر/تبر/کاتاپولت) هم‌گام با
        # چرخه‌ی ضربه — «حرکت‌ها و ضربه‌ها ابتدایی نباشد» (بازخورد کاربر)
        if _model != null:
                _model.play_attack()
        _strike_impact_fx()
        # گام ۶R4 — جرقه‌ی برخورد در نقطه‌ی میانی (حسِ ضربه خواناتر می‌شود)
        _spawn_hit_spark((hostile.global_position + global_position) * 0.5 \
                        + Vector3(0.0, 0.5, 0.0))


## گام ۶R4 — جرقه‌ی کوتاهِ لحظه‌ی ضربه (هسته‌ی درخشان، بزرگ‌شونده-محو)
func _spawn_hit_spark(at: Vector3) -> void:
        var parent := get_parent()
        if parent == null or not is_inside_tree():
                return
        var m := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 0.09
        sm.height = 0.18
        m.mesh = sm
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(1.0, 0.92, 0.6, 0.95)
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.emission_enabled = true
        mat.emission = Color(1.0, 0.78, 0.32)
        mat.emission_energy_multiplier = 2.0
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.material_override = mat
        parent.add_child(m)
        m.global_position = at
        var tw := m.create_tween()
        tw.set_parallel(true)
        tw.tween_property(m, "scale", Vector3(2.2, 2.2, 2.2), 0.14) \
                        .set_ease(Tween.EASE_OUT)
        tw.tween_property(mat, "albedo_color:a", 0.0, 0.14)
        tw.chain().tween_callback(m.queue_free)


## ژست کشش ضربه (پیش‌فرض: بدنه کمی عقب + چرخش کوتاه پهلو) — زیرکلاس می‌تواند override کند
## گام ۶R9 — سوئینگِ سلاح: بر اساس سبکِ کلاس، دستِ سلاح‌دار هم حرکت می‌کند
func _strike_windup_fx() -> void:
        if _body == null:
                return
        var tw := create_tween()
        tw.set_parallel(true)
        tw.tween_property(_body, "position:z", -0.09,
                        GameConstants.STRIKE_WINDUP).set_ease(Tween.EASE_OUT)
        tw.tween_property(_body, "rotation:y", -0.22,
                        GameConstants.STRIKE_WINDUP).set_ease(Tween.EASE_OUT)
        match _swing_style:
                SwingStyle.SWORD_SLASH:
                        # عقب‌کشیدنِ تیغه به بالای شانه — آماده‌ی اسلش
                        if _hand != null:
                                var hw := create_tween()
                                hw.set_parallel(true)
                                hw.tween_property(_hand, "rotation:y", 1.0,
                                                GameConstants.STRIKE_WINDUP) \
                                                .set_ease(Tween.EASE_OUT)
                                hw.tween_property(_hand, "rotation:z", 0.5,
                                                GameConstants.STRIKE_WINDUP)
                SwingStyle.THRUST:
                        # نیزه کمی عقب می‌رود — کوبشِ بعدی پرقدرت‌تر دیده می‌شود
                        if _hand != null:
                                var tw2 := create_tween()
                                tw2.tween_property(_hand, "position:z", -0.12,
                                                GameConstants.STRIKE_WINDUP) \
                                                .set_ease(Tween.EASE_OUT)
                _:
                        pass


## ژست لحظه‌ی ضربه (پیش‌فرض: بازگشت بدنه) — جاویدان: _lunge، نیزه‌دار: _thrust
## گام ۶R9 — اسلشِ تندِ شمشیر/کوبشِ نیزه در لحظه‌ی برخورد + بازگشت نرم
func _strike_impact_fx() -> void:
        if _body == null:
                return
        var tw := create_tween()
        tw.set_parallel(true)
        tw.tween_property(_body, "position:z", 0.0, GameConstants.STRIKE_RECOVER)
        tw.tween_property(_body, "rotation:y", 0.0, GameConstants.STRIKE_RECOVER)
        match _swing_style:
                SwingStyle.SWORD_SLASH:
                        if _hand != null:
                                # اسلش: قوسِ تند از بالا-عقب به پایین-جلو (خوانا و زیبا)
                                var hs := create_tween()
                                hs.set_parallel(true)
                                hs.tween_property(_hand, "rotation:y", -1.35,
                                                GameConstants.STRIKE_LUNGE + 0.05) \
                                                .set_ease(Tween.EASE_OUT)
                                hs.tween_property(_hand, "rotation:z", -0.2,
                                                GameConstants.STRIKE_LUNGE + 0.05)
                                hs.chain().tween_property(_hand, "rotation:y", 0.0,
                                                GameConstants.STRIKE_RECOVER)
                                hs.parallel().tween_property(_hand, "rotation:z",
                                                0.0, GameConstants.STRIKE_RECOVER)
                SwingStyle.THRUST:
                        if _hand != null:
                                # کوبش: دست به جلو پرت می‌شود و نرم برمی‌گردد
                                var ht := create_tween()
                                ht.tween_property(_hand, "position:z", 0.34,
                                                GameConstants.STRIKE_LUNGE + 0.04) \
                                                .set_ease(Tween.EASE_OUT)
                                ht.tween_property(_hand, "position:z", 0.0,
                                                GameConstants.STRIKE_RECOVER)
                _:
                        pass


## گام ۶R2 — حرکت در حین نبرد به سمت هدف تا فاصله‌ی stop_at.
## ریشه‌ی «شمشیرزن به تیرانداز نزدیک نمی‌شود»: لایه ۳ فقط رو می‌چرخید و ضربه
## می‌زد — هدفِ دورِتر هیچ‌وقت تعقیب نمی‌شد. true = این فریم جابه‌جا شد.
func _combat_move_toward(delta: float, hostile: Node3D, stop_at: float,
                speed: float) -> bool:
        var d := _dist_xz_to(hostile)
        if d <= stop_at:
                return false
        var pos := Vector2(global_position.x, global_position.z)
        var up := Vector2(hostile.global_position.x, hostile.global_position.z)
        var dir := (up - pos).normalized()
        if dir == Vector2.ZERO:
                return false
        var step := dir * speed * delta
        var next := _avoid_step(pos, step, dir, delta)
        next = _separate(next)
        # گام ۶R3 — جداسازی نباید واحدِ تعقیب‌گر را به سلول بسته (خانه/صخره/آب)
        # بیندازد؛ فشار ازدحامِ نبرد جلوی خانه این را واقعاً اتفاق می‌انداخت
        next = _slide_walkable(pos, next)
        next = PathService.clamp_to_grid(next)
        var gy := 0.0
        if ground_provider.is_valid():
                gy = ground_provider.call(next)
        _y_smooth = lerpf(_y_smooth, gy, clampf(10.0 * delta, 0.0, 1.0))
        global_position = Vector3(next.x, _y_smooth, next.y)
        var target := atan2(dir.x, dir.y)
        var diff := wrapf(target - _heading, -PI, PI)
        _heading = wrapf(_heading + clampf(diff,
                        -GameConstants.ROTATE_SPEED_RAD * delta,
                        GameConstants.ROTATE_SPEED_RAD * delta), -PI, PI)
        rotation.y = _heading
        _bob_visual(true)
        return true


## هوک لایه ۳ زیرکلاس‌ها — آیا این واحد می‌خواهد با هدف بجنگد؟
## (قوانین کلاس: نیزه‌دار فقط ایست، کماندار ایست + مسیر باز، جاویدان همیشه)
func _combat_wants(_hostile: Node3D) -> bool:
        return false


## هوک لایه ۳ زیرکلاس‌ها — اجرای رفتار نبرد در هر فریمِ فعال
func _combat_tick(_delta: float, _hostile: Node3D) -> void:
        pass


## پایان رفتار نبرد (خروج هدف از برد / مرگ) — زیرکلاس ژست را برمی‌گرداند
func _combat_end() -> void:
        pass


# ---------------- اسلات آرایش ----------------

## اسلات آرایش این واحد را تعیین می‌کند (صحنه قبل از فرمان صدا می‌زند)
func set_slot(world_xz: Vector2) -> void:
        _slot = world_xz
        _has_slot = true
        # فرمان تازه: وول‌خوردنِ در جریان باطل — وگرنه فیدجتِ باقی‌مانده با اسلاتِ
        # کهنه ادامه می‌یافت و واحد به موقعیت قدیم «تله‌پورت» می‌شد
        _fidget_state = 0
        # گام ۶R4 — ساعتِ بی‌پیشرفتی و دورزدن هم برای مقصدِ نو صفر می‌شوند
        _stuck_t = 0.0
        _best_gd = 1e9
        _near_latch = false
        _wf_active = false
        _wf_t = 0.0
        if _arrived:
                _arrived = false
                _set_color(_spawn_color)


func clear_slot() -> void:
        _has_slot = false


func has_slot() -> bool:
        return _has_slot


func slot_pos() -> Vector2:
        return _slot


## هدف مؤثر این واحد: اسلات خودش یا هدف سراسری جریان (کانال ۰)
## گام ۶R9 — فراری فقط یک هدف دارد: ساحل (همه‌ی ماشینِ حرکتِ لایه ۱ استفاده می‌شود)
func _effective_goal() -> Vector2:
        if _fleeing:
                return _flee_goal
        return _slot if _has_slot else PathService.goal_world()


func _effective_arrive_radius() -> float:
        if _fleeing:
                return GameConstants.FLEE_ARRIVE_RADIUS
        return SLOT_ARRIVE_RADIUS if _has_slot else ARRIVE_RADIUS


# ---------------- حلقه‌ی اصلی: ۴ لایه با اولویت ----------------

func _process(delta: float) -> void:
        # گام ۶R — داخل خانه: هیچ لایه‌ای اجرا نمی‌شود (نامرئی، خارج از گروه units)
        if garrisoned:
                return
        _bob_t += delta

        # فلش سفید ضربه (§۱۰ — بدون عدد)
        if _flashing:
                _flash_t += delta
                if _flash_t >= 0.12:
                        _flashing = false
                        _set_color(GameConstants.COL_ARRIVED \
                                        if _arrived else _flash_restore)

        # ---- لایه ۳: واکنش نبرد (بالاترین اولویت) ----
        # گام ۶R9 — تسک A: فراری‌ها نمی‌جنگند (گروه منحل شده — فقط فرار)
        if _fleeing:
                _flee_t += delta   # گام ۶R9-fix — ساعتِ فرار از همین‌جا خوانده می‌شود
                if _in_combat:
                        _in_combat = false
                        _combat_target = null
                        _combat_end()
        else:
                _scan_accum += delta
                if _scan_accum >= GameConstants.COMBAT_SCAN_INTERVAL:
                        _scan_accum = 0.0
                        _rescan_hostile()
                if _in_combat and is_instance_valid(_combat_target):
                        _combat_tick(delta, _combat_target)
                        return

        # ---- لایه ۱/۲: حرکت و Fidget ----
        if _arrived:
                # لایه ۴ (گام ۵): آشکارسازی جابه‌جایی بیرونی (ضربه/کولک) —
                # واحدِ کناررفته خودش به پست بازمی‌گردد (گام ۶: دفاع از خانه/عقب‌نشینی)
                # ⚠️ در حین Fidget اعمال نمی‌شود (قدم وول تا 0.8m قانونی است)
                if _has_slot and _fidget_state == 0 \
                                and Vector2(global_position.x, global_position.z).distance_to(_slot) \
                                > SLOT_ARRIVE_RADIUS + 0.10:
                        _arrived = false
                        _vel = Vector2.ZERO
                        _set_color(_spawn_color)
                        return
                if _fidget_state != 0:
                        _process_fidget(delta)
                else:
                        # ایست در آرایش — گام ۶R12: بدنه‌ی اسکلتی با انیمیشن Idle
                        # خودش نفس می‌کشد؛ bobِ قدیمیِ چینی لرزش می‌ساخت (حذف شد)
                        _tick_fidget_timer(delta)
                return

        var pos := Vector2(global_position.x, global_position.z)
        var goal := _effective_goal()
        var to_goal := goal - pos
        var arrive_r := _effective_arrive_radius()
        if to_goal.length() <= arrive_r:
                # گام ۶R9 — تسک A: فراری به ساحل رسید → جزیره را ترک می‌کند
                # گام ۶R9-fix — اما نه پیش از FLEE_MIN_TIME ثانیه فرار؛ وگرنه
                # فراریِ کنارِ هدف، در همان فریمِ شروعِ فرار محو می‌شد
                if _fleeing:
                        if _flee_t >= GameConstants.FLEE_MIN_TIME:
                                _flee_despawn()
                                return
                else:
                        _arrived = true
                        _vel = Vector2.ZERO
                        _set_color(GameConstants.COL_ARRIVED)  # سرخ روشن = رسیده به هدف
                        return

        # گام ۶R4 — حرکتِ دوحالته با «چسبندگی»: داخلِ حبابِ هدایتِ مستقیم، اسلات
        # مرجع است و میدان کاری‌اش ندارد (هدفِ میدان «پستِ» دسته است نه اسلاتِ
        # واحد؛ میدان هرگز نمی‌تواند واحد را «دورِ» برآمدگیِ جلوی اسلات ببرد چون
        # گرادیانش فقط به‌سمتِ پست است). مرزِ حباب با هیسترزیسِ ۱ متری —
        # پینگ‌پنگِ مرز (میرفت بیرون، میدان برمی‌گرداند، دوباره مستقیم...) بود.
        var steer_r := SLOT_STEER_RADIUS if _has_slot else DIRECT_STEER_RADIUS
        var gd := to_goal.length()
        if gd < steer_r:
                _near_latch = true
        elif gd > steer_r + 1.0:
                _near_latch = false
                _wf_active = false
        # ساعتِ «بی‌پیشرفتیِ خالص»: سنجش نسبت به بهترینِ فاصله — لرزشِ خُردِ
        # جلو-عقبِ سرِ گوشه (±۰٫۰۲m) پیشرفت حساب نمی‌شود و ساعت می‌خواند.
        if gd < _best_gd - 0.01:
                _best_gd = gd
                _stuck_t = 0.0
        else:
                _stuck_t += delta
        # پیروی از دیوار (الگوی bug): هدایتِ مستقیم و میدان در گوشه‌ی مقعر
        # (L-shape) هر دو پین می‌شوند — ~۶۶° در یک سمتِ «متعهد» می‌چرخیم و
        # دورِ برآمدگی می‌رویم؛ چون فاصله ۰٫۳m از ابتدای دورزدن کمتر شد
        # (یا مهلت/دوریِ زیاد) → خروج به حالت عادی؛ اشتباهِ سمت با معکوس‌کردن.
        if _wf_active:
                _wf_t += delta
                _wf_best_gd = minf(_wf_best_gd, gd)
                if gd <= _wf_best_gd - 0.3:
                        _wf_active = false
                        _best_gd = gd
                        _stuck_t = 0.0
                elif _wf_t > 7.0 or gd > _wf_best_gd + 5.0:
                        _wf_active = false
                        _wf_side = -_wf_side
                        _best_gd = gd
                        _stuck_t = 0.0
        elif _stuck_t > 1.2:
                _wf_active = true
                _wf_t = 0.0
                _wf_best_gd = gd
                _stuck_t = 0.0
                _wf_pick_side(to_goal)

        # نزدیک اسلات/هدف، جریان صفر می‌شود → هدایت مستقیم (رفع باگ «یخ زدن»)
        var flow_d := PathService.sample_direction(pos, squad_id)
        var dir := to_goal.normalized() if _near_latch else flow_d
        # گام ۶R6 — ضدِ پینگ‌پنگِ «پستِ مقابلِ اسلات»: هدفِ میدانِ کانال «پستِ»
        # دسته است نه اسلاتِ واحد؛ اگر اسلات نزدیک باشد ولی میدان به سمتِ
        # مخالفِ اسلات برود (اسلات آن‌طرفِ مانع)، هدایتِ مستقیم + لغزشِ دیوار
        # ارجح است تا واحد بینِ پست و اسلات در نوسانِ ابدی نیفتد
        if not _near_latch and _has_slot and gd < 6.0 \
                        and flow_d != Vector2.ZERO \
                        and flow_d.dot(to_goal.normalized()) < -0.5:
                dir = to_goal.normalized()
                _near_latch = true
        if _wf_active:
                dir = to_goal.normalized().rotated(float(_wf_side) * 1.15)
        if dir == Vector2.ZERO:
                # گام ۶R — میدان روی «سلول هدفِ تغییرمسیر» (خانه/مانعِ وسط مسیر)
                # صفر است؛ ایستِ مطلق اینجا یخ‌زدگی دائمی می‌سازد (باگ گاریسون).
                # → هدایت مستقیم با گارد لغزش دیوار؛ واحد دور مانع می‌پیچد.
                dir = to_goal.normalized()
                if dir == Vector2.ZERO:
                        return

        # گام ۶R9-fix — فرارِ اضطراری = دویدنِ ویلان‌آسا (FLEE_SPEED_MULT)
        var speed := GameConstants.SPEED_BASE * speed_mult \
                        * (GameConstants.FLEE_SPEED_MULT if _fleeing else 1.0)
        var desired := dir * speed
        # §۵.۲ — شتاب 8 m/s² (به‌جای lerp نمایی: حرکت قابل‌پیش‌بینی و قانون‌مند)
        _vel = _vel.move_toward(desired, GameConstants.ACCEL * delta)
        if _vel.length_squared() < 0.0001:
                return
        # گام ۶R — قدم با پرهیز از مانع: اگر مسیر مستقیم بسته بود (حتی نزدیک
        # اسلات، داخل «سایه‌ی» شعاع هدایت مستقیم) جهت را نرم می‌چرخاند تا دور
        # مانع پیچ بخورد — رفع یخ‌زدگیِ «اسلات پشت خانه».
        pos = _avoid_step(pos, _vel * delta, dir, delta)
        pos = _separate(pos)
        # گام ۶R4 — فشار جداسازی (۱۹ سرباز خودی + ازدحام نبرد ساحل) هیچ‌کس را
        # به سلول بسته (آب/صخره/خانه) نمی‌فرستد — الگوی گاردِ EnemyBase ۶R3.
        # ریشه‌ی «واحدی انتهای فاز در آب بود» همین جداسازیِ بی‌گارد بود.
        pos = _slide_walkable(Vector2(global_position.x, global_position.z), pos)
        pos = PathService.clamp_to_grid(pos)
        # ایستادن روی زمین هموار (اگر provider وصل باشد) — هموارشده تا نپَرد
        var gy := 0.0
        if ground_provider.is_valid():
                gy = ground_provider.call(pos)
        _y_smooth = lerpf(_y_smooth, gy, clampf(10.0 * delta, 0.0, 1.0))
        global_position = Vector3(pos.x, _y_smooth, pos.y)

        # §۵.۲ — چرخش ۳۶۰ درجه بر ثانیه (به‌جای چرخش آنی)
        var moving := _vel.length_squared() > 0.01
        if moving:
                var target := atan2(_vel.x, _vel.y)
                var diff := wrapf(target - _heading, -PI, PI)
                _heading = wrapf(_heading + clampf(diff, -GameConstants.ROTATE_SPEED_RAD * delta,
                                GameConstants.ROTATE_SPEED_RAD * delta), -PI, PI)
                rotation.y = _heading
        _bob_visual(moving)


## وضعیت مغز واحد — برای تست خودکار و HUD
func brain_state() -> StringName:
        if _fleeing:
                return &"flee"
        if _in_combat:
                return &"combat"
        if _arrived:
                return &"fidget" if _fidget_state != 0 else &"idle"
        return &"moving"


# ---------------- گام ۶R9 — تسک A: انحلال گروه و فرار از جزیره ----------------

## آغاز فرار اضطراری — صحنه (IslandTest) هنگام انحلال گروه صدا می‌زند:
## نبرد رها می‌شود، اسلات پاک می‌شود و تنها هدف = ساحلِ نزدیک
func start_flee(shore_xz: Vector2) -> void:
        _fleeing = true
        _flee_goal = shore_xz
        _flee_t = 0.0   # گام ۶R9-fix — ساعتِ فرار صفر
        _in_combat = false
        _combat_target = null
        _combat_end()
        clear_slot()
        _arrived = false
        _near_latch = false
        _wf_active = false
        _best_gd = 1e9
        _stuck_t = 0.0
        _fidget_state = 0
        _vel = Vector2.ZERO
        _set_color(_spawn_color)   # رنگ تولد — تابع نیست، متغیر است (رفع خطای کامپایل)


## فراری به آبِ ساحل رسید — از صحنه خارج می‌شود (محوِ نرم، بدون جنازه؛ او «رفت»)
func _flee_despawn() -> void:
        _fleeing = false
        set_process(false)
        remove_from_group("units")
        set_selected_ring(false)
        GameEvents.unit_fled_island.emit(self)
        # گام ۶R۱۲ — محوِ مدلِ اسکلتی (جایگزین ChibiLook)
        if _model != null:
                _model.fade_out(0.7)
        var tw := create_tween()
        tw.tween_interval(1.1)
        tw.chain().tween_callback(queue_free)


## گام ۶R9 — تسک A: خاکستری‌شدن پیکر/پرتره — فرماندهِ افتاده رنگِ دسته را نمی‌ماند
func gray_out_body() -> void:
        _base_color = GameConstants.COL_FLAG_GRAY
        if _model != null:
                _model.apply_team_tint(GameConstants.COL_FLAG_GRAY, 0.8)


func is_arrived() -> bool:
        return _arrived


## گام ۶R۱۲ — محوِ نرمِ جنازه (سقفِ جنازه‌ها) — از صحنه صدا زده می‌شود
func fade_corpse(secs: float) -> void:
        if _model != null:
                _model.fade_out(secs)


func is_fidgeting() -> bool:
        return _arrived and _fidget_state != 0


## وضعیت داخلی Fidget — برای تست خودکار گام ۶R
func fidget_state_now() -> int:
        return _fidget_state


## هدف فعلی لایه ۳ (null = بیرون نبرد)
func combat_target() -> Node3D:
        return _combat_target


## شعاع جست‌وجوی دشمن این کلاس — کماندار باید از «برد شلیک» ببیند
func _scan_radius() -> float:
        return GameConstants.AGGRO_RADIUS


func _rescan_hostile() -> void:
        var h := _nearest_hostile(_scan_radius())
        if h != null and _combat_wants(h):
                if not _in_combat or _combat_target != h:
                        _combat_begin(h)
                return
        if _in_combat:
                # پایان نبرد — حتی اگر هدف آزاد شده باشد (بازگرداندن ژست کلاس)
                _in_combat = false
                _combat_target = null
                _combat_end()


func _combat_begin(h: Node3D) -> void:
        # نبرد بر Fidget اولویت دارد — وول‌خوردن لغو می‌شود
        _fidget_state = 0
        _combat_target = h
        _in_combat = true


func _nearest_hostile(max_dist: float) -> Node3D:
        var best: Node3D = null
        var best_d := max_dist
        for n in get_tree().get_nodes_in_group("hostiles"):
                var h := n as Node3D
                if h == null or not h.is_inside_tree():
                        continue
                if h.has_method("is_alive") and not h.is_alive():
                        continue
                var d := global_position.distance_to(h.global_position)
                if d < best_d:
                        best_d = d
                        best = h
        return best


## آیا مسیر شلیک از این واحد تا نقطه‌ی هدف باز است؟ (قانون کماندار §۵ سند طراحی)
## زمینِ تپه‌مانند وسط مسیر = مسیر بسته؛ در گام ۶ صخره/سپر دشمن هم اضافه می‌شود.
func has_clear_shot(from_xz: Vector2, from_y: float, to_xz: Vector2, to_y: float) -> bool:
        var dist := from_xz.distance_to(to_xz)
        if dist < 0.5:
                return true
        var steps := maxi(int(dist / 0.4), 2)
        var line_h := maxf(from_y, to_y)
        for i in range(1, steps):
                var k := float(i) / float(steps)
                var p := from_xz.lerp(to_xz, k)
                if ground_provider.is_valid():
                        var gh: float = ground_provider.call(p)
                        # تیر از فراز قوس بالستیک رد می‌شود — سقفِ مجاز: خط مستقیم + نیم‌متر
                        if gh > line_h + 0.5:
                                return false
        return true


## آیا این واحد «عملاً سرِ جایش» است؟ (رسیده یا چسبیده به اسلاتش)
## گام ۶R۱۲ — خانه‌نشین‌ها بخشی از چشم‌اندازِ آرایش‌اند: جداسازی آنها را سد
## نمی‌کند و تیرِ بالستیک از فرازشان رد می‌شود (وگرنه کماندار تا ابد ساکت
## می‌ماند — یک هم‌رزمیِ سرِ پستِ دسته‌ی دیگر در امتدادِ تیر کافی بود)
func _is_practically_home(n: Node3D) -> bool:
        var u := n as UnitBase
        if u == null:
                return false
        if u.is_arrived():
                return true
        if not u.has_slot():
                return false
        return u.slot_pos().distance_to(Vector2(u.global_position.x,
                        u.global_position.z)) <= SLOT_ARRIVE_RADIUS + 0.25


## آیا بین این واحد و هدف، هم‌رزمی ایستاده؟ (قانون «آسیب دوستانه ندارد»)
## برای جلوگیری از بن‌بستِ آرایشِ فشرده، فقط هم‌رزمیِ «میانه‌ی مسیر» مانع است:
##   * هم‌رزمیِ شانه‌به‌شانه در ۲۰٪ ابتدای مسیر سد نیست (تیر از فراز سرشان می‌رود)
##   * هم‌رزمیِ چسبیده به هدف سد نیست
func friendly_in_corridor(target_xz: Vector2) -> bool:
        var from := Vector2(global_position.x, global_position.z)
        var to := target_xz
        var seg := to - from
        var seg_len := seg.length()
        if seg_len < 0.001:
                return false
        for n in get_tree().get_nodes_in_group("units"):
                var u := n as Node3D
                if u == null or u == self:
                        continue
                # خانه‌نشین‌ها سد نیستند — تیر از فرازِ آرایش رد می‌شود (۶R۱۲)
                if _is_practically_home(u):
                        continue
                var up := Vector2(u.global_position.x, u.global_position.z)
                var t := clampf((up - from).dot(seg) / (seg_len * seg_len), 0.0, 1.0)
                # گام ۶R۱۲ — سرِ مسیر تا ۳۰٪ آزاد است: تیرِ بالستیک از فرازِ
                # آرایشِ متراکمِ خودی (حلقه‌های ۰٫۵۵m) رد می‌شود؛ بندِ ۲۰٪ قدیمی
                # با جداسازیِ ۰٫۷۲m تقریباً همه‌ی شلیک‌های نزدیک را می‌بست
                if t < 0.3 or t > 0.85:
                        continue
                var proj := from + seg * t
                if proj.distance_to(up) <= GameConstants.FRIENDLY_CORRIDOR_HALF_W \
                                and up.distance_to(to) > 0.9:
                        return true
        return false


## پرچم سراسری جابه‌جا شد → «رسیده‌های بدون اسلات» بیدار می‌شوند (صحنه‌ی FlowFieldTest)
func _on_goal_changed(_new_goal: Vector2) -> void:
        if _arrived and not _has_slot:
                _arrived = false
                _vel = Vector2.ZERO
                _set_color(_spawn_color)  # برگشت به رنگ تولد


## حلقه‌ی انتخاب دسته — گام ۶R10: زبان انتخاب Bad North از اسکرین‌شات‌های کاربر:
## دسته‌ی انتخابی «تمام‌قد» فیروزه‌ی روشن می‌شود (بدنه + پرچم + حلقه‌ی زیر پا)
## و با لغو انتخاب به رنگ منطقیِ جاری (تولد/خاکستری بی‌فرمانده) برمی‌گردد.
## نکته: رنگ منطقی در _base_color زندگی می‌کند؛ تینتِ انتخاب فقط شیدر را عوض
## می‌کند تا با فلشِ ضربه (یونیفرم flash) و حالت «رسیده» تداخل نکند.
func set_selected_ring(on: bool) -> void:
        if _ring != null:
                _ring.visible = on
                var rm := _ring.material_override as StandardMaterial3D
                if rm != null:
                        rm.albedo_color = GameConstants.COL_SELECTED \
                                        if on else Color(1, 1, 1, 0.35)
        if _model == null:
                return
        var fl := _find_squad_flag()
        if on:
                if _model != null:
                        _model.apply_team_tint(GameConstants.COL_SELECTED, 0.78)
                if fl != null:
                        fl.set_color(GameConstants.COL_SELECTED)
        else:
                if _model != null:
                        _model.apply_team_tint(_base_color, 0.42)
                if fl != null:
                        fl.set_color(_base_color)


## پرچمِ فرمانده — فقط فرماندهِ دسته SquadFlag دارد (صحنه به فرزندش وصل می‌کند)
func _find_squad_flag() -> SquadFlag:
        for c in get_children():
                if c is SquadFlag:
                        return c
        return null


## رنگ فعلی تینتِ مدل — برای تست خودکارِ تینت انتخاب
func body_shader_color() -> Color:
        if _model != null:
                return _model.display_color()
        return _base_color


func is_ring_visible() -> bool:
        return _ring != null and _ring.visible


# ---------------- گام ۶R — ورود/خروج از خانه (گاریسون) ----------------

## ورود به خانه: پنهان، بی‌واکنش، خارج از گروه «units» (مهاجمان نمی‌بینندش)
func enter_house() -> void:
        garrisoned = true
        visible = false
        _in_combat = false
        _combat_target = null
        _combat_end()
        _fidget_state = 0
        if is_in_group("units"):
                remove_from_group("units")


## خروج از خانه در نقطه‌ی داده‌شده — آماده‌ی آرایش تازه
func exit_house(at: Vector3) -> void:
        garrisoned = false
        visible = true
        global_position = at
        _y_smooth = at.y
        _vel = Vector2.ZERO
        _arrived = false
        _set_color(_spawn_color)
        if not is_in_group("units"):
                add_to_group("units")


## «در سفر به فرمان جدید است؟» — لایه ۳ نباید فرمان کاربر را خفه کند:
## تا وقتی واحد دور از اسلاتِ تازه است، فقط تماسِ نزدیک (CONTACT) واکنش می‌دهد
func _is_traveling() -> bool:
        return _has_slot and not _arrived \
                and _effective_goal().distance_to(
                        Vector2(global_position.x, global_position.z)) > SLOT_STEER_RADIUS + 0.6


func _dist_xz_to(n: Node3D) -> float:
        return Vector2(global_position.x, global_position.z).distance_to(
                Vector2(n.global_position.x, n.global_position.z))


func body_color() -> Color:
        return _base_color


## رنگ فعلی بدنه — برای تست خودکار (رنگ تولد نباید سرخ «رسیده» باشد)
func spawn_color() -> Color:
        return _spawn_color


## جداسازی ساده بین واحدها (تا روی هم نلغزند) — هزینه با ≤۱۶ واحد ناچیز است
func _separate(pos: Vector2) -> Vector2:
        var out := pos
        var others := get_tree().get_nodes_in_group("units")
        for other in others:
                if other == self:
                        continue
                # رسیده‌ها و خانه‌نشین‌ها جا می‌دهند (۶R۱۲): دورِ اسلات جمع می‌شوند
                # ولی مانع رسیدن بقیه نمی‌شوند
                if other is UnitBase and _is_practically_home(other):
                        continue
                var op := Vector2(other.global_position.x, other.global_position.z)
                var diff := out - op
                var d := diff.length()
                if d > 0.001 and d < SEPARATION_DIST:
                        out += (diff / d) * (SEPARATION_DIST - d) * 0.5
        # گام ۶R۱۲ — میراییِ نزدیکِ اسلاتِ خود: واحدی که به اسلاتش چسبیده
        # فشارِ جداسازی را ۵۵٪ کم می‌کند تا نوسانِ «رسیدن ← هل خوردن ← برگشتن»
        # تمام شود و آرایشِ متراکمِ اسکرین‌شات سرِ جایش بنشیند
        # (حلقه‌های ۰٫۵۵m شانه‌به‌شانه، نه روی هم)
        if _has_slot and pos.distance_to(_slot) <= SLOT_ARRIVE_RADIUS * 2.0:
                var corr := out - pos
                out = pos + corr * 0.45
        return out


## گام ۶R4 — انتخابِ سمتِ دورزدن: سمتی که قدمِ اولش بازتر است (۶۶° چرخیده)؛
## اگر هر دو سمت یکسان بود، سمت عوض می‌شود تا از تکرارِ مسیرِ شکست‌خورده بگریزد.
func _wf_pick_side(to_goal: Vector2) -> void:
        var tg := to_goal.normalized()
        var here := Vector2(global_position.x, global_position.z)
        var s_pos := _slide_walkable(here, here + tg.rotated(1.15) * 0.6)
        var s_neg := _slide_walkable(here, here + tg.rotated(-1.15) * 0.6)
        var d_pos := s_pos.distance_to(here)
        var d_neg := s_neg.distance_to(here)
        if d_pos > d_neg + 0.01:
                _wf_side = 1
        elif d_neg > d_pos + 0.01:
                _wf_side = -1
        else:
                _wf_side = -_wf_side


## گام ۶R — گارد لغزش: قدم بعدی روی سلول بلاک (خانه/آب/صخره) نمی‌افتد.
## مثل _move_with دشمن: اول لغزش تک‌محوره X، بعد Y؛ اگر هر دو بسته → همان‌جا.
func _slide_walkable(from: Vector2, next: Vector2) -> Vector2:
        var nav := PathService.nav
        if nav == null or nav.is_walkable(nav.world_to_cell(next)):
                return next
        var s1 := Vector2(next.x, from.y)
        if nav.is_walkable(nav.world_to_cell(s1)):
                return s1
        var s2 := Vector2(from.x, next.y)
        if nav.is_walkable(nav.world_to_cell(s2)):
                return s2
        return from


## گام ۶R — قدمِ پرهیز از مانع: مسیر مستقیم اگر بیش از ۴۰٪ بسته بود، جهت را
## در ۴۵°/۹۰°/۱۳۵° می‌چرخانیم و بهترین پیشرفتِ «به سمت هدف» را برمی‌داریم.
## موانع جزیره (خانه/صخره) محدب‌اند → پیچ خوردن نرم همیشه راه باز می‌کند.
## ⚠️ ضد نوسان: سمتِ چرخش تا ۰.۸s «تعهد» می‌شود — وگرنه tieهای هر فریم واحد را
## در یک چرخه‌ی حدی (بالا-پایین جلوی دیوار) قفل می‌کردند.
func _avoid_step(from: Vector2, step: Vector2, to_dir: Vector2,
                delta: float) -> Vector2:
        var want := step.length()
        if want < 0.0001:
                return from
        var base := _slide_walkable(from, from + step)
        if from.distance_to(base) >= want * 0.6:
                _avoid_side = 0          # حرکت مستقیم برقرار — تعهد برداشته می‌شود
                _avoid_hold = 0.0
                return base
        _avoid_hold -= delta
        var angs: Array = [PI * 0.25, -PI * 0.25, PI * 0.5, -PI * 0.5,
                        PI * 0.75, -PI * 0.75]
        if _avoid_side != 0 and _avoid_hold > 0.0:
                # فقط سمتِ تعهدشده — تا دور زدنِ مانع تمام شود
                angs = [_avoid_side * PI * 0.25, _avoid_side * PI * 0.5,
                                _avoid_side * PI * 0.75]
        var best := base
        var best_score := -1e9
        var best_ang := 0.0
        for ang in angs:
                var d := to_dir.rotated(ang)
                var cand := _slide_walkable(from, from + d * want)
                var progress := from.distance_to(cand)
                if progress < 0.0005:
                        continue
                var toward := (cand - from).normalized().dot(to_dir)
                # امتیاز = پیشرفت واقعی × هم‌راستایی با هدف؛ چرخش زیاد جریمه می‌شود
                var score := progress * (0.35 + 0.65 * clampf(toward, 0.0, 1.0))
                if score > best_score:
                        best_score = score
                        best = cand
                        best_ang = ang
        if best_score <= -1e9:
                # سمتِ تعهدشده کاملاً بسته شد → تعهد را بشکن و یک‌بار full-scan کن
                if _avoid_side != 0:
                        _avoid_side = 0
                        _avoid_hold = 0.0
                        return _avoid_step(from, step, to_dir, 0.0)
                return base
        if _avoid_side == 0 and best_ang != 0.0:
                _avoid_side = 1 if best_ang > 0.0 else -1
        _avoid_hold = 0.8
        return best


func _bob_visual(moving: bool) -> void:
        # گام ۶R12 — فقط انیمیشن اسکلتی؛ bobِ عمودی حذف شد (ریشه‌ی «همش تکان
        # می‌خوردن» — بازخورد کاربر)
        if _model != null:
                _model.set_moving(moving)


func _set_color(c: Color) -> void:
        _base_color = c
        # گام ۶R10 — حینِ انتخابِ Bad North بدنه فیروزه‌ای می‌ماند؛ رنگِ منطقی
        # (رسیده/تولد) فقط ثبت می‌شود تا با لغو انتخاب برگردد
        if is_ring_visible():
                return
        if _model != null:
                _model.apply_team_tint(c, 0.42)


# ---------------- Fidget (§۵.۳ پرامت — لایه ۲) ----------------
## «واحدها وول می‌خورند و شلوغ می‌کنند؛ گاهی یک جامانده بیرون می‌زند»

func _tick_fidget_timer(delta: float) -> void:
        if not fidget_enabled or not _has_slot:
                return
        _fidget_timer -= delta
        if _fidget_timer > 0.0:
                return
        _fidget_timer = _rng.randf_range(GameConstants.FIDGET_INTERVAL_MIN,
                        GameConstants.FIDGET_INTERVAL_MAX)
        # یک قدم کوتاه به بیرون آرایش (0.4–0.8 m) — به سمت خودِ اسلات برنمی‌گردیم
        var ang := _rng.randf() * TAU
        var dist := _rng.randf_range(GameConstants.FIDGET_DIST_MIN, GameConstants.FIDGET_DIST_MAX)
        _fidget_from = _slot
        _fidget_to = _slot + Vector2(cos(ang), sin(ang)) * dist
        # گارد: مقصد وول‌خوردن باید قابل‌عبور بماند (خانه/صخره/آب) — وگرنه این نوبت را رد کن
        var nav := PathService.nav
        if nav != null and not nav.is_walkable(nav.world_to_cell(_fidget_to)):
                return
        _fidget_t = 0.0
        _fidget_dur = _rng.randf_range(GameConstants.FIDGET_DUR_MIN, GameConstants.FIDGET_DUR_MAX)
        _fidget_state = 1


func _process_fidget(delta: float) -> void:
        # گارد دفاعی: مبدأ/مقصد فیدجت باید نزدیک اسلاتِ فعلی باشند — با اسلاتِ
        # عوض‌شده، فیدجتِ کهنه اعتبار ندارد (همان ریشه‌ی «تله‌پورت»)
        if _fidget_from.distance_to(_slot) > 1.5 or _fidget_to.distance_to(_slot) > 1.5:
                _fidget_state = 0
                return
        _fidget_t += delta
        var k := clampf(_fidget_t / _fidget_dur, 0.0, 1.0)
        var target := (_fidget_to if _fidget_state == 1 else _fidget_from)
        var pos := _fidget_from.lerp(target, k) if _fidget_state == 1 \
                        else _fidget_to.lerp(target, k)
        var gy := 0.0
        if ground_provider.is_valid():
                gy = ground_provider.call(pos)
        _y_smooth = lerpf(_y_smooth, gy, clampf(10.0 * delta, 0.0, 1.0))
        global_position = Vector3(pos.x, _y_smooth, pos.y)
        _body.position.y = 0.0
        if k >= 1.0:
                if _fidget_state == 1:
                        _fidget_state = 2  # بازگشت به آرایش
                        _fidget_t = 0.0
                else:
                        _fidget_state = 0
