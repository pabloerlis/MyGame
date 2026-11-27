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
	lab.demo_toggle.button_pressed = false
	lab._clear_all_equipment()
	lab._choose_context(0)
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
	if lab.items.size() != 143:
		push_error("Expected 143 locked models including interaction props")
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
		var right_initial: Vector3 = lab.grip.position
		lab.axis_picker.select(0)
		lab._adjust_grip(1)
		if not is_equal_approx(lab.grip.position.x, right_initial.x + 0.01):
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
		if lab.grip == null or not is_equal_approx(lab.grip.position.x, right_initial.x + 0.01):
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
		var left_initial: Vector3 = lab.grip.position
		lab.axis_picker.select(1)
		lab._adjust_grip(1)
		lab._switch_slot(0)
		if lab.attachment != right_attachment or not is_equal_approx(lab.grip.position.x, right_initial.x + 0.01) or not is_equal_approx(lab.grip.position.y, right_initial.y):
			push_error("Independent slot calibration failed")
			quit(1)
			return
		lab.next_button.pressed.emit()
		if not is_instance_valid(left_attachment) or not is_instance_valid(right_attachment):
			push_error("Dual equipment not retained on animation switch")
			quit(1)
			return
		var scale_anchor: Vector3 = lab.grip.get_meta("fit_anchor", Vector3.ZERO)
		var contact_before: Vector3 = lab.grip.transform * scale_anchor
		lab._set_equipped_scale(125.0)
		if not lab.grip.scale.is_equal_approx(Vector3.ONE * 1.25) or not (lab.grip.transform * scale_anchor).is_equal_approx(contact_before):
			push_error("Equipped object scale failed")
			quit(1)
			return
		lab._reset_grip()
		lab.equipment_picker.item_selected.emit(0)
		if lab.attachment != null:
			push_error("Equipment removal failed")
			quit(1)
			return
		lab._switch_slot(1)
		if lab.attachment != left_attachment or not is_equal_approx(lab.grip.position.y, left_initial.y + 0.01):
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
	var base_size: Vector3 = lab.context_base_size
	var ctx_ui: Dictionary = lab.scale_controls[1]
	ctx_ui["axis"].select(0)
	lab._set_object_scale(200.0, 1)
	if not box.size.is_equal_approx((base_size * 2.0).max(Vector3(0.01, 0.01, 0.01))) or not lab.context_root.get_child(0).scale.is_equal_approx(Vector3.ONE * 2.0):
		push_error("Context uniform scale did not update geometry and collider")
		quit(1)
		return
	ctx_ui["axis"].select(2)
	lab._set_object_scale(150.0, 1)
	var factors := Vector3(2, 1.5, 2)
	if not box.size.is_equal_approx((base_size * factors).max(Vector3(0.01, 0.01, 0.01))) or not is_equal_approx(body.position.y, base_size.y * 0.75):
		push_error("Context independent height scaling failed")
		quit(1)
		return
	var scaled_outside: Vector3 = col.to_global(Vector3(box.size.x * 0.5 + 0.1, 0, 0))
	if not is_equal_approx(lab._context_gap(scaled_outside), 0.1):
		push_error("Scaled contact distance invalid")
		quit(1)
		return
	var same_item: int = lab.context_record_index
	lab._set_mode(1)
	lab._load_item(same_item)
	if not lab.item_pivot.scale.is_equal_approx(factors):
		push_error("Item size not shared with context")
		quit(1)
		return
	lab._reset_object_scale(0)
	if not lab.item_pivot.scale.is_equal_approx(Vector3.ONE) or not box.size.is_equal_approx(base_size.max(Vector3(0.01, 0.01, 0.01))):
		push_error("Original scale reset failed")
		quit(1)
		return
	lab._set_mode(0)
	print("SCALE_OK: uniform, per-axis, collider, contact distance and reset.")
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
	print("LOCALIZATION_OK: 143 item labels; original clip and bone keys preserved.")
	if not pending_clips.is_empty() or not pending_bones.is_empty():
		push_error("Untranslated names: " + str(pending_clips.keys()) + " / " + str(pending_bones.keys()))
		quit(1)
		return
	lab.settings_preferences_path = "user://smoke-interface.cfg"
	lab._set_menu_transparency(75.0)
	lab._save_menu_preferences()
	lab._set_menu_transparency(0.0)
	lab._load_menu_preferences()
	if not is_equal_approx(lab.menu_transparency, 75.0) or not is_equal_approx(lab.catalog_panel.get_theme_stylebox("panel").bg_color.a, 0.25):
		push_error("Menu transparency or persistence failed")
		quit(1)
		return
	if not is_equal_approx(lab.choice_overlay.get_theme_stylebox("panel").bg_color.a, 0.25):
		push_error("Picker transparency failed")
		quit(1)
		return
	lab._set_settings(true)
	if not lab.player.is_playing():
		push_error("Settings stopped live simulation")
		quit(1)
		return
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
	DirAccess.remove_absolute(lab.settings_preferences_path)
	print("TRANSPARENCY_OK: background alpha, disk round-trip and live playback.")
	# Responsive width after actual layout, not just a clipping mask.
	lab._set_settings(true)
	for section in range(6):
		if lab.section_buttons[section].disabled:
			continue
		lab._select_settings_section(section)
		await process_frame
		await process_frame
		var panel_rect: Rect2 = lab.catalog_panel.get_global_rect()
		var view_rect: Rect2 = root.get_visible_rect()
		if panel_rect.end.x > view_rect.end.x + 1.0 or lab.panel.size.x > lab.settings_scroll.size.x + 1.0:
			push_error("Responsive settings width exceeded in section " + str(section))
			quit(1)
			return
	lab._set_settings(false)
	var original_focus: Vector3 = lab.focus
	var original_distance: float = lab.distance
	var original_yaw: float = lab.yaw
	lab._pan_camera(Vector2(40, -25))
	if lab.focus.is_equal_approx(original_focus) or not is_equal_approx(lab.distance, original_distance) or not is_equal_approx(lab.yaw, original_yaw):
		push_error("Camera pan must translate without changing distance or orbit")
		quit(1)
		return
	lab.focus = original_focus
	lab._update_camera()
	lab._open_quick_menu()
	if not lab.quick_panel.visible or lab.hud_nav.visible:
		push_error("Context menu visibility failed")
		quit(1)
		return
	lab.quick_target.select(0)
	lab._rebuild_quick_controls()
	var old_mode: bool = lab.camera_pan_mode
	lab._toggle_camera_gesture()
	if old_mode == lab.camera_pan_mode:
		push_error("Camera drag mode did not toggle")
		quit(1)
		return
	lab._toggle_camera_gesture()
	lab._close_quick_menu()
	lab._set_mode(1)
	await process_frame
	var picker = preload("res://lab/visual_pick.gd")
	var bounds: Rect2 = picker.screen_bounds(lab.item_node, lab.camera)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		push_error("Item selection has no visible bounds")
		quit(1)
		return
	lab._open_target(4)
	if lab.quick_target.get_selected_id() != 4 or not lab.selected_outline.visible:
		push_error("Context selection did not highlight item")
		quit(1)
		return
	await process_frame
	var quick_rect: Rect2 = lab.quick_panel.get_global_rect()
	var screen: Rect2 = root.get_visible_rect()
	if quick_rect.end.x > screen.end.x + 1.0 or quick_rect.end.y > screen.end.y + 1.0 or quick_rect.position.y < 68.0 or lab.quick_review_fields.visible:
		push_error("Context overlay bounds or compact review separation failed")
		quit(1)
		return
	var old_dock: bool = lab.quick_dock_top
	lab._flip_quick_dock()
	if lab.quick_dock_top == old_dock:
		push_error("Context dock toggle failed")
		quit(1)
		return
	lab._select_quick_page(2)
	if not lab.quick_review_fields.visible:
		push_error("Context review tab did not open")
		quit(1)
		return
	lab._select_quick_page(0)
	if lab.quick_review_fields.visible or not is_instance_valid(lab.quick_axis):
		push_error("Context transform tab did not restore")
		quit(1)
		return
	var original: Transform3D = lab.item_node.transform
	lab.quick_axis.select(0)
	lab._quick_nudge(4, lab.quick_axis, 1)
	lab.quick_axis.select(4)
	lab._quick_nudge(4, lab.quick_axis, 1)
	var snapshot: Dictionary = lab._review_entry()
	if absf(lab.item_node.position.x - original.origin.x - 0.01) > 0.0001 or absf(lab.item_node.rotation_degrees.y - 1.0) > 0.01 or not snapshot.has("itemTransform"):
		push_error("Context item move/rotate/export failed")
		quit(1)
		return
	# Confirmed edits remain local until explicitly sent. No network in this test.
	lab.quick_outbox_path = "user://smoke-feedback.json"
	lab.quick_outbox.clear()
	lab._confirm_quick_feedback()
	if lab.quick_outbox.size() != 1 or not lab.quick_pending_id.is_empty() or not lab.git_button.text.contains("(1)"):
		push_error("Local confirmation or GIT count failed")
		quit(1)
		return
	lab.quick_outbox.clear()
	lab._load_quick_outbox()
	lab._open_git_panel()
	if lab.quick_outbox.size() != 1 or not lab.git_panel.visible or lab.git_send_button.disabled:
		push_error("Feedback queue restoration or GIT panel failed")
		quit(1)
		return
	lab.quick_token.text = ""
	lab._send_quick_feedback()
	if lab.quick_outbox.size() != 1 or not lab.git_last_status.contains("token") or not lab.quick_pending_id.is_empty():
		push_error("Missing token must not lose or send feedback")
		quit(1)
		return
	lab.quick_pending_id = str(lab.quick_outbox[0]["id"])
	lab._quick_response(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	if lab.quick_outbox.size() != 1 or not lab.git_last_status.contains("preservada"):
		push_error("Unconfirmed transmission must preserve feedback")
		quit(1)
		return
	lab.quick_pending_id = str(lab.quick_outbox[0]["id"])
	lab._quick_response(HTTPRequest.RESULT_SUCCESS, 201, PackedStringArray(), '{"number":123}'.to_utf8_buffer())
	if not lab.quick_outbox.is_empty() or lab.git_sent_count != 1 or not lab.git_last_status.contains("#123"):
		push_error("Confirmed transmission must remove feedback")
		quit(1)
		return
	lab.git_panel.hide()
	DirAccess.remove_absolute(lab.quick_outbox_path)
	print("GIT_FEEDBACK_OK: explicit send, persistent queue, token check and simulated HTTP outcomes.")
	lab._close_quick_menu()
	lab._set_mode(0)
	lab._close_quick_menu()
	if not lab.hud_nav.visible:
		push_error("Context menu did not restore transport")
		quit(1)
		return
	print("UI_OK: separate settings, section navigation, searchable touch rows, selection and return.")
	print("LOCALIZATION_COMPLETE: all imported clips, bones and items.")
	print("ITEMS_OK: ", lab.items.size(), " models; mode switch, navigation and actor restoration.")
	print("SMOKE_OK: ", packs.size(), " packs; ", count, " imported clip variants.")
	print("TRANSPORT_OK: ", navigation_checks, " scenes; wrap, sync, visibility, playback mode and speed.")

	# Review records include current observations, saved notes and numeric transforms.
	var rules = preload("res://lab/equipment_rules.gd")
	if not rules.matches("Sword", "Sword_Attack") or rules.matches("Sword_Big", "Sword_Attack") or not rules.matches("Bow_Wooden", "Bow_Shoot"):
		push_error("Equipment action classification failed")
		quit(1)
		return
	lab.review_path = "user://smoke-reviews.json"
	lab.review_records.clear()
	lab.review_notes.text = "Teste de encaixe: mão esquerda"
	lab._record_review()
	lab.review_notes.text = "Observação atual"
	lab.review_verdict.select(2)
	# Programmatic assignment does not guarantee TextEdit.text_changed; mirror explicit UI save.
	lab._save_reviews()
	var report: Variant = JSON.parse_string(lab._report_json())
	if not report is Dictionary or report["reviews"].size() != 1 or report["reviews"][0]["notes"] != "Teste de encaixe: mão esquerda" or report["current"]["notes"] != "Observação atual" or report["build"] != ProjectSettings.get_setting("application/config/version") or not report["current"].has("demo") or not report["current"].has("balance") or not report["current"]["bodyWarp"].has("yawDeg") or not report["current"]["contextIK"].has("contacts") or not report["current"].has("bodyWarp") or not report.has("bodyWarpProfiles") or not report["current"].has("contextIK") or not report.has("contextContactProfiles") or not report["current"].has("supportIK") or not report.has("supportProfiles"):
		push_error("Review JSON failed")
		quit(1)
		return
	lab.review_records.clear()
	lab._load_reviews()
	if lab.review_records.size() != 1 or lab.review_notes.text != "Observação atual" or lab.review_verdict.selected != 2:
		push_error("Review persistence failed")
		quit(1)
		return
	DirAccess.remove_absolute(lab.review_path)
	print("REVIEW_OK: classification, JSON export and persistent notes.")
	if not await _test_support_ik():
		push_error("Support IK synthetic chain failed")
		quit(1)
		return
	print("SUPPORT_IK_OK: reachable target, scale and unreachable rejection.")
	if not await _test_renik():
		push_error("RenIK backend integration failed")
		quit(1)
		return
	print("RENIK_OK: backend selection, finite result, reach rejection and axis guard.")
	if not _test_context_geometry():
		push_error("Context anchor geometry failed")
		quit(1)
		return
	print("CONTEXT_ANCHOR_OK: closest surface, top, rescale, phase window and leg mapping.")
	if not _test_body_warp():
		push_error("Body warp geometry failed")
		quit(1)
		return
	if not is_instance_valid(lab.warp_root) or lab.actor.get_parent() != lab.warp_root:
		push_error("Actor wrapper missing")
		quit(1)
		return
	lab.warp_root.position = Vector3(0.1, 0.2, 0.3)
	lab._reset_warp_frame()
	if not lab.warp_root.position.is_zero_approx():
		push_error("Warp did not reset")
		quit(1)
		return
	print("BODY_WARP_OK: bounded translation, axis filter, swept box guard, wrapper and reset.")
	if not await _test_multi_contact():
		push_error("Multi-contact test failed")
		quit(1)
		return
	print("MULTI_CONTACT_OK: independent limb solvers, weighted root compromise and exact tip guard.")
	if not _test_body_yaw():
		push_error("Body yaw fit or guard failed")
		quit(1)
		return
	lab.warp_root.rotation.y = 0.3
	lab._reset_warp_frame()
	if not lab.warp_root.transform.is_equal_approx(Transform3D.IDENTITY):
		push_error("Warp rotation did not reset")
		quit(1)
		return
	print("BODY_YAW_OK: weighted fit, limit, arc guard and reset.")
	if not _test_balance():
		push_error("Support balance geometry failed")
		quit(1)
		return
	print("BALANCE_OK: projection, support margin, axis and correction limits.")
	if not _test_equipment_fit():
		push_error("Equipment geometry fitting failed")
		quit(1)
		return
	if not _test_demo_samples(lab):
		push_error("Demo sample attachment/context failed")
		quit(1)
		return
	print("DEMO_OK: real pistol, bow, axe/tree and chair sample mappings; actual attachment and context loading.")
	if not _test_gallery(lab):
		push_error("Demo gallery navigation failed")
		quit(1)
		return
	print("GALLERY_OK: indexed clips across real libraries, automatic equipment, camera and pose alignment geometry.")
	quit(0)

func _test_support_ik() -> bool:
	var solver = preload("res://lab/contact_ik.gd").new()
	var rig := Skeleton3D.new()
	root.add_child(rig)
	for bone in ["Root", "LeftUpperArm", "LeftLowerArm", "LeftHand"]:
		rig.add_bone(bone)
	for i in range(1, 4):
		rig.set_bone_parent(i, i - 1)
		rig.set_bone_rest(i, Transform3D(Basis.IDENTITY, Vector3(0.3, 0, 0) if i > 1 else Vector3.ZERO))
	rig.reset_bone_poses()
	var goal := Vector3(0.35, 0.25, 0)
	solver.apply(rig, 3, goal, 1.0)
	for i in range(5):
		await process_frame
	var ok: bool = solver.state == "active" and solver.after_cm >= 0.0 and solver.after_cm < 3.0 and solver.after_cm < solver.before_cm
	solver.apply(rig, 3, Vector3(5, 0, 0), 1.0)
	ok = ok and solver.state == "out_of_reach" and not solver.ik.is_running()
	ok = ok and solver.reachable(Vector3.ZERO, Vector3(0.3, 0, 0), Vector3(0.6, 0, 0), Vector3(0.4, 0.1, 0))
	ok = ok and not solver.reachable(Vector3.ZERO, Vector3(0.3, 0, 0), Vector3(0.6, 0, 0), Vector3(0.8, 0, 0))
	solver.clear()
	rig.queue_free()
	return ok

func _test_renik() -> bool:
	var solver = preload("res://lab/contact_ik.gd").new()
	var rig := Skeleton3D.new()
	root.add_child(rig)
	for bone in ["Root", "LeftUpperArm", "LeftLowerArm", "LeftHand"]:
		rig.add_bone(bone)
	for i in range(1, 4):
		rig.set_bone_parent(i, i - 1)
		rig.set_bone_rest(i, Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0) if i > 1 else Vector3.ZERO))
	rig.reset_bone_poses()
	solver.select_backend("renik")
	var goal := Vector3(0.25, 0.35, 0.1)
	solver.apply(rig, 3, goal, 1.0)
	for i in range(5):
		await process_frame
	var ok: bool = solver.state == "active" and solver.samples > 0 and solver.after_cm >= 0.0 and is_finite(solver.after_cm)
	print("RenIK synthetic error cm: ", solver.before_cm, " -> ", solver.after_cm)
	solver.apply(rig, 3, Vector3(5, 0, 0), 1.0)
	ok = ok and solver.state == "out_of_reach" and not solver.renik.active
	solver.select_backend("godot_fabrik")
	ok = ok and solver.renik == null and solver.backend == "godot_fabrik"
	solver.select_backend("renik")
	rig.set_bone_rest(2, Transform3D(Basis.IDENTITY, Vector3(0.3, 0, 0)))
	rig.reset_bone_poses()
	solver.apply(rig, 3, Vector3(0.2, 0.3, 0.1), 1.0)
	ok = ok and solver.state == "renik_rig_incompatible" and not solver.renik.active
	solver.clear()
	rig.queue_free()
	return ok

