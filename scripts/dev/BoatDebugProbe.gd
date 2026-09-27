extends Node
## پرابِ دیباگِ ۶R17 — ناوگان: چرا سربازها پیاده نمی‌شوند؟
## یک موج اسپاون می‌کند و هر ثانیه وضعیت قایق‌ها/سربازها را چاپ می‌کند

var _t := 0.0
var _spawned := false
var _gid := -1


func _process(delta: float) -> void:
	_t += delta
	var scene := get_parent()
	if not _spawned and _t >= 6.0:
		_spawned = true
		_gid = scene.director.spawn_wave()
		print("[BOATPROBE] wave gid=", _gid)
		return
	if not _spawned or _t < 7.0:
		return
	if absf(_t - roundf(_t)) < delta * 0.5 and int(_t) % 2 == 0:
		var g: Dictionary = scene.director.group_info(_gid)
		if g.is_empty():
			print("[BOATPROBE] t=%.0f group gone" % _t)
			if _t > 40.0:
				get_tree().quit(0)
			return
		var fleet: Array = g.get("fleet", [])
		var binfo := ""
		for e in fleet:
			var b = e.get("boat")
			if b == null or not is_instance_valid(b):
				continue
			binfo += " [st=%d riders=%d cells=%d next=%d anchor=(%.1f,%.1f) pos=(%.1f,%.1f)]" % [
				b.state, b.rider_count(), b._disembark_cells.size(), b._next_rider,
				b.anchor_point.x, b.anchor_point.z,
				b.global_position.x, b.global_position.z]
		var rinfo := ""
		var raiders: Array = scene.director.raiders_of(_gid)
		for r in raiders:
			if not is_instance_valid(r):
				continue
			var dts := "INF" if r.disembark_target == Vector2.INF else "set"
			var lts := "INF" if r.last_disembark_target == Vector2.INF else "set"
			rinfo += " [rid=%s dt=%s last=%s pos=(%.1f,%.1f)]" % [
				str(r.riding), dts, lts,
				r.global_position.x, r.global_position.z]
		print("[BOATPROBE] t=%.0f\n  boats:%s\n  raiders:%s" % [_t, binfo, rinfo])
	if _t > 40.0:
		get_tree().quit(0)
