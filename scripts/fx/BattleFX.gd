class_name BattleFX
extends RefCounted
## گام ۶R9 — جلوه‌های صحنه‌ی نبرد (بازخورد کاربر: «خون ریزی بشه»):
##   * blood_burst — پاشش ذرات خون در لحظه‌ی ضربه (CPUParticles3D one-shot)
##   * blood_stain — لکه‌ی خونِ دائمی روی زمین در جای افتادن (حافظه‌ی میدان جنگ)
##   * play_sfx   — صدای سنتزشده (بدون فایل صوتی): برخورد و افتادن
##
## همه‌ی توابع استاتیک‌اند؛ مالکِ نودها صحنه است. خونِ سربازانِ خودی سرخِ
## تیره و خونِ شبح‌ها بنفشِ ژرف است — هر دو «خون» خوانا روی چمن پاستلی.

const HIT_SFX_RATE := 22050          # نرخ نمونه‌برداری صدای سنتزشده
## سقف لکه‌های خون هم‌زمان — قدیمی‌ها محو می‌شوند (ضد انباشت در جنگ‌های طولانی)
## گام ۶R۱۳ — ۴۰ (بازخورد: «خون‌ها مسخره‌اند» — میدانِ سیاهِ لکه نشود)
const STAIN_CAP := 40

static var _stains: Array = []       # FIFO لکه‌ها — فقط آخرین STAIN_CAP می‌ماند
static var _sfx_cache := {}
static var _sfx_played := 0


## پاشش خون در نقطه‌ی برخورد — dir جهت ضربه است (صفر = پاشش عمودی)
## گام ۶R۱۳ — بازخورد کاربر: «خون‌ها مسخره‌تر از همه» — پاششِ ۲۲ ذره‌ایِ
## بزرگِ ۶R۱۲ به پفِ کوچکِ ۹ ذره‌ایِ کوتاه تبدیل شد؛ لکه هم ریز و کم‌رنگ است
static func blood_burst(host: Node, at: Vector3, dir: Vector3, col: Color) -> void:
        if host == null or not host.is_inside_tree():
                return
        var p := CPUParticles3D.new()
        p.add_to_group("blood_burst")
        p.one_shot = true
        p.explosiveness = 1.0
        p.amount = 9
        p.lifetime = 0.45
        p.direction = Vector3(dir.x, 0.5, dir.z) if dir.length() > 0.01 \
                        else Vector3.UP
        p.spread = 40.0
        p.initial_velocity_min = 1.0
        p.initial_velocity_max = 1.9
        p.gravity = Vector3(0.0, -8.0, 0.0)
        p.scale_amount_min = 0.55
        p.scale_amount_max = 1.1
        var sm := SphereMesh.new()
        sm.radius = 0.03
        sm.height = 0.06
        sm.radial_segments = 6
        sm.rings = 3
        p.mesh = sm
        var m := StandardMaterial3D.new()
        m.albedo_color = col
        m.roughness = 0.4
        m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
        p.material_override = m
        host.add_child(p)
        p.global_position = at
        p.emitting = true
        var tw := p.create_tween()
        tw.tween_interval(0.85)
        tw.tween_callback(p.queue_free)


## لکه‌ی خون دائمی روی زمین — دیسکِ تختِ تیره با اندازه/تیرگیِ کمی متفاوت
static func blood_stain(host: Node, xz: Vector2, ground_y: float,
                col: Color) -> void:
        if host == null or not host.is_inside_tree():
                return
        var s := MeshInstance3D.new()
        s.add_to_group("blood_stain")
        var cm := CylinderMesh.new()
        # گام ۶R۱۳ — لکه‌ی ریز و کم‌رنگ (قبلاً دیسکِ ۰٫۳-۰٫۵mِ نپاخ ۸۵٪ بود)
        cm.top_radius = 0.14 + randf() * 0.08
        cm.bottom_radius = cm.top_radius
        cm.height = 0.012
        cm.radial_segments = 12
        s.mesh = cm
        var m := StandardMaterial3D.new()
        var c := col.darkened(randf() * 0.2)
        c.a = 0.42
        m.albedo_color = c
        m.roughness = 0.65
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        s.material_override = m
        host.add_child(s)
        s.global_position = Vector3(xz.x + randf_range(-0.08, 0.08),
                        ground_y + 0.018, xz.y + randf_range(-0.08, 0.08))
        _stains.append(s)
        while _stains.size() > STAIN_CAP:
                var old = _stains.pop_front()
                if is_instance_valid(old):
                        _fade_free_stain(old)


## محوِ نرم قدیمی‌ترین لکه — ناگهان‌ناپدیدی ندارد
static func _fade_free_stain(s: MeshInstance3D) -> void:
        var mat := s.material_override as StandardMaterial3D
        if mat == null:
                s.queue_free()
                return
        var tw := s.create_tween()
        tw.tween_property(mat, "albedo_color:a", 0.0, 2.5)
        tw.tween_callback(s.queue_free)


## خالی‌کردن رجیستری (بازتولید جزیره) — نودها با ریشه‌ی FX آزاد می‌شوند
static func reset_stains() -> void:
        _stains.clear()


## صدای سنتزشده — «hit» برخورد کوتاه، «fall» افتادنِ بم‌شونده
static func play_sfx(tree: SceneTree, kind: StringName, volume_db := -8.0) -> void:
        if tree == null or tree.root == null:
                return
        var stream := _stream_for(kind)
        if stream == null:
                return
        var pl := AudioStreamPlayer.new()
        pl.stream = stream
        pl.volume_db = volume_db
        tree.root.add_child(pl)
        pl.play()
        _sfx_played += 1
        pl.finished.connect(pl.queue_free)


static func played_count() -> int:
        return _sfx_played


## ساخت/کشِ استریم‌ها — یک بار برای هر نوع
static func _stream_for(kind: StringName) -> AudioStreamWAV:
        if _sfx_cache.has(kind):
                return _sfx_cache[kind]
        var samples := PackedFloat32Array()
        if kind == &"hit":
                # برخورد: نویز کوتاه + تپِ بم ۱۷۰ هرتز با افت نمایی تند
                var n := int(0.1 * HIT_SFX_RATE)
                for i in n:
                        var t := float(i) / HIT_SFX_RATE
                        var env := exp(-t * 42.0)
                        samples.append((randf() * 2.0 - 1.0) * 0.5 * env
                                        + sin(TAU * 170.0 * t) * 0.5 * env)
        elif kind == &"fall":
                # افتادن: گلیساندوی بم‌شونده ۲۹۰→۹۵ هرتز، ملایم
                var n2 := int(0.42 * HIT_SFX_RATE)
                for i in n2:
                        var t2 := float(i) / HIT_SFX_RATE
                        var env2 := exp(-t2 * 7.0)
                        var f := lerpf(290.0, 95.0, t2 * t2)
                        samples.append(sin(TAU * f * t2) * 0.42 * env2)
        else:
                return null
        var bytes := PackedByteArray()
        bytes.resize(samples.size() * 2)
        for i in samples.size():
                var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
                bytes.encode_s16(i * 2, v)
        var wav := AudioStreamWAV.new()
        wav.format = AudioStreamWAV.FORMAT_16_BITS
        wav.mix_rate = HIT_SFX_RATE
        wav.stereo = false
        wav.data = bytes
        _sfx_cache[kind] = wav
        return wav