func _test_context_geometry() -> bool:
	var g = preload("res://lab/context_contact.gd")
	var half := Vector3(1.0, 0.5, 0.75)
	var top: Vector3 = g.top_surface(Vector3(0.25, 2, -0.3), half)
	var side: Vector3 = g.nearest_surface(Vector3(2, 0.1, 0), half)
	var inside: Vector3 = g.nearest_surface(Vector3.ZERO, half)
	var ok := top.is_equal_approx(Vector3(0.25, 1, -0.4)) and side.is_equal_approx(Vector3(1, 0.2, 0))
	ok = ok and inside.is_equal_approx(Vector3(0, 1, 0))
	ok = ok and (top * (half * Vector3(2, 3, 1))).is_equal_approx(Vector3(0.5, 1.5, -0.3))
	ok = ok and is_equal_approx(g.phase_weight(0.5, 0.5, 0.3), 1.0) and is_zero_approx(g.phase_weight(0.1, 0.5, 0.3))
	var rig := Skeleton3D.new()
	for bone in ["Root", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"]:
		rig.add_bone(bone)
	for i in range(1, 4):
		rig.set_bone_parent(i, i - 1)
	ok = ok and preload("res://lab/contact_ik.gd").chain(rig, 3) == PackedInt32Array([1, 2, 3])
	rig.free()
	return ok

func _test_body_warp() -> bool:
	var w = preload("res://lab/body_warp.gd")
	var half := Vector3(0.5, 0.5, 0.5)
	var p: Vector3 = w.proposed_offset(Vector3.ZERO, Vector3(1, 1, 0), 0.5, 0.4, 1)
	var ok := p.is_equal_approx(Vector3(0.2, 0, 0))
	ok = ok and w.proposed_offset(Vector3.ZERO, Vector3(1, 1, 0), 1.0, 0.3, 2).is_equal_approx(Vector3(0, 0.3, 0))
	ok = ok and is_equal_approx(w.safe_fraction(PackedVector3Array([Vector3(-2, 1, 0)]), Vector3(4, 0, 0), half, 0.1), 1.0)
	var blocked: float = w.safe_fraction(PackedVector3Array([Vector3(-1, 0, 0)]), Vector3(2, 0, 0), half, 0.1)
	ok = ok and blocked > 0.18 and blocked < 0.21
	ok = ok and is_zero_approx(w.safe_fraction(PackedVector3Array([Vector3.ZERO]), Vector3(2, 0, 0), half, 0.1))
	ok = ok and is_zero_approx(w.safe_fraction(PackedVector3Array(), Vector3(2, 0, 0), half, 0.1))
	return ok

func _test_multi_contact() -> bool:
	var w = preload("res://lab/body_warp.gd")
	var ik = preload("res://lab/contact_ik.gd")
	var offsets := PackedVector3Array([Vector3(0.2, 0, 0), Vector3(-0.2, 0, 0)])
	var ok: bool = w.compromise(offsets, PackedFloat32Array([1.0, 1.0]), 0.4).is_zero_approx()
	ok = ok and w.compromise(offsets, PackedFloat32Array([0.5, 0.0]), 0.4).is_equal_approx(Vector3(0.1, 0, 0))
	ok = ok and ik.is_contact_tip("foot.L") and ik.is_contact_tip("mixamorig:RightHand") and not ik.is_contact_tip("RightHandIndex1")
	var rig := Skeleton3D.new()
	root.add_child(rig)
	rig.add_bone("Root")
	for side in ["Left", "Right"]:
		var upper := rig.get_bone_count()
		rig.add_bone(side + "UpperArm")
		rig.add_bone(side + "LowerArm")
		rig.add_bone(side + "Hand")
		rig.set_bone_parent(upper, 0)
		rig.set_bone_rest(upper, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.3 if side == "Left" else -0.3)))
		for i in range(upper + 1, upper + 3):
			rig.set_bone_parent(i, i - 1)
			rig.set_bone_rest(i, Transform3D(Basis.IDENTITY, Vector3(0.3, 0, 0)))
	rig.reset_bone_poses()
	var left = ik.new()
	var right = ik.new()
	left.apply(rig, 3, Vector3(0.35, 0.25, 0.3), 1.0)
	right.apply(rig, 6, Vector3(0.35, -0.25, -0.3), 1.0)
	for i in range(5):
		await process_frame
	ok = ok and left.state == "active" and right.state == "active" and left.after_cm >= 0 and right.after_cm >= 0 and left.after_cm < 3 and right.after_cm < 3
	left.suspend("test")
	ok = ok and not left.ik.is_running() and right.ik.is_running()
	left.clear()
	right.clear()
	rig.queue_free()
	return ok

