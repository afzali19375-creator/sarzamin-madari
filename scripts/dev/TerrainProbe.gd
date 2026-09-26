extends SceneTree
## پراب مشِ زمین — چند مثلثِ واقعاً در مش است؟ AABB؟ ارتفاع گوشه‌ها؟

func _init() -> void:
        call_deferred("_run")

func _run() -> void:
        await process_frame
        var wfc := WfcIsland.new()
        var isl: Dictionary = wfc.generate(20260924)
        print("PROBE island ok=", isl.get("ok"), " size=", isl.get("size"),
                        " land=", isl.get("land_count"),
                        " walk=", isl.get("walkable_count"))
        var ground := IslandGround.new()
        var cell := 1.0
        var origin := Vector2(-15, -15)
        ground.build(isl, cell, origin)
        var tm: MeshInstance3D = ground._terrain_mesh
        var mesh: Mesh = tm.mesh
        var faces := mesh.get_faces()
        print("PROBE terrain surfaces=", mesh.get_surface_count(),
                        " faces=", faces.size() / 3)
        var aabb := mesh.get_aabb()
        print("PROBE terrain aabb=", aabb)
        # چند نمونه‌ی ارتفاع گوشه
        var n1: int = int(isl["size"]) + 1
        print("PROBE corner(0,0)=", ground.corner_height(0, 0),
                        " corner(15,15)=", ground.corner_height(15, 15),
                        " corner(8,8)=", ground.corner_height(8, 8))
        # شمارش مثلث‌های بالای سطح (y بزرگ‌ترین مؤلفه)
        var up_tris := 0
        var below_sea := 0
        for t in range(0, faces.size(), 3):
                var a := faces[t]
                var b := faces[t + 1]
                var c := faces[t + 2]
                var n := (b - a).cross(c - a)
                if n.y > 0.5:
                        up_tris += 1
                if a.y < -0.15 and b.y < -0.15 and c.y < -0.15:
                        below_sea += 1
        print("PROBE up_tris=", up_tris, " below_sea_tris=", below_sea)
        # توزیع ارتفاع رأس‌ها
        var hist := {"<-0.1": 0, "-0.1..0.3": 0, "0.3..0.8": 0, ">0.8": 0}
        for v in faces:
                if v.y < -0.1:
                        hist["<-0.1"] += 1
                elif v.y < 0.3:
                        hist["-0.1..0.3"] += 1
                elif v.y < 0.8:
                        hist["0.3..0.8"] += 1
                else:
                        hist[">0.8"] += 1
        print("PROBE vert_y_hist=", hist)
        quit(0)
