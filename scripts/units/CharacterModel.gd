class_name CharacterModel
extends CharacterModelBase
## ============================================================
## گام ۶R۲۶ — «کاراکترهای GIF کاربر، واقعاً سه‌بعدی شدند»
## بازخورد کاربر (بعد از دوره‌ی اسپرایتِ ۲بعدیِ ۶R21): «این ترکیب اشتباه است؛
## کاراکترهایی که فرستادم را سه‌بعدی کن و استفاده کن» — پس مسیرِ پیش‌فرض از
## SpriteCharacterModel به این مدلِ پروسیجرالِ سه‌بعدی منتقل شد
## (GameConstants.UNITS_2D = false) و پک‌های آماده حذف.
##
##   سپاه هخامنشی (خودی):
##     * جاویدان   — تاج‌سرِ بنفش‌وزرد، ریش، زره‌ی پولکانی زر، جامه‌ی سپید با
##                   لبه‌ی بنفش، ردای سرخ، شمشیر          (GIF: sword-woman)
##     * کماندار   — همان تاج‌سر، زره‌ی بنفشِ تیره، تیردان پشتی، کمان
##                                                       (GIF: archer)
##     * نیزه‌دار  — زره‌ی زر، ردا، نیزه‌ی کلاس + پرچمِ بنفشِ پشتی
##                                                       (GIF: Spearman)
##   سپاه رومی (دشمن):
##     * لژیون سنگین — زره‌ی آهنیِ سیاه با آذین زر، تونیک سرخ، کاکل سرخ،
##                   اسکوتوم + گلادیوس                     (GIF: armored-warrior)
##     * پرتاب‌گر — زره‌ی تیره، شال سرخ، کاکل، نیزه‌ی پرتاب
##                                                       (GIF: soldier-in-dark)
##     * لژیون سبک  — بدون زره‌ی سینه، شمشیر                (GIF: centurion)
##
## موتور ژست بدون AnimationPlayer: IDLE / WALK / حمله‌ی نوع‌به‌نوع / ضربه /
## مرگ با خطِ زمانِ پروسیجرال روی اسکلتِ پیوتی‌بندی‌شده.
## API کاملِ CharacterModelBase را پیاده می‌کند.
## ============================================================

## قدِ نهایی کاراکتر (متر) — لنگه‌ی کفش روی y=۰ دقیقاً می‌نشیند
const TARGET_HEIGHT := 0.84
const HIP_H := 0.375

## نام‌های انیمیشن قدیمی — برای سازگاری نرم نگه داشته شده‌اند
const A_IDLE := "Idle"
const A_WALK := "Walk"
const A_HIT := "RecieveHit"
const A_DEATH := "Death"

## نقش → سبک ساخت
const KINDS := {
        &"warrior": "persian_sword",
        &"ranger": "persian_archer",
        &"viking": "persian_bearer",
        &"knight_heavy": "roman_heavy",
        &"legionary": "roman_heavy",
        &"soldier": "roman_slinger",
        &"slinger": "roman_slinger",
        &"legionary_light": "roman_light",
}

## سبک → نوع انیمیشن حمله
const ATTACK_STYLE := {
        "persian_sword": "slash",
        "roman_heavy": "slash",
        "roman_light": "slash",
        "persian_archer": "bow",
        "persian_bearer": "thrust",
        "roman_slinger": "throw",
}

## ---------------- پالت‌ها — چشیده از خودِ GIFها ----------------
const PAL := {
        "skin": Color("d9a077"), "beard": Color("33251f"),
        "tiara": Color("5a3d8f"), "gold": Color("d9a441"),
        "gold_hi": Color("e8bd5a"), "lam_gold": Color("c9a256"),
        "lam_dark": Color("4d4162"), "trim_purple": Color("6b4a9e"),
        "tunic": Color("ece7f2"), "cape": Color("a8202e"),
        "boot": Color("6b4a2e"), "wrap": Color("8a6a45"),
        "iron": Color("2e2c33"), "iron_hi": Color("3c3a44"),
        "gold_trim": Color("b08d3e"), "tunic_red": Color("8e2126"),
        "crest": Color("a8202e"), "scutum": Color("3a2326"),
        "steel": Color("dfe4ea"), "wood": Color("7a5533"),
        "quiver": Color("3f3555"), "arrow": Color("c9b0e0"),
        "banner": Color("5a3d8f"), "strap": Color("7a5a36"),
}

## ---------------- وضعیت موتور ژست ----------------
enum _St { IDLE, WALK, ATK, HIT, DEAD }

