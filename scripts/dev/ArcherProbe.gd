extends SceneTree
## پراب تجربی کماندار + مشعل — بازسازی فاز ۱۰ (کمان) و فاز ۱۷ (مشعل)
## اجرا: godot --headless --path . -s scripts/dev/ArcherProbe.gd

var _t := 0.0
var _stage := 0
var _scene: Node
var _dummy: Node
var _peltast: Node
var _house: Node
var _samples := 0


func _initialize() -> void:
        var ps: PackedScene = load("res://scenes/dev/IslandTest.tscn")
        _scene = ps.instantiate()
        root.add_child(_scene)


func _process(delta: float) -> bool:
        _t += delta
        match _stage:
                0:
                        if _t >= 2.0:
                                _scene.regenerate(4242)
                                _stage = 1
                                _t = 0.0
                1:
                        if _t >= 8.0:
                                _dummy = _scene.spawn_dummy_at_range(2, 6.5)
                                print("[PROBE-A] dummy=", _xz(_dummy),
                                                " shots0=", _scene.arrows_fired_total())
                                _stage = 2
                                _t = 0.0
                                _samples = 0
                2:
                        if _t >= _samples * 2.0:
                                _samples += 1
                                for u in _scene.squads[2]:
                                        if u is ArcherUnit and is_instance_valid(u) \
                                                        and not u.is_dead():
                                                var dxz := _xz(_dummy)
                                                var uxz := _xz(u)
                                                var cshot: bool = u.call("has_clear_shot",
                                                                uxz, u.global_position.y + 0.5,
                                                                dxz, _dummy.global_position.y + 0.4)
                                                var culprit := "-"
                                                if u.call("friendly_in_corridor", dxz):
                                                        var seg := dxz - uxz
                                                        var seg_len := seg.length()
                                                        for n2 in get_nodes_in_group("units"):
                                                                var u2 := n2 as Node3D
                                                                if u2 == null or u2 == u:
                                                                        continue
                                                                var u2p := Vector2(u2.global_position.x,
                                                                                u2.global_position.z)
                                                                var t2 := clampf((u2p - uxz).dot(seg)
                                                                                / (seg_len * seg_len), 0.0, 1.0)
                                                                if t2 < 0.3 or t2 > 0.85:
                                                                        continue
                                                                var proj2 := uxz + seg * t2
                                                                if proj2.distance_to(u2p) <= 0.8 \
                                                                                and u2p.distance_to(dxz) > 0.9:
                                                                        culprit = "%s@%s t=%.2f sq=%s" % [
                                                                                        u2.get_class(), u2p, t2,
                                                                                        str(u2.get("squad_id"))]
                                                                        break
                                                print("[PROBE-A] t=%.0f pos=%s d=%.2f arrived=%s brain=%s clear=%s corridor=%s(%s) cd=%.2f shots=%d" % [
                                                                _t, uxz, uxz.distance_to(dxz),
                                                                u.is_arrived(), u.brain_state(),
                                                                cshot,
                                                                u.call("friendly_in_corridor", dxz),
                                                                culprit,
                                                                u.get("_shoot_cooldown"),
                                                                u.get("shots_fired")])
                                if _samples >= 6:
                                        _stage = 3
                                        _t = 0.0
                                        _samples = 0
                3:
                        # فاز ب: مشعل — دورترین خانه از سربازها + پرتابگر انسانی
                        if _t >= 1.0:
                                var best: Node = null
                                var best_d := -1.0
                                for b in _scene.props.buildings:
                                        var bxz := _xz(b)
                                        var min_u := 1e9
                                        for su in _scene.squads:
                                                for uu in su:
                                                        if is_instance_valid(uu) \
                                                                        and not uu.is_dead():
                                                                min_u = minf(min_u,
                                                                                _xz(uu).distance_to(bxz))
                                        if min_u > best_d:
                                                best_d = min_u
                                                best = b
                                _house = best
                                var hxz := _xz(_house)
                                var nav = root.get_node("PathService").nav
                                var near_d := 1e9
                                var near_u := Vector2.ZERO
                                for su in _scene.squads:
                                        for uu in su:
                                                if is_instance_valid(uu) and not uu.is_dead():
                                                        var ud := _xz(uu).distance_to(hxz)
                                                        if ud < near_d:
                                                                near_d = ud
                                                                near_u = _xz(uu)
                                var dir := (hxz - near_u).normalized() \
                                                if near_d > 0.01 else Vector2.RIGHT
                                # همان زنجیره‌ی تازه‌ی تست: ۱۶ جهت × ۲ شعاع با
                                # شرط «خطِ باز تا حاشیه‌ی ۲٫۴ متری خانه»
                                var pp: Vector2 = Vector2.INF
                                var base_ang: float = dir.angle()
                                for rr: float in [3.0, 4.5]:
                                        for k in 16:
                                                var ang2: float = base_ang \
                                                                + TAU * float(k) / 16.0
                                                var cand := hxz + Vector2(cos(ang2),
                                                                sin(ang2)) * rr
                                                var cw: Vector2 = _scene.call(
                                                                "_nearest_walkable_point",
                                                                nav, cand, 1.2)
                                                if cw == Vector2.INF:
                                                        continue
                                                var seg_ok := true
                                                var sd: float = cw.distance_to(hxz)
                                                var steps := maxi(int(sd / 0.3), 2)
                                                var perp: Vector2 = (hxz - cw) \
                                                                .normalized().orthogonal()
                                                for i in range(1, steps + 1):
                                                        var lp: Vector2 = cw.lerp(hxz,
                                                                        float(i) / float(steps))
                                                        if lp.distance_to(hxz) <= 2.4:
                                                                break
                                                        for off in [Vector2.ZERO,
                                                                        perp * 0.35,
                                                                        -perp * 0.35]:
                                                                if not nav.is_walkable(
                                                                                nav.world_to_cell(
                                                                                                lp + off)):
                                                                        seg_ok = false
                                                                        break
                                                        if not seg_ok:
                                                                break
                                                if not seg_ok:
                                                        continue
                                                pp = cw
                                                break
                                        if pp != Vector2.INF:
                                                break
                                if pp == Vector2.INF:
                                        pp = _scene.call("_nearest_walkable_point",
                                                        nav, hxz, 6.0)
                                print("[PROBE-B] house=", hxz, " min_unit_d=%.1f pp=%s" % [
                                                best_d, str(pp)])
                                print("[PROBE-B] cell_size=", nav.cell_size,
                                                " origin=", nav.origin,
                                                " w=", nav.width, " h=", nav.height,
                                                " cell(hxz)=", nav.world_to_cell(hxz),
                                                " walk(hxz-ish)=", nav.is_walkable(nav.world_to_cell(Vector2(10.88, 2.88))),
                                                " walk(11.19,3.19)=", nav.is_walkable(nav.world_to_cell(Vector2(11.19, 3.19))),
                                                " walk(pp)=", nav.is_walkable(nav.world_to_cell(pp)))
                                if pp == Vector2.INF:
                                        print("[PROBE-B] NO SPOT")
                                        return true
                                _peltast = _scene.director.spawn_enemy(
                                                "peltast", pp, -1)
                                if _peltast == null:
                                        print("[PROBE-B] SPAWN FAILED")
                                        return true
                                _peltast.raid_target = hxz
                                _peltast.target_house = _house
                                _stage = 4
                                _t = 0.0
                                _samples = 0
                4:
                        if _t >= _samples * 2.0:
                                _samples += 1
                                var pxz := _xz(_peltast)
                                print("[PROBE-B] t=%.0f pos=%s d_house=%.2f engaged=%s torches=%d hp_house=%s dead=%s" % [
                                                _t, pxz,
                                                pxz.distance_to(_xz(_house)),
                                                _peltast.get("engaged_unit") != null,
                                                _peltast.get("torches_thrown"),
                                                _house.get("hp"), _peltast.get("hp") <= 0])
                                if _samples >= 10 or _house.get("burning"):
                                        print("[PROBE-B] done burning=", _house.get("burning"))
                                        return true
        return false


func _xz(n: Node3D) -> Vector2:
        return Vector2(n.global_position.x, n.global_position.z)
