extends Node
## پرابِ دیباگِ ۶R17 — چرا پلتاست پرتاب نمی‌کند؟
## اسپاون مثل فاز ۱۴ + چاپِ وضعیت هر ثانیه

var _t := 0.0
var _peltast: Node = null
var _host_si := -1
var _spawned := false


func _process(delta: float) -> void:
        _t += delta
        var scene := get_parent()
        if _t < 8.0:
                return
        if not _spawned:
                _spawned = true
                # دسته‌ی زنده‌ی غیرکماندار با بیشترین عضو
                var best_n := 0
                for si in [0, 1, 3, 4]:
                        var n := 0
                        for u in scene.squads[si]:
                                if is_instance_valid(u) and not u.is_dead():
                                        n += 1
                        if n > best_n:
                                best_n = n
                                _host_si = si
                if _host_si < 0:
                        _host_si = 2
                var chost: Vector2 = scene.squad_center(_host_si)
                var nav: NavGrid = PathService.nav
                # سلول فرمان در باند 3.4..4.6 با سقف 4.4 — دقیقاً مثل _point_near_units تست
                var best := Vector2.INF
                var best_err := 1e9
                for i in scene.cmd_grid.cell_count:
                        var info: Dictionary = scene.cmd_grid.cell_info(i)
                        var w: Vector2 = info["center"]
                        var min_u := 1e9
                        for u in scene.squad:
                                if is_instance_valid(u) and not u.is_dead():
                                        min_u = minf(min_u, w.distance_to(Vector2(
                                                        u.global_position.x, u.global_position.z)))
                        if min_u < 3.4 or min_u > 4.6 or min_u > 4.4:
                                continue
                        var err := absf(min_u - 4.0)
                        if err < best_err:
                                best_err = err
                                best = w
                if best == Vector2.INF:
                        # فالبکِ تست: نزدیک‌ترین سلول فرمان به فاصله‌ی 4.0 بدونِ سقف
                        for i in scene.cmd_grid.cell_count:
                                var info2: Dictionary = scene.cmd_grid.cell_info(i)
                                var w2: Vector2 = info2["center"]
                                var min_u2 := 1e9
                                for u2 in scene.squad:
                                        if is_instance_valid(u2) and not u2.is_dead():
                                                min_u2 = minf(min_u2, w2.distance_to(Vector2(
                                                                u2.global_position.x, u2.global_position.z)))
                                var err2 := absf(min_u2 - 4.0)
                                if err2 < best_err:
                                        best_err = err2
                                        best = w2
                print("[PELPROBE] host=", _host_si, " spawn=", best, " err=", best_err)
                _peltast = scene.director.spawn_enemy("peltast", best, -1)
                print("[PELPROBE] spawned=", _peltast != null)
                return
        if _peltast == null or not is_instance_valid(_peltast):
                print("[PELPROBE] t=%.1f peltast INVALID (died/freed)" % _t)
                _peltast = null
                if _t > 25.0:
                        get_tree().quit(0)
                return
        var up := Vector2.INF
        var engaged: Node = _peltast.get("engaged_unit")
        if engaged != null and is_instance_valid(engaged):
                up = Vector2(engaged.global_position.x, engaged.global_position.z)
        var pos := Vector2(_peltast.global_position.x, _peltast.global_position.z)
        var lvl := ""
        if "level" in _peltast:
                lvl = str(_peltast.get("level"))
        print("[PELPROBE] t=%.1f pos=(%.1f,%.1f) y=%.2f engaged=%s d=%.2f hp=%s thrown=%d" % [
                _t, pos.x, pos.y, _peltast.global_position.y,
                str(engaged != null and is_instance_valid(engaged)),
                pos.distance_to(up) if up != Vector2.INF else -1.0,
                str(_peltast.get("hp")), _peltast.get("javelins_thrown")])
        if _t > 25.0:
                get_tree().quit(0)
