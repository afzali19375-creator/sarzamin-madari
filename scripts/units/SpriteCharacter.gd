class_name SpriteCharacter
extends CharacterModel
## گام ۶R۱۶ — کاراکترِ دوبعدیِ «۲٫۵بعدی» به سبک Bad North (بازخورد کاربر:
## «کاراکترها در بد نورث همیشه رو به دوربین‌اند — دوبعدی در فضای سه‌بعدی»)
##
## معماری:
##   * اسپرایت‌شیت‌های تولیدشده (assets/sprites/chars/) با ۵ انیمیشن
##     (idle/walk/attack/hit/death) برای هر ۵ نقش
##   * Sprite3D با billboard عمودی (BILLBOARD_FIXED_Y) — همیشه رو به دوربین،
##     ولی همیشه قائم (مثل فیگور واقعی روی زمین)
##   * سه لایه‌ی اسپرایت روی هم: پایه (رنگ عادی) + گرادیان انتخاب + فلش سفید
##     — همان زبان بصری ۶R۱۵ (انتخاب = گرادیان رنگ پرچم از بالا به پایین)
##     بدون هیچ شیدر سفارشی (فقط modulate و render_priority)
##   * سایه‌ی بیضی نرم زیر پا (blob) — امضای بصری Bad North
##   * برگشت (flip) افقی بر اساس جهت حرکت در فضای صفحه‌ی دوربین
##
## API کاملاً همسان با CharacterModel — UnitBase/EnemyBase بدون تغییر منطقی
## فقط کارخانه را عوض می‌کنند (GameConstants.CHARACTERS_2D).
## توجه: _kind/_tint/_tint_k/_moving/_dead/TARGET_HEIGHT از کلاس پدر ارث است.

const SPRITE_DIR := "res://assets/sprites/chars/"
const TINT_TOP := 0.95          # (فقط مستندسازی — گرادیان در خودِ تکسچر است)
const TINT_BOTTOM := 0.30

static var _manifest: Dictionary = {}
static var _tex_cache: Dictionary = {}

var _pivot: Node3D
var _base: Sprite3D
var _tint_sp: Sprite3D
var _flash: Sprite3D
var _shadow: Sprite3D
var _anims: Dictionary = {}          # name -> {frames,fps,loop}
var _cur := ""
var _frame := 0
var _ft := 0.0                       # ساعت فریم
var _texs: Dictionary = {}           # anim -> Texture2D (پایه)
var _tint_texs: Dictionary = {}      # anim -> Texture2D (سیلوئت گرادیانی)
var _pixel_size := 0.0073
var _frame_h := 128
var _ground_row := 120.0
var _attack_lock := false
var _frozen := false
var _flash_tween: Tween
var _fade_tween: Tween
var _last_pos := Vector3.ZERO
var _flip := false                   # false = رو به راستِ صفحه
var _flip_speed := 0.0               # سرعت افقی صفحه‌ای — برای هیسترزیس


# ---------------- ساخت ----------------

func setup(kind: StringName, tint: Color, tint_k := 0.42,
                special: Dictionary = {}) -> void:
        _kind = kind if _manifest_known(kind) else &"warrior"
        var kd: Dictionary = _manifest.get("kinds", {}).get(String(_kind), {})
        _anims = kd.get("anims", {})
        var figure_px := float(kd.get("figure_px", 110.0))
        _pixel_size = TARGET_HEIGHT / maxf(figure_px, 1.0)
        _frame_h = int(_manifest.get("frame_h", 128))
        _ground_row = float(_manifest.get("ground_row", 120.0))

        _pivot = Node3D.new()
        add_child(_pivot)

        _base = _make_sprite()
        _tint_sp = _make_sprite()
        _flash = _make_sprite()
        _tint_sp.render_priority = 1
        _flash.render_priority = 2

        # سایه‌ی بیضی نرم روی زمین (بدون billboard — تخت روی زمین)
        _shadow = Sprite3D.new()
        _shadow.texture = _load_tex("shadow.png")
        _shadow.pixel_size = _pixel_size * 11.0
        _shadow.centered = true
        _shadow.rotation_degrees.x = -90.0
        _shadow.position.y = 0.025
        _shadow.modulate = Color(1, 1, 1, 0.85)
        _shadow.render_priority = -1
        _shadow.shaded = false
        _shadow.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
        _pivot.add_child(_shadow)

        _tint_sp.modulate = Color(1, 1, 1, 0.0)   # شروع: رنگِ طبیعی (amt=0)
        _flash.modulate = Color(1, 1, 1, 0.0)
        apply_team_tint(tint, tint_k)
        _play_anim(&"idle")
        # گام ۶R۱۶b — هنوز داخل درخت نیستیم؛ مبنای flip در نخستین فریم ست می‌شود
        _last_pos = Vector3.INF


