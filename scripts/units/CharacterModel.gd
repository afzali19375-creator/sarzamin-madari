class_name CharacterModel
extends Node3D
## کاراکتر Low-Poly واقعی (پک KayKit «Adventurers» — لایسنس CC0) جایگزین
## استوانه‌ی ساده‌ی قبلی — بازخورد کاربر: «گرافیک واقعا ساده است؛ برو پروژه‌های
## اپن‌سورس پیدا کن و از کاراکترهای آنها استفاده کن».
##
## پک گیت‌هاب: KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
##   * هر کاراکتر یک AnimationPlayer کامل دارد (۷۶ انیمیشن): راه‌رفتن، حمله،
##     ضربه‌خوردن، مرگ، پرتاب، سپر و ...
##   * اسلحه‌های همه‌ی واریانت‌ها داخل GLB روی دست‌ها سوارند → در setup پاکسازی
##     می‌شوند (فقط سلاحِ نقشِ این یونیت دیده می‌شود)
##   * رنگ تیم: همه‌ی متریال‌ها per-instance دوباره‌سازی و به رنگ دسته می‌گرایند
##     (۳۵-۵۰٪ میکس — بافت پالت کاراکتر حفظ می‌شود)
##
## نقش‌ها (بازخورد اسکرین‌شات‌های Bad North):
##   knight        → جاویدان (شمشیر + سپر مستطیلی فیروزه‌ای)
##   knight_round  → هوپلیت سنگین دشمن (شمشیر + سپر گرد)
##   barbarian     → نیزه‌دار خودی / هوپلیت سبک دشمن (تبر + سپر گرد + نیزه‌ی پروسیجرال)
##   rogue_hooded  → کماندار خودی (کاتاپولت دوشی)
##   rogue_thrower → پرتاب‌گر دشمن (سنگ پرتابی در دست)

const MODEL_DIR := "res://assets/models/kaykit/"
const TARGET_HEIGHT := 0.95   # بلندی نهایی کاراکتر (m) — متناسب با تایل ۲ متری

## نام انیمیشن‌های مشترک در همه‌ی کاراکترهای پک
const A_IDLE := "Idle"
const A_WALK := "Walking_A"
const A_RUN := "Running_A"
const A_HIT := "Hit_A"
const A_DEATH := "Death_A"
const A_BLOCK := "Blocking"   # حالتِ نگه‌داشتن سپر (لوپ)

## پیکربندی هر نقش: فایل + پاکسازی تجهیز + انیمیشن حمله
const KINDS := {
        &"knight": {
                "file": "Knight.glb",
                "show": ["1H_Sword", "Rectangle_Shield"],
                "hide": ["1H_Sword_Offhand", "Badge_Shield", "Round_Shield",
                                "Spike_Shield", "2H_Sword"],
                "attack": "1H_Melee_Attack_Stab",
        },
        &"knight_round": {
                "file": "Knight.glb",
                "show": ["1H_Sword", "Round_Shield"],
                "hide": ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield",
                                "Spike_Shield", "2H_Sword"],
                "attack": "1H_Melee_Attack_Stab",
        },
        &"barbarian": {
                "file": "Barbarian.glb",
                "show": ["1H_Axe", "Barbarian_Round_Shield"],
                "hide": ["1H_Axe_Offhand", "2H_Axe", "Mug"],
                "attack": "1H_Melee_Attack_Stab",
        },
        &"rogue_hooded": {
                "file": "Rogue_Hooded.glb",
                "show": ["2H_Crossbow"],
                "hide": ["1H_Crossbow", "Knife", "Knife_Offhand"],
                "attack": "1H_Ranged_Shoot",
        },
        &"rogue_thrower": {
                "file": "Rogue.glb",
                "show": [],
                "hide": ["1H_Crossbow", "2H_Crossbow", "Knife", "Knife_Offhand",
                                "Throwable"],
                "attack": "Throw",
        },
}

static var _scene_cache: Dictionary = {}

var _kind: StringName = &"knight"
var _root: Node3D
var _anim: AnimationPlayer
var _mats: Array[StandardMaterial3D] = []
var _mat_colors: Array[Color] = []
var _tex: Texture2D = null
var _moving := false
var _busy := false             # انیمیشن یک‌باره در جریان است (حمله/ضربه)
var _dead := false
var _attack_anim := "1H_Melee_Attack_Stab"
## آخرین تینتِ اعمال‌شده — برای تست خودکار و دیباگ (display_color)
var _tint := Color.WHITE
var _tint_k := 0.0


