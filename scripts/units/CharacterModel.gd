class_name CharacterModel
extends Node3D
## کاراکتر Low-Poly واقعی — گام ۶R۱۲: پک «Quaternius» (لایسنس CC0) جایگزین
## KayKit — بازخورد کاربر: «کیفیت کاراکترها خوب نیست؛ باکیفیت‌تر پیدا کن».
##
## پک‌ها (هر دو CC0، فایل glTF با بافت/بافر embed — تک‌فایلی):
##   * RPG Character Pack: Warrior / Ranger / Rogue / Wizard / Cleric / Monk
##   * Ultimate Animated Character Pack: Viking_Male / Knight_Male / Soldier_Male …
##
##   * هر کاراکتر AnimationPlayer کامل دارد: Idle / Walk / Run / حمله /
##     RecieveHit / Death — انیمیشن واقعی اسکلتی (لرزشِ bobِ قدیمی حذف شد)
##   * رنگ تیم: همه‌ی متریال‌ها per-instance و به رنگ دسته می‌گرایند
##   * قد نرمال می‌شود به TARGET_HEIGHT (مدل‌ها ~۲٫۹–۳٫۶m ایمپورت می‌شوند)
##
## نقش‌ها:
##   warrior      → جاویدان (شمشیر + سپر پروسیجرال، انیمیشن Sword_Attack)
##   ranger       → کماندار (انیمیشن Bow_Shoot واقعی — ارتقای بزرگِ ۶R۱۲)
##   viking       → نیزه‌دار خودی / مهاجم سبک (تبر + نیزه‌ی پروسیجرال)
##   knight_heavy → هوپلیت سنگین دشمن (شمشیر + سپر مستطیلی)
##   soldier      → پرتاب‌گر دشمن (نیزه‌ی پرتابِ پروسیجرال)

const MODEL_DIR := "res://assets/models/quaternius/"
## گام ۶R۱۲ — بازخورد کاربر «کاراکترها یکهو بزرگ شدند»: قد نهایی کوچک‌تر تا
## نسبت سرباز به پد/خانه مثل اسکرین‌شات‌های Bad North باشد (سرباز ریزِ جزیره)
const TARGET_HEIGHT := 0.82   # بلندی نهایی کاراکتر (m)

## نام انیمیشن‌های مشترک — پک‌های Quaternius هر دو همین نام‌ها را دارند
const A_IDLE := "Idle"
const A_WALK := "Walk"
const A_HIT := "RecieveHit"
const A_DEATH := "Death"

## پیکربندی هر نقش: فایل + انیمیشن حمله
const KINDS := {
        &"warrior": {
                "file": "Warrior.gltf",
                "attack": "Sword_Attack",
        },
        &"ranger": {
                "file": "Ranger.gltf",
                "attack": "Bow_Shoot",
        },
        &"viking": {
                "file": "Viking_Male.gltf",
                "attack": "SwordSlash",
        },
        &"knight_heavy": {
                "file": "Knight_Male.gltf",
                "attack": "SwordSlash",
        },
        &"soldier": {
                "file": "Soldier_Male.gltf",
                "attack": "SwordSlash",
        },
}

static var _scene_cache: Dictionary = {}

var _kind: StringName = &"warrior"
var _root: Node3D
var _anim: AnimationPlayer
var _mats: Array[StandardMaterial3D] = []
var _mat_colors: Array[Color] = []
var _tex: Texture2D = null
var _moving := false
var _busy := false             # انیمیشن یک‌باره در جریان است (حمله/ضربه)
var _dead := false
var _attack_anim := "SwordSlash"
## آخرین تینتِ اعمال‌شده — برای تست خودکار و دیباگ (display_color)
var _tint := Color.WHITE
var _tint_k := 0.0
## گام ۶R۱۳ — مقیاسِ نرمال‌شده‌ی قد (set_crouch روی همین ضرب می‌شود تا
## «غول‌شدن» هنگام نبرد رخ ندهد — بازخورد کاربر)
var _norm_scale := 1.0