var _kind: StringName = &"warrior"
var _style := "persian_sword"
var _atk_style := "slash"
var _state: _St = _St.IDLE
var _t := 0.0                 # ساعتِ وضعیت جاری
var _walk_phase := 0.0        # فاز پیوسته‌ی قدم (بین IDLE/WALK حفظ می‌شود)
var _stride_hz := 9.0         # سرعتِ چرخه‌ی قدم (± رندومِ هر سرباز)
var _moving := false
var _busy := false            # حمله/ضربه‌ی یک‌باره در جریان است
var _dead := false
var _atk_dur := 0.55
var _dur := 0.3

## اسکلت — همه‌ی پیوت‌ها در یک دیکشنری
var _p: Dictionary = {}       # StringName -> Node3D
var _root: Node3D             # fx — UnitBase روی آن lean می‌زند (ما دست نمی‌زنیم)
var _rig: Node3D              # اسکلتِ واقعی — مرگ/کراچ/بابی روی این است
var _mats: Array[ShaderMaterial] = []
var _mat_colors: Array[Color] = []
var _tint := Color.WHITE
var _tint_k := 0.0
var _last_feet_y := -1000.0
var _norm_scale := 1.0
var _cape_on := false
var _flag_on := false


func setup(kind: StringName, tint: Color, tint_k := 0.42,
                special: Dictionary = {}) -> void:
        _kind = kind if KINDS.has(kind) else &"warrior"
        _style = KINDS[_kind]
        _atk_style = ATTACK_STYLE.get(_style, "slash")
        _stride_hz = randf_range(8.2, 9.8)
        _build_body()
        apply_team_tint(tint, tint_k)


func body_root() -> Node3D:
        return _root


## ================= API سازگار با قبل =================

func set_moving(moving: bool) -> void:
        _moving = moving
        # در اوجِ حمله/ضربه فقط ثبت می‌شود؛ پایانِ خطِ زمان خودش ادامه می‌دهد
        if not _busy and not _dead:
                _state = _St.WALK if _moving else _St.IDLE


func play_attack() -> void:
        if _dead:
                return
        _busy = true
        _state = _St.ATK
        _t = 0.0
        _atk_dur = 0.6 if _atk_style == "thrust" else 0.55
        _dur = _atk_dur


func play_hit() -> void:
        if _dead:
                return
        _busy = true
        _state = _St.HIT
        _t = 0.0
        _dur = 0.32


func play_death() -> void:
        if _dead:
                return
        _dead = true
        _busy = false
        _state = _St.DEAD
        _t = 0.0
        _dur = 0.9


func freeze_pose() -> void:
        _busy = false
        set_process(false)


func set_blocking(_on: bool) -> void:
        pass   # GIFها ژستِ سپری ندارند — no-op امن (همانند قبل)


func display_color() -> Color:
        return _tint


func tint_amount() -> float:
        return _tint_k


## گام ۶R۱۳ — کراچ بدون نابودی مقیاس
func set_crouch(k: float) -> void:
        if _rig == null:
                return
        _rig.scale = Vector3(_norm_scale, _norm_scale * k, _norm_scale)


## ================= سازنده‌ها =================

static var _shader_cache: Shader = null


static func _team_shader() -> Shader:
        # همان شیدر گرادیان/فلش/محوِ نسخه‌ی قبل — چرخه‌ی انتخاب دسته سالم می‌ماند
        if _shader_cache == null:
                var sh := Shader.new()
                sh.code = """
shader_type spatial;
uniform vec4 base_col : source_color = vec4(1.0);
uniform vec4 tint_col : source_color = vec4(1.0);
uniform float tint_amt = 0.0;
uniform float flash = 0.0;
uniform float alpha = 1.0;
uniform float rough = 1.0;
uniform float metallic_f = 0.0;
uniform float feet_y = 0.0;
uniform float body_h = 0.84;
varying float v_h;
void vertex() {
        vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        v_h = clamp((wp.y - feet_y) / max(body_h, 0.2), 0.0, 1.0);
}
void fragment() {
        vec3 col = base_col.rgb;
        vec3 grad = tint_col.rgb * mix(0.50, 1.35, v_h);
        col = mix(col, grad, tint_amt);
        col = mix(col, vec3(1.0), flash);
        ALBEDO = col;
        ROUGHNESS = rough;
        METALLIC = metallic_f;
        ALPHA = alpha;
}
"""
                _shader_cache = sh
        return _shader_cache


## همه‌ی قطعه‌ها از این می‌گذرند — فلش/محو/تینت روی کل بدن کار می‌کند
func _mesh(parent: Node3D, m: Mesh, col: Color, pos: Vector3,
                rot := Vector3.ZERO, metal := 0.0, rough := 0.8) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        mi.mesh = m
        mi.position = pos
        if rot != Vector3.ZERO:
                mi.rotation = rot
        var sm := ShaderMaterial.new()
        sm.shader = _team_shader()
        sm.set_shader_parameter("base_col", col)
        sm.set_shader_parameter("rough", rough)
        sm.set_shader_parameter("metallic_f", metal)
        sm.set_shader_parameter("feet_y",
                        global_position.y if is_inside_tree() else 0.0)
        sm.set_shader_parameter("body_h", TARGET_HEIGHT)
        mi.material_override = sm
        parent.add_child(mi)
        _mats.append(sm)
        _mat_colors.append(col)
        return mi


