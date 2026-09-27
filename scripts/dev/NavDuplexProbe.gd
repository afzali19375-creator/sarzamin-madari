## پراب ناوبریِ دوبلکس ۶R۱۵ (نسخه‌ی یال‌محور) — FlowField با ماسکِ یال باید
## از تراسِ پایین به سقف فقط از راهِ مسیرِ باریک برسد؛ هیچ عبورِ دیگری مجاز نیست
extends SceneTree

func _init() -> void:
        var gen := WfcIsland.new()
        var fails := 0
        for s in range(1, 13):
                var r: Dictionary = gen.generate(s, 32)
                if r.get("ok", false) != true:
                        continue
                var duplex: Dictionary = r.get("duplex", {})
                if duplex.is_empty():
                        print("seed ", s, ": (no duplex)")
                        continue
                var size: int = r["size"]
                var levels: PackedInt32Array = r["levels"]
                var w: PackedByteArray = r["walkable"]
                var tops: PackedFloat32Array = r["tops"]
                # --- ماسکِ یال (همان الگوریتم IslandTest — گره‌ها باز می‌مانند) ---
                var edge := PackedInt32Array()
                edge.resize(size * size)
                edge.fill(15)
                var cuts := 0
                for y in size:
                        for x in size:
                                var a := Vector2i(x, y)
                                if w[a.y * size + a.x] == 0:
                                        continue
                                var la := levels[a.y * size + a.x]
                                for d in [Vector2i(1, 0), Vector2i(0, 1)]:
                                        var nb: Vector2i = a + d
                                        if nb.x >= size or nb.y >= size:
                                                continue
                                        if w[nb.y * size + nb.x] == 0:
                                                continue
                                        var lb := levels[nb.y * size + nb.x]
                                        if la == 2 and lb == 2:
                                                continue
                                        var diff := absf(tops[a.y * size + a.x]
                                                        - tops[nb.y * size + nb.x])
                                        if diff > 0.55:
                                                # قطعِ دوطرفه (شبیه‌سازیِ NavGrid.cut_edge)
                                                var bits := [[1, 2], [4, 8]]
                                                var bi := 0 if d == Vector2i(1, 0) else 1
                                                edge[a.y * size + a.x] &= ~bits[bi][0]
                                                edge[nb.y * size + nb.x] &= ~bits[bi][1]
                                                cuts += 1
                # --- FlowField از یک سلولِ پایینی به یک سلولِ سقفی ---
                var upper_cell := Vector2i(-1, -1)
                var lower_cell := Vector2i(-1, -1)
                for y in size:
                        for x in size:
                                var i2 := y * size + x
                                if w[i2] == 0:
                                        continue
                                if levels[i2] == 1 and upper_cell == Vector2i(-1, -1):
                                        upper_cell = Vector2i(x, y)
                                if levels[i2] == 0 and lower_cell == Vector2i(-1, -1):
                                        lower_cell = Vector2i(x, y)
                var ff := FlowField.new()
                ff.setup(size, size)
                ff.compute(size, size, w, lower_cell, PackedFloat32Array(), edge,
                                levels)
                # سقف باید از دهانه‌ی پایین «از راهِ مسیر» قابل‌دسترس باشد
                var reach_ramp := 0
                var ramp_cells: PackedInt32Array = duplex["path_cells"]
                for rc in ramp_cells:
                        if ff.integration[rc] < FlowField.INF_COST:
                                reach_ramp += 1
                var ok_upper: bool = ff.integration[upper_cell.y * size
                                + upper_cell.x] < FlowField.INF_COST
                # هیچ یالِ بازِ پرتگاهی نمانده باشد؟ (سلولِ پایینیِ همسایه‌ی سقف
                # با اختلافِ بلند باید یالش قطع شده باشد)
                var bad_cross := 0
                for y in size:
                        for x in size:
                                var i3 := y * size + x
                                if w[i3] == 0 or levels[i3] != 0:
                                        continue
                                for d in [Vector2i(1, 0), Vector2i(-1, 0),
                                                Vector2i(0, 1), Vector2i(0, -1)]:
                                        var nb2: Vector2i = Vector2i(x, y) + d
                                        if nb2.x < 0 or nb2.y < 0 or nb2.x >= size \
                                                        or nb2.y >= size:
                                                continue
                                        var ni3 := nb2.y * size + nb2.x
                                        if w[ni3] == 0 or levels[ni3] != 1:
                                                continue
                                        if absf(tops[i3] - tops[ni3]) > 0.55:
                                                var m := edge[i3]
                                                var bit := 0
                                                if d == Vector2i(1, 0):
                                                        bit = 1
                                                elif d == Vector2i(-1, 0):
                                                        bit = 2
                                                elif d == Vector2i(0, 1):
                                                        bit = 4
                                                else:
                                                        bit = 8
                                                if (m & bit) != 0:
                                                        bad_cross += 1
                var pass_ok := ok_upper and reach_ramp >= 4 and bad_cross == 0
                if not pass_ok:
                        fails += 1
                print("seed ", s, " cuts=", cuts,
                                " upper_reachable=", ok_upper,
                                " ramp_reach=", reach_ramp, "/",
                                ramp_cells.size(),
                                " bad_edges=", bad_cross,
                                " -> ", "OK" if pass_ok else "FAIL")
        print("[PROBE] nav duplex fails: ", fails, "/12")
        quit(0)