func _test_body_yaw() -> bool:
	var w = preload("res://lab/body_warp.gd")
	var points := PackedVector3Array([Vector3(-1, 0, 0), Vector3(1, 0, 0)])
	var goals := PackedVector3Array([Vector3(2, 0, 4), Vector3(2, 0, 2)])
	var weights := PackedFloat32Array([1.0, 1.0])
	var ok: bool = is_equal_approx(w.fitted_yaw(points, goals, weights, PI), PI / 2.0)
	ok = ok and is_equal_approx(w.fitted_yaw(points, goals, weights, 0.3), 0.3)
	ok = ok and is_equal_approx(w.fitted_yaw(points, goals, PackedFloat32Array([0.5, 0.5]), 0.3), 0.15)
	ok = ok and is_zero_approx(w.fitted_yaw(points, goals, PackedFloat32Array([1.0, 0.0]), 0.3))
	var half := Vector3(0.2, 0.2, 0.2)
	var box := Transform3D(Basis.IDENTITY, Vector3(0.7071, 0, -0.7071))
	ok = ok and not w.yaw_is_clear(PackedVector3Array([Vector3(1, 0, 0)]), Vector3.ZERO, PI / 2.0, box, half, 0.05)
	box.origin = Vector3(0, 2, 0)
	ok = ok and w.yaw_is_clear(PackedVector3Array([Vector3(1, 0, 0)]), Vector3.ZERO, PI / 2.0, box, half, 0.05)
	return ok

