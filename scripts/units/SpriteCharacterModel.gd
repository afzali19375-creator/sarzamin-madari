class_name SpriteCharacterModel
extends CharacterModel
## اسپرایت‌های GIF کاربر — لایه‌ی ۲٫۵بعدی (گام ۶R17)
##
## فریم‌های GIF با حذف پس‌زمینه به شیت‌های افقی تبدیل شده‌اند
## (assets/sprites/<kind>/<anim>.png + manifest.json). این کلاس دقیقاً همان
## API عمومیِ CharacterModel را دارد (setup/set_moving/play_attack/play_hit/
## play_death/flash_white/fade_out/apply_team_tint/display_color/tint_amount/
## body_root) تا UnitBase و EnemyBase بدون تغییر منطق جابه‌جا شوند.
##
## رندر:
##   * Sprite3D با بیلبوردِ «فقط محور Y» — اسپرایت همیشه رو به دوربین می‌ایستد
##     ولی با چرخشِ سرِ دوربین (yaw) می‌چرخد؛ با hframes فریم عوض می‌شود
##   * لنگر پا = مبدأ نود (اسپرایت نیم‌قد بالای مبدأ می‌ایستد)
##   * سایه‌ی بیضیِ نرم زیر پا (بیلبورد سایه‌ی سه‌بعدیِ زشت نمی‌اندازد)
##   * جهتِ نگاه: آینه‌ی افقی بر اساس جهت حرکت نسبت به راستِ دوربین
##   * مرگ: پس از پایانِ انیمیشن، کوارتِ اسپرایت روی زمین می‌خوابد (جسد)
##   * فلش ضربه = اوربرایتِ modulate | محو = آلفای modulate

const SPRITE_MANIFEST := "res://assets/sprites/manifest.json"
## قدِ جهانی اسپرایت (هم‌ترازِ TARGET_HEIGHT مدلِ سه‌بعدی)
const SPRITE_HEIGHT := 0.82
## نقش‌هایی که آرت‌شان ذاتاً رو به راستِ تصویر است (بقیه رو به چپ)
const NATIVE_FACING_RIGHT := {
        "warrior": false, "viking": false, "ranger": false,
        "knight_heavy": true, "soldier": true,
}
## زنجیره‌ی جایگزین انیمیشن‌ها (اگر شیت نبود)
const ANIM_FALLBACK := {
        "walk": "idle", "attack": "walk", "attak2": "attack",
        "hit": "attack", "death": "idle",
}

static var _manifest: Dictionary = {}
static var _tex_cache: Dictionary = {}

var _skind := "warrior"
var _spr: Sprite3D
var _shadow: MeshInstance3D
var _anims: Dictionary = {}
var _cur := &"idle"
var _frame := 0.0
var _loop := true
var _speed := 1.0
var _sbusy := false
var _sdead := false
var _corpse_laid := false
var _frozen := false
var _smoving := false
var _att_n := 0
var _face_flip := false
var _stint := Color.WHITE
var _stint_k := 0.0
var _alpha := 1.0
var _flash := 0.0
var _shadow_mat: StandardMaterial3D


# ---------------- منبع مشترک ----------------

static func _load_manifest() -> void:
        if not _manifest.is_empty():
                return
        var f := FileAccess.open(SPRITE_MANIFEST, FileAccess.READ)
        if f == null:
                push_warning("SpriteCharacterModel: manifest missing")
                return
        var data: Variant = JSON.parse_string(f.get_as_text())
        if data is Dictionary:
                _manifest = data


static func has_kind(kind: StringName) -> bool:
        _load_manifest()
        return _manifest.has(String(kind))


static func sheet_tex(path: String) -> Texture2D:
        if not _tex_cache.has(path):
                _tex_cache[path] = load(path)
        return _tex_cache[path]


# ---------------- چرخه‌ی عمر ----------------