## ساخت و آماده‌سازی — قبل از add_child صدا زده می‌شود (به درخت نیاز ندارد)
func setup(kind: StringName, tint: Color, tint_k := 0.42,
                special: Dictionary = {}) -> void:
        _kind = kind if KINDS.has(kind) else &"warrior"
        var cfg: Dictionary = KINDS[_kind]
        var path: String = MODEL_DIR + String(cfg["file"])
        if not _scene_cache.has(path):
                _scene_cache[path] = load(path)
        var ps: PackedScene = _scene_cache[path]
        if ps == null:
                push_warning("CharacterModel: scene missing %s" % path)
                return
        _root = ps.instantiate() as Node3D
        if _root == null:
                return
        # گام ۶R۱۲ — ضدِ کرش: آزادشدنِ مدل، انیمیشن‌پلیر را null می‌کند تا
        # هیچ فریمِ بعدی روی شیءِ مرده کار نکند
        _root.tree_exiting.connect(_on_root_freed)
        add_child(_root)
        if cfg.has("attack"):
                _attack_anim = String(cfg["attack"])
        _setup_anim()
        _collect_and_tint(tint, tint_k, special)
        _normalize_height()


func body_root() -> Node3D:
        return _root


func _on_root_freed() -> void:
        _anim = null
        _mats.clear()
        _mat_colors.clear()


# ---------------- آماده‌سازی ----------------

func _setup_anim() -> void:
        var players := _root.find_children("*", "AnimationPlayer", true, false)
        if players.is_empty():
                return
        _anim = players[0] as AnimationPlayer
        # لوپِ حالت‌های پیوسته
        for a in [A_IDLE, A_WALK, "Run"]:
                if _anim.has_animation(a):
                        _anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
        _anim.animation_finished.connect(_on_anim_finished)
        _play(A_IDLE)
        # گام ۶R۱۲ — فازِ تصادفیِ آیدل: سربازها هم‌زمان و ماشینی نفس نمی‌کشند
        if _anim.has_animation(A_IDLE):
                _anim.seek(_anim.get_animation(A_IDLE).length * randf(), true)


## متریال‌ها per-instance + گِرَش رنگ تیم
func _collect_and_tint(tint: Color, tint_k: float, special: Dictionary) -> void:
        var meshes := _root.find_children("*", "MeshInstance3D", true, false)
        for m in meshes:
                var mi := m as MeshInstance3D
                if mi.mesh == null:
                        continue
                for i in mi.mesh.get_surface_count():
                        var mat := mi.get_active_material(i)
                        if mat is StandardMaterial3D:
                                var sm := (mat as StandardMaterial3D).duplicate() \
                                                as StandardMaterial3D
                                mi.set_surface_override_material(i, sm)
                                _mats.append(sm)
                                _mat_colors.append(sm.albedo_color)
                                if _tex == null and sm.albedo_texture != null:
                                        _tex = sm.albedo_texture
        apply_team_tint(tint, tint_k)


## گِرَش همه‌ی متریال‌ها به رنگ تیم — میکس پیش‌فرض ۴۲٪ تا شکلِ کاراکتر زیر رنگ
## گم نشود. رنگِ تینت‌شده جایگزین رنگ پایه در حافظه می‌شود تا فلشِ سفیدِ ضربه
## بعد از بازیابی، تینتِ تیم را از دست ندهد.
func apply_team_tint(tint: Color, tint_k := 0.42) -> void:
        _tint = tint
        _tint_k = tint_k
        for i in _mats.size():
                var c := _mat_colors[i].lerp(tint, tint_k)
                _mats[i].albedo_color = c
                _mat_colors[i] = c


## آخرین رنگِ تینتِ اعمال‌شده (قبل از میکس با پالت) — مصرفِ تستِ انتخاب
func display_color() -> Color:
        return _tint


## توقفِ فوریِ انیمیشن در ژستِ فعلی — برای جسدِ یخ‌زده (اگر لازم شود)
func freeze_pose() -> void:
        _busy = false
        if _anim != null:
                _anim.pause()


## هم‌ارزسازی قد — مدل‌ها ~۲٫۹–۳٫۶ واحد ایمپورت می‌شوند؛ به TARGET_HEIGHT می‌رسیم
func _normalize_height() -> void:
        var top := _scan_top(_root, Transform3D.IDENTITY)
        if top > 0.1:
                _norm_scale = TARGET_HEIGHT / top
                _root.scale = Vector3(_norm_scale, _norm_scale, _norm_scale)


