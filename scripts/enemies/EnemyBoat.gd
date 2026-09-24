class_name EnemyBoat
extends Node3D
## قایق بادبانی مهاجمان (§۶): «گروه‌ها با قایق بادبانی می‌آیند؛ قایق برای برگشتن
## لنگر می‌ماند.» — چرخه: SAILING (از دریا) → ANCHORED (پیاده‌شدن مهاجمان، ایست)
## → LEAVING (وقتی همه‌ی مهاجمانش کشته شدند یا غارت تمام شد) → آزادسازی.
##
## بصری (مینیمال ولی واقعی، همه از پالت): بدنه‌ی چوبی #6B4A2E، نوار سرخ پارسی
## روی گلدسته — نه، این قایق «یونانی» است: نوار سرخ COL_CRIMSON، بادبان عاجی
## COL_IVORY، دکل چوبی. تکان‌خوردن ملایم روی موج + کشیدن بادبان هنگام لنگر.

enum BoatState { SAILING, ANCHORED, LEAVING }

signal landed(boat: EnemyBoat)
signal departed(boat: EnemyBoat)

const SEA_Y := -0.18                    # هم‌خوان با IslandGround.SEA_Y
const REACH_EPS := 0.25

var state := BoatState.SAILING
var speed := GameConstants.BOAT_SPEED
var anchor_point: Vector3 = Vector3.ZERO   # نقطه‌ی لنگر (روی آب، کنار ساحل)
var retreat_point: Vector3 = Vector3.ZERO  # نقطه‌ی خروج به دریا

var _t := 0.0
var _heading := 0.0
var _sail: MeshInstance3D
var _sail_yard: MeshInstance3D


func _ready() -> void:
        _t = randf() * TAU
        global_position.y = SEA_Y

        var wood := StandardMaterial3D.new()
        wood.albedo_color = GameConstants.COL_DOOR_WOOD
        wood.roughness = 0.9

        # بدنه — طول در راستای +Z (جلو = +Z، هم‌کنوانسیون با واحدها)
        var hull := MeshInstance3D.new()
        var hm := BoxMesh.new()
        hm.size = Vector3(0.95, 0.42, 2.2)
        hull.mesh = hm
        hull.position.y = 0.16
        hull.material_override = wood
        add_child(hull)

        # نوک‌های خمیده (پیش‌وپس‌سر قایق)
        for z in [-1.0, 1.0]:
                var prow := MeshInstance3D.new()
                var pm := BoxMesh.new()
                pm.size = Vector3(0.6, 0.34, 0.5)
                prow.mesh = pm
                prow.position = Vector3(0.0, 0.28, z * 1.15)
                prow.rotation_degrees.x = -12.0 * z
                prow.material_override = wood
                add_child(prow)

        # نوار سرخ روی بدنه (هویت مهاجم)
        var stripe := MeshInstance3D.new()
        var sm := BoxMesh.new()
        sm.size = Vector3(0.99, 0.1, 2.24)
        stripe.mesh = sm
        stripe.position.y = 0.3
        var cr_mat := StandardMaterial3D.new()
        cr_mat.albedo_color = GameConstants.COL_CRIMSON
        cr_mat.roughness = 0.7
        stripe.material_override = cr_mat
        add_child(stripe)

        # دکل و بازوی بادبان
        var mast := MeshInstance3D.new()
        var mm := CylinderMesh.new()
        mm.top_radius = 0.045
        mm.bottom_radius = 0.06
        mm.height = 1.7
        mast.mesh = mm
        mast.position.y = 1.0
        mast.material_override = wood
        add_child(mast)

        _sail_yard = MeshInstance3D.new()
        var ym := BoxMesh.new()
        ym.size = Vector3(1.5, 0.06, 0.06)
        _sail_yard.mesh = ym
        _sail_yard.position.y = 1.72
        _sail_yard.material_override = wood
        add_child(_sail_yard)

        # بادبان عاجی — جعبه‌ی نازک عمودی (فروکش مستقیم با scale:y)
        _sail = MeshInstance3D.new()
        var plane := BoxMesh.new()
        plane.size = Vector3(1.35, 1.15, 0.02)
        _sail.mesh = plane
        _sail.position.y = 1.1
        var sail_mat := StandardMaterial3D.new()
        sail_mat.albedo_color = GameConstants.COL_IVORY
        sail_mat.roughness = 0.95
        _sail.material_override = sail_mat
        add_child(_sail)


func depart() -> void:
        if state == BoatState.ANCHORED:
                state = BoatState.LEAVING
                # بازکردن بادبان برای بازگشت
                var tw := create_tween()
                tw.tween_property(_sail, "scale:y", 1.0, 0.6)


func _process(delta: float) -> void:
        _t += delta
        # تکان‌خوردن روی موج
        global_position.y = SEA_Y + sin(_t * 1.5) * 0.05
        rotation.z = sin(_t * 1.1) * 0.02

        match state:
                BoatState.SAILING:
                        _sail_toward(anchor_point, delta)
                        if _xz().distance_to(Vector2(anchor_point.x, anchor_point.z)) \
                                        <= REACH_EPS:
                                state = BoatState.ANCHORED
                                _furl_sail()
                                landed.emit(self)
                BoatState.LEAVING:
                        _sail_toward(retreat_point, delta)
                        if _xz().distance_to(Vector2(retreat_point.x, retreat_point.z)) \
                                        <= REACH_EPS:
                                departed.emit(self)
                                queue_free()
                _:
                        pass


func _xz() -> Vector2:
        return Vector2(global_position.x, global_position.z)


func _sail_toward(target: Vector3, delta: float) -> void:
        var tp := Vector2(target.x, target.z)
        var pos := _xz()
        var to := tp - pos
        var dist := to.length()
        var step := speed * delta
        if dist <= step:
                pos = tp
        else:
                pos += to.normalized() * step
        global_position.x = pos.x
        global_position.z = pos.y
        # چرخش نرم به سمت حرکت
        var target_h := atan2(to.x, to.y)
        var diff := wrapf(target_h - _heading, -PI, PI)
        _heading = wrapf(_heading + clampf(diff, -1.2 * delta, 1.2 * delta), -PI, PI)
        rotation.y = _heading


## بادبان کشیدن هنگام لنگر (فروکش به نیمه)
func _furl_sail() -> void:
        var tw := create_tween()
        tw.tween_property(_sail, "scale:y", 0.3, 0.6).set_ease(Tween.EASE_OUT)
        tw.parallel().tween_property(_sail_yard, "position:y", 1.3, 0.6)