func _test_balance() -> bool:
	var bal = preload("res://lab/support_balance.gd")
	var a := Vector3(-0.2, 0.4, 0)
	var b := Vector3(0.2, 0.4, 0)
	var center := Vector3(0, 1.2, 0.3)
	var delta: Vector3 = bal.correction(center, a, b, 0.08, 0.15)
	var ok := delta.is_equal_approx(Vector3(0, 0, -0.15))
	ok = ok and is_equal_approx(bal.support_error(center, a, b, 0.08), 0.22)
	ok = ok and is_equal_approx(bal.support_error(center + delta, a, b, 0.08), 0.07)
	ok = ok and bal.correction(Vector3(0, 2, 0.03), a, b, 0.08, 0.15).is_zero_approx()
	ok = ok and bal.closest_support(Vector3(0.8, 2, 0), a, b).is_equal_approx(Vector3(0.2, 0, 0))
	ok = ok and bal.closest_support(Vector3(0.8, 2, 0), a, a).is_equal_approx(Vector3(-0.2, 0, 0))
	return ok

func _test_demo_samples(lab) -> bool:
	var demos = preload("res://lab/demo_samples.gd")
	var checks := 0
	var pistol_found := false
	var tree_found := false
	var chair_found := false
	for i in range(lab.records.size()):
		lab._load_scene(i)
		lab.demo_toggle.set_pressed_no_signal(true)
		for j in range(lab.clips.size()):
			var sample: Dictionary = demos.for_clip(str(lab.clips[j]))
			if sample.is_empty():
				continue
			lab._select_clip(j)
			if sample.has("item"):
				var item: int = demos.find_item(lab.items, sample["item"])
				if item < 0 or lab.equipped_index != item or not is_instance_valid(lab.attachment):
					return false
				var rules = preload("res://lab/equipment_rules.gd")
				var target: float = lab.grip.get_meta("fit_target_m", 0.0)
				var local_bounds: AABB = rules.model_bounds(lab.grip)
				var world_scale: Vector3 = (lab.skeleton.global_transform * lab.skeleton.get_bone_global_pose(lab.skeleton.find_bone(lab.attachment.bone_name)) * lab.grip.transform).basis.get_scale().abs()
				var extent: float = maxf(local_bounds.size.x, maxf(local_bounds.size.y, local_bounds.size.z))
				var approximate_m: float = extent * (world_scale.x + world_scale.y + world_scale.z) / 3.0
				if target <= 0.0 or absf(approximate_m - target) > target * 0.05:
					print("DEMO_FIT_DIAG: ", sample["item"], " measured=", approximate_m, " target=", target, " actor=", lab.actor_height_m)
					return false
			if sample.has("context"):
				var item: int = demos.find_item(lab.items, sample["context"])
				if item < 0 or lab.context_record_index != item or not is_instance_valid(lab.context_root):
					return false
			if sample.get("seat", false):
				var fit: Dictionary = lab.context_root.get_meta("seat_fit", {})
				if fit.is_empty():
					return false
				var v: Array = fit["seatLocal"]
				var local: Vector3 = Vector3(float(v[0]), float(v[1]), float(v[2])) * lab._object_scale(lab.context_record_index)
				var world: Vector3 = lab.context_root.to_global(local)
				var target: Array = fit["seatTargetXZ"]
				if not world.is_finite() or absf(world.y - float(fit["seatHeightM"])) > 0.01 or Vector2(world.x - float(target[0]), world.z - float(target[1])).length() > 0.01:
					print("SEAT_FIT_DIAG: ", fit, " world=", world)
					return false
				chair_found = true
			pistol_found = pistol_found or sample.get("item", "") == "survival_pack/Pistol_1"
			tree_found = tree_found or sample.get("context", "") == "nature_pack/CommonTree_1"
			checks += 1
		lab.demo_toggle.set_pressed_no_signal(false)
		lab._clear_all_equipment()
		lab._choose_context(0)
	return checks > 0 and pistol_found and tree_found and chair_found