func setup(kind: StringName, tint: Color, tint_k := 0.42,
                special: Dictionary = {}) -> void:
        _load_manifest()
        _skind = String(kind) if has_kind(kind) else "warrior"
        if not has_kind(_skind):
                return   # هیچ شیتی نیست — بی‌صدا (کارخانه به مدل سه‌بعدی برمی‌گردد)
        _anims = _manifest[_skind]["anims"]

        var cw: int = int(_manifest[_skind].get("canvas_w", 128))
        var ch: int = int(_manifest[_skind].get("canvas_h", 176))

        _spr = Sprite3D.new()
        _spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
        _spr.shaded = false
        _spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
        _spr.pixel_size = SPRITE_HEIGHT / float(ch)
        _spr.position = Vector3(0.0, SPRITE_HEIGHT * 0.5, 0.0)   # پا روی مبدأ
        _spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(_spr)

        # سایه‌ی بیضیِ نرم زیر پا (جایگزین سایه‌ی واقعیِ مدل اسکلتی)
        _shadow = MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.20
        cm.bottom_radius = 0.20
        cm.height = 0.012
        cm.radial_segments = 20
        _shadow.mesh = cm
        _shadow.scale = Vector3(1.35, 1.0, 0.95)
        _shadow.position.y = 0.012
        _shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _shadow_mat = StandardMaterial3D.new()
        _shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _shadow_mat.albedo_color = Color(0.05, 0.07, 0.05, 0.30)
        _shadow.material_override = _shadow_mat
        add_child(_shadow)

        _stint = tint
        _stint_k = tint_k
        _face_flip = not NATIVE_FACING_RIGHT.get(_skind, false)
        # _cur باید خالی باشد تا _play_sheet پیکربندیِ اولیه را رد نکند
        # (باگ: early-return روی «همان انیمیشن» باعث texture=null و
        # hframes=1 و خطای frame out-of-bounds می‌شد)
        _cur = &""
        _play_sheet(&"idle", true, 1.0)
        # فازِ تصادفیِ آیدل — سربازها هم‌زمان نفس نمی‌کشند
        var idle: Dictionary = _anims.get("idle", {})
        if idle.has("frames"):
                _frame = randf() * float(idle["frames"])
        _apply_visuals()


func body_root() -> Node3D:
        return self


func _process(delta: float) -> void:
        if _spr == null or _anims.is_empty():
                return
        _update_facing()
        if _frozen:
                return
        var cfg: Dictionary = _anims.get(String(_cur), {})
        if cfg.is_empty():
                return
        var n := float(cfg["frames"])
        _frame += delta * float(cfg["fps"]) * _speed
        if _loop:
                if n > 0.0:
                        _frame = fmod(_frame, n)
        else:
                if _frame >= n - 0.001:
                        _frame = n - 1.0
                        if _sdead:
                                if not _corpse_laid:
                                        _lay_corpse()
                        else:
                                _sbusy = false
                                _apply_locomotion()
        _spr.frame = int(_frame)


# ---------------- انیمیشن ----------------

func _resolve_anim(a: StringName) -> StringName:
        var s := String(a)
        var guard := 0
        while not _anims.has(s) and ANIM_FALLBACK.has(s) and guard < 4:
                s = String(ANIM_FALLBACK[s])
                guard += 1
        return StringName(s) if _anims.has(s) else &""


func _play_sheet(a: StringName, loop := true, speed := 1.0) -> void:
        var real := _resolve_anim(a)
        if real == &"":
                return
        if real == _cur and _spr != null:
                _loop = loop
                _speed = speed
                return
        var cfg: Dictionary = _anims[String(real)]
        _cur = real
        _loop = loop
        _speed = speed
        _frame = 0.0
        _spr.texture = sheet_tex(String(cfg["sheet"]))
        _spr.hframes = int(cfg["frames"])
        _spr.frame = 0
        _spr.flip_h = _face_flip


func _apply_locomotion() -> void:
        if _sdead or _sbusy:
                return
        _play_sheet(&"walk" if _smoving else &"idle", true, 1.0)


func set_moving(moving: bool) -> void:
        if moving != _smoving:
                _smoving = moving
                _apply_locomotion()


func play_attack() -> void:
        if _sdead or _spr == null:
                return
        _att_n += 1
        var a := &"attack"
        if _anims.has("attak2") and _att_n % 2 == 0:
                a = &"attak2"
        var cfg: Dictionary = _anims[String(_resolve_anim(a))]
        # هم‌گام با چرخه‌ی ضربه‌ی بازی (~۰٫۴۵s)
        var speed := 1.0
        if cfg.has("frames") and cfg.has("fps"):
                speed = clampf(float(cfg["frames"]) / (0.45 * float(cfg["fps"])),
                                1.0, 4.0)
        _sbusy = true
        _play_sheet(a, false, speed)


func play_hit() -> void:
        if _sdead or _spr == null:
                return
        if _anims.has("hit"):
                _sbusy = true
                _play_sheet(&"hit", false, 1.6)
        else:
                flash_white()   # ست‌های دشمن انیمیشنِ ضربه ندارند — فلش کافی است


