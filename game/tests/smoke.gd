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
	var navigation_checks := 0
	for i in range(lab.records.size()):
		lab._load_scene(i)
		if lab.player == null or lab.clips.is_empty():
			push_error("Scene has no imported animation: " + str(i))
			quit(1)
			return
		packs[lab.records[i]["pack"]] = true
		lab.catalog_panel.hide()
		lab._select_clip(0)
		lab.previous_button.pressed.emit()
		if lab.clip_index != lab.clips.size() - 1 or lab.clip_picker.selected != lab.clip_index or lab.selected_clip != StringName(lab.clips[lab.clip_index]):
			push_error("Previous navigation wrap/sync failed")
			quit(1)
			return
		lab.next_button.pressed.emit()
		if lab.clip_index != 0 or lab.clip_picker.selected != 0 or not lab.player.is_playing():
			push_error("Next navigation wrap/replay failed")
			quit(1)
			return
		if not lab.previous_button.is_visible_in_tree() or not lab.next_button.is_visible_in_tree():
			push_error("Transport hidden with catalog")
			quit(1)
			return
		lab.loop_toggle.set_pressed_no_signal(false)
		lab.next_button.pressed.emit()
		if lab.player.get_animation(lab.selected_clip).loop_mode != Animation.LOOP_NONE:
			push_error("One-shot mode not preserved")
			quit(1)
			return
		lab.loop_toggle.set_pressed_no_signal(true)
		lab.previous_button.pressed.emit()
		if lab.player.get_animation(lab.selected_clip).loop_mode != Animation.LOOP_LINEAR:
			push_error("Loop mode not preserved")
			quit(1)
			return
		lab.speed_picker.item_selected.emit(0)
		if not is_equal_approx(lab.player.speed_scale, 0.25):
			push_error("Slow motion failed")
			quit(1)
			return
		lab.speed_picker.item_selected.emit(2)
		if not is_equal_approx(lab.player.speed_scale, 1.0):
			push_error("Normal speed reset failed")
			quit(1)
			return
		navigation_checks += 1
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
	if lab.items.size() != 130:
		push_error("Expected 130 locked RPG and weapon models")
		quit(1)
		return
	var actor_before: Node3D = lab.actor
	var selected_before: StringName = lab.selected_clip
	lab.mode_picker.item_selected.emit(1)
	if not lab.item_mode or lab.actor.visible or lab.item_node == null:
		push_error("Item mode failed")
		quit(1)
		return
	for i in range(lab.items.size()):
		lab._load_item(i)
		if not is_instance_valid(lab.item_node) or lab.item_index != i or lab.item_picker.selected != i:
			push_error("Item import failed: " + str(i))
			quit(1)
			return
		await process_frame
	lab.next_button.pressed.emit()
	if lab.item_index != 0:
		push_error("Item wrap failed")
		quit(1)
		return
	lab.previous_button.pressed.emit()
	if lab.item_index != lab.items.size() - 1:
		push_error("Item reverse wrap failed")
		quit(1)
		return
	lab.mode_picker.item_selected.emit(0)
	if lab.item_mode or lab.item_node != null or lab.actor != actor_before or not lab.actor.visible or lab.selected_clip != selected_before or not lab.player.is_playing():
		push_error("Animation state restoration failed")
		quit(1)
		return
	print("ITEMS_OK: ", lab.items.size(), " models; mode switch, navigation and actor restoration.")
	print("SMOKE_OK: ", packs.size(), " packs; ", count, " imported clip variants.")
	print("TRANSPORT_OK: ", navigation_checks, " scenes; wrap, sync, visibility, playback mode and speed.")
	quit(0)
