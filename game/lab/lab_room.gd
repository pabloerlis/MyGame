extends Node3D
## Single-room inspector. Real imported scenes only; no synthetic character or clip.
var records: Array = []
var actor: Node3D
var player: AnimationPlayer
var camera: Camera3D
var yaw := 0.65
var pitch := 0.24
var distance := 4.0
var focus := Vector3(0, 1, 0)
var touches := {}
var scene_picker: OptionButton
var clip_picker: OptionButton
var loop_toggle: CheckButton
var play_button: Button
var status: Label
var details: Label
var panel: VBoxContainer
var clips: PackedStringArray = []
var selected_clip: StringName
var original_modes := {}
var clip_index := -1
var previous_button: Button
var next_button: Button
var clip_caption: Label
var catalog_panel: PanelContainer
var speed_picker: OptionButton
const SPEEDS := [0.25, 0.5, 1.0, 1.5, 2.0]
var playback_speed := 1.0
var items: Array = []
var item_mode := false
var item_index := -1
var item_node: Node3D
var mode_picker: OptionButton
var item_picker: OptionButton
var animation_controls: VBoxContainer
var saved_focus := Vector3(0, 1, 0)
var saved_distance := 4.0
var item_focus := Vector3(0, 1, 0)
var item_distance := 4.0
var equipment_controls: VBoxContainer
var equipment_toggle: Button
var equipment_picker: OptionButton
var bone_picker: OptionButton
var axis_picker: OptionButton
var equip_label: Label
var skeleton: Skeleton3D
var attachment: BoneAttachment3D
var grip: Node3D
var equipped_index := -1
var equipment_indices: Array[int] = []
var grip_profiles := {}
var active_profile := ""
var slot_picker: OptionButton
var active_slot := 0
var slot_states := {}
var hand_bones := [-1, -1]
var profile_path := "user://grip-profiles-v1.cfg"
var profile_status := ""
var context_toggle: Button
var context_controls: VBoxContainer
var context_picker: OptionButton
var context_axis: OptionButton
var context_label: Label
var context_indices: Array[int] = []
var context_root: Node3D
var context_origin := Vector3(0.0, 0.0, -1.2)
var context_offset := Vector3.ZERO
var inspection_toggle: Button
var inspection_controls: VBoxContainer
var phase_slider: HSlider
var phase_label: Label
var contact_picker: OptionButton
var contact_label: Label
var diagnostics_elapsed := 0.0
const CONTACT_TOLERANCE := 0.02

func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#272e37")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	add_child(env)
	# Neutral inspection surface, not an authored game asset.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#626971")
	floor_mesh.material_override = material
	add_child(floor_mesh)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	_update_camera()
	_create_ui()
	_load_grip_profiles()
	var file := FileAccess.open("res://assets/runtime/catalog.json", FileAccess.READ)
	if file == null:
		status.text = "Assets ausentes. Execute o pipeline de aquisição."
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Array or parsed.is_empty():
		status.text = "Catálogo vazio ou inválido."
		return
	records = parsed
	for record in records:
		scene_picker.add_item(str(record["pack"]) + " | " + str(record["sourcePath"]).get_file())
	_load_scene(0)
	var item_file := FileAccess.open("res://assets/runtime/items.json", FileAccess.READ)
	if item_file != null:
		var parsed_items: Variant = JSON.parse_string(item_file.get_as_text())
		if parsed_items is Array:
			items = parsed_items
	for item in items:
		item_picker.add_item(str(item["name"]) + " | " + ("RPG" if item["pack"] == "rpg_items_pack" else "Armas"))
	for i in range(items.size()):
		var record: Dictionary = items[i]
		var name := str(record["name"]).to_lower()
		if record["pack"] == "medieval_weapons_pack" or name.begins_with("sword") or name.begins_with("axe") or name.begins_with("bow") or name.begins_with("dagger") or name.begins_with("hammer"):
			equipment_indices.append(i)
			equipment_picker.add_item(str(record["name"]) + " | " + ("RPG" if record["pack"] == "rpg_items_pack" else "Armas"))
	for i in range(items.size()):
		var record: Dictionary = items[i]
		var name := str(record["name"]).to_lower()
		if record["pack"] == "rpg_items_pack" and (name.begins_with("chest") or name.begins_with("mineral") or name.begins_with("crystal") or name.begins_with("book")):
			context_indices.append(i)
			context_picker.add_item(str(record["name"]))
	context_toggle.disabled = context_indices.is_empty()
	mode_picker.set_item_disabled(1, items.is_empty())
	equipment_toggle.disabled = equipment_indices.is_empty() or not is_instance_valid(skeleton)