func play_death() -> void:
        if _sdead or _spr == null:
                return
        _sdead = true
        var real := _resolve_anim(&"death")
        if real == &"":
                _lay_corpse()
                return
        var cfg: Dictionary = _anims[String(real)]
        var speed := 1.0
        if cfg.has("frames") and cfg.has("fps"):
                var ln := float(cfg["frames"]) / float(cfg["fps"])
                if ln > 0.05:
                        speed = clampf(ln / 0.9, 1.0, 2.6)   # کلِ افتادن ≤۰٫۹s (۶R13)
        _sbusy = true
        _play_sheet(&"death", false, speed)


## جسد: بیلبورد خاموش + خواباندنِ کوارت روی زمین (سر به سمتِ جلوی یونیت)
func _lay_corpse() -> void:
        _corpse_laid = true
        _spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
        _spr.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
        _spr.position = Vector3(0.0, 0.02, -0.05)
        _frame = _anims[String(_cur)]["frames"] - 1.0
        _spr.frame = int(_frame)
        _sbusy = false


func freeze_pose() -> void:
        _frozen = true
        _sbusy = false


func set_blocking(_on: bool) -> void:
        pass   # آرت‌های GIF ژستِ سپر جدا ندارند — تینتِ انتخاب خوانایی می‌دهد


func set_crouch(k: float) -> void:
        # لهجه‌ی ملایمِ اسپرایت در حالت سپر — مقیاسِ غیر یکنواخت با بیلبوردِ Y
        # هم‌خوان است (کوارت عمودی می‌ماند) و برخلافِ مدل اسکلتی مقیاسِ نرمال
        # را خراب نمی‌کند
        if _spr != null:
                _spr.scale = Vector3(1.0, clampf(k, 0.7, 1.2), 1.0)


# ---------------- جهتِ نگاه (آینه‌ی افقی) ----------------

func _update_facing() -> void:
        if _spr == null or _sdead:
                return
        var cam := get_viewport().get_camera_3d()
        if cam == null:
                return
        var right := cam.global_transform.basis.x
        right.y = 0.0
        if right.length_squared() < 0.01:
                return
        right = right.normalized()
        # جهتِ نگاهِ یونیت (پدرِ این نود به سمتِ هدف می‌چرخد)
        var fwd := global_transform.basis.z
        var d := fwd.dot(right)
        if d > 0.18:
                _face_flip = not NATIVE_FACING_RIGHT.get(_skind, false)
        elif d < -0.18:
                _face_flip = NATIVE_FACING_RIGHT.get(_skind, false)
        if _spr.flip_h != _face_flip:
                _spr.flip_h = _face_flip


# ---------------- افکت‌های ضربه و مرگ ----------------

func _apply_visuals() -> void:
        if _spr == null:
                return
        var c := Color.WHITE.lerp(_stint, clampf(_stint_k * 0.6, 0.0, 0.8))
        var k := 1.0 + _flash * 5.0
        c = Color(minf(c.r * k, 2.0), minf(c.g * k, 2.0), minf(c.b * k, 2.0),
                        _alpha)
        _spr.modulate = c
        if _shadow_mat != null:
                _shadow_mat.albedo_color = Color(0.05, 0.07, 0.05, 0.30 * _alpha)
        if _shadow != null:
                _shadow.visible = _alpha > 0.02


## فلش سفید — اوربرایتِ modulate (سیلوئت روشن)؛ ۰٫۱۲s
func flash_white() -> void:
        if _spr == null or _sdead:
                return
        var tw := create_tween()
        tw.tween_method(_set_flash, 1.0, 0.0, 0.12)


func _set_flash(v: float) -> void:
        _flash = v
        _apply_visuals()


## محوِ جسد/فرار — آلفای modulate به صفر
func fade_out(secs: float) -> void:
        if _spr == null:
                return
        var tw := create_tween()
        tw.tween_interval(0.2)
        tw.tween_method(_set_sheet_alpha, 1.0, 0.0, secs)


func _set_sheet_alpha(v: float) -> void:
        _alpha = v
        _apply_visuals()


# ---------------- تینتِ تیم (سازگار با تست) ----------------

func apply_team_tint(tint: Color, amt := 0.0) -> void:
        _stint = tint
        _stint_k = amt
        _apply_visuals()


func display_color() -> Color:
        return _stint


func tint_amount() -> float:
        return _stint_k


## نقشِ فعال — برای تست خودکار و دیباگ
func active_kind() -> String:
        return _skind


func active_anim() -> String:
        return String(_cur)
