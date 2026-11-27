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
	mode_picker.set_item_disabled(1, items.is_empty())

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
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(details)

func _load_scene(index: int) -> void:
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