func _create_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 24
	status = Label.new()
	status.text = "MyGame Lab"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(status)
	var toggle := Button.new()
	toggle.text = "Catálogo"
	top.add_child(toggle)
	var reset := Button.new()
	reset.text = "Câmera"
	top.add_child(reset)
	reset.pressed.connect(func():
		yaw = 0.65
		pitch = 0.24
		focus = item_focus if item_mode else Vector3(0, 1, 0)
		distance = item_distance if item_mode else 4.0
		_update_camera()
	)
	# Persistent transport: independent of the collapsible catalog.
	var nav := PanelContainer.new()
	root.add_child(nav)
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_left = 12
	nav.offset_right = -12
	nav.offset_top = -86
	nav.offset_bottom = -16
	var nav_row := HBoxContainer.new()
	nav.add_child(nav_row)
	previous_button = Button.new()
	previous_button.text = "◀ Anterior"
	previous_button.custom_minimum_size = Vector2(112, 62)
	previous_button.disabled = true
	nav_row.add_child(previous_button)
	previous_button.pressed.connect(func(): _step_clip(-1))
	clip_caption = Label.new()
	clip_caption.text = "—"
	clip_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clip_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clip_caption.clip_text = true
	clip_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	clip_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_row.add_child(clip_caption)
	next_button = Button.new()
	next_button.text = "Próxima ▶"
	next_button.custom_minimum_size = Vector2(112, 62)
	next_button.disabled = true
	nav_row.add_child(next_button)
	next_button.pressed.connect(func(): _step_clip(1))
	var bottom := PanelContainer.new()
	catalog_panel = bottom
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_top = -355
	bottom.offset_bottom = -94
	panel = VBoxContainer.new()
	bottom.add_child(panel)
	toggle.pressed.connect(func(): bottom.visible = not bottom.visible)
	mode_picker = OptionButton.new()
	mode_picker.add_item("Personagens e animações")
	mode_picker.add_item("Inspecionar peças")
	mode_picker.set_item_disabled(1, true)
	panel.add_child(mode_picker)
	mode_picker.item_selected.connect(_set_mode)
	item_picker = OptionButton.new()
	item_picker.fit_to_longest_item = false
	item_picker.hide()
	panel.add_child(item_picker)
	item_picker.item_selected.connect(_load_item)
	animation_controls = VBoxContainer.new()
	panel.add_child(animation_controls)
	scene_picker = OptionButton.new()
	scene_picker.fit_to_longest_item = false
	animation_controls.add_child(scene_picker)
	scene_picker.item_selected.connect(_load_scene)
	clip_picker = OptionButton.new()
	clip_picker.fit_to_longest_item = false
	animation_controls.add_child(clip_picker)
	clip_picker.item_selected.connect(_select_clip)
	var row := HBoxContainer.new()
	animation_controls.add_child(row)
	loop_toggle = CheckButton.new()
	loop_toggle.text = "Loop"
	loop_toggle.button_pressed = true
	row.add_child(loop_toggle)
	loop_toggle.toggled.connect(func(_value): _replay())
	play_button = Button.new()
	play_button.text = "Reproduzir"
	row.add_child(play_button)
	play_button.pressed.connect(_replay)
	var pause := Button.new()
	pause.text = "Pausa"
	row.add_child(pause)
	pause.pressed.connect(func():
		if is_instance_valid(player):
			player.pause()
	)
	speed_picker = OptionButton.new()
	speed_picker.fit_to_longest_item = false
	for value in SPEEDS:
		speed_picker.add_item("Velocidade %s×" % str(value))
	speed_picker.select(2)
	animation_controls.add_child(speed_picker)
	speed_picker.item_selected.connect(_set_speed)
	equipment_toggle = Button.new()
	equipment_toggle.text = "Equipamentos / encaixe"
	animation_controls.add_child(equipment_toggle)
	equipment_toggle.pressed.connect(func():
		equipment_controls.visible = not equipment_controls.visible
		if equipment_controls.visible:
			context_controls.hide()
			inspection_controls.hide()
		# Keep the controls in the lower part of the screen.
		catalog_panel.offset_top = -520 if equipment_controls.visible else -355
	)
	equipment_controls = VBoxContainer.new()
	equipment_controls.hide()
	animation_controls.add_child(equipment_controls)
	slot_picker = OptionButton.new()
	slot_picker.add_item("Mão direita")
	slot_picker.add_item("Mão esquerda")
	equipment_controls.add_child(slot_picker)
	slot_picker.item_selected.connect(_switch_slot)
	equipment_picker = OptionButton.new()
	equipment_picker.fit_to_longest_item = false
	equipment_picker.add_item("Sem equipamento")
	equipment_controls.add_child(equipment_picker)
	equipment_picker.item_selected.connect(_choose_equipment)
	bone_picker = OptionButton.new()
	bone_picker.fit_to_longest_item = false
	equipment_controls.add_child(bone_picker)
	bone_picker.item_selected.connect(func(_index): _choose_equipment(equipment_picker.selected))
	var adjust_row := HBoxContainer.new()
	equipment_controls.add_child(adjust_row)
	axis_picker = OptionButton.new()
	for axis_name in ["Pos X", "Pos Y", "Pos Z", "Rot X", "Rot Y", "Rot Z"]:
		axis_picker.add_item(axis_name)
	axis_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adjust_row.add_child(axis_picker)
	for direction in [-1, 1]:
		var step_button := Button.new()
		step_button.text = "−" if direction == -1 else "+"
		step_button.custom_minimum_size = Vector2(48, 40)
		adjust_row.add_child(step_button)
		step_button.pressed.connect(_adjust_grip.bind(direction))
	var reset_grip := Button.new()
	reset_grip.text = "Zerar"
	adjust_row.add_child(reset_grip)
	reset_grip.pressed.connect(_reset_grip)
	equip_label = Label.new()
	equip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_controls.add_child(equip_label)
	context_toggle = Button.new()
	context_toggle.text = "Objetos de contexto"
	animation_controls.add_child(context_toggle)
	context_toggle.pressed.connect(func():
		context_controls.visible = not context_controls.visible
		if context_controls.visible:
			equipment_controls.hide()
			inspection_controls.hide()
		catalog_panel.offset_top = -490 if context_controls.visible else -355
	)
	context_controls = VBoxContainer.new()
	context_controls.hide()
	animation_controls.add_child(context_controls)
	context_picker = OptionButton.new()
	context_picker.fit_to_longest_item = false
	context_picker.add_item("Sem objeto")
	context_controls.add_child(context_picker)
	context_picker.item_selected.connect(_choose_context)
	var context_row := HBoxContainer.new()
	context_controls.add_child(context_row)
	context_axis = OptionButton.new()
	for axis_name in ["X lateral", "Y altura", "Z distância"]:
		context_axis.add_item(axis_name)
	context_axis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_row.add_child(context_axis)
	for direction in [-1, 1]:
		var step := Button.new()
		step.text = "−" if direction == -1 else "+"
		step.custom_minimum_size = Vector2(48, 40)
		context_row.add_child(step)
		step.pressed.connect(_adjust_context.bind(direction))
	var context_reset := Button.new()
	context_reset.text = "Zerar"
	context_row.add_child(context_reset)
	context_reset.pressed.connect(_reset_context)
	context_label = Label.new()
	context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_controls.add_child(context_label)
	inspection_toggle = Button.new()
	inspection_toggle.text = "Tempo / contato"
	animation_controls.add_child(inspection_toggle)
	inspection_toggle.pressed.connect(func():
		inspection_controls.visible = not inspection_controls.visible
		if inspection_controls.visible:
			equipment_controls.hide()
			context_controls.hide()
		catalog_panel.offset_top = -520 if inspection_controls.visible else -355
	)
	inspection_controls = VBoxContainer.new()
	inspection_controls.hide()
	animation_controls.add_child(inspection_controls)
	phase_label = Label.new()
	phase_label.text = "Tempo da animação"
	inspection_controls.add_child(phase_label)
	phase_slider = HSlider.new()
	phase_slider.min_value = 0.0
	phase_slider.max_value = 1.0
	phase_slider.step = 0.001
	phase_slider.custom_minimum_size.y = 36
	inspection_controls.add_child(phase_slider)
	phase_slider.value_changed.connect(_seek_phase)
	var frame_row := HBoxContainer.new()
	inspection_controls.add_child(frame_row)
	for direction in [-1, 1]:
		var step_frame := Button.new()
		step_frame.text = "− 1/60 s" if direction == -1 else "+ 1/60 s"
		step_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		step_frame.custom_minimum_size.y = 40
		frame_row.add_child(step_frame)
		step_frame.pressed.connect(_step_time.bind(direction))
	contact_picker = OptionButton.new()
	contact_picker.fit_to_longest_item = false
	inspection_controls.add_child(contact_picker)
	contact_picker.item_selected.connect(func(_index): _update_inspection())
	contact_label = Label.new()
	contact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspection_controls.add_child(contact_label)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(details)

