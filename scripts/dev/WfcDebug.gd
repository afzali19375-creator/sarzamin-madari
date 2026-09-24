extends SceneTree
## دیباگ گام ۴ — آمار شکست سولو WFC برای seedهای استرس + ۶۰۶
## اجرا: godot --headless --path . --script res://scripts/dev/WfcDebug.gd

func _init() -> void:
	for s in [101, 202, 303, 404, 505, 606, 707, 808, 777, 20260924]:
		var gen := WfcIsland.new()
		var t0 := Time.get_ticks_usec()
		var r := gen.generate(s, 32)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		if r.get("ok", false) == true:
			print("seed %6d -> OK    attempts=%2d  gen=%.0fms  walk=%d" % [
				s, int(r["attempts"]), ms, int(r["walkable_count"])])
		else:
			print("seed %6d -> FAIL  stats=%s  (%.0fms)" % [s, gen.last_stats, ms])
	quit(0)
