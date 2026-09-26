extends SceneTree
## کاوشگر متریال — رنگِ پایه/بافتِ هر مدلِ Quaternius (۶R۱۴c)
## اجرا: godot --headless -s scripts/dev/MatProbe.gd

const DIR := "res://assets/models/quaternius/"
const FILES := ["Warrior.gltf", "Ranger.gltf", "Viking_Male.gltf",
                "Knight_Male.gltf", "Soldier_Male.gltf"]


func _init() -> void:
        for f in FILES:
                var ps: PackedScene = load(DIR + f)
                if ps == null:
                        print("MISSING ", f)
                        continue
                var root := ps.instantiate() as Node3D
                print("=== ", f)
                var mis := root.find_children("*", "MeshInstance3D", true, false)
                for mi in mis:
                        var mesh: Mesh = (mi as MeshInstance3D).mesh
                        for s in mesh.get_surface_count():
                                var mat := mesh.surface_get_material(s)
                                if mat is StandardMaterial3D:
                                        var sm := mat as StandardMaterial3D
                                        print("  ", mi.name, " s", s,
                                                        " albedo=", sm.albedo_color,
                                                        " tex=", "YES" if sm.albedo_texture != null else "no",
                                                        " vtx_col=", sm.vertex_color_use_as_albedo)
                root.free()
        quit(0)