## گام ۶R۱۳ — نشستنِ کوتاهِ زانو در حالتِ سپر — بدونِ نابودیِ مقیاسِ نرمال:
## زیرکلاس‌ها دیگر هرگز مستقیم _body.scale را دستکاری نمی‌کنند (ریشه‌ی
## «یهو مثل غول بزرگ میشن» — مقیاسِ نرمال ~۰٫۲۵ با Vector3.ONE پاک می‌شد)
func set_crouch(k: float) -> void:
        if _root == null:
                return
        _root.scale = Vector3(_norm_scale, _norm_scale * k, _norm_scale)


func _scan_top(node: Node3D, xf: Transform3D) -> float:
        var local := xf * node.transform
        var top := 0.0
        if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
                var aabb: AABB = local * (node as MeshInstance3D).mesh.get_aabb()
                top = aabb.end.y
        for c in node.get_children():
                if c is Node3D:
                        top = maxf(top, _scan_top(c as Node3D, local))
        return top


# ---------------- پخش انیمیشن ----------------

func _play(name: String, speed := 1.0, blend := 0.18) -> void:
        if _anim == null or not _anim.has_animation(name):
                return
        _anim.play(name, blend, speed)


func _on_anim_finished(name: StringName) -> void:
        if StringName(name) == StringName(A_DEATH):
                return  # روی آخرین فریمِ افتادن بمان
        _busy = false
        _apply_locomotion()


## وضعیت حرکت — هر فریم از UnitBase صدا زده می‌شود؛ فقط در تغییر وضعیت کاری می‌کند
func set_moving(moving: bool) -> void:
        if moving != _moving:
                _moving = moving
                if not _busy and not _dead:
                        _apply_locomotion()


func _apply_locomotion() -> void:
        if _dead or _busy or _anim == null:
                return
        _play(A_WALK if _moving else A_IDLE)


## حمله (یک‌باره) — سرعت انیمیشن با چرخه‌ی ضربه‌ی بازی (~۰٫۴۵s) هم‌گام می‌شود
func play_attack() -> void:
        if _dead or _anim == null:
                return
        var speed := 1.0
        if _anim.has_animation(_attack_anim):
                var ln := _anim.get_animation(_attack_anim).length
                speed = clampf(ln / 0.45, 1.0, 2.4)
        _busy = true
        _play(_attack_anim, speed, 0.1)


func play_hit() -> void:
        if _dead or _anim == null:
                return
        if _anim.has_animation(A_HIT):
                _busy = true
                _play(A_HIT, 1.4, 0.08)


## ایستِ سپری — پک‌های Quaternius انیمیشن Blocking ندارند؛ no-op امن
## (حالتِ نبردِ جاویدان با play_attack و تینت سپر خوانا می‌ماند)
func set_blocking(_on: bool) -> void:
        pass


func play_death() -> void:
        if _dead:
                return
        _dead = true
        if _anim != null and _anim.has_animation(A_DEATH):
                _busy = true
                # گام ۶R۱۳ — «دشمن ایستاده می‌میرد» (بازخورد کاربر): پک‌ها Death
                # کش‌دار دارند (Ultimate ~۲٫۳s که نیمی‌اش سکوتِ اولیه است) —
                # کلِ افتادن در ≤۰٫۹ ثانیه کامل می‌شود تا مرگ همیشه دیده شود
                var speed := 1.0
                var ln := _anim.get_animation(A_DEATH).length
                if ln > 0.05:
                        speed = clampf(ln / 0.9, 1.0, 2.6)
                _play(A_DEATH, speed, 0.08)


# ---------------- افکت‌های ضربه و مرگ ----------------

## فلش سفید کلاسیک — بافت موقتاً حذف → سیلوئت تمام‌سفید؛ ۰٫۱۲s بعد برمی‌گردد
func flash_white() -> void:
        if _mats.is_empty() or _dead:
                return
        for m in _mats:
                m.albedo_color = Color(1, 1, 1, 1)
                m.albedo_texture = null
        var tw := create_tween()
        tw.tween_interval(0.12)
        tw.tween_callback(_restore_flash)


func _restore_flash() -> void:
        for i in _mats.size():
                _mats[i].albedo_texture = _tex
                _mats[i].albedo_color = _mat_colors[i]


## محوِ جسد — متریال‌ها ALPHA و آلفا به صفر (فرار از جزیره)
func fade_out(secs: float) -> void:
        if _mats.is_empty():
                return
        for m in _mats:
                m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        var tw := create_tween()
        tw.tween_interval(0.35)
        tw.set_parallel(true)
        for m in _mats:
                tw.tween_property(m, "albedo_color:a", 0.0, secs)
