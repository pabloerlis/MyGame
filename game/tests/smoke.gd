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
	lab.profile_path = "user://smoke-grips.cfg"
	if FileAccess.file_exists(lab.profile_path):
		DirAccess.remove_absolute(lab.profile_path)
	lab._load_grip_profiles()
	var equipment_checks := 0
	for i in range(lab.records.size()):
		lab._load_scene(i)
		if lab.skeleton == null or lab.bone_picker.item_count == 0 or lab.equipment_indices.is_empty():
			push_error("Missing real skeleton or equipment catalog")
			quit(1)
			return
		if lab.bone_picker.selected < 0:
			lab.bone_picker.select(0)
		lab.equipment_picker.item_selected.emit(1)
		if lab.attachment == null or lab.grip == null or lab.attachment.get_parent() != lab.skeleton:
			push_error("Equipment attachment failed")
			quit(1)
			return
		var selected_bone: int = lab.bone_picker.get_selected_id()
		if lab.attachment.bone_name != lab.skeleton.get_bone_name(selected_bone):
			push_error("Attachment bone mismatch")
			quit(1)
			return
		lab.axis_picker.select(0)
		lab._adjust_grip(1)
		if not is_equal_approx(lab.grip.position.x, 0.01):
			push_error("Grip translation failed")
			quit(1)
			return
		lab.next_button.pressed.emit()
		if lab.attachment == null or not lab.player.is_playing():
			push_error("Equipment not preserved during playback")
			quit(1)
			return
		lab.equipment_picker.item_selected.emit(0)
		lab.equipment_picker.item_selected.emit(1)
		if lab.grip == null or not is_equal_approx(lab.grip.position.x, 0.01):
			push_error("Grip calibration restore failed")
			quit(1)
			return
		var right_attachment: BoneAttachment3D = lab.attachment
		lab._load_grip_profiles()
		if not lab.grip_profiles.has(lab.active_profile):
			push_error("Persisted profile not loaded")
			quit(1)
			return
		lab._switch_slot(1)
		if lab.bone_picker.selected < 0 or lab.bone_picker.get_selected_id() == selected_bone:
			for b in range(lab.bone_picker.item_count):
				if lab.bone_picker.get_item_id(b) != selected_bone:
					lab.bone_picker.select(b)
					break
		lab.equipment_picker.item_selected.emit(2)
		var left_attachment: BoneAttachment3D = lab.attachment
		if left_attachment == null or left_attachment == right_attachment or left_attachment.bone_name == right_attachment.bone_name or not is_instance_valid(right_attachment):
			push_error("Independent slots failed")
			quit(1)
			return
		lab.axis_picker.select(1)
		lab._adjust_grip(1)
		lab._switch_slot(0)
		if lab.attachment != right_attachment or not is_equal_approx(lab.grip.position.x, 0.01) or not is_equal_approx(lab.grip.position.y, 0.0):
			push_error("Independent slot calibration failed")
			quit(1)
			return
		lab.next_button.pressed.emit()
		if not is_instance_valid(left_attachment) or not is_instance_valid(right_attachment):
			push_error("Dual equipment not retained on animation switch")
			quit(1)
			return
		lab._reset_grip()
		lab.equipment_picker.item_selected.emit(0)
		if lab.attachment != null:
			push_error("Equipment removal failed")
			quit(1)
			return
		lab._switch_slot(1)
		if lab.attachment != left_attachment or not is_equal_approx(lab.grip.position.y, 0.01):
			push_error("Other slot lost after removal")
			quit(1)
			return
		lab._reset_grip()
		lab.equipment_picker.item_selected.emit(0)
		equipment_checks += 1
		await process_frame
	DirAccess.remove_absolute(lab.profile_path)
	print("DUAL_GRIP_OK: ", equipment_checks, " rigs; independent slots and disk round-trip.")
	print("EQUIPMENT_OK: ", equipment_checks, " rigs; attachment, calibration, playback and removal.")
	if lab.context_indices.is_empty():
		push_error("Missing context assets")
		quit(1)
		return
	for i in range(1, lab.context_picker.item_count):
		lab._choose_context(i)
		if not is_instance_valid(lab.context_root) or lab.context_root.get_child_count() != 2 or not lab.context_root.get_child(1) is StaticBody3D:
			push_error("Context missing real model or static collision")
			quit(1)
			return
		lab.context_axis.select(0)
		lab._adjust_context(1)
		if not is_equal_approx(lab.context_root.position.x, 0.05):
			push_error("Context adjustment failed")
			quit(1)
			return
		lab._reset_context()
		await process_frame
	var previous_context: Node3D = lab.context_root
	var body: StaticBody3D = lab.context_root.get_child(1)
	var col: CollisionShape3D = body.get_child(0)
	var box: BoxShape3D = col.shape
	var outside: Vector3 = col.to_global(Vector3(box.size.x * 0.5 + 0.1, 0, 0))
	var surface: Vector3 = col.to_global(Vector3(box.size.x * 0.5, 0, 0))
	if not is_equal_approx(lab._context_gap(outside), 0.1) or not is_zero_approx(lab._context_gap(surface)) or lab._context_gap(col.global_position) >= 0.0:
		push_error("Signed context distance failed")
		quit(1)
		return
	lab._select_clip(0)
	lab._seek_phase(0.5)
	var length: float = lab._clip_length()
	if length <= 0.0 or not is_equal_approx(lab.player.current_animation_position, length * 0.5) or lab.player.is_playing():
		push_error("Phase seek or pause failed")
		quit(1)
		return
	lab._step_time(1)
	if not is_equal_approx(lab.player.current_animation_position, minf(length, length * 0.5 + 1.0 / 60.0)):
		push_error("Time step failed")
		quit(1)
		return
	lab._replay()
	if not lab.player.is_playing():
		push_error("Replay after seek failed")
		quit(1)
		return
	print("INSPECTION_OK: phase, pause, time step and signed box distance.")
	lab.next_button.pressed.emit()
	if lab.context_root != previous_context:
		push_error("Context lost on clip switch")
		quit(1)
		return
	lab._choose_context(0)
	if lab.context_root != null:
		push_error("Context cleanup failed")
		quit(1)
		return
	print("CONTEXT_OK: ", lab.context_indices.size(), " real props with approximate collision.")
	var labels = preload("res://lab/labels_pt.gd")
	var pending_clips := {}
	var pending_bones := {}
	for i in range(lab.records.size()):
		lab._load_scene(i)
		for j in range(lab.clips.size()):
			var original: String = lab.clips[j]
			var translated: String = labels.clip(original, j)
			if "nome pendente" in translated:
				pending_clips[original] = true
			if lab.clip_picker.get_item_text(j) != translated:
				push_error("Localized label mismatch")
				quit(1)
				return
			lab._select_clip(j)
			if lab.selected_clip != StringName(original) or not lab.player.has_animation(lab.selected_clip):
				push_error("Localization changed animation key")
				quit(1)
				return
		for j in range(lab.bone_picker.item_count):
			var id: int = lab.bone_picker.get_item_id(j)
			var original: String = str(lab.skeleton.get_bone_name(id))
			var translated: String = labels.bone(original, id)
			if "nome pendente" in translated:
				pending_bones[original] = true
			if lab.bone_picker.get_item_text(j) != translated:
				push_error("Localized bone mismatch")
				quit(1)
				return
		await process_frame
	for i in range(lab.items.size()):
		if "nome pendente" in labels.item(str(lab.items[i]["name"]), i):
			push_error("Missing item translation")
			quit(1)
			return
	print("LOCALIZATION_OK: 130 item labels; original clip and bone keys preserved.")
	if not pending_clips.is_empty() or not pending_bones.is_empty():
		push_error("Untranslated names: " + str(pending_clips.keys()) + " / " + str(pending_bones.keys()))
		quit(1)
		return
	lab._set_settings(true)
	lab._select_settings_section(1)
	await process_frame
	if not lab.catalog_panel.visible or lab.previous_button.is_visible_in_tree() or not lab.animation_controls.is_visible_in_tree():
		push_error("Separate settings page failed")
		quit(1)
		return
	lab._open_choices(lab.clip_picker, "Movimento")
	if not lab.choice_overlay.visible or lab.choice_list.get_child_count() != lab.clips.size():
		push_error("Full screen picker failed")
		quit(1)
		return
	lab._rebuild_choices("zzzzzzzz")
	if lab.choice_list.get_child_count() != 0:
		push_error("Search filtering failed")
		quit(1)
		return
	lab._rebuild_choices("")
	if lab.choice_list.get_child(0).custom_minimum_size.y < 72:
		push_error("Search rows too small")
		quit(1)
		return
	lab._choose_search_result(0)
	if lab.choice_overlay.visible or lab.clip_index != 0 or lab.selected_clip != StringName(lab.clips[0]):
		push_error("Search selection did not preserve original clip")
		quit(1)
		return
	lab._select_settings_section(0)
	lab._set_mode(1)
	if not lab.section_buttons[1].disabled or lab.settings_section != 0:
		push_error("Item mode section state failed")
		quit(1)
		return
	lab._set_mode(0)
	lab._set_settings(false)
	if lab.catalog_panel.visible or not lab.previous_button.is_visible_in_tree() or not lab.next_button.is_visible_in_tree():
		push_error("Return to room failed")
		quit(1)
		return
	print("UI_OK: separate settings, section navigation, searchable touch rows, selection and return.")
	print("LOCALIZATION_COMPLETE: all imported clips, bones and items.")
	print("ITEMS_OK: ", lab.items.size(), " models; mode switch, navigation and actor restoration.")
	print("SMOKE_OK: ", packs.size(), " packs; ", count, " imported clip variants.")
	print("TRANSPORT_OK: ", navigation_checks, " scenes; wrap, sync, visibility, playback mode and speed.")
	quit(0)
