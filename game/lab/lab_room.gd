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
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Array or parsed.is_empty():
		status.text = "Catálogo vazio ou inválido."
		return
	records = parsed
	for record in records:
		scene_picker.add_item(str(record["pack"]) + " | " + str(record["sourcePath"]).get_file())
	_load_scene(0)

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
	reset.pressed.connect(func(): yaw = 0.65; pitch = 0.24; distance = 4.0; _update_camera())
	var bottom := PanelContainer.new()
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_top = -240
	bottom.offset_bottom = -20
	panel = VBoxContainer.new()
	bottom.add_child(panel)
	toggle.pressed.connect(func(): bottom.visible = not bottom.visible)
	scene_picker = OptionButton.new()
	panel.add_child(scene_picker)
	scene_picker.item_selected.connect(_load_scene)
	clip_picker = OptionButton.new()
	panel.add_child(clip_picker)
	clip_picker.item_selected.connect(_select_clip)
	var row := HBoxContainer.new()
	panel.add_child(row)
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
	pause.pressed.connect(func(): if is_instance_valid(player): player.pause())
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(details)

func _load_scene(index: int) -> void:
	if is_instance_valid(actor):
		remove_child(actor)
		actor.queue_free()
	actor = null
	player = null
	original_modes.clear()
	clip_picker.clear()
	clips.clear()
	selected_clip = &""
	var record: Dictionary = records[index]
	var packed = load(str(record["path"]))
	if not packed is PackedScene:
		status.text = "Falha ao importar asset"
		return
	var node = packed.instantiate()
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
	selected_clip = StringName(clips[index])
	_replay()

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
					var after := event.position.distance_to(other)
					if before > 1.0 and after > 1.0:
						distance = clampf(distance * before / after, 1.5, 12.0)
		else:
			yaw -= event.relative.x * 0.006
			pitch = clampf(pitch + event.relative.y * 0.006, -0.15, 1.2)
		_update_camera()
