extends SceneTree
## پراب تشخیصی ۶R6 — اسنپ بلوک‌های ورونوی در برابر پیکینگ واقعی دوربین
## اجرا: godot --headless -s scripts/dev/BlockProbe.gd --path .

func _init() -> void:
        # صحنه دستی بالا آورده نمی‌شود؛ به‌جای آن یک Instance از IslandTest می‌سازیم
        var scene: PackedScene = load("res://scenes/dev/IslandTest.tscn")
        var inst = scene.instantiate()
        root.add_child(inst)
        await process_frame
        await process_frame
        await create_timer(2.0).timeout

        var isle = inst
        var cam: Camera3D = isle.get_viewport().get_camera_3d()
        var cmd = isle.cmd_grid
        print("[PROBE] blocks=", cmd.cell_count)
        var bad_nook := 0
        var bad_pick := 0
        for i in cmd.cell_count:
                var info: Dictionary = cmd.cell_info(i)
                var spot: Vector2 = info["center"]
                var bi: Dictionary = cmd.block_at_world(spot)
                if not bool(bi.get("ok", false)):
                        bad_nook += 1
                        print("[PROBE] spot not in block: ", spot)
                var y: float = isle.ground.height_at_world(spot)
                var sp: Vector2 = cam.unproject_position(Vector3(spot.x, y + 0.1, spot.y))
                var hit: Dictionary = isle.ground.ray_pick(cam, sp)
                var ok := bool(hit.get("in_island", false))
                var hxz := Vector2.ZERO
                if ok:
                        var nav = isle.cmd_grid._nav
                        var c: Vector2i = hit["cell"]
                        hxz = nav.cell_center(c)
                var bi2: Dictionary = cmd.block_at_world(hxz) if ok else {}
                if not bool(bi2.get("ok", false)):
                        bad_pick += 1
                        print("[PROBE] pick no-block: spot=", spot, " hit_walkable=",
                                        str(hit.get("walkable", "-")), " hit_cell=",
                                        str(hit.get("cell", "-")), " module=",
                                        str(hit.get("module", "-")))
        print("[PROBE] spot_fail=", bad_nook, " pick_fail=", bad_pick, " / ", cmd.cell_count)
        quit(0)