func _box(parent: Node3D, size: Vector3, col: Color, pos: Vector3,
                rot := Vector3.ZERO, metal := 0.0, rough := 0.8) -> MeshInstance3D:
        var bm := BoxMesh.new()
        bm.size = size
        return _mesh(parent, bm, col, pos, rot, metal, rough)


func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, col: Color,
                pos: Vector3, rot := Vector3.ZERO, metal := 0.0,
                rough := 0.8, seg := 10) -> MeshInstance3D:
        var cm := CylinderMesh.new()
        cm.top_radius = r_top
        cm.bottom_radius = r_bot
        cm.height = h
        cm.radial_segments = seg
        return _mesh(parent, cm, col, pos, rot, metal, rough)


func _sph(parent: Node3D, r: float, col: Color, pos: Vector3,
                metal := 0.0, rough := 0.8) -> MeshInstance3D:
        var sm := SphereMesh.new()
        sm.radius = r
        sm.height = r * 2.0
        sm.radial_segments = 12
        sm.rings = 8
        return _mesh(parent, sm, col, pos, Vector3.ZERO, metal, rough)


func _capsule(parent: Node3D, r: float, h: float, col: Color, pos: Vector3,
                metal := 0.0, rough := 0.8) -> MeshInstance3D:
        var cm := CapsuleMesh.new()
        cm.radius = r
        cm.height = h
        return _mesh(parent, cm, col, pos, Vector3.ZERO, metal, rough)


## پیوتِ خالیِ اسکلت
func _pivot(parent: Node3D, name: StringName, pos: Vector3) -> Node3D:
        var n := Node3D.new()
        n.name = name
        n.position = pos
        parent.add_child(n)
        _p[name] = n
        return n


