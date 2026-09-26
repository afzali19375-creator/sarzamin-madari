extends SceneTree
## پرابِ چگالیِ آرایش — بیشترین فاصله‌ی زوجیِ اعضای رسیده‌ی هر دسته
## اجرا: godot --headless --path . -s scripts/dev/PackedProbe.gd

var _t := 0.0
var _stage := 0
var _scene: Node
var _samples := 0


func _initialize() -> void:
        var ps: PackedScene = load("res://scenes/dev/IslandTest.tscn")
        _scene = ps.instantiate()
        root.add_child(_scene)


func _process(delta: float) -> bool:
        _t += delta
        if _stage == 0:
                if _t >= 2.0:
                        _scene.regenerate(4242)
                        _stage = 1
                        _t = 0.0
        elif _stage == 1:
                if _t >= 2.0 + _samples * 2.5:
                        _samples += 1
                        var dbg := ""
                        for si in _scene.squads.size():
                                var pts: Array[Vector2] = []
                                for u in _scene.squads[si]:
                                        if is_instance_valid(u) and not u.is_dead() \
                                                        and u.is_arrived():
                                                pts.append(Vector2(
                                                                u.global_position.x,
                                                                u.global_position.z))
                                var mp := 0.0
                                for a in pts.size():
                                        for b in range(a + 1, pts.size()):
                                                mp = maxf(mp, pts[a].distance_to(pts[b]))
                                dbg += " s%d=%.2f(%d)" % [si, mp, pts.size()]
                        print("[PACKED] t=%.1f%s" % [_t, dbg])
                        if _samples >= 4:
                                return true
                _t += 0.0
        return false