func _load_scene(index: int) -> void:
	_clear_all_equipment()
	skeleton = null
	bone_picker.clear()
	equipment_picker.select(0)
	if is_instance_valid(player):
		player.stop()
		for clip in original_modes:
			player.get_animation(clip).loop_mode = original_modes[clip]
	if is_instance_valid(actor):
		remove_child(actor)
		actor.queue_free()
	actor = null
	player = null
	original_modes.clear()
	clip_picker.clear()
	clips.clear()
	selected_clip = &""
	clip_index = -1
	_update_transport()
	if index < 0 or index >= records.size():
		return
	scene_picker.select(index)
	var record: Dictionary = records[index]
	var packed: Resource = load(str(record["path"]))
	if not packed is PackedScene:
		status.text = "Falha ao importar asset"
		return
	var node: Node = packed.instantiate()
	if not node is Node3D:
		node.free()
		status.text = "Cena 3D inválida"
		return
	actor = node
	add_child(actor)
	skeleton = _find_skeleton(actor)
	_populate_bones()
	equipment_toggle.disabled = equipment_indices.is_empty() or not is_instance_valid(skeleton)
	player = _find_player(actor)
	if player == null:
		status.text = "Sem AnimationPlayer"
		return
	clips = player.get_animation_list()
	player.speed_scale = playback_speed
	for clip in clips:
		clip_picker.add_item(clip)
		original_modes[clip] = player.get_animation(clip).loop_mode
	status.text = "%s movimentos" % clips.size()
	details.text = str(record["pack"]) + " • CC0"
	if not clips.is_empty():
		var start := 0
		for i in range(clips.size()):
			if "idle" in clips[i].to_lower():
				start = i
				break
		clip_picker.select(start)
		_select_clip(start)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _populate_bones() -> void:
	bone_picker.clear()
	contact_picker.clear()
	if not is_instance_valid(skeleton):
		return
	# Exact names from the imported skeleton. Prefer hand bones, not fingers.
	var hands: Array[int] = []
	var others: Array[int] = []
	hand_bones = [-1, -1]
	for i in range(skeleton.get_bone_count()):
		var bone_name := str(skeleton.get_bone_name(i))
		var normalized := bone_name.to_lower().replace("_", "").replace(".", "").replace(":", "").replace("-", "").replace(" ", "")
		var is_right := normalized.ends_with("righthand") or normalized.ends_with("handr") or normalized.ends_with("rhand") or normalized.ends_with("handright")
		var is_left := normalized.ends_with("lefthand") or normalized.ends_with("handl") or normalized.ends_with("lhand") or normalized.ends_with("handleft")
		if is_right or is_left:
			hands.append(i)
			if is_right:
				hand_bones[0] = i
			if is_left:
				hand_bones[1] = i
		else:
			others.append(i)
	for i in hands + others:
		bone_picker.add_item(str(skeleton.get_bone_name(i)), i)
		contact_picker.add_item(str(skeleton.get_bone_name(i)), i)
	_select_default_bone()
	if bone_picker.selected >= 0:
		contact_picker.select(bone_picker.selected)
	elif contact_picker.item_count > 0:
		contact_picker.select(0)
	equip_label.text = "Escolha peça e osso. Ajuste a empunhadura."

