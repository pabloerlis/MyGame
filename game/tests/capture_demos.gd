extends SceneTree
## Render actual laboratory frames using the same renderer and assets as CI.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("LAB_CAPTURE_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Missing capture directory")
		quit(1)
		return
	var packed := load("res://lab/lab_room.tscn") as PackedScene
	var lab = packed.instantiate()
	root.add_child(lab)
	await process_frame
	var requested := ["pistol_idle", "pistol_shoot", "pistol_reload", "sword_attack", "bow_shoot", "treechopping", "push", "sitting_idle", "climbup_1m"]
	var manifest: Array = []
	for key in requested:
		var index := -1
		for i in range(lab.demo_entries.size()):
			var name := str(lab.demo_entries[i]["clip"]).get_file().to_lower()
			if name == key or name.begins_with(key + "_"):
				index = i
				break
		if index < 0:
			continue
		lab._choose_demo_gallery(index)
		for phase in [0.25, 0.65]:
			lab._seek_phase(phase)
			for frame in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if image == null or image.is_empty():
				push_error("Empty rendered frame")
				quit(1)
				return
			var filename := "%s-%02d.png" % [key, int(phase * 100)]
			if image.save_png(output.path_join(filename)) != OK:
				push_error("Capture failed")
				quit(1)
				return
			var entry: Dictionary = lab._review_entry()
			entry["file"] = filename
			entry["validation"] = "rendered_unreviewed"
			manifest.append(entry)
	if manifest.size() < 8:
		push_error("Insufficient demonstration screenshots")
		quit(1)
		return
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("CAPTURE_OK: ", manifest.size(), " rendered frames (not visual approval)")
	quit(0)
