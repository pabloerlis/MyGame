extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://lab/lab_room.tscn") as PackedScene
	if packed == null:
		quit(1)
		return
	var lab = packed.instantiate()
	root.add_child(lab)
	await process_frame
	if lab.records.size() < 2:
		push_error("Expected both animation libraries")
		quit(1)
		return
	var count := 0
	var packs := {}
	for i in range(lab.records.size()):
		lab._load_scene(i)
		if lab.player == null or lab.clips.is_empty():
			push_error("Scene has no imported animation: " + str(i))
			quit(1)
			return
		packs[lab.records[i]["pack"]] = true
		for j in range(lab.clips.size()):
			lab._select_clip(j)
			var animation: Animation = lab.player.get_animation(lab.selected_clip)
			if animation == null or animation.get_track_count() == 0:
				push_error("Missing clip tracks")
				quit(1)
				return
			count += 1
		await process_frame
	if packs.size() != 2:
		quit(1)
		return
	print("SMOKE_OK: ", packs.size(), " packs; ", count, " imported clip variants.")
	quit(0)
