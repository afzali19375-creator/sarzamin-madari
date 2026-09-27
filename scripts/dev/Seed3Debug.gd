## دیباگ بذر ۳ — وضعیت سلول‌های شیب و همسایه‌ها در navw
extends SceneTree

func _init() -> void:
        var gen := WfcIsland.new()
        var r: Dictionary = gen.generate(3, 32)
        var size: int = r["size"]
        var levels: PackedInt32Array = r["levels"]
        var w: PackedByteArray = r["walkable"]
        var tops: PackedFloat32Array = r["tops"]
        var duplex: Dictionary = r["duplex"]
        var navw := PackedByteArray()
        navw.resize(size * size)
        for i in size * size:
                navw[i] = w[i]
        var blocked := {}
        for y in size:
                for x in size:
                        var a := Vector2i(x, y)
                        if w[a.y * size + a.x] == 0:
                                continue
                        var la := levels[a.y * size + a.x]
                        for d in [Vector2i(1, 0), Vector2i(-1, 0),
                                        Vector2i(0, 1), Vector2i(0, -1)]:
                                var nb: Vector2i = a + d
                                if nb.x < 0 or nb.y < 0 or nb.x >= size or nb.y >= size:
                                        continue
                                if w[nb.y * size + nb.x] == 0:
                                        continue
                                var lb := levels[nb.y * size + nb.x]
                                var diff := absf(tops[a.y * size + a.x]
                                                - tops[nb.y * size + nb.x])
                                if diff <= 0.55:
                                        continue
                                if la == 2:
                                        if lb != 2:
                                                blocked[nb] = true
                                elif lb == 2:
                                        blocked[a] = true
                                else:
                                        blocked[a if tops[a.y * size + a.x]
                                                        > tops[nb.y * size + nb.x]
                                                        else nb] = true
        for c in blocked:
                navw[c.y * size + c.x] = 0
        var ramp: PackedInt32Array = duplex["path_cells"]
        # FlowField مثل پراب: هدف = اولین سلولِ سقفیِ قابل‌عبور (اسکن سطری)
        var upper_cell := Vector2i(-1, -1)
        var lower_cell := Vector2i(-1, -1)
        for y in size:
                for x in size:
                        var i2 := y * size + x
                        if navw[i2] == 0:
                                continue
                        if levels[i2] == 1 and upper_cell == Vector2i(-1, -1):
                                upper_cell = Vector2i(x, y)
                        if levels[i2] == 0 and lower_cell == Vector2i(-1, -1):
                                lower_cell = Vector2i(x, y)
        print("upper_cell=", upper_cell, " lower_cell=", lower_cell)
        var ff := FlowField.new()
        ff.setup(size, size)
        ff.compute(size, size, navw, upper_cell)
        for rc in ramp:
                var cx: int = rc % size
                var cy: int = rc / size
                var nb_info := []
                for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                        var n2: Vector2i = Vector2i(cx, cy) + d
                        if n2.x < 0 or n2.y < 0 or n2.x >= size or n2.y >= size:
                                nb_info.append("out")
                                continue
                        var ni: int = n2.y * size + n2.x
                        var wc: String = "w" if navw[ni] == 1 else "x"
                        nb_info.append("L%d%s%.1f" % [levels[ni], wc, tops[ni]])
                print("ramp (", cx, ",", cy, ") L", levels[rc],
                                " navw=", navw[rc], " top=%.2f" % tops[rc],
                                " integ=%.1f" % ff.integration[rc],
                                " nb=", nb_info)
        quit(0)