func _select_default_bone() -> void:
	var preferred: int = hand_bones[active_slot]
	if preferred >= 0:
		bone_picker.select(bone_picker.get_item_index(preferred))
	else:
		# No guessed bone when the rig does not expose a recognized hand.
		bone_picker.select(-1)

func _remember_slot() -> void:
	slot_states[active_slot] = {
		"attachment": attachment, "grip": grip, "item": equipped_index,
		"profile": active_profile, "bone": bone_picker.get_selected_id(),
		"picker": equipment_picker.selected
	}

func _switch_slot(index: int) -> void:
	if index < 0 or index > 1 or index == active_slot:
		return
	_remember_slot()
	active_slot = index
	slot_picker.select(index)
	var state: Dictionary = slot_states.get(index, {})
	attachment = state.get("attachment")
	grip = state.get("grip")
	equipped_index = int(state.get("item", -1))
	active_profile = str(state.get("profile", ""))
	equipment_picker.select(int(state.get("picker", 0)))
	var bone_id := int(state.get("bone", -1))
	if bone_id >= 0 and bone_picker.get_item_index(bone_id) >= 0:
		bone_picker.select(bone_picker.get_item_index(bone_id))
	else:
		_select_default_bone()
	if is_instance_valid(grip):
		_update_grip_label()
	else:
		equip_label.text = "Sem equipamento neste encaixe"

