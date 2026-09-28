class_name SpriteCharacterModel
extends CharacterModelBase
## گام ۶R16 — کاراکترِ دوبعدیِ بیلبوردی (سبکِ Bad North) — مسیرِ پیش‌فرضِ جدید:
##
##   * هر واحد = یک QuadMesh عمودی که هر فریم «رو به دوربین» می‌چرخد
##     (بیلبوردِ Y در شیدر — چرخشِ yِ واحدِ میزبان خنثی می‌شود)
##   * اسپرایت‌ها: res://assets/sprites/units/<kind>/<anim>_<i>.png
##         anim ∈ idle | walk | attack | hit | death | block  (هر کدام ۱..n فریم)
##     برای واردکردنِ کاراکترِ دو بعدیِ تازه فقط PNG در پوشه‌ی <kind> بگذارید —
##     نام‌گذاری همین باشد؛ مدل خودش می‌شمارد.
##   * همان API مدلِ سه‌بعدی: گرادیانِ انتخابِ پرچمی (سر روشن → پا تیره)،
##     فلشِ سفیدِ ضربه، آلفای محوِ جسد — همه با یونیفرمِ شیدر
##   * ارتفاع نرمال: بلندیِ کادر = GameConstants.UNIT_WORLD_HEIGHT

const SPRITE_DIR := "res://assets/sprites/units/"
const ANIMS := ["idle", "walk", "attack", "attack2", "hit", "block", "death"]
## fps هر انیمیشن — walk تندتر تا حسِ حرکتِ اسکلتی بدهد
## attack2 = نسخه‌ی دومِ حمله از کاربر (۵۰٪ تصادفی در play_attack)
const FPS := {"idle": 2.0, "walk": 7.0, "attack": 8.0, "attack2": 8.0,
                "hit": 6.0, "block": 2.0, "death": 5.0}
const LOOPED := {"idle": true, "walk": true, "attack": false, "attack2": false,
                "hit": false, "block": true, "death": false}

## شیدرِ بیلبوردِ Y + گرادیان/فلش/آلفا — کشِ استاتیک (یکی برای همه)
static var _shader_cache: Shader = null

var _kind: StringName = &"warrior"
var _quad: MeshInstance3D
var _mat: ShaderMaterial
var _anims: Dictionary = {}            # "idle" → Array[Texture2D]
var _anim := "idle"
var _frame := 0.0                      # شمارنده‌ی اعشاری فریم
var _moving := false
var _busy := false                     # انیمیشنِ یک‌باره در جریان
var _dead := false
var _tint := Color.WHITE
var _tint_k := 0.0
var _crouch_k := 1.0
var _quad_h := GameConstants.UNIT_WORLD_HEIGHT
var _last_feet_y := -1000.0
var _flip := 0.0                       # ۰ = رو به راستِ صفحه، ۱ = آینه
var _fade_tween: Tween


static func _billboard_shader() -> Shader:
        if _shader_cache == null:
                var sh := Shader.new()
                sh.code = """
shader_type spatial;
render_mode world_vertex_coords, blend_mix, depth_draw_opaque,
                cull_disabled, unshaded, specular_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint_col : source_color = vec4(1.0);
uniform float tint_amt = 0.0;
uniform float flash = 0.0;
uniform float alpha = 1.0;
uniform float scissor = 0.45;
uniform float flip_h = 0.0;
uniform float feet_y = 0.0;
uniform float body_h = 0.82;
varying float v_h;

void vertex() {
        // مبدأِ گره (پایِ کاراکتر) در جهان — چرخشِ واحدِ میزبان نادیده گرفته می‌شود
        vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
        // راستِ دوربین روی صفحه‌ی XZ — بیلبوردِ Y (بدونِ خیز به عقب)
        vec3 cam_right = (vec4(1.0, 0.0, 0.0, 0.0) * VIEW_MATRIX).xyz;
        cam_right.y = 0.0;
        cam_right = normalize(cam_right);
        // مقیاسِ گره (نشستِ زانو روی y) حفظ می‌شود
        float sw = length(MODEL_MATRIX[0].xyz);
        float sh = length(MODEL_MATRIX[1].xyz);
        VERTEX = origin + cam_right * (VERTEX.x * sw)
                        + vec3(0.0, 1.0, 0.0) * (VERTEX.y * sh);
        // گرادیانِ عمودی نسبت به پایِ واقعی روی زمین (مثل مدلِ سه‌بعدی)
        v_h = clamp((VERTEX.y - feet_y) / max(body_h, 0.2), 0.0, 1.0);
}

void fragment() {
        vec4 c = texture(tex, vec2(mix(UV.x, 1.0 - UV.x, flip_h), UV.y));
        // امضای Bad North: سر روشن‌تر، پا تیره‌تر — ۶R16b: «ضرب» نه جایگزینی —
        // جزئیاتِ اسپرایت (خط دور/سلاح) زیرِ گرادیانِ دسته خوانا می‌ماند
        vec3 grad = vec3(mix(0.50, 1.35, v_h));
        vec3 col = mix(c.rgb, c.rgb * grad * tint_col.rgb, tint_amt);
        col = mix(col, vec3(1.0), flash);
        ALBEDO = col;
        float a = c.a * alpha;
        ALPHA = a;
        ALPHA_SCISSOR_THRESHOLD = scissor;
}
"""
                _shader_cache = sh
        return _shader_cache