## ---------------- بدنه‌ی مشترک ----------------
## cfg: side="persian"/"roman" | armor | trim | tunic | beard | helmet
##      cape | quiver | banner | scutum | weapon
func _build_body() -> void:
        _p.clear()
        _root = Node3D.new()
        _root.name = "fx"
        add_child(_root)
        _rig = Node3D.new()
        _rig.name = "rig"
        _root.add_child(_rig)
        _norm_scale = 1.0

        var persian := _style.begins_with("persian")
        var armor: Color
        var trim: Color
        var sleeve: Color
        match _style:
                "persian_sword":
                        armor = PAL.lam_gold; trim = PAL.gold
                        sleeve = PAL.tunic
                "persian_archer":
                        armor = PAL.lam_dark; trim = PAL.gold
                        sleeve = PAL.lam_dark
                "persian_bearer":
                        armor = PAL.lam_gold; trim = PAL.gold
                        sleeve = PAL.tunic
                _:
                        armor = PAL.iron; trim = PAL.gold_trim
                        sleeve = PAL.tunic_red
        var skirt: Color = PAL.tunic if persian else PAL.tunic_red
        var pants: Color = PAL.tunic if persian else PAL.iron_hi
        var skin: Color = PAL.skin

        var hips := _pivot(_rig, &"hips", Vector3(0, HIP_H, 0))

        # ---- پاها ----
        for side in [-1.0, 1.0]:
                var ln: StringName = &"leg_l" if side < 0 else &"leg_r"
                var kn: StringName = &"knee_l" if side < 0 else &"knee_r"
                var leg := _pivot(hips, ln, Vector3(side * 0.055, 0, 0))
                _capsule(leg, 0.046, 0.15, pants, Vector3(0, -0.085, 0))
                var knee := _pivot(leg, kn, Vector3(0, -0.17, 0))
                _capsule(knee, 0.039, 0.14, pants, Vector3(0, -0.065, 0))
                # پوتین + لنگه‌ی رو به جلو
                _box(knee, Vector3(0.07, 0.05, 0.13), PAL.boot,
                                Vector3(0, -0.18, 0.025))
                _capsule(knee, 0.042, 0.05,
                                PAL.wrap if persian else PAL.iron_hi,
                                Vector3(0, -0.145, 0))

        # ---- تنه ----
        var spine := _pivot(hips, &"spine", Vector3.ZERO)
        _box(spine, Vector3(0.15, 0.09, 0.10), skirt, Vector3(0, 0.04, 0))
        # دامن/پیراهنِ پایین‌تنه — لبه‌ی رنگی
        _cyl(spine, 0.085, 0.105, 0.17, skirt, Vector3(0, -0.05, 0))
        _cyl(spine, 0.104, 0.106, 0.02,
                        trim if persian else PAL.gold_trim, Vector3(0, -0.125, 0))
        # سینه‌زره
        _capsule(spine, 0.088, 0.20, armor, Vector3(0, 0.16, 0))
        # کمربند + آذین
        _cyl(spine, 0.092, 0.092, 0.035, trim, Vector3(0, 0.075, 0), \
                        Vector3.ZERO, 0.4, 0.4)
        # شانه‌های پولکانی
        for side in [-1.0, 1.0]:
                _sph(spine, 0.048, armor, Vector3(side * 0.105, 0.235, 0))

        # ---- دست‌ها ----
        for side in [-1.0, 1.0]:
                var an: StringName = &"arm_l" if side < 0 else &"arm_r"
                var en: StringName = &"elb_l" if side < 0 else &"elb_r"
                var sh := _pivot(spine, an,
                                Vector3(side * 0.118, 0.255, 0))
                _capsule(sh, 0.033, 0.12, sleeve, Vector3(0, -0.06, 0))
                var el := _pivot(sh, en, Vector3(0, -0.125, 0))
                _capsule(el, 0.029, 0.11, skin, Vector3(0, -0.05, 0))
                _sph(el, 0.026, skin, Vector3(0, -0.105, 0))

        # ---- سر و گردن ----
        _cyl(spine, 0.03, 0.034, 0.05, skin, Vector3(0, 0.315, 0))
        var head := _pivot(spine, &"head", Vector3(0, 0.345, 0))
        _sph(head, 0.06, skin, Vector3(0, 0.01, 0.008)).scale = \
                        Vector3(1.0, 1.1, 1.0)
        if persian:
                # ریشِ مشکیِ هخامنشی
                _box(head, Vector3(0.052, 0.052, 0.032), PAL.beard,
                                Vector3(0, -0.042, 0.044))
                # تاج‌سرِ مخروطیِ بنفش با نوک زر
                _cyl(head, 0.013, 0.062, 0.115, PAL.tiara,
                                Vector3(0, 0.085, 0))
                _cyl(head, 0.064, 0.064, 0.022, PAL.gold,
                                Vector3(0, 0.038, 0.004), Vector3.ZERO, 0.5, 0.35)
                _sph(head, 0.014, PAL.gold_hi, Vector3(0, 0.148, 0))
        else:
                # کلاه‌خودِ رومی + کاکلِ سرخ
                _sph(head, 0.064, PAL.iron, Vector3(0, 0.03, 0))
                _box(head, Vector3(0.09, 0.035, 0.03), PAL.iron_hi,
                                Vector3(0, -0.02, -0.05))
                _box(head, Vector3(0.016, 0.045, 0.17), PAL.crest,
                                Vector3(0, 0.105, -0.005))
                _box(head, Vector3(0.02, 0.06, 0.02), PAL.gold_trim,
                                Vector3(0, 0.062, 0.0), Vector3.ZERO, 0.5, 0.35)

        # ---- ردا (سه‌بندی با تاب‌خوردن زنجیره‌ای) ----
        if _style == "persian_sword" or _style == "persian_bearer":
                _cape_on = true
                var prev := spine
                for i in 3:
                        var cn: StringName = &"cape1" if i == 0 \
                                        else (&"cape2" if i == 1 else &"cape3")
                        var seg := _pivot(prev, cn,
                                        Vector3(0, -0.005 if i == 0 else -0.105,
                                                        -0.085 if i == 0 else 0.0))
                        _box(seg, Vector3(0.145 - i * 0.012, 0.11, 0.012),
                                        PAL.cape, Vector3(0, -0.055, 0))
                        prev = seg

        # ---- لوازم نقش ----
        if _style == "persian_archer":
                _build_quiver(spine)
        if _style == "persian_bearer":
                _build_banner(spine)
        _build_weapon(spine)


## تیردانِ پشتی کماندار — چهار تیر با فلتش بنفش
func _build_quiver(spine: Node3D) -> void:
        var q := Node3D.new()
        q.position = Vector3(-0.045, 0.16, -0.085)
        q.rotation = Vector3(0.35, 0.0, -0.35)
        spine.add_child(q)
        _cyl(q, 0.032, 0.028, 0.15, PAL.quiver, Vector3.ZERO, \
                        Vector3.ZERO, 0.0, 0.9)
        for i in 4:
                var a := i * 0.8 - 1.2
                _cyl(q, 0.004, 0.004, 0.13, PAL.wood,
                                Vector3(a * 0.014, 0.13, a * 0.008),
                                Vector3(a * 0.12, 0, a * 0.08))
                _box(q, Vector3(0.028, 0.016, 0.004), PAL.arrow,
                                Vector3(a * 0.02, 0.195, a * 0.014),
                                Vector3(0, a * 0.5, 0))