func _clear_all_equipment() -> void:
	_remember_slot()
	for state in slot_states.values():
		var node: BoneAttachment3D = state.get("attachment")
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	slot_states.clear()
	attachment = null
	grip = null
	equipped_index = -1
	active_profile = ""
	active_slot = 0
	slot_picker.select(0)

func _load_grip_profiles() -> void:
	grip_profiles.clear()
	var config := ConfigFile.new()
	var result := config.load(profile_path)
	if result == ERR_FILE_NOT_FOUND:
		profile_status = ""
		return
	if result != OK:
		profile_status = " | Falha ao ler ajustes"
		return
	for key in config.get_section_keys("grips") if config.has_section("grips") else PackedStringArray():
		var value: Variant = config.get_value("grips", key)
		if value is Transform3D and value.is_finite():
			grip_profiles[key] = value
	profile_status = ""

func _save_grip_profiles() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "schema", 1)
	for key in grip_profiles:
		config.set_value("grips", key, grip_profiles[key])
	var result := config.save(profile_path)
	profile_status = " | Salvo" if result == OK else " | Falha ao salvar"

func _clear_equipment() -> void:
	if is_instance_valid(attachment):
		attachment.get_parent().remove_child(attachment)
		attachment.queue_free()
	attachment = null
	grip = null
	equipped_index = -1
	active_profile = ""
	slot_states.erase(active_slot)

