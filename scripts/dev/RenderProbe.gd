extends SceneTree
## پراب رندر — متریال قرمزِ unshaded روی زمین: آیا همه‌ی مثلث‌ها دیده می‌شوند؟

func _init() -> void:
        call_deferred("_run")

func _run() -> void:
        await process_frame
        var wfc := WfcIsland.new()
        var isl: Dictionary = wfc.generate(20260924)
        var ground := IslandGround.new()
        ground.build(isl, 1.0, Vector2(-16, -16))
        get_root().add_child(ground)
        # نور + دوربین
        var sun := DirectionalLight3D.new()
        sun.rotation_degrees = Vector3(-55, 45, 0)
        get_root().add_child(sun)
        var cam := Camera3D.new()
        get_root().add_child(cam)
        cam.position = Vector3(0, 13, 9)
        cam.rotation_degrees.x = -55
        # متریال قرمزِ بدون نور روی مشِ زمین
        var red := StandardMaterial3D.new()
        red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        red.albedo_color = Color(1, 0, 0)
        ground._terrain_mesh.material_override = red
        # آب/کف خاموش
        ground._water.visible = false
        ground._foam.visible = false
        for i in 8:
            await process_frame
        var img := get_root().get_viewport().get_texture().get_image()
        img.save_png("/tmp/shots_dbg/red_terrain.png")
        print("PROBE saved red_terrain.png")
        quit(0)