func setup(kind: StringName, tint: Color, tint_k := 0.0,
                _special: Dictionary = {}) -> void:
        _kind = kind
        _load_frames()
        if _anims.is_empty():
                push_warning("SpriteCharacterModel: no sprites for %s" % kind)
                return
        var idle: Array = _anims.get("idle", _anims.values()[0])
        var tex0: Texture2D = idle[0]
        var w := float(tex0.get_width())
        var h := float(tex0.get_height())
        _quad_h = GameConstants.UNIT_WORLD_HEIGHT
        var qw := _quad_h * (w / maxf(h, 1.0))

        _quad = MeshInstance3D.new()
        var qm := QuadMesh.new()
        qm.size = Vector2(qw, _quad_h)
        qm.center_offset = Vector3(0.0, _quad_h * 0.5, 0.0)   # مبدأ = پایِ کاراکتر
        qm.orientation = PlaneMesh.FACE_Z
        _quad.mesh = qm
        _quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        _mat = ShaderMaterial.new()
        _mat.shader = _billboard_shader()
        _mat.set_shader_parameter("tex", tex0)
        _mat.set_shader_parameter("feet_y", global_position.y if is_inside_tree() else 0.0)
        _mat.set_shader_parameter("body_h", _quad_h)
        _mat.set_shader_parameter("scissor", 0.45)
        _quad.material_override = _mat
        add_child(_quad)
        apply_team_tint(tint, tint_k)
        _anim = "idle"
        _frame = randf() * 1.0   # فازِ تصادفیِ آیدل — سربازها ماشینی نفس نمی‌کشند


func body_root() -> Node3D:
        return _quad if _quad != null else self


## شمارش‌گرِ فریم‌ها: <SPRITE_DIR>/<kind>/<anim>_<i>.png تا شکستِ اول
func _load_frames() -> void:
        _anims.clear()
        var base := SPRITE_DIR + String(_kind) + "/"
        for a in ANIMS:
                var frames: Array[Texture2D] = []
                var i := 0
                while true:
                        var p := base + "%s_%d.png" % [a, i]
                        if not ResourceLoader.exists(p):
                                break
                        frames.append(load(p))
                        i += 1
                if not frames.is_empty():
                        _anims[a] = frames
        # جایگزین‌ها: walk→idle (لغزشِ نرم)، attack2→attack،
        # attack→walk اولین فریم، block→idle، death→idle
        if not _anims.has("walk") and _anims.has("idle"):
                _anims["walk"] = _anims["idle"].duplicate()
        if not _anims.has("attack2") and _anims.has("attack"):
                _anims["attack2"] = _anims["attack"]
        if not _anims.has("attack") and _anims.has("walk"):
                _anims["attack"] = [_anims["walk"][0]]
        if not _anims.has("block") and _anims.has("idle"):
                _anims["block"] = _anims["idle"]
        if not _anims.has("hit") and _anims.has("idle"):
                _anims["hit"] = _anims["idle"]
        if not _anims.has("death") and _anims.has("idle"):
                _anims["death"] = _anims["idle"]