func _choose_equipment(index: int) -> void:
	_clear_equipment()
	equipment_picker.select(index)
	if index <= 0:
		equip_label.text = "Sem equipamento"
		return
	if index > equipment_indices.size() or not is_instance_valid(skeleton) or bone_picker.selected < 0:
		equip_label.text = "Osso ou peça indisponível"
		return
	var record_index: int = equipment_indices[index - 1]
	var record: Dictionary = items[record_index]
	var bone_index := bone_picker.get_selected_id()
	var other: Dictionary = slot_states.get(1 - active_slot, {})
	var other_attachment: BoneAttachment3D = other.get("attachment")
	if is_instance_valid(other_attachment) and other_attachment.bone_name == skeleton.get_bone_name(bone_index):
		equip_label.text = "Este osso já está ocupado pelo outro encaixe"
		equipment_picker.select(0)
		return
	var packed := load(str(record["path"])) as PackedScene
	if packed == null or bone_index < 0 or bone_index >= skeleton.get_bone_count():
		equip_label.text = "Falha no carregamento"
		return
	var model := packed.instantiate()
	if not model is Node3D:
		model.free()
		return
	attachment = BoneAttachment3D.new()
	attachment.bone_name = skeleton.get_bone_name(bone_index)
	skeleton.add_child(attachment)
	grip = Node3D.new()
	attachment.add_child(grip)
	grip.add_child(model)
	equipped_index = record_index
	active_profile = "%s|%s|%s|%d" % [records[scene_picker.selected]["id"], record["id"], attachment.bone_name, active_slot]
	if grip_profiles.has(active_profile):
		grip.transform = grip_profiles[active_profile]
	_update_grip_label()

func _adjust_grip(direction: int) -> void:
	if not is_instance_valid(grip):
		return
	var axis := axis_picker.selected
	if axis < 0 or axis > 5:
		return
	if axis < 3:
		var offset := grip.position
		offset[axis] += 0.01 * direction
		grip.position = offset
	else:
		var rotation_offset := grip.rotation_degrees
		rotation_offset[axis - 3] += 15.0 * direction
		grip.rotation_degrees = rotation_offset
	grip_profiles[active_profile] = grip.transform
	_save_grip_profiles()
	_update_grip_label()

func _reset_grip() -> void:
	if is_instance_valid(grip):
		grip.transform = Transform3D.IDENTITY
		grip_profiles.erase(active_profile)
		_save_grip_profiles()
		_update_grip_label()

func _update_grip_label() -> void:
	if is_instance_valid(grip):
		equip_label.text = "%s | P %.2f %.2f %.2f m | R %.0f %.0f %.0f°" % [attachment.bone_name, grip.position.x, grip.position.y, grip.position.z, grip.rotation_degrees.x, grip.rotation_degrees.y, grip.rotation_degrees.z] + profile_status

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null

func _select_clip(index: int) -> void:
	if index < 0 or index >= clips.size():
		return
	clip_index = index
	selected_clip = StringName(clips[index])
	clip_picker.select(index)
	_update_transport()
	_replay()

func _step_clip(direction: int) -> void:
	if item_mode:
		if not items.is_empty():
			_load_item(posmod(item_index + direction, items.size()))
		return
	if clips.is_empty() or not is_instance_valid(player):
		return
	_select_clip(posmod(clip_index + direction, clips.size()))

func _update_transport() -> void:
	if item_mode:
		previous_button.disabled = items.size() < 2
		next_button.disabled = items.size() < 2
		clip_caption.text = "%d/%d\n%s" % [item_index + 1, items.size(), items[item_index]["name"]] if item_index >= 0 else "—"
		return
	var available := clip_index >= 0 and clip_index < clips.size()
	previous_button.disabled = not available or clips.size() < 2
	next_button.disabled = not available or clips.size() < 2
	clip_caption.text = "%d/%d\n%s" % [clip_index + 1, clips.size(), selected_clip] if available else "—"

func _set_mode(index: int) -> void:
	var new_mode := index == 1
	if new_mode == item_mode or (new_mode and items.is_empty()):
		return
	item_mode = new_mode
	mode_picker.select(index)
	animation_controls.visible = not item_mode
	item_picker.visible = item_mode
	catalog_panel.offset_top = -520 if not item_mode and (equipment_controls.visible or inspection_controls.visible) else (-490 if not item_mode and context_controls.visible else -355)
	if is_instance_valid(context_root):
		context_root.visible = not item_mode
		var body := context_root.get_child(1) as StaticBody3D if context_root.get_child_count() > 1 else null
		if body != null:
			body.collision_layer = 0 if item_mode else 1
	if item_mode:
		saved_focus = focus
		saved_distance = distance
		if is_instance_valid(player):
			player.pause()
		if is_instance_valid(actor):
			actor.hide()
		_load_item(maxi(item_index, 0))
	else:
		_clear_item()
		focus = saved_focus
		distance = saved_distance
		if is_instance_valid(actor):
			actor.show()
		status.text = "%s movimentos" % clips.size()
		_update_camera()
		_update_transport()
		_replay()

