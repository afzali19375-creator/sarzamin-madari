extends SceneTree
## دیباگ گام ۴ — چرا seed 606 همیشه «تکه‌تکه» است؟ نقشه‌ی ASCII تلاش‌ها
## اجرا: godot --headless --path . --script res://scripts/dev/WfcDebug2.gd

func _init() -> void:
	var gen := WfcIsland.new()
	var rng := RandomNumberGenerator.new()
	for attempt in range(1, 7):
		rng.seed = hash("606:%d" % attempt)
		gen._phase1 = rng.randf() * TAU
		gen._phase2 = rng.randf() * TAU
		gen._radius0 = 0.56 + rng.randf() * 0.10
		var grid: PackedInt32Array = gen._attempt(rng)
		if grid.is_empty():
			print("attempt %d: CONTRADICTION" % attempt)
			continue
		var packed: Dictionary = gen._package(grid, 606, attempt, Time.get_ticks_usec())
		var size := 32
		print("attempt %d: reason=%s radius0=%.2f" % [attempt, packed.get("reason", "OK"), gen._radius0])
		var lines := PackedStringArray()
		for y in size:
			var line := ""
			for x in size:
				var i := y * size + x
				var sock: String = gen._mods[int(grid[i])]["socket"]
				if sock.begins_with("w"):
					line += "~"
				elif gen._mods[int(grid[i])]["walkable"]:
					line += "."
				else:
					line += "R"  # صخره = ناامن
			lines.append(line)
		for l in lines:
			print("  ", l)
	quit(0)