func _test_gallery(lab) -> bool:
	var demos = preload("res://lab/demo_samples.gd")
	var entries: Array = lab.demo_entries
	if entries.size() < 8 or lab.demo_gallery.item_count != entries.size():
		print("GALLERY_DIAG: entries=", entries.size(), " picker=", lab.demo_gallery.item_count)
		return false
	var found := false
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		if str(entry["clip"]).to_lower().contains("pistol_idle"):
			lab._choose_demo_gallery(i)
			if not is_instance_valid(lab.grip) or not str(lab.selected_clip).to_lower().contains("pistol_idle"):
				print("GALLERY_DIAG: selected=", lab.selected_clip, " expected=", entry["clip"], " attached=", is_instance_valid(lab.grip))
				return false
			var original: Transform3D = lab.grip.transform
			lab._set_isometric_view()
			if lab.camera.projection != Camera3D.PROJECTION_ORTHOGONAL or not is_equal_approx(lab.camera.size, 6.0) or not lab.grip.transform.is_equal_approx(original):
				return false
			lab._focus_equipment_demo()
			if lab.camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
				return false
			lab.axis_picker.select(0)
			lab.fine_grip.button_pressed = true
			var bone: int = lab.skeleton.find_bone(lab.attachment.bone_name)
			var basis: Basis = (lab.skeleton.global_transform * lab.skeleton.get_bone_global_pose(bone)).basis
			lab._adjust_grip(1)
			var delta: Vector3 = lab.grip.position - original.origin
			var physical: float = (basis * delta).length()
			lab._adjust_grip(-1)
			lab.fine_grip.button_pressed = false
			if absf(physical - 0.001) > 0.0001:
				return false
			lab._reset_grip()
			found = lab.distance < 3.6 and lab.focus.is_finite()
			print("GALLERY_DIAG: pistol distance=", lab.distance, " focus=", lab.focus)
			break
	var p: Vector3 = demos.face_position(Vector3(0.2, 1, -0.6), Vector3(0, 1, 0), Vector3(0.3, 0.5, 0.4))
	return found and p.is_equal_approx(Vector3(0.2, 0, -1.0))

func _test_equipment_fit() -> bool:
	var rules = preload("res://lab/equipment_rules.gd")
	var bounds := AABB(Vector3(-0.57, -0.82, -0.13), Vector3(1.14, 5.45, 0.26))
	var hand := {"center": Vector3(0.05, 0.02, 0.0), "basis": Basis(Vector3.FORWARD, 0.4)}
	var data: Dictionary = rules.fit({"pack": "medieval_weapons_pack", "name": "Sword"}, bounds, 1.75, 1.0, hand)
	if data.is_empty():
		return false
	var transform: Transform3D = data["transform"]
	var anchor: Vector3 = data["anchor"]
	if not is_equal_approx(transform.basis.get_scale().y * bounds.size.y, 0.90):
		return false
	if not (transform * anchor).is_equal_approx(hand["center"]):
		return false
	var small: Dictionary = rules.fit({"pack": "medieval_weapons_pack", "name": "Sword"}, bounds, 0.875, 2.0, hand)
	if not is_equal_approx(float(small["scale"]) * 2.0 * bounds.size.y, 0.45):
		return false
	print("EQUIPMENT_FIT_OK: scale relative to actor and parent; anchor preserved under fit.")
	return true