func _choose_context(index: int) -> void:
	if is_instance_valid(context_root):
		remove_child(context_root)
		context_root.queue_free()
	context_root = null
	context_picker.select(index)
	context_offset = Vector3.ZERO
	context_label.text = "Sem objeto"
	if index <= 0 or index > context_indices.size():
		return
	var record: Dictionary = items[context_indices[index - 1]]
	var packed := load(str(record["path"])) as PackedScene
	if packed == null:
		context_label.text = "Falha ao carregar objeto"
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		return
	context_root = Node3D.new()
	add_child(context_root)
	context_root.add_child(model)
	var boxes: Array[AABB] = []
	_collect_bounds(model, boxes)
	if boxes.is_empty():
		return
	var bounds: AABB = boxes[0]
	for i in range(1, boxes.size()):
		bounds = bounds.merge(boxes[i])
	model.position += Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
	var body := StaticBody3D.new()
	context_root.add_child(body)
	body.position = Vector3(0, bounds.size.y * 0.5, 0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bounds.size.max(Vector3(0.01, 0.01, 0.01))
	collision.shape = shape
	body.add_child(collision)
	context_root.visible = not item_mode
	_reset_context()

func _adjust_context(direction: int) -> void:
	if not is_instance_valid(context_root):
		return
	var axis := context_axis.selected
	if axis < 0 or axis > 2:
		return
	context_offset[axis] = clampf(context_offset[axis] + 0.05 * direction, -4.0, 4.0)
	_update_context()

func _reset_context() -> void:
	context_offset = Vector3.ZERO
	_update_context()

func _update_context() -> void:
	if is_instance_valid(context_root):
		context_root.position = context_origin + context_offset
		context_label.text = "X %.2f | Y %.2f | Z %.2f m • colisão caixa" % [context_root.position.x, context_root.position.y, context_root.position.z]

func _clear_item() -> void:
	if is_instance_valid(item_node):
		remove_child(item_node)
		item_node.queue_free()
	item_node = null

func _load_item(index: int) -> void:
	if not item_mode or index < 0 or index >= items.size():
		return
	var record: Dictionary = items[index]
	var packed := load(str(record["path"])) as PackedScene
	if packed == null:
		status.text = "Falha ao importar peça"
		return
	var node := packed.instantiate()
	if not node is Node3D:
		node.free()
		return
	_clear_item()
	item_node = node as Node3D
	add_child(item_node)
	item_index = index
	item_picker.select(index)
	var boxes: Array[AABB] = []
	_collect_bounds(item_node, boxes)
	if not boxes.is_empty():
		var bounds: AABB = boxes[0]
		for i in range(1, boxes.size()):
			bounds = bounds.merge(boxes[i])
		# Translate to a neutral inspection position, without rescaling the model.
		item_node.position += Vector3(-bounds.get_center().x, 0.12 - bounds.position.y, -bounds.get_center().z)
		item_focus = Vector3(0, 0.12 + bounds.size.y * 0.5, 0)
		item_distance = clampf(bounds.size.length() * 2.0, 0.25, 12.0)
	else:
		item_focus = Vector3(0, 1, 0)
		item_distance = 4.0
	focus = item_focus
	distance = item_distance
	status.text = "%d peças" % items.size()
	details.text = str(record["name"]) + " | " + str(record["pack"]) + " | CC0"
	_update_camera()
	_update_transport()

func _collect_bounds(node: Node, boxes: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(node.global_transform * node.get_aabb())
	for child in node.get_children():
		_collect_bounds(child, boxes)

func _set_speed(index: int) -> void:
	if index < 0 or index >= SPEEDS.size():
		return
	playback_speed = float(SPEEDS[index])
	speed_picker.select(index)
	if is_instance_valid(player):
		player.speed_scale = playback_speed

func _replay() -> void:
	if not is_instance_valid(player) or selected_clip == &"":
		return
	player.stop()
	for clip in original_modes:
		player.get_animation(clip).loop_mode = original_modes[clip]
	var animation := player.get_animation(selected_clip)
	animation.loop_mode = Animation.LOOP_LINEAR if loop_toggle.button_pressed else Animation.LOOP_NONE
	player.play(selected_clip)
	player.seek(0.0, true)
	details.text = "%s | %.2f s | %d tracks" % [selected_clip, animation.length, animation.get_track_count()]

func _process(delta: float) -> void:
	diagnostics_elapsed += delta
	if diagnostics_elapsed >= 0.10:
		diagnostics_elapsed = 0.0
		if is_instance_valid(inspection_controls) and inspection_controls.is_visible_in_tree():
			_update_inspection()

func _clip_length() -> float:
	if not is_instance_valid(player) or selected_clip == &"":
		return 0.0
	var anim := player.get_animation(selected_clip)
	return anim.length if anim != null else 0.0

func _seek_phase(value: float) -> void:
	if item_mode or not is_instance_valid(player):
		return
	var length := _clip_length()
	if length <= 0.0:
		return
	# Assign the selected clip if one-shot has ended, then stop advancement.
	if player.assigned_animation != selected_clip:
		player.play(selected_clip)
	player.pause()
	player.seek(clampf(value, 0.0, 1.0) * length, true)
	_update_inspection()

func _step_time(direction: int) -> void:
	var length := _clip_length()
	if length > 0.0 and not item_mode:
		_seek_phase((player.current_animation_position + float(direction) / 60.0) / length)

func _context_gap(point: Vector3) -> float:
	if not is_instance_valid(context_root) or context_root.get_child_count() < 2:
		return INF
	var body := context_root.get_child(1) as StaticBody3D
	if body == null or body.get_child_count() == 0:
		return INF
	var collision := body.get_child(0) as CollisionShape3D
	if collision == null or not collision.shape is BoxShape3D:
		return INF
	var shape := collision.shape as BoxShape3D
	var local := collision.to_local(point)
	var q := local.abs() - shape.size * 0.5
	# Signed distance: positive outside, negative inside the approximate box.
	return q.max(Vector3.ZERO).length() + minf(maxf(q.x, maxf(q.y, q.z)), 0.0)

func _update_inspection() -> void:
	if item_mode or not is_instance_valid(player):
		return
	var length := _clip_length()
	if length > 0.0:
		var t := clampf(player.current_animation_position, 0.0, length)
		phase_slider.set_value_no_signal(t / length)
		phase_label.text = "%.3f / %.3f s | %.1f%%" % [t, length, 100.0 * t / length]
	if not is_instance_valid(context_root) or not is_instance_valid(skeleton) or contact_picker.selected < 0:
		contact_label.text = "Selecione um objeto de contexto e um osso."
		return
	var bone := contact_picker.get_selected_id()
	if bone < 0 or bone >= skeleton.get_bone_count():
		return
	var point := skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
	var gap := _context_gap(point)
	if not is_finite(gap):
		contact_label.text = "Colisor indisponível"
		return
	var description := "fora" if gap > CONTACT_TOLERANCE else ("dentro" if gap < -CONTACT_TOLERANCE else "próximo")
	contact_label.text = "%s: %.1f cm (%s) | caixa aproximada" % [skeleton.get_bone_name(bone), gap * 100.0, description]

func _update_camera() -> void:
	camera.position = focus + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))*distance
	camera.look_at(focus)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		var previous: Vector2 = touches.get(event.index, event.position)
		touches[event.index] = event.position
		if touches.size() == 2:
			for index in touches:
				if index != event.index:
					var other: Vector2 = touches[index]
					var before := previous.distance_to(other)
					var after: float = event.position.distance_to(other)
					if before > 1.0 and after > 1.0:
						distance = clampf(distance * before / after, 0.15 if item_mode else 1.5, 12.0)
		else:
			yaw -= event.relative.x * 0.006
			pitch = clampf(pitch + event.relative.y * 0.006, -0.15, 1.2)
		_update_camera()