func _process(delta: float) -> void:
        if _mat == null or not is_inside_tree():
                return
        # گرادیان همیشه نسبت به پایِ واقعی روی زمین
        var fy := global_position.y
        if absf(fy - _last_feet_y) > 0.01:
                _last_feet_y = fy
                _mat.set_shader_parameter("feet_y", fy)
        # آینه‌ی جهت نسبت به دوربین — هر فریم (نه فقط هنگامِ حرکت) تا حمله‌ی
        # ایستا هم رو به دشمن آینه شود (چرخشِ rotation.y را دنبال می‌کند)
        if not _dead:
                var cam := get_viewport().get_camera_3d()
                if cam != null:
                        var right := cam.global_transform.basis.x
                        var fwd2 := Vector2(sin(_heading_ref()), cos(_heading_ref()))
                        var r2 := Vector2(right.x, right.z)
                        var f := 1.0 if fwd2.dot(r2) < 0.0 else 0.0
                        if f != _flip:
                                _flip = f
                                _mat.set_shader_parameter("flip_h", _flip)
        # پیشرویِ فریم
        if _anims.is_empty():
                return
        var frames: Array = _anims[_anim]
        var fps: float = FPS.get(_anim, 5.0)
        if not LOOPED.get(_anim, true):
                # مرگ/ضربه/حمله: یک‌بار — مرگ روی آخرین فریم یخ می‌زند
                if _frame >= float(frames.size()) - 0.001:
                        _frame = float(frames.size()) - 0.001
                        if _busy and _anim != "death":
                                _busy = false
                                _anim = "walk" if _moving else "idle"
                                _frame = 0.0
                else:
                        _frame += delta * fps
        else:
                _frame = wrapf(_frame + delta * fps, 0.0, frames.size())
        var idx := clampi(int(_frame), 0, frames.size() - 1)
        _mat.set_shader_parameter("tex", frames[idx])


## جهتِ فعلیِ رو به دشمن/حرکت — از والد (واحد) می‌آید
func _heading_ref() -> float:
        var p := get_parent()
        if p is Node3D:
                return (p as Node3D).rotation.y
        return 0.0


# ---------------- تینتِ تیم (همان قراردادِ مدلِ سه‌بعدی) ----------------

func apply_team_tint(tint: Color, amt := 0.0) -> void:
        _tint = tint
        _tint_k = amt
        if _mat == null:
                return
        if is_inside_tree():
                _mat.set_shader_parameter("feet_y", global_position.y)
        _mat.set_shader_parameter("tint_col", tint)
        _mat.set_shader_parameter("tint_amt", clampf(amt, 0.0, 1.0))


func display_color() -> Color:
        return _tint


func tint_amount() -> float:
        return _tint_k


# ---------------- پخشِ حالت‌ها ----------------

func set_moving(moving: bool) -> void:
        if moving != _moving:
                _moving = moving
                if not _busy and not _dead:
                        _anim = "walk" if _moving else "idle"
                        _frame = 0.0


## حمله‌ی متنوع: اگر attack2 موجود باشد ۵۰٪ شانس — ضدِ تکرارِ ماشینی
func play_attack() -> void:
        if _anims.has("attack2") and randf() < 0.5:
                _play_once("attack2")
        else:
                _play_once("attack")


func play_hit() -> void:
        if not _dead:
                _play_once("hit")


func _play_once(a: String) -> void:
        if _dead or not _anims.has(a):
                return
        _busy = true
        _anim = a
        _frame = 0.0


func set_blocking(on: bool) -> void:
        # حالتِ سپری — اگر فریمِ block باشد روی آن می‌ماند
        if _dead or not _anims.has("block"):
                return
        if on and not _busy:
                _anim = "block"
                _frame = 0.0
        elif not on and _anim == "block" and not _busy:
                _anim = "walk" if _moving else "idle"
                _frame = 0.0


func set_crouch(k: float) -> void:
        if _quad == null:
                return
        _crouch_k = k
        _quad.scale = Vector3(1.0, k, 1.0)


func freeze_pose() -> void:
        _busy = false


func play_death() -> void:
        if _dead:
                return
        _dead = true
        if _anims.has("death"):
                _busy = true
                _anim = "death"
                _frame = 0.0
        if _mat != null:
                _mat.set_shader_parameter("flip_h", _flip)


# ---------------- افکت‌های ضربه و مرگ ----------------

func flash_white() -> void:
        if _mat == null or _dead:
                return
        _mat.set_shader_parameter("flash", 1.0)
        var tw := create_tween()
        tw.tween_interval(0.10)
        tw.tween_callback(_restore_flash)


func _restore_flash() -> void:
        if _mat != null:
                _mat.set_shader_parameter("flash", 0.0)


func fade_out(secs: float) -> void:
        if _mat == null:
                return
        if _fade_tween != null and _fade_tween.is_valid():
                _fade_tween.kill()
        _mat.set_shader_parameter("alpha", 1.0)
        _mat.set_shader_parameter("scissor", 0.45)
        _fade_tween = create_tween()
        _fade_tween.tween_interval(0.35)
        _fade_tween.set_parallel(true)
        _fade_tween.tween_method(_set_alpha, 1.0, 0.0, secs)
        _fade_tween.tween_method(_set_scissor, 0.45, 0.0, secs)


func _set_alpha(v: float) -> void:
        if _mat != null:
                _mat.set_shader_parameter("alpha", v)


func _set_scissor(v: float) -> void:
        if _mat != null:
                _mat.set_shader_parameter("scissor", v)
