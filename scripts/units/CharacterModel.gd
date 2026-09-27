class_name CharacterModel
extends CharacterModelBase
## کاراکتر Low-Poly واقعی — گام ۶R۱۲: پک «Quaternius» (لایسنس CC0) جایگزین
## KayKit — بازخورد کاربر: «کیفیت کاراکترها خوب نیست؛ باکیفیت‌تر پیدا کن».
##
## گام ۶R16 — از گامِ ۶R16 این کلاس «مسیرِ ۳بعدی» است؛ مسیرِ پیش‌فرض بازی
## SpriteCharacterModel (اسپرایتِ بیلبوردیِ Bad North) شد — GameConstants.UNITS_2D.
## این کلاس برای مقایسه/بازگشتِ احتمالی حفظ می‌شود (همان API پایه).
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
## _mats الان ShaderMaterial است
var _mats: Array[ShaderMaterial] = []
var _mat_colors: Array[Color] = []
var _tex: Texture2D = null
var _moving := false
var _busy := false             # انیمیشن یک‌باره در جریان است (حمله/ضربه)
var _dead := false
var _attack_anim := "SwordSlash"
## آخرین رنگِ تینتِ اعمال‌شده — برای تست خودکار و دیباگ (display_color)
var _tint := Color.WHITE
var _tint_k := 0.0
## گام ۶R۱۵ — چسباندنِ گرادیان به سطحِ زمینِ فعلی (y پایِ کاراکتر)
var _last_feet_y := -1000.0
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


func _process(_delta: float) -> void:
        # گرادیانِ انتخاب باید همیشه نسبت به پایِ کاراکتر روی زمین باشد
        # (سربار ناچیز: فقط هنگام تغییرِ y بیش از ۱ سانتی‌متر)
        if _root == null or _mats.is_empty() or not is_inside_tree():
                return
        var fy := global_position.y
        if absf(fy - _last_feet_y) > 0.01:
                _last_feet_y = fy
                for m in _mats:
                        m.set_shader_parameter("feet_y", fy)


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


## متریال‌ها per-instance + شیدرِ گرادیانیِ تیم — گام ۶R۱۵:
##   * بافتِ طبیعیِ پک «برگردانده شد» (بازخورد: «رنگ عادی داشته باشند») —
##     فیگورِ تک‌رنگِ ۶R۱۴ حذف شد
##   * تینت = «میزانِ گرادیانِ رنگِ پرچم» از بالا (روشن) به پایین (تیره)
##     روی خودِ بدنه — انتخابِ دسته = amt ۱٫۰ با رنگِ پرچمِ خودِ دسته
static func _team_shader() -> Shader:
        if _shader_cache == null:
                var sh := Shader.new()
                sh.code = """
shader_type spatial;
uniform vec4 base_col : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float has_tex = 0.0;
uniform vec4 tint_col : source_color = vec4(1.0);
uniform float tint_amt = 0.0;
uniform float flash = 0.0;
uniform float alpha = 1.0;
uniform float rough = 1.0;
uniform float metallic_f = 0.0;
uniform float feet_y = 0.0;
uniform float body_h = 0.82;
varying float v_h;
void vertex() {
        vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        v_h = clamp((wp.y - feet_y) / max(body_h, 0.2), 0.0, 1.0);
}
void fragment() {
        vec3 base = base_col.rgb * COLOR.rgb;
        if (has_tex > 0.5) {
                base *= texture(tex, UV).rgb;
        }
        // گام ۶R۱۵b — لیفتِ ملایمِ بافت: پالتِ تیره‌ی پک زیرِ نورِ نرمِ مرجع
        // «لجن» دیده نمی‌شود و رنگِ عادیِ انسانی خوانا می‌ماند
        base = min(base * 1.28 + vec3(0.025), vec3(1.0));
        // گرادیانِ عمودی: سر روشن‌تر، پا تیره‌تر (امضای Bad North)
        vec3 grad = tint_col.rgb * mix(0.50, 1.35, v_h);
        vec3 col = mix(base, grad, tint_amt);
        col = mix(col, vec3(1.0), flash);
        ALBEDO = col;
        ROUGHNESS = rough;
        METALLIC = metallic_f;
        ALPHA = alpha;
}
"""
                _shader_cache = sh
        return _shader_cache


static var _shader_cache: Shader = null


