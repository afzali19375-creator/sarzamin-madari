## پراب سریع دوبلکس ۶R۱۵ — تولید جزیره + چکِ دو سطح و مسیر (بدون رندر)
extends SceneTree

func _init() -> void:
        var gen := WfcIsland.new()
        var ok_duplex := 0
        for s in range(1, 13):
                var r: Dictionary = gen.generate(s, 32)
                if r.get("ok", false) != true:
                        print("seed ", s, " FAIL stats=", r.get("stats", {}))
                        continue
                var duplex: Dictionary = r.get("duplex", {})
                var ups := 0
                var ramps := 0
                if duplex.has("levels"):
                        for lv in duplex["levels"]:
                                if lv == 1:
                                        ups += 1
                                elif lv == 2:
                                        ramps += 1
                if not duplex.is_empty():
                        ok_duplex += 1
                print("seed ", s, " walk=", r["walkable_count"],
                                " upper=", ups, " ramp=", ramps,
                                " axis=", duplex.get("axis", "-"),
                                " len=%.1f" % float(duplex.get("len", 0.0)),
                                " low=%.2f" % float(duplex.get("low_top", 0.0)))
        print("[PROBE] duplex islands: ", ok_duplex, "/12")
        quit(0)