## ساخت و آماده‌سازی — قبل از add_child صدا زده می‌شود (به درخت نیاز ندارد)
func setup(kind: StringName, tint: Color, tint_k := 0.42,
                special: Dictionary = {}) -> void:
        _kind = kind if KINDS.has(kind) else &"knight"
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
        add_child(_root)
        if cfg.has("attack"):
                _attack_anim = String(cfg["attack"])
        _prune_gear(cfg)
        _setup_anim()
        _collect_and_tint(tint, tint_k, special)
        _normalize_height()


func body_root() -> Node3D:
        return _root


# ---------------- آماده‌سازی ----------------

## حذفِ سلاح‌های واریانت‌های دیگر — فقط تجهیزِ این نقش دیده می‌شود
func _prune_gear(cfg: Dictionary) -> void:
        var hide: Array = cfg.get("hide", [])
        for n in hide:
                var node := _find_by_name(_root, String(n))
                if node != null:
                        node.visible = false


func _find_by_name(root: Node, wanted: String) -> Node:
        if root.name == StringName(wanted):
                return root
        for c in root.get_children():
                var r := _find_by_name(c, wanted)
                if r != null:
                        return r
        return null


func _setup_anim() -> void:
        var players := _root.find_children("*", "AnimationPlayer", true, false)
        if players.is_empty():
                return
        _anim = players[0] as AnimationPlayer
        # لوپِ حالت‌های پیوسته
        for a in [A_IDLE, A_WALK, A_RUN, A_BLOCK, "Unarmed_Idle"]:
                if _anim.has_animation(a):
                        _anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
        _anim.animation_finished.connect(_on_anim_finished)
        _play(A_IDLE)


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
        # تینت ویژه‌ی یک گره (مثلاً سپر فیروزه‌ای جاویدان)
        for node_name in special:
                var node := _find_by_name(_root, String(node_name))
                if node is MeshInstance3D:
                        var mi2 := node as MeshInstance3D
                        var col: Color = special[node_name]
                        for i in mi2.mesh.get_surface_count():
                                var m2 := mi2.get_active_material(i)
                                if m2 is StandardMaterial3D:
                                        var sm2 := (m2 as StandardMaterial3D) \
                                                        .duplicate() \
                                                        as StandardMaterial3D
                                        sm2.albedo_color = Color.WHITE.lerp(col, 0.8)
                                        mi2.set_surface_override_material(i, sm2)


## گِرَش همه‌ی متریال‌ها به رنگ تیم — میکس پیش‌فرض ۴۲٪ تا بافت پالت کاراکتر
## حفظ شود (بازخورد اسکرین‌شات‌های Bad North: دسته‌ها باید از دور قابل‌تفکیک
## باشند ولی «شکل» کاراکتر زیر رنگ گم نشود).
## رنگِ تینت‌شده جایگزین رنگ پایه در حافظه می‌شود تا فلشِ سفیدِ ضربه بعد از
## بازیابی، تینتِ تیم را از دست ندهد.
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


## توقفِ فوریِ انیمیشن در ژستِ فعلی — هنگام مرگ (افتادن با چرخشِ کلِ نود)
func freeze_pose() -> void:
        _busy = false
        if _anim != null:
                _anim.pause()


## هم‌ارزسازی قد — GLB پک حدود ۱٫۹ واحد است؛ به TARGET_HEIGHT می‌رسیم
func _normalize_height() -> void:
        var top := _scan_top(_root, Transform3D.IDENTITY)
        if top > 0.1:
                var s := TARGET_HEIGHT / top
                _root.scale = Vector3(s, s, s)


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


## ایستِ سپری جاویدان — لوپِ Blocking تا پایان نبرد
func set_blocking(on: bool) -> void:
        if _dead or _anim == null:
                return
        if on and _anim.has_animation(A_BLOCK):
                _busy = false
                _play(A_BLOCK)
        elif not on:
                _apply_locomotion()


func play_death() -> void:
        if _dead:
                return
        _dead = true
        if _anim != null and _anim.has_animation(A_DEATH):
                _busy = true
                _play(A_DEATH, 1.0, 0.12)


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


## محوِ جسد — متریال‌ها ALPHA و آلفا به صفر (جایگزین فیدِ متریالِ تکی)
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
