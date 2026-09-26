extends SceneTree
## کاوشگر GLB — نام انیمیشن‌ها و قد واقعی هر کاراکتر KayKit
## اجرا: godot --headless -s scripts/dev/GlbProbe.gd

const MODELS := ["Knight.glb", "Barbarian.glb", "Rogue.glb", "Rogue_Hooded.glb"]


func _init() -> void:
        for f in MODELS:
                var path: String = "res://assets/models/kaykit/" + f
                var ps: PackedScene = load(path)
                if ps == null:
                        print("MISSING ", path)
                        continue
                var root := ps.instantiate() as Node3D
                var top := _scan_top(root, Transform3D.IDENTITY)
                var names := []
                var players := root.find_children("*", "AnimationPlayer", true, false)
                if not players.is_empty():
                        var ap := players[0] as AnimationPlayer
                        for a in ap.get_animation_list():
                                names.append(String(a))
                print("=== ", f, "  height=", "%.3f" % top)
                print("  anims: ", ", ".join(names))
                root.free()
        quit(0)


func _scan_top(node: Node3D, xf: Transform3D) -> float:
        var local := xf * node.transform
        var top := 0.0
        if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
                var aabb: AABB = local * (node as MeshInstance3D).mesh.get_aabb()
                top = aabb.end.y
                print("    mesh ", node.name, " aabb_end_y=", "%.3f" % aabb.end.y)
        for c in node.get_children():
                if c is Node3D:
                        top = maxf(top, _scan_top(c as Node3D, local))
        return top
