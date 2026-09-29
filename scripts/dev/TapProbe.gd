extends Node
## پراب تشخیصی ۶R۲۵ — کدام فیلترِ انتخابِ سلولِ فاز ۴ فرو ریخته؟
## اجرا: godot --headless --path . res://scenes/dev/IslandTest.tscn -- --tapprobe

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _t := 0.0
var _stage := 0
var _scene: Node


func _process(delta: float) -> void:
        _t += delta
        if _stage == 0 and _t >= 2.0:
                _scene._target_size = 9.0   # همان زومی که فاز ۳ تست می‌کند
        if _stage == 0 and _t >= 5.0:
                _stage = 1
                _run()


func _run() -> void:
        var nav: NavGrid = PathService.nav
        var start := nav.world_to_cell(PathService.goal_world())
        var depths := {}
        var q: Array[Vector2i] = [start]
        depths[start] = 0
        var head := 0
        while head < q.size():
                var c: Vector2i = q[head]
                head += 1
                for d in DIRS:
                        var n2: Vector2i = c + d
                        if nav.is_walkable(n2) and not depths.has(n2):
                                depths[n2] = int(depths[c]) + 1
                                q.append(n2)
        var entries: Array = []
        for i in _scene.cmd_grid.cell_count:
                var info: Dictionary = _scene.cmd_grid.cell_info(i)
                var center: Vector2 = info["center"]
                var cc: Vector2i = nav.world_to_cell(center)
                if depths.has(cc):
                        entries.append([i, int(depths[cc]), center])
        var cam: Camera3D = _scene.get_viewport().get_camera_3d()
        var clean := 0
        var reasons := {"house": 0, "ray": 0, "px": 0}
        var worst_px := 1e9
        var worst_cell := Vector2.INF
        for e in entries:
                var center: Vector2 = e[2]
                if _scene._alive_house_near(center) != null:
                        reasons["house"] += 1
                        continue
                if not _click_lands_on(center):
                        reasons["ray"] += 1
                        continue
                var click_sp: Vector2 = _screen_of(Vector3(center.x,
                                _scene.ground.height_at_world(center) + 0.1, center.y))
                var min_px := 1e9
                for u in _scene.squad:
                        var wp: Vector3 = (u as Node3D).global_position + Vector3(0, 0.35, 0)
                        if cam.is_position_behind(wp):
                                continue
                        min_px = minf(min_px, cam.unproject_position(wp).distance_to(click_sp))
                if min_px > 70.0:
                        clean += 1
                else:
                        reasons["px"] += 1
                if min_px < worst_px:
                        worst_px = min_px
                        worst_cell = center
        print("[TAPPROBE] entries=%d clean=%d reasons=%s worst_px=%.0f @%s posts=%s"
                        % [entries.size(), clean, str(reasons), worst_px, str(worst_cell),
                        str(_scene._squad_posts)])
        get_tree().quit(0)


func _screen_of(world: Vector3) -> Vector2:
        var cam: Camera3D = _scene.get_viewport().get_camera_3d()
        return cam.unproject_position(world)


func _click_lands_on(center: Vector2) -> bool:
        var cam: Camera3D = _scene.get_viewport().get_camera_3d()
        if cam == null:
                return true
        var sp := _screen_of(Vector3(center.x,
                        _scene.ground.height_at_world(center) + 0.1, center.y))
        var hit: Dictionary = _scene.ground.ray_pick(cam, sp)
        if not bool(hit.get("in_island", false)):
                return false
        var nav: NavGrid = PathService.nav
        var hxz: Vector2 = nav.cell_center(hit["cell"])
        var info: Dictionary = _scene.cmd_grid.cell_at_world(hxz)
        if not bool(info.get("ok", false)):
                return false
        return (info["center"] as Vector2).distance_to(center) <= 0.9