## پرچمِ پشتی نیزه‌دار — میله + پرچم بنفش با نشان زرین (تاب با انیمیشن)
func _build_banner(spine: Node3D) -> void:
        _flag_on = true
        var pole := _pivot(spine, &"pole", Vector3(0.03, 0.18, -0.09))
        pole.rotation = Vector3(0.12, 0.0, 0.06)
        _cyl(pole, 0.007, 0.009, 0.52, PAL.wood, Vector3(0, 0.08, 0), \
                        Vector3.ZERO, 0.0, 0.85)
        _sph(pole, 0.011, PAL.gold_hi, Vector3(0, 0.35, 0))
        var flag := _pivot(pole, &"flag", Vector3(0.0, 0.29, 0.0))
        _box(flag, Vector3(0.13, 0.10, 0.006), PAL.banner,
                        Vector3(-0.065, 0, 0))
        var emblem := _box(flag, Vector3(0.035, 0.035, 0.008), PAL.gold_hi,
                        Vector3(-0.065, 0, 0.001))
        emblem.rotation = Vector3.ZERO
        emblem.rotation.z = PI * 0.25


## سلاح بر اساس سبک — از کتابخانه‌ی WeaponLook (بدنه‌های خوش‌ساختِ موجود)
func _build_weapon(_spine: Node3D) -> void:
        var elb_r: Node3D = _p[&"elb_r"]
        var elb_l: Node3D = _p[&"elb_l"]
        match _style:
                "persian_sword", "roman_light":
                        var mount := _pivot(elb_r, &"wmount",
                                        Vector3(0, -0.105, 0))
                        mount.rotation = Vector3(0.35, 0, PI)
                        if _style == "persian_sword":
                                mount.add_child(WeaponLook.sword(PAL.steel, 0.42))
                        else:
                                mount.add_child(WeaponLook.sword(
                                                WeaponLook.BRONZE, 0.40))
                # نکته: لژیونِ سنگین (roman_heavy) سپرِ بزرگِ کلاسِ HopliteHeavy
                # را دارد (مخروطِ انحرافِ پرتابه — گیم‌پلی) → شمشیرِ مدل کافی است
                # و اسکوتومِ دستیِ تکراری نمی‌سازیم.
                "persian_archer":
                        var bmount := _pivot(elb_l, &"wmount",
                                        Vector3(0, -0.105, 0))
                        bmount.rotation = Vector3(0, PI * 0.5, 0)
                        bmount.add_child(WeaponLook.bow(0.27))
                "roman_slinger":
                        var jmount := _pivot(elb_r, &"wmount",
                                        Vector3(0, -0.105, 0))
                        jmount.add_child(WeaponLook.javelin(0.62))
                # نیزه‌دار (persian_bearer): نیزه‌ی کلاسِ SpearmanUnit با مکانیکِ
                # آماده‌باش — سلاحِ دستیِ تکراری ممنوع؛ پرچمِ پشتی از _build_banner

## ================= موتور ژست =================

const _K_SOFT := 14.0      # نرمیِ گذار IDLE/WALK
const _K_SNAP := 30.0      # ضربه‌های تندِ حمله
const _REST_MOUNT := {
        "slash": Vector3(0.35, 0, PI),
        "bow": Vector3(0, PI * 0.5, 0),
        "thrust": Vector3(0.10, 0, 0),
        "throw": Vector3(0.18, 0, 0),
}


func _seg(t: float, a: float, b: float) -> float:
        return clampf((t - a) / maxf(b - a, 0.001), 0.0, 1.0)


func _eo(x: float) -> float:
        return 1.0 - pow(1.0 - x, 2.4)


func _sm(x: float) -> float:
        return x * x * (3.0 - 2.0 * x)


func _process(delta: float) -> void:
        _t += delta
        if _state == _St.WALK:
                _walk_phase += delta * _stride_hz
        if (_state == _St.ATK or _state == _St.HIT) and _t >= _dur:
                _busy = false
                _state = _St.WALK if _moving else _St.IDLE
                _t = 0.0

        var tgt := {}
        _rig_y_target = 0.0
        _rig_rot_target = Vector3.ZERO
        match _state:
                _St.IDLE:
                        _pose_idle(tgt)
                _St.WALK:
                        _pose_walk(tgt)
                _St.ATK:
                        _pose_attack(tgt)
                _St.HIT:
                        _pose_hit(tgt)
                _St.DEAD:
                        _pose_death(tgt)

        var k := 1.0 - exp(-_K_SNAP * delta) \
                        if (_state == _St.ATK or _state == _St.HIT) \
                        else 1.0 - exp(-_K_SOFT * delta)
        if _state == _St.DEAD:
                k = 1.0   # مرگ دقیقاً روی خطِ زمان می‌افتد
        for key in tgt:
                var n: Node3D = _p.get(key)
                if n == null:
                        continue
                n.rotation = n.rotation.lerp(tgt[key], k)
        _rig.position.y = lerpf(_rig.position.y, _rig_y_target, k)
        _rig.rotation = _rig.rotation.lerp(_rig_rot_target, k)

        # گرادیانِ انتخاب به سطحِ زمینِ فعلی می‌چسبد
        if not _mats.is_empty() and is_inside_tree():
                var fy := global_position.y
                if absf(fy - _last_feet_y) > 0.01:
                        _last_feet_y = fy
                        for m in _mats:
                                m.set_shader_parameter("feet_y", fy)


