class_name ArcherUnit
extends UnitBase
## کماندار — پشتیبان (سند طراحی §۵):
##   «رگبار قاره‌ای؛ آسیب دوستانه ندارد، مسیر شلیک باز می‌خواهد»
##
## لایه ۳ — واکنش نبرد (گام ۵، روی کوله‌ی تمرین):
##   * فقط در ایست شلیک می‌کند
##   * برد ARCHER_RANGE + مسیر باز (has_clear_shot) + بدون هم‌رزمی در کریدور
##   * خنک‌شدن ARCHER_COOLDOWN؛ تیر بالستیک (ArrowProjectile)
## بصری: کاراکتر Rogue_Hooded پک KayKit (کاتاپولت دوشیِ داخل اسکلت) + تیردانِ
## پشت + تیرِ شناور هنگام هدف‌گیری (گام ۶R11 — کمانِ پروسیجرال پنهان شد)

var _nock: MeshInstance3D       # تیرِ روی کمان هنگام هدف‌گیری
var shots_fired := 0            # برای تست خودکار


func _default_hp() -> int:
        return GameConstants.PLAYER_HP_ARCHER


func _model_kind() -> StringName:
        return &"ranger"


func _build_gear() -> void:
        # ۶R۲۶ — کمان و تیردان داخلِ مدلِ پروسیجرالِ کماندار ساخته می‌شوند؛
        # فقط «تیرِ نُک» (نشانگرِ کشیدنِ کمان هنگام هدف‌گیری) اینجا می‌ماند
        _nock = MeshInstance3D.new()
        var nm := BoxMesh.new()
        nm.size = Vector3(0.02, 0.02, 0.4)
        _nock.mesh = nm
        _nock.position = Vector3(0.05, 0.5, 0.22)
        var nmat := StandardMaterial3D.new()
        nmat.albedo_color = GameConstants.COL_BEACH_SAND
        _nock.material_override = nmat
        _nock.visible = false
        add_child(_nock)


func _scan_radius() -> float:
        # کماندار باید هدف را در «برد شلیک» ببیند، نه فقط در شعاع توجه پیاده
        return maxf(GameConstants.AGGRO_RADIUS, GameConstants.ARCHER_RANGE + 0.5)


func _combat_wants(_hostile: Node3D) -> bool:
        # کماندار فقط در ایست شلیک می‌کند (رگبار قاره‌ای از جای ثابت)
        return _arrived


func _combat_tick(delta: float, hostile: Node3D) -> void:
        # رو به دشمن
        var d := hostile.global_position - global_position
        var face := atan2(d.x, d.z)
        var diff := wrapf(face - _heading, -PI, PI)
        _heading = wrapf(_heading + clampf(diff, -GameConstants.ROTATE_SPEED_RAD * delta,
                        GameConstants.ROTATE_SPEED_RAD * delta), -PI, PI)
        rotation.y = _heading

        _shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)
        if _shoot_cooldown > 0.0:
                # گام ۶R16 — در مسیرِ ۲بعدی تیرِ سه‌بعدیِ شناور مخفی می‌ماند
                _nock.visible = not GameConstants.UNITS_2D  # در حال کمان‌کشیدن
                return

        var from_xz := Vector2(global_position.x, global_position.z)
        var to_xz := Vector2(hostile.global_position.x, hostile.global_position.z)
        var dist := from_xz.distance_to(to_xz)
        if dist > GameConstants.ARCHER_RANGE:
                return
        if not has_clear_shot(from_xz, global_position.y + 0.5,
                        to_xz, hostile.global_position.y + 0.4):
                return  # مسیر شلیک بسته است (تپه/قله)
        if friendly_in_corridor(to_xz):
                return  # قانون: آسیب دوستانه ندارد — نگه!

        _shoot_cooldown = GameConstants.ARCHER_COOLDOWN
        _nock.visible = false
        shots_fired += 1
        # گام ۶R2 — shooter پاس می‌شود تا مهاجمِ تیرخورده به «این کماندار» تلافی کند
        ArrowProjectile.fire(get_parent(), global_position + Vector3(0, 0.5, 0),
                        hostile.global_position + Vector3(0, 0.4, 0),
                        ground_provider, self)


func _combat_end() -> void:
        _nock.visible = false
        _shoot_cooldown = 0.0