func _collect_and_tint(tint: Color, tint_k: float, special: Dictionary) -> void:
        var meshes := _root.find_children("*", "MeshInstance3D", true, false)
        for m in meshes:
                var mi := m as MeshInstance3D
                if mi.mesh == null:
                        continue
                for i in mi.mesh.get_surface_count():
                        var mat := mi.get_active_material(i)
                        var sm := ShaderMaterial.new()
                        sm.shader = _team_shader()
                        var base_col := Color(1, 1, 1)
                        var tex: Texture2D = null
                        var rough := 1.0
                        var metal := 0.0
                        if mat is StandardMaterial3D:
                                var std := mat as StandardMaterial3D
                                base_col = std.albedo_color
                                tex = std.albedo_texture
                                rough = std.roughness
                                metal = std.metallic
                        elif mat is ShaderMaterial:
                                # بافتِ تعبیه‌شده‌ی glTF معمولاً StandardMaterial است؛
                                # اگر شیدرِ سفارشی بود، رنگِ سفیدِ خنثی می‌دهیم
                                base_col = Color(1, 1, 1)
                        sm.set_shader_parameter("base_col", base_col)
                        if tex != null:
                                sm.set_shader_parameter("tex", tex)
                                sm.set_shader_parameter("has_tex", 1.0)
                                _tex = tex
                        sm.set_shader_parameter("rough", rough)
                        sm.set_shader_parameter("metallic_f", metal)
                        sm.set_shader_parameter("feet_y",
                                        global_position.y if is_inside_tree() else 0.0)
                        sm.set_shader_parameter("body_h", TARGET_HEIGHT)
                        mi.set_surface_override_material(i, sm)
                        _mats.append(sm)
                        _mat_colors.append(base_col)
        apply_team_tint(tint, tint_k)


## گام ۶R۱۵ — تینتِ گرادیانیِ تیم:
##   amt = ۰  → رنگِ عادیِ انسانی (بافت پک، بدونِ هیچ تینت)
##   amt = ۱  → گرادیانِ کاملِ رنگِ پرچم از بالا به پایین (حالتِ انتخاب)
##   ۰-۱      → میکس (دشمنان ~۰٫۵ قرمزِ گرادیانی | منحل‌شده‌ها خاکستری)
## feet_y هم تازه می‌شود تا گرادیان به قدِ واقعیِ زمینِ فعلی بچسبد.
func apply_team_tint(tint: Color, amt := 0.0) -> void:
        _tint = tint
        _tint_k = amt
        if _root != null and is_inside_tree():
                var fy := global_position.y
                for m in _mats:
                        m.set_shader_parameter("feet_y", fy)
        for m in _mats:
                m.set_shader_parameter("tint_col", tint)
                m.set_shader_parameter("tint_amt", clampf(amt, 0.0, 1.0))


## آخرین رنگِ تینتِ اعمال‌شده (قبل از میکس با پالت) — مصرفِ تستِ انتخاب
func display_color() -> Color:
        return _tint


## میزانِ گرادیانِ فعلی (۰=عادی، ۱=انتخاب کامل) — مصرفِ تستِ انتخاب
func tint_amount() -> float:
        return _tint_k


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

## فلش سفید کلاسیک — یونیفرمِ flash → سیلوئت تمام‌سفید؛ ۰٫۱۲s بعد برمی‌گردد
func flash_white() -> void:
        if _mats.is_empty() or _dead:
                return
        for m in _mats:
                m.set_shader_parameter("flash", 1.0)
        var tw := create_tween()
        tw.tween_interval(0.10)
        tw.tween_callback(_restore_flash)


func _restore_flash() -> void:
        for m in _mats:
                m.set_shader_parameter("flash", 0.0)


## محوِ جسد — یونیفرمِ آلفا به صفر (فرار از جزیره)
func fade_out(secs: float) -> void:
        if _mats.is_empty():
                return
        for m in _mats:
                m.set_shader_parameter("alpha", 1.0)
        var tw := create_tween()
        tw.tween_interval(0.35)
        tw.set_parallel(true)
        for m in _mats:
                tw.tween_method(_set_alpha.bind(m), 1.0, 0.0, secs)


func _set_alpha(v: float, m: ShaderMaterial) -> void:
        if is_instance_valid(m):
                m.set_shader_parameter("alpha", v)
