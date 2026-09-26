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

var _bow: Node3D
var _quiver: MeshInstance3D
var _nock: MeshInstance3D       # تیرِ روی کمان هنگام هدف‌گیری
var shots_fired := 0            # برای تست خودکار


func _default_hp() -> int:
        return GameConstants.PLAYER_HP_ARCHER


func _model_kind() -> StringName:
        return &"rogue_hooded"


func _build_gear() -> void:
        # گام ۶R11 — کاتاپولت دوشی داخل اسکلت Rogue_Hooded دیده می‌شود؛
        # کمانِ پروسیجرال ۶R9 فقط نگه داشته می‌شود ولی پنهان است (ضدِ تکرار)
        _bow = WeaponLook.bow(0.3)
        _bow.position = Vector3(-0.4, -0.07, 0.02)
        _bow.rotation_degrees = Vector3(0.0, 90.0, 0.0)
        _bow.visible = false
        _hand.add_child(_bow)

        # تیردان پشت (قدِ مدلِ اسکلتی KayKit ≈ ۰٫۹۵m)
        _quiver = MeshInstance3D.new()
        var qm := CylinderMesh.new()
        qm.top_radius = 0.05
        qm.bottom_radius = 0.05
        qm.height = 0.34
        _quiver.mesh = qm
        _quiver.position = Vector3(0.14, 0.55, -0.16)
        _quiver.rotation_degrees.z = 18.0
        var qmat := StandardMaterial3D.new()
        qmat.albedo_color = GameConstants.COL_GOLD
        qmat.roughness = 0.6
        _quiver.material_override = qmat
        add_child(_quiver)

        # تیرِ روی کمان (فقط هنگام هدف‌گیری دیده می‌شود)
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
                _nock.visible = true  # در حال کمان‌کشیدن
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
