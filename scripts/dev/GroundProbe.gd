class_name GroundProbe
extends RefCounted
## پراب تشخیصیِ «شناوری اسپرایت‌ها» — مقایسه‌ی ارتفاعِ منطقی (height_at_world)
## با ارتفاعِ واقعیِ مثلث‌های مشِ رندرشده در همان نقطه (درون‌یابی باری‌سنتریک).
## اجرا: GROUND_PROBE=1 godot --headless --path . res://scenes/dev/IslandTest.tscn
## (صدا از IslandTest._ready — بعد از تولید جزیره و spawn واحدها)


static func _mesh_height_at(mesh: Mesh, xz: Vector2) -> float:
        for s in mesh.get_surface_count():
                var arrays := mesh.surface_get_arrays(s)
                var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
                if idx.is_empty():
                        continue
                var i := 0
                while i + 2 < idx.size():
                        var a: Vector3 = verts[idx[i]]
                        var b: Vector3 = verts[idx[i + 1]]
                        var c: Vector3 = verts[idx[i + 2]]
                        i += 3
                        var axz := Vector2(a.x, a.z)
                        var v0 := Vector2(b.x, b.z) - axz
                        var v1 := Vector2(c.x, c.z) - axz
                        var v2 := xz - axz
                        var d00 := v0.dot(v0)
                        var d01 := v0.dot(v1)
                        var d11 := v1.dot(v1)
                        var d20 := v2.dot(v0)
                        var d21 := v2.dot(v1)
                        var den := d00 * d11 - d01 * d01
                        if absf(den) < 1e-12:
                                continue
                        var u := (d11 * d20 - d01 * d21) / den
                        var v := (d00 * d21 - d01 * d20) / den
                        if u < -0.002 or v < -0.002 or u + v > 1.002:
                                continue
                        return a.y + u * (b.y - a.y) + v * (c.y - a.y)
        return NAN


static func measure(isle) -> Dictionary:
        ## اندازه‌گیریِ فاصله‌ی ارتفاعِ منطقی از مشِ رندرشده + شکافِ پاهای واحدها
        var ground = isle.ground
        var mesh: Mesh = ground._terrain_mesh.mesh
        var max_unit_gap := 0.0
        var sum := 0.0
        var n := 0
        for u in isle.get_tree().get_nodes_in_group("units"):
                var xz := Vector2(u.global_position.x, u.global_position.z)
                var logic: float = ground.height_at_world(xz)
                var visual := _mesh_height_at(mesh, xz)
                if is_nan(visual):
                        continue
                var d: float = logic - visual
                sum += absf(d)
                n += 1
                max_unit_gap = maxf(max_unit_gap, absf(d))
        var size: int = ground.size
        var origin: Vector2 = ground._origin
        var csize: float = ground._cell
        var bad := 0
        var scanned := 0
        var max_d := 0.0
        for j in range(1, size - 1, 2):
                for i in range(1, size - 1, 2):
                        if not ground.walkable_at(Vector2i(i, j)):
                                continue
                        var xz: Vector2 = origin + Vector2(i, j) * csize
                        var logic2: float = ground.height_at_world(xz)
                        var visual2 := _mesh_height_at(mesh, xz)
                        if is_nan(visual2):
                                continue
                        scanned += 1
                        max_d = maxf(max_d, absf(logic2 - visual2))
                        if absf(logic2 - visual2) > 0.12:
                                bad += 1
        return {"units": n, "avg_gap": sum / maxf(n, 1.0), "max_unit_gap": max_unit_gap,
                        "scanned": scanned, "bad_cells": bad, "max_d": max_d}


static func run(isle) -> void:
        var m := measure(isle)
        print("[GPROBE] units=%d avg_gap=%.3f max_unit_gap=%.3f | cells=%d bad=%d max_d=%.3f"
                        % [m["units"], m["avg_gap"], m["max_unit_gap"],
                        m["scanned"], m["bad_cells"], m["max_d"]])
        if m["bad_cells"] > 0:
                # گزارش جزئیاتِ سلول‌های بد — برای دیباگ
                var ground = isle.ground
                var mesh: Mesh = ground._terrain_mesh.mesh
                var size: int = ground.size
                var origin: Vector2 = ground._origin
                var csize: float = ground._cell
                var reported := 0
                for j in range(1, size - 1, 2):
                        for i in range(1, size - 1, 2):
                                if not ground.walkable_at(Vector2i(i, j)):
                                        continue
                                var xz: Vector2 = origin + Vector2(i, j) * csize
                                var d: float = ground.height_at_world(xz) - _mesh_height_at(mesh, xz)
                                if absf(d) > 0.12 and reported < 12:
                                        reported += 1
                                        print("[GPROBE] CELL %d,%d xz=%.1f,%.1f d=%.3f"
                                                        % [i, j, xz.x, xz.y, d])
        isle.get_tree().quit(0)