func _manifest_known(kind: StringName) -> bool:
        _load_manifest()
        return _manifest.get("kinds", {}).has(String(kind))


static func _load_manifest() -> void:
        if not _manifest.is_empty():
                return
        var f := FileAccess.open(SPRITE_DIR + "manifest.json", FileAccess.READ)
        if f != null:
                var parsed: Variant = JSON.parse_string(f.get_as_text())
                if parsed is Dictionary:
                        _manifest = parsed


func _make_sprite() -> Sprite3D:
        var sp := Sprite3D.new()
        sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
        sp.shaded = false
        sp.centered = true
        sp.pixel_size = _pixel_size
        sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
        sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
        sp.transparent = true
        sp.no_depth_test = false
        # با centered=true: مرکزِ تکسچر روی مبدا nod؛ پا باید روی مبدا بنشیند
        # → اسپرایت به اندازه‌ی (ground_row - h/2) پیکسل بالا می‌رود
        sp.position.y = (_ground_row - float(_frame_h) * 0.5) * _pixel_size
        sp.flip_h = _flip
        _pivot.add_child(sp)
        return sp


static func _load_tex(file: String) -> Texture2D:
        if not _tex_cache.has(file):
                _tex_cache[file] = load(SPRITE_DIR + file)
        return _tex_cache[file]


func body_root() -> Node3D:
        return _pivot if _pivot != null else self


# ---------------- حلقه‌ی انیمیشن ----------------

func _process(delta: float) -> void:
        if _base == null or _frozen:
                return
        # پیش‌روی فریم
        var info: Dictionary = _anims.get(_cur, {})
        if not info.is_empty():
                var fps: float = float(info.get("fps", 8.0))
                var frames: int = int(info.get("frames", 1))
                var loop: bool = bool(info.get("loop", false))
                _ft += delta * fps
                if _ft >= 1.0:
                        _ft -= floorf(_ft)
                        _frame += 1
                        if _frame >= frames:
                                if loop:
                                        _frame = 0
                                else:
                                        _frame = frames - 1
                                        _on_anim_end()
        _apply_frame()
        # برگشت افقی بر اساس جهت حرکت در فضای صفحه‌ی دوربین (Bad North:
        # اسپرایت همیشه رو به دوربین، فقط چپ/راست عوض می‌شود)
        _update_flip()


func _apply_frame() -> void:
        var tex: Texture2D = _texs.get(_cur)
        if tex == null:
                return
        # گام ۶R۱۶b — هر انیمیشن = یک استریپِ افقی؛ hframes باید با آن
        # هم‌گام شود وگرنه frame>0 روی تکسچرِ تک‌فریمی خطای انبوه می‌دهد
        var frames: int = int(_anims.get(_cur, {}).get("frames", 1))
        _base.texture = tex
        _base.hframes = frames
        _base.frame = _frame
        _tint_sp.texture = _tint_texs.get(_cur)
        _flash.texture = _tint_texs.get(_cur)   # فلش = سیلوئتِ سفیدِ فریم فعلی
        _tint_sp.hframes = frames
        _tint_sp.frame = _frame
        _flash.hframes = frames
        _flash.frame = _frame


func _on_anim_end() -> void:
        if _cur == &"attack" or _cur == &"hit":
                _attack_lock = false
                if not _dead:
                        _play_anim(&"walk" if _moving else &"idle")
        # death عمداً روی آخرین فریم می‌ماند (جسد)


# ---------------- حرکت و انیمیشن (همسانِ CharacterModel) ----------------