var _rig_y_target := 0.0
var _rig_rot_target := Vector3.ZERO


## ژست پایه — سهمِ مشترکِ آرامش؛ سلاح‌داران دستِ سلاح را ثابت نگه می‌دارند
func _rest(tgt: Dictionary, t: float) -> void:
        var holds_right := _atk_style == "thrust" or _atk_style == "throw"
        var holds_left := _atk_style == "bow" or \
                        (_atk_style == "slash" and _style == "roman_heavy")
        tgt[&"spine"] = Vector3(0.03 + 0.015 * sin(t * 2.1), 0, 0)
        tgt[&"head"] = Vector3(0.02 + 0.02 * sin(t * 1.3), 0, 0)
        tgt[&"arm_l"] = Vector3(
                        (-0.22 if holds_left else -0.10) \
                                        + 0.02 * sin(t * 2.1 + 0.5),
                        0, 0.10)
        tgt[&"elb_l"] = Vector3(-0.30 if holds_left else -0.18, 0, 0)
        tgt[&"arm_r"] = Vector3(
                        (-0.10 if holds_right else -0.10) \
                                        + (0.0 if holds_right \
                                        else 0.02 * sin(t * 2.1)),
                        0, -0.10)
        tgt[&"elb_r"] = Vector3(-0.18, 0, 0)
        tgt[&"leg_l"] = Vector3(0, 0, 0.02)
        tgt[&"knee_l"] = Vector3(0.06, 0, 0)
        tgt[&"leg_r"] = Vector3(0, 0, -0.02)
        tgt[&"knee_r"] = Vector3(0.06, 0, 0)
        var sway := 0.05 * sin(t * 1.8)
        if _cape_on:
                tgt[&"cape1"] = Vector3(-(0.10 + sway), 0, 0)
                tgt[&"cape2"] = Vector3(-(0.06 + sway * 0.8), 0, 0)
                tgt[&"cape3"] = Vector3(-(0.05 + sway * 0.6), 0, 0)
        if _flag_on:
                tgt[&"flag"] = Vector3(0, 0.12 * sin(t * 1.6), 0)
        tgt[&"wmount"] = _REST_MOUNT.get(_atk_style, Vector3(0.35, 0, PI))


func _pose_idle(tgt: Dictionary) -> void:
        _rest(tgt, _t)


func _pose_walk(tgt: Dictionary) -> void:
        var p := _walk_phase
        var holds_right := _atk_style == "thrust" or _atk_style == "throw"
        var holds_left := _atk_style == "bow" or \
                        (_atk_style == "slash" and _style == "roman_heavy")
        tgt[&"leg_l"] = Vector3(0.52 * sin(p), 0, 0.02)
        tgt[&"knee_l"] = Vector3(0.85 * maxf(0.0, -sin(p - 0.6)), 0, 0)
        tgt[&"leg_r"] = Vector3(0.52 * sin(p + PI), 0, -0.02)
        tgt[&"knee_r"] = Vector3(0.85 * maxf(0.0, -sin(p + PI - 0.6)), 0, 0)
        if not holds_left:
                tgt[&"arm_l"] = Vector3(-0.10 - 0.38 * sin(p), 0, 0.10)
                tgt[&"elb_l"] = Vector3(-0.18 - 0.15 * maxf(0.0, sin(p)), 0, 0)
        else:
                tgt[&"arm_l"] = Vector3(-0.30, 0, 0.10)
                tgt[&"elb_l"] = Vector3(-0.40, 0, 0)
        if not holds_right:
                tgt[&"arm_r"] = Vector3(-0.10 + 0.38 * sin(p), 0, -0.10)
                tgt[&"elb_r"] = Vector3(-0.18 - 0.15 * maxf(0.0, -sin(p)), 0, 0)
        else:
                tgt[&"arm_r"] = Vector3(-0.10, 0, -0.10)
                tgt[&"elb_r"] = Vector3(-0.18, 0, 0)
        tgt[&"spine"] = Vector3(0.07, 0.04 * sin(p), 0)
        tgt[&"head"] = Vector3(-0.04, 0, 0)
        _rig_y_target = 0.022 * absf(cos(p))
        if _cape_on:
                var c := 0.22 + 0.10 * sin(p + 1.0)
                tgt[&"cape1"] = Vector3(-c, 0, 0)
                tgt[&"cape2"] = Vector3(-c * 0.75, 0.03 * sin(p + 0.5), 0)
                tgt[&"cape3"] = Vector3(-c * 0.55, 0.04 * sin(p + 0.9), 0)
        if _flag_on:
                tgt[&"flag"] = Vector3(0, 0.18 * sin(p * 0.9 + 0.3), 0)
        tgt[&"wmount"] = _REST_MOUNT.get(_atk_style, Vector3(0.35, 0, PI))


