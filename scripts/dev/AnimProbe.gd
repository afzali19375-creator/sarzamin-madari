extends SceneTree
## پراب تشخیصی — ژستِ پایانیِ Death (آیا تا آخر هم می‌افتد؟)

func _init() -> void:
        call_deferred("_run")

func _run() -> void:
        await process_frame
        var root_node := Node3D.new()
        get_root().add_child(root_node)
        var kinds := ["Viking_Male", "Warrior"]
        for k in kinds:
                var ps: PackedScene = load("res://assets/models/quaternius/%s.gltf" % k)
                var inst := ps.instantiate() as Node3D
                root_node.add_child(inst)
                var ap: AnimationPlayer = null
                for c in inst.find_children("*", "AnimationPlayer", true, false):
                        ap = c as AnimationPlayer
                var skel: Skeleton3D = null
                for c2 in inst.find_children("*", "Skeleton3D", true, false):
                        skel = c2 as Skeleton3D
                var hip_idx := skel.find_bone("Hips")
                ap.play("Death")
                var t0 := Time.get_ticks_msec()
                while ap.is_playing() and Time.get_ticks_msec() - t0 < 8000:
                        await process_frame
                print("PROBE %s: finished=%s pos=%.2f hips_end_y=%.3f" % [k,
                                ap.is_playing(), ap.current_animation_position,
                                skel.get_bone_global_pose(hip_idx).origin.y])
                root_node.remove_child(inst)
                inst.free()
        print("PROBE DONE")
        quit(0)