func set_moving(moving: bool) -> void:
        if moving == _moving:
                return
        _moving = moving
        if not _attack_lock and not _dead:
                _play_anim(&"walk" if moving else &"idle")


func play_attack() -> void:
        if _dead:
                return
        _attack_lock = true
        _play_anim(&"attack")


func play_hit() -> void:
        if _dead or (_attack_lock and _cur == &"attack"):
                return
        _attack_lock = true
        _play_anim(&"hit")


func play_death() -> void:
        if _dead:
                return
        _dead = true
        _attack_lock = true
        _play_anim(&"death")


func set_crouch(k: float) -> void:
        # نشستِ کوتاهِ زانو — فقط مقیاس عمودیِ پیوت (بدون دستکاری عکس)
        if _pivot != null:
                _pivot.scale = Vector3(1.0, k, 1.0)


func set_blocking(_on: bool) -> void:
        pass  # سپر در خودِ اسپرایت کشیده شده است


func freeze_pose() -> void:
        _frozen = true


# ---------------- تینتِ گرادیانیِ تیم (همسانِ ۶R۱۵) ----------------

func apply_team_tint(tint: Color, amt := 0.0) -> void:
        _tint = tint
        _tint_k = clampf(amt, 0.0, 1.0)
        if _tint_sp != null:
                # گرادیانِ سر→پا در آلفای تکسچر سیلوئت بسته شده؛
                # modulate فقط رنگ پرچم و شدت کل (amt) را می‌دهد
                _tint_sp.modulate = Color(tint.r, tint.g, tint.b, _tint_k)


func display_color() -> Color:
        return _tint


func tint_amount() -> float:
        return _tint_k


# ---------------- افکت‌های ضربه و مرگ ----------------

func flash_white() -> void:
        if _flash == null or _dead:
                return
        if _flash_tween != null and _flash_tween.is_valid():
                _flash_tween.kill()
        _flash.modulate = Color(1, 1, 1, 0.95)
        _flash_tween = create_tween()
        _flash_tween.tween_interval(0.08)
        _flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.06)


func fade_out(secs: float) -> void:
        if _base == null:
                return
        if _fade_tween != null and _fade_tween.is_valid():
                _fade_tween.kill()
        _fade_tween = create_tween()
        _fade_tween.tween_interval(0.35)
        _fade_tween.set_parallel(true)
        for sp: Sprite3D in [_base, _tint_sp, _shadow]:
                _fade_tween.tween_property(sp, "modulate:a", 0.0, secs)


# ---------------- داخلی ----------------

func _play_anim(name: StringName) -> void:
        if StringName(_cur) == name or not _anims.has(String(name)):
                return
        # تکسچرهای هر انیمیشن را یک‌بار کش کن
        if not _texs.has(String(name)):
                _texs[String(name)] = _load_tex("%s_%s.png" % [String(_kind), name])
                _tint_texs[String(name)] = _load_tex("%s_%s_tint.png" % [String(_kind), name])
        _cur = String(name)
        _frame = 0
        _ft = 0.0
        # فازِ تصادفیِ آیدل — سربازها ماشینی و هم‌زمان نفس نمی‌کشند
        if name == &"idle":
                _ft = randf() * 0.9
        _apply_frame()


## برگشت افقی: سرعتِ افقیِ کاراکتر را روی محورِ «راستِ دوربین» می‌سنجد
func _update_flip() -> void:
        if not is_inside_tree():
                return
        var cam := get_viewport().get_camera_3d()
        if cam == null:
                return
        if _last_pos == Vector3.INF:
                _last_pos = global_position
                return
        var vel := (global_position - _last_pos) / maxf(get_process_delta_time(), 0.0001)
        _last_pos = global_position
        var right := cam.global_transform.basis.x
        var v_h := vel.dot(Vector3(right.x, 0.0, right.z))
        _flip_speed = lerpf(_flip_speed, v_h, 0.25)
        if absf(_flip_speed) > 0.35:
                var want := _flip_speed < 0.0
                if want != _flip:
                        _flip = want
                        _base.flip_h = _flip
                        _tint_sp.flip_h = _flip
                        _flash.flip_h = _flip