## حمله — خطِ زمانِ نوع‌به‌نوع؛ play_attack در لحظه‌ی ضربه صدا زده می‌شود
func _pose_attack(tgt: Dictionary) -> void:
        var t := _t
        match _atk_style:
                "slash":
                        var w := _seg(t, 0.0, 0.10)
                        var s := _seg(t, 0.10, 0.30)
                        var r := _seg(t, 0.30, 1.0)
                        var ax: float
                        var sy: float
                        if t < 0.10:
                                ax = lerpf(-0.10, 2.35, _eo(w))
                                sy = lerpf(0.0, 0.38, _eo(w))
                        elif t < 0.30:
                                ax = lerpf(2.35, -1.15, _sm(s))
                                sy = lerpf(0.38, -0.30, _sm(s))
                        else:
                                ax = lerpf(-1.15, -0.10, _eo(r))
                                sy = lerpf(-0.30, 0.0, _eo(r))
                        tgt[&"arm_r"] = Vector3(ax, 0, -0.06)
                        tgt[&"elb_r"] = Vector3(
                                        -0.10 if t < 0.30 else -0.18, 0, 0)
                        tgt[&"spine"] = Vector3(0.06 + 0.10 * s, sy, 0)
                        tgt[&"head"] = Vector3(-0.05, sy * 0.4, 0)
                        tgt[&"arm_l"] = Vector3(-0.25, 0, 0.10 + 0.22 * s)
                        if _cape_on:
                                tgt[&"cape1"] = Vector3(
                                                -(0.25 + 0.25 * s), 0, 0)
                "thrust":
                        var c := _seg(t, 0.0, 0.16)
                        var th := _seg(t, 0.16, 0.34)
                        var r := _seg(t, 0.34, 1.0)
                        var ax: float
                        var mx: float
                        if t < 0.16:
                                ax = lerpf(-0.10, 0.45, _eo(c))
                                mx = lerpf(0.10, -0.55, _eo(c))
                        elif t < 0.34:
                                ax = lerpf(0.45, -1.35, _sm(th))
                                mx = lerpf(-0.55, -1.42, _sm(th))
                        else:
                                ax = lerpf(-1.35, -0.10, _eo(r))
                                mx = lerpf(-1.42, 0.10, _eo(r))
                        tgt[&"arm_r"] = Vector3(ax, 0, -0.04)
                        tgt[&"elb_r"] = Vector3(-0.08, 0, 0)
                        tgt[&"wmount"] = Vector3(mx, 0, 0)
                        tgt[&"spine"] = Vector3(
                                        0.03 + 0.14 * _sm(th) - 0.08 * _eo(c),
                                        0, 0)
                        tgt[&"arm_l"] = Vector3(-0.30, 0, 0.05)
                "bow":
                        var up := _seg(t, 0.0, 0.12)
                        var dr := _seg(t, 0.0, 0.12)
                        var rl := _seg(t, 0.12, 0.24)
                        var r := _seg(t, 0.30, 1.0)
                        tgt[&"arm_l"] = Vector3(lerpf(-0.22, -1.30, _eo(up)),
                                        0, 0.04)
                        tgt[&"elb_l"] = Vector3(-0.06, 0, 0)
                        var rx: float
                        var ex: float
                        if t < 0.12:
                                rx = lerpf(-0.10, -1.45, _eo(dr))
                                ex = lerpf(-0.18, -1.85, _eo(dr))
                        elif t < 0.24:
                                rx = lerpf(-1.45, -0.85, _sm(rl))
                                ex = lerpf(-1.85, -0.35, _sm(rl))
                        else:
                                rx = lerpf(-0.85, -0.10, _eo(r))
                                ex = lerpf(-0.35, -0.18, _eo(r))
                        tgt[&"arm_r"] = Vector3(rx, 0, -0.02)
                        tgt[&"elb_r"] = Vector3(ex, 0, 0)
                        tgt[&"spine"] = Vector3(0.05, -0.05 * up, 0)
                        tgt[&"head"] = Vector3(0.03, 0, 0)
                "throw":
                        var w := _seg(t, 0.0, 0.16)
                        var wh := _seg(t, 0.16, 0.34)
                        var r := _seg(t, 0.34, 1.0)
                        var ax: float
                        var sy: float
                        var mx: float
                        if t < 0.16:
                                ax = lerpf(-0.10, 2.85, _eo(w))
                                sy = lerpf(0.0, -0.35, _eo(w))
                                mx = lerpf(0.18, -0.35, _eo(w))
                        elif t < 0.34:
                                ax = lerpf(2.85, -1.05, _sm(wh))
                                sy = lerpf(-0.35, 0.30, _sm(wh))
                                mx = lerpf(-0.35, -1.10, _sm(wh))
                        else:
                                ax = lerpf(-1.05, -0.10, _eo(r))
                                sy = lerpf(0.30, 0.0, _eo(r))
                                mx = lerpf(-1.10, 0.18, _eo(r))
                        tgt[&"arm_r"] = Vector3(ax, 0, -0.04)
                        tgt[&"elb_r"] = Vector3(-0.10, 0, 0)
                        tgt[&"wmount"] = Vector3(mx, 0, 0)
                        tgt[&"spine"] = Vector3(0.03 + 0.16 * _sm(wh), sy, 0)
                        tgt[&"arm_l"] = Vector3(-0.35, 0, 0.14)
        tgt[&"leg_l"] = Vector3(0, 0, 0.02)
        tgt[&"knee_l"] = Vector3(0.08, 0, 0)
        tgt[&"leg_r"] = Vector3(0, 0, -0.02)
        tgt[&"knee_r"] = Vector3(0.08, 0, 0)


