extends SceneTree
## پراب رندر ۲ — ۶R۱۴c: رنگِ خالصِ vertex هایِ زمین (unshaded = بدونِ نور/مه/سایه)
## اجرا: DISPLAY=:99 godot --path . -s scripts/dev/RenderProbe2.gd

func _init() -> void:
        call_deferred("_run")

func _run() -> void:
        await process_frame
        # تستِ قطعی ۶R۱۴c: پس‌زمینه‌ی سرخابی — اگر نوارهای تیره سرخابی شوند =
        # «چهارضلعیِ غایب» = کانال‌های آبِ WFC داخل جزیره
        get_root().get_world_3d().environment = Environment.new()
        RenderingServer.set_default_clear_color(Color(1, 0, 1))
        var wfc := WfcIsland.new()
        var isl: Dictionary = wfc.generate(20260924)
        var ground := IslandGround.new()
        ground.build(isl, 1.0, Vector2(-16, -16))
        get_root().add_child(ground)
        var cam := Camera3D.new()
        get_root().add_child(cam)
        cam.projection = Camera3D.PROJECTION_ORTHOGONAL
        cam.position = Vector3(0, 30, 0.01)
        cam.rotation_degrees.x = -90
        cam.size = 26.0
        # تستِ سایه‌صفحه: تنها شیءِ باقی‌مانده‌ی غیرِ terrain — اگر حفره‌ها
        # رفتند، مقصر همین است (۶R۱۴c)
        for child in ground.get_children():
                if child != ground._terrain_mesh:
                        child.visible = false
        # متریال unshaded + vertex color = نمایشِ رنگِ خامِ رأس‌ها
        # cull_disabled = آیا راه‌راه‌ها «مثلث‌های حذف‌شده»اند؟ (۶R۱۴c)
        # تستِ آلفا: بدونِ vertex-color — اگر راه‌راه‌ها رفتند، مقصرِ آلفای
        # رأس‌هاست (رنگِ رأس با ALPHA=0 مثلث را نامرئی می‌کند)
        var raw := StandardMaterial3D.new()
        raw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        raw.vertex_color_use_as_albedo = false
        raw.albedo_color = Color(0.3, 0.8, 0.3, 1.0)
        raw.cull_mode = BaseMaterial3D.CULL_DISABLED
        ground._terrain_mesh.material_override = raw
        ground._water.visible = false
        ground._foam.visible = false
        for i in 8:
                await process_frame
        # --- داده‌ی خام ۶R۱۴c: مشِ زمین چند رأس دارد و سلول‌های «حفره‌دار»
        # در داده‌ی WFC چه‌هسته‌اند؟ ---
        var mesh: Mesh = ground._terrain_mesh.mesh
        print("PROBE terrain vertices=", mesh.get_faces().size() / 3)
        var arrays := mesh.surface_get_arrays(0)
        var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
        print("PROBE surface verts=", verts.size(), " cols=", cols.size())
        var bad := 0
        for v in verts:
                if is_nan(v.x) or is_nan(v.y) or is_nan(v.z) \
                                or absf(v.x) > 60.0 or absf(v.z) > 60.0 \
                                or v.y < -3.0 or v.y > 6.0:
                        bad += 1
                        if bad <= 6:
                                print("PROBE BAD VERTEX ", v)
        print("PROBE bad_vertices=", bad)
        # اسکنِ یک خط افقی (z=+2 → ردیفِ میانیِ حفره‌ها): برای هر سلولِ این ردیف
        # وضعیتِ WFC را چاپ کن
        var isl_walk: PackedByteArray = isl["walkable"]
        var isl_mods: PackedInt32Array = isl["modules"]
        var sockets: PackedStringArray = isl["meta_sockets"]
        var size := int(isl["size"])
        var walk_total := 0
        var rock_total := 0
        var water_total := 0
        for cyy in size:
                for cxx in size:
                        var ci2 := cyy * size + cxx
                        var w2 := int(isl_walk[ci2])
                        if w2 == 1:
                                walk_total += 1
                        else:
                                var mi2 := int(isl_mods[ci2])
                                var sock2 := "w"
                                if mi2 >= 0 and mi2 < sockets.size():
                                        sock2 = sockets[mi2]
                                if sock2.begins_with("w"):
                                        water_total += 1
                                else:
                                        rock_total += 1
        print("PROBE totals walk=%d rock=%d water=%d -> quads=%d top_tris=%d" % [
                        walk_total, rock_total, water_total,
                        walk_total + rock_total, (walk_total + rock_total) * 2])
        var cy := 18
        # شمارشِ مثلثِ واقعیِ مش در هر سلولِ ردیفِ ۱۸ (قطعی: کدام سلول‌ها
        # مثلث ندارند؟) — مرکزِ هر مثلث را به سلولِ contained نگه می‌داریم
        var tri_per_cell := {}
        for t in int(verts.size() / 3):
                var c := (verts[t * 3] + verts[t * 3 + 1] + verts[t * 3 + 2]) / 3.0
                var gx := int(floor(c.x + 16.0))   # origin=-16, cell=1
                var gy := int(floor(c.z + 16.0))
                var key := Vector2i(gx, gy)
                tri_per_cell[key] = int(tri_per_cell.get(key, 0)) + 1
        for dump_cy in [13, 14, 18]:
                for cx in size:
                        var ci: int = dump_cy * size + cx
                        var mi := int(isl_mods[ci])
                        var sock := sockets[mi] if mi >= 0 and mi < sockets.size() else "?"
                        var tc := int(tri_per_cell.get(Vector2i(cx, dump_cy), 0))
                        print("PROBE cell(%d,%d) walk=%d sock=%s tris=%d gw=%s" % [
                                        cx, dump_cy, int(isl_walk[ci]), sock, tc,
                                        ground._is_water_module(ci)])
        # رأس‌های کاملِ همه‌ی مثلث‌هایی که مرکزشان در ستون‌های ۸ و ۹ ردیفِ ۱۳ است
        for t in int(verts.size() / 3):
                var c := (verts[t * 3] + verts[t * 3 + 1] + verts[t * 3 + 2]) / 3.0
                var gx := int(floor(c.x + 16.0))
                var gy := int(floor(c.z + 16.0))
                if gy == 13 and (gx == 8 or gx == 9):
                        print("PROBE TRI cell(%d) tri%d: %s | %s | %s" % [gx, t,
                                        verts[t * 3], verts[t * 3 + 1], verts[t * 3 + 2]])
        var img := get_root().get_viewport().get_texture().get_image()
        img.save_png("/tmp/shots_dbg/raw_vertex_colors.png")
        print("PROBE saved raw_vertex_colors.png")
        quit(0)
