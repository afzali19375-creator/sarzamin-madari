class_name BlobShadow
extends Decal
## گام M2 — سایه‌ی لکه‌ایِ نرمِ زیر پا (بازخورد چینش §۶):
## «هر سرباز یک سایه‌ی نرم بیضی‌شکل زیر پایش، کمی به سمتِ مخالفِ نور کج —
## علاوه بر سایه‌ی نور جهت‌دار، برای عمق و حسِ سه‌بعدی»
##
## * Decal = تصویر روی زمینِ ناهموار هم می‌نشیند (برخلافِ کوادِ تخت روی شیب نمی‌برد)
## * بیضیِ کشیده در راستای سایه + جابجاییِ مرکز به سمتِ مخالفِ نور
## * رنگ = خاکستریِ گرمِ BLOB_COLOR (نه سیاهِ محض) با آلفای نرم
## * فرزندِ خودِ واحد است → با حرکت/نشستِ روی زمین خودکار دنبال می‌شود
## * هنگامِ مرگ با پیکر محو/آزاد می‌شود (سایه‌ی جسد طبیعی می‌ماند)

static var _tex_cache: GradientTexture2D = null


## بافتِ شعاعیِ نرم — یکبار برای همه‌ی واحدها ساخته و کش می‌شود
static func blob_texture() -> GradientTexture2D:
        if _tex_cache == null:
                var g := Gradient.new()
                g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
                g.colors = PackedColorArray([
                                Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
                _tex_cache = GradientTexture2D.new()
                _tex_cache.gradient = g
                _tex_cache.fill = GradientTexture2D.FILL_RADIAL
                _tex_cache.fill_from = Vector2(0.5, 0.5)
                _tex_cache.fill_to = Vector2(0.5, 0.02)
                _tex_cache.width = 128
                _tex_cache.height = 128
        return _tex_cache


## جهتِ زمینیِ «سایه‌افتادن» از زاویه‌ی خورشید (تک‌منبع: GameConstants.SUN_ROT_DEG)
static func shadow_dir_xz() -> Vector2:
        var f := Vector3(0, 0, -1)
        f = f.rotated(Vector3(1, 0, 0), deg_to_rad(GameConstants.SUN_ROT_DEG.x))
        f = f.rotated(Vector3(0, 1, 0), deg_to_rad(GameConstants.SUN_ROT_DEG.y))
        var d := Vector2(f.x, f.z)
        return d.normalized() if d.length() > 0.001 else Vector2(0.6, -0.8)


## ساخت و چسباندن به واحد (میزبان = UnitBase/EnemyBase با مبدأِ پا)
static func attach(host: Node3D) -> void:
        var d := BlobShadow.new()
        var dia := GameConstants.unit_body_diameter()
        var dir := shadow_dir_xz()
        d.texture_albedo = blob_texture()
        # بیضیِ کشیده در راستای سایه (X بلند) — کمی کج به سمتِ مخالفِ نور
        d.size = Vector3(dia * 2.6, 0.5, dia * 1.9)
        d.position = Vector3(
                        dir.x * dia * GameConstants.BLOB_OFFSET_FRAC,
                        0.02,
                        dir.y * dia * GameConstants.BLOB_OFFSET_FRAC)
        # چرخش تا محورِ بلندِ بیضی هم‌راستای سایه شود
        d.rotation.y = atan2(-dir.y, dir.x)
        d.modulate = Color(GameConstants.BLOB_COLOR.r, GameConstants.BLOB_COLOR.g,
                        GameConstants.BLOB_COLOR.b, GameConstants.BLOB_OPACITY)
        d.cull_mask = 0x7FFFFFFF   # همه‌ی لایه‌ها — زمینِ زیر پا همیشه می‌گیرد
        host.add_child(d)