func _pose_hit(tgt: Dictionary) -> void:
        var k := _eo(_seg(_t, 0.0, 0.12))
        var r := _eo(_seg(_t, 0.12, 1.0))
        tgt[&"spine"] = Vector3(0.03 - 0.32 * k * (1.0 - r * 0.85), 0, 0)
        tgt[&"head"] = Vector3(0.02 - 0.28 * k * (1.0 - r), 0, 0)
        tgt[&"arm_l"] = Vector3(-0.10, 0, 0.10 + 0.45 * k * (1.0 - r))
        tgt[&"arm_r"] = Vector3(-0.10, 0, -0.10 - 0.45 * k * (1.0 - r))
        tgt[&"elb_l"] = Vector3(-0.18, 0, 0)
        tgt[&"elb_r"] = Vector3(-0.18, 0, 0)
        tgt[&"leg_l"] = Vector3(0, 0, 0.02)
        tgt[&"knee_l"] = Vector3(0.06, 0, 0)
        tgt[&"leg_r"] = Vector3(0, 0, -0.02)
        tgt[&"knee_r"] = Vector3(0.06, 0, 0)
        _rig_y_target = -0.02 * k * (1.0 - r)
        if _cape_on:
                tgt[&"cape1"] = Vector3(-(0.10 + 0.45 * k * (1.0 - r)), 0, 0)


## مرگ — زانو خم می‌شود، تن به عقب می‌افتد، روی زمین یخ می‌زند
func _pose_death(tgt: Dictionary) -> void:
        _t = minf(_t, _dur)
        var b := _sm(_seg(_t, 0.0, 0.20))
        var f := _sm(_seg(_t, 0.20, 0.78))
        var s := _seg(_t, 0.78, 1.0)
        _rig_rot_target = Vector3(-1.52 * f - 0.03 * s, 0.35 * f, 0)
        _rig_y_target = -0.06 * b * (1.0 - f)
        var relax := f
        tgt[&"spine"] = Vector3(0.28 * b * (1.0 - f) - 0.10 * relax, 0, 0)
        tgt[&"head"] = Vector3(-0.15 * relax, 0, 0)
        tgt[&"arm_l"] = Vector3(-0.15 * relax, 0, 0.10 + 0.80 * relax)
        tgt[&"arm_r"] = Vector3(-0.15 * relax, 0, -0.10 - 0.80 * relax)
        tgt[&"elb_l"] = Vector3(-0.10 * relax, 0, 0)
        tgt[&"elb_r"] = Vector3(-0.10 * relax, 0, 0)
        tgt[&"leg_l"] = Vector3(-0.08 * relax, 0, 0.02 + 0.14 * relax)
        tgt[&"knee_l"] = Vector3(0.55 * b * (1.0 - f) + 0.05, 0, 0)
        tgt[&"leg_r"] = Vector3(-0.08 * relax, 0, -0.02 - 0.14 * relax)
        tgt[&"knee_r"] = Vector3(0.55 * b * (1.0 - f) + 0.05, 0, 0)
        if _cape_on:
                tgt[&"cape1"] = Vector3(-(0.10 + 0.5 * f), 0, 0)
                tgt[&"cape2"] = Vector3(-0.15 * (1.0 - f), 0, 0)
                tgt[&"cape3"] = Vector3(-0.10 * (1.0 - f), 0, 0)
        if _flag_on:
                tgt[&"flag"] = Vector3(0, 0.12 * (1.0 - f), 0)


# ---------------- تینت/فلش/محو (API نسخه‌ی قبل) ----------------

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
                if is_instance_valid(m):
                        m.set_shader_parameter("flash", 0.0)


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

