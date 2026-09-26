extends SceneTree
## پراب تجربی گارد لایه ۴ — بازسازی فاز ۱۱ زیرفاز ۲:
## جابه‌جایی squads[0][0] به slot+(2.6,1.4) و رصدِ بازگشت
## اجرا: godot --headless -s scripts/dev/GuardProbe.gd

var _t := 0.0
var _stage := 0
var _scene: Node
var _slot := Vector2.ZERO
var _samples := 0


func _initialize() -> void:
        var ps: PackedScene = load("res://scenes/dev/IslandTest.tscn")
        _scene = ps.instantiate()
        root.add_child(_scene)


func _process(delta: float) -> bool:
        _t += delta
        if _stage == 0:
                # همان مسیر تست: بازتولید با بذر ثابت فاز ۷
                if _t >= 2.0:
                        _scene.regenerate(4242)
                        _stage = 1
                        _t = 0.0
        elif _stage == 1:
                if _t >= 8.0:
                        var u0: Node = _scene.squads[0][0]
                        _slot = u0.slot_pos()
                        var nav = root.get_node("PathService").nav
                        print("[PROBE] slot=", _slot, " pos=", _xz(u0),
                                        " arrived=", u0.is_arrived(),
                                        " fidget=", u0.get("_fidget_state"),
                                        " brain=", u0.brain_state())
                        var displaced := _slot + Vector2(2.6, 1.4)
                        var c: Vector2 = nav.cell_center(
                                        nav.world_to_cell(displaced))
                        u0.global_position = Vector3(c.x,
                                        u0.global_position.y, c.y)
                        u0.set("_fidget_state", 0)
                        _stage = 2
                        _t = 0.0
        elif _stage == 2:
                if _t >= _samples * 0.5:
                        _samples += 1
                        var u0: Node = _scene.squads[0][0]
                        var d: float = _xz(u0).distance_to(_slot)
                        print("[PROBE] t=%.1f dist=%.2f arrived=%s fidget=%d brain=%s combat=%s vel=%.2f wf=%s latch=%s stuck=%.2f goal=%s pos=%s" % [
                                        _t, d, u0.is_arrived(),
                                        u0.get("_fidget_state"), u0.brain_state(),
                                        u0.get("_in_combat"),
                                        (u0.get("_vel") as Vector2).length(),
                                        u0.get("_wf_active"),
                                        u0.get("_near_latch"),
                                        u0.get("_stuck_t"),
                                        u0.call("_effective_goal"),
                                        _xz(u0)])
                        if _samples >= 16:
                                return true
        return false


func _xz(n: Node3D) -> Vector2:
        return Vector2(n.global_position.x, n.global_position.z)
