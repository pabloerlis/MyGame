extends Node3D
const Labels = preload("res://lab/labels_pt.gd")
const EquipmentRules = preload("res://lab/equipment_rules.gd")
var category_profiles := {}
var compatible_only: CheckButton
var auto_action: CheckButton
var review_notes: TextEdit
var review_verdict: OptionButton
var review_status: Label
var review_records: Array = []
var review_path := "user://lab-reviews-v1.json"
var review_dialog: FileDialog
var export_payload := ""
var grip_source := ""
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
const TOUCH_HEIGHT := 72.0
var hud_top: HBoxContainer
var hud_nav: PanelContainer
var settings_button: Button
var settings_back: Button
var settings_tabs: GridContainer
var settings_scroll: ScrollContainer
var scene_controls: VBoxContainer
var sections: Array[VBoxContainer] = []
var section_buttons: Array[Button] = []
var settings_section := 1
var picker_buttons := {}
var choice_overlay: PanelContainer
var choice_title: Label
var choice_search: LineEdit
var choice_scroll: ScrollContainer
var choice_list: VBoxContainer
var choice_picker: OptionButton
var choice_count: Label
var settings_open := false
var menu_transparency := 40.0
var transparency_slider: HSlider
var transparency_label: Label
var settings_theme: Theme
var settings_preferences_path := "user://lab-interface-v1.cfg"
var object_scales := {}
var scale_controls := {}
var context_record_index := -1
var context_base_size := Vector3.ZERO
var item_base_size := Vector3.ZERO
var item_pivot: Node3D
var equipped_scale_slider: HSlider
var equipped_scale_label: Label
const MIN_OBJECT_SCALE := 0.1
const MAX_OBJECT_SCALE := 5.0

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
	_load_menu_preferences()
	_load_grip_profiles()
	_load_reviews()
	var file := FileAccess.open("res://assets/runtime/catalog.json", FileAccess.READ)
	if file == null:
		status.text = "Assets ausentes. Execute o pipeline de aquisição."
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Array or parsed.is_empty():
		status.text = "Catálogo vazio ou inválido."
		return
	records = parsed
	for i in range(records.size()):
		scene_picker.add_item(Labels.scene(records[i], i))
	_load_scene(0)
	var item_file := FileAccess.open("res://assets/runtime/items.json", FileAccess.READ)
	if item_file != null:
		var parsed_items: Variant = JSON.parse_string(item_file.get_as_text())
		if parsed_items is Array:
			items = parsed_items
	for i in range(items.size()):
		var item: Dictionary = items[i]
		item_picker.add_item(Labels.item(str(item["name"]), i) + " | " + Labels.pack(str(item["pack"])))
	for i in range(items.size()):
		var record: Dictionary = items[i]
		var name := str(record["name"]).to_lower()
		if record["pack"] == "medieval_weapons_pack" or name.begins_with("sword") or name.begins_with("axe") or name.begins_with("bow") or name.begins_with("dagger") or name.begins_with("hammer") or EquipmentRules.category(name) != "other":
			equipment_indices.append(i)
			equipment_picker.add_item(Labels.item(str(record["name"]), i) + " | " + Labels.pack(str(record["pack"])))
	for i in range(items.size()):
		var record: Dictionary = items[i]
		var name := str(record["name"]).to_lower()
		if record["pack"] == "rpg_items_pack" and (name.begins_with("chest") or name.begins_with("mineral") or name.begins_with("crystal") or name.begins_with("book")):
			context_indices.append(i)
			context_picker.add_item(Labels.item(str(record["name"]), i))
	context_toggle.disabled = context_indices.is_empty()
	mode_picker.set_item_disabled(1, items.is_empty())
	equipment_toggle.disabled = equipment_indices.is_empty() or not is_instance_valid(skeleton)
	_refresh_sections()
	_refresh_picker_labels()

func _create_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _mobile_theme()
	var top := HBoxContainer.new()
	root.add_child(top)
	hud_top = top
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 24
	status = Label.new()
	status.text = "MyGame Lab"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.clip_text = true
	top.add_child(status)
	settings_button = Button.new()
	settings_button.text = "Configurar"
	top.add_child(settings_button)
	settings_button.pressed.connect(_set_settings.bind(true))
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
	hud_nav = nav
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_left = 12
	nav.offset_right = -12
	nav.offset_top = -112
	nav.offset_bottom = -16
	var nav_row := HBoxContainer.new()
	nav.add_child(nav_row)
	previous_button = Button.new()
	previous_button.text = "◀ Anterior"
	previous_button.custom_minimum_size = Vector2(122, 80)
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
	next_button.custom_minimum_size = Vector2(122, 80)
	next_button.disabled = true
	nav_row.add_child(next_button)
	next_button.pressed.connect(func(): _step_clip(1))
	# Separate full-screen settings page. The 3D room is never reloaded.
	catalog_panel = PanelContainer.new()
	root.add_child(catalog_panel)
	catalog_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_theme = _mobile_theme()
	catalog_panel.theme = settings_theme
	catalog_panel.add_theme_stylebox_override("panel", _flat(Color("#151d28"), 0, 24))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	catalog_panel.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var settings_title := Label.new()
	settings_title.text = "Configurações"
	settings_title.add_theme_font_size_override("font_size", 32)
	settings_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(settings_title)
	settings_back = Button.new()
	settings_back.text = "Voltar à sala"
	heading.add_child(settings_back)
	settings_back.pressed.connect(_set_settings.bind(false))
	transparency_label = Label.new()
	transparency_label.text = "Transparência do menu: 40%"
	transparency_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(transparency_label)
	transparency_slider = HSlider.new()
	transparency_slider.min_value = 0
	transparency_slider.max_value = 90
	transparency_slider.step = 5
	transparency_slider.value = menu_transparency
	transparency_slider.custom_minimum_size.y = 52
	layout.add_child(transparency_slider)
	transparency_slider.value_changed.connect(_set_menu_transparency)
	transparency_slider.drag_ended.connect(func(_changed): _save_menu_preferences())
	settings_tabs = GridContainer.new()
	settings_tabs.columns = 3
	settings_tabs.add_theme_constant_override("h_separation", 8)
	settings_tabs.add_theme_constant_override("v_separation", 8)
	layout.add_child(settings_tabs)
	for section_name in ["Cena", "Movimentos", "Equipamentos", "Objetos", "Tempo", "Revisão"]:
		var tab := Button.new()
		tab.text = section_name
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.clip_text = true
		tab.add_theme_font_size_override("font_size", 19)
		var tab_index := section_buttons.size()
		section_buttons.append(tab)
		settings_tabs.add_child(tab)
		tab.pressed.connect(_select_settings_section.bind(tab_index))
	settings_scroll = ScrollContainer.new()
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(settings_scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 18)
	settings_scroll.add_child(panel)
	for i in range(6):
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 14)
		panel.add_child(section)
		sections.append(section)
	scene_controls = sections[0]
	animation_controls = sections[1]
	equipment_controls = sections[2]
	context_controls = sections[3]
	inspection_controls = sections[4]
	equipment_toggle = section_buttons[2]
	context_toggle = section_buttons[3]
	inspection_toggle = section_buttons[4]
	_section_heading(scene_controls, "Modo de inspeção", "Escolha o que deseja visualizar na sala.")
	mode_picker = OptionButton.new()
	mode_picker.add_item("Personagens e animações")
	mode_picker.add_item("Inspecionar peças")
	mode_picker.set_item_disabled(1, true)
	scene_controls.add_child(mode_picker)
	mode_picker.item_selected.connect(_set_mode)
	item_picker = OptionButton.new()
	item_picker.fit_to_longest_item = false
	_long_picker(scene_controls, "Peça", item_picker)
	_make_scale_controls(scene_controls, 0)
	item_picker.item_selected.connect(_load_item)
	scene_picker = OptionButton.new()
	scene_picker.fit_to_longest_item = false
	_long_picker(scene_controls, "Personagem / biblioteca", scene_picker)
	scene_picker.item_selected.connect(_load_scene)
	_section_heading(animation_controls, "Animação", "Selecione o movimento e como ele será reproduzido.")
	clip_picker = OptionButton.new()
	clip_picker.fit_to_longest_item = false
	_long_picker(animation_controls, "Movimento", clip_picker)
	clip_picker.item_selected.connect(_select_clip)
	compatible_only = CheckButton.new()
	compatible_only.text = "Somente movimentos compatíveis"
	animation_controls.add_child(compatible_only)
	var row := HBoxContainer.new()
	animation_controls.add_child(row)
	loop_toggle = CheckButton.new()
	loop_toggle.text = "Repetir"
	loop_toggle.button_pressed = true
	animation_controls.add_child(loop_toggle)
	animation_controls.move_child(loop_toggle, row.get_index())
	loop_toggle.toggled.connect(func(_value): _replay())
	play_button = Button.new()
	play_button.text = "Reproduzir"
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(play_button)
	play_button.pressed.connect(_replay)
	var pause := Button.new()
	pause.text = "Pausa"
	pause.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_section_heading(equipment_controls, "Equipamentos", "Escolha a mão, a peça e o osso. Ajustes salvos automaticamente.")
	slot_picker = OptionButton.new()
	slot_picker.add_item("Mão direita")
	slot_picker.add_item("Mão esquerda")
	equipment_controls.add_child(slot_picker)
	slot_picker.item_selected.connect(_switch_slot)
	equipment_picker = OptionButton.new()
	equipment_picker.fit_to_longest_item = false
	equipment_picker.add_item("Sem equipamento")
	_long_picker(equipment_controls, "Equipamento", equipment_picker)
	equipment_picker.item_selected.connect(_equip_and_suggest)
	auto_action = CheckButton.new()
	auto_action.text = "Escolher movimento compatível"
	auto_action.button_pressed = true
	equipment_controls.add_child(auto_action)
	var suggest := Button.new()
	suggest.text = "Ver movimentos compatíveis"
	equipment_controls.add_child(suggest)
	suggest.pressed.connect(_show_compatible)
	var reuse := Button.new()
	reuse.text = "Reutilizar este encaixe na categoria"
	equipment_controls.add_child(reuse)
	reuse.pressed.connect(_save_category_grip)
	bone_picker = OptionButton.new()
	bone_picker.fit_to_longest_item = false
	_long_picker(equipment_controls, "Osso de encaixe", bone_picker)
	bone_picker.item_selected.connect(func(_index): _choose_equipment(equipment_picker.selected))
	var adjust_row := HBoxContainer.new()
	equipment_controls.add_child(adjust_row)
	axis_picker = OptionButton.new()
	for axis_name in ["Pos X", "Pos Y", "Pos Z", "Rot X", "Rot Y", "Rot Z"]:
		axis_picker.add_item(axis_name)
	axis_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_controls.add_child(axis_picker)
	equipment_controls.move_child(axis_picker, adjust_row.get_index())
	for direction in [-1, 1]:
		var step_button := Button.new()
		step_button.text = "−" if direction == -1 else "+"
		step_button.custom_minimum_size = Vector2(84, TOUCH_HEIGHT)
		step_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		adjust_row.add_child(step_button)
		step_button.pressed.connect(_adjust_grip.bind(direction))
	var reset_grip := Button.new()
	reset_grip.text = "Zerar"
	adjust_row.add_child(reset_grip)
	reset_grip.pressed.connect(_reset_grip)
	equip_label = Label.new()
	equip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_controls.add_child(equip_label)
	equipped_scale_label = Label.new()
	equipped_scale_label.text = "Tamanho do equipamento: 100%"
	equipment_controls.add_child(equipped_scale_label)
	equipped_scale_slider = HSlider.new()
	equipped_scale_slider.min_value = MIN_OBJECT_SCALE * 100.0
	equipped_scale_slider.max_value = MAX_OBJECT_SCALE * 100.0
	equipped_scale_slider.step = 5.0
	equipped_scale_slider.value = 100
	equipped_scale_slider.custom_minimum_size.y = 60
	equipment_controls.add_child(equipped_scale_slider)
	equipped_scale_slider.value_changed.connect(_set_equipped_scale)
	var equip_size_reset := Button.new()
	equip_size_reset.text = "Restaurar tamanho do equipamento"
	equipment_controls.add_child(equip_size_reset)
	equip_size_reset.pressed.connect(_set_equipped_scale.bind(100.0))
	_section_heading(context_controls, "Objetos de contexto", "Escolha e posicione o objeto junto ao personagem.")
	context_picker = OptionButton.new()
	context_picker.fit_to_longest_item = false
	context_picker.add_item("Sem objeto")
	_long_picker(context_controls, "Objeto", context_picker)
	context_picker.item_selected.connect(_choose_context)
	var context_row := HBoxContainer.new()
	context_controls.add_child(context_row)
	context_axis = OptionButton.new()
	for axis_name in ["X lateral", "Y altura", "Z distância"]:
		context_axis.add_item(axis_name)
	context_axis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_controls.add_child(context_axis)
	context_controls.move_child(context_axis, context_row.get_index())
	for direction in [-1, 1]:
		var step := Button.new()
		step.text = "−" if direction == -1 else "+"
		step.custom_minimum_size = Vector2(84, TOUCH_HEIGHT)
		step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		context_row.add_child(step)
		step.pressed.connect(_adjust_context.bind(direction))
	var context_reset := Button.new()
	context_reset.text = "Zerar"
	context_row.add_child(context_reset)
	context_reset.pressed.connect(_reset_context)
	context_label = Label.new()
	context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_controls.add_child(context_label)
	_make_scale_controls(context_controls, 1)
	_section_heading(inspection_controls, "Tempo e contato", "Pause em um instante e confira a distância ao objeto.")
	phase_label = Label.new()
	phase_label.text = "Tempo da animação"
	inspection_controls.add_child(phase_label)
	phase_slider = HSlider.new()
	phase_slider.min_value = 0.0
	phase_slider.max_value = 1.0
	phase_slider.step = 0.001
	phase_slider.custom_minimum_size.y = 64
	inspection_controls.add_child(phase_slider)
	phase_slider.value_changed.connect(_seek_phase)
	var frame_row := HBoxContainer.new()
	inspection_controls.add_child(frame_row)
	for direction in [-1, 1]:
		var step_frame := Button.new()
		step_frame.text = "− 1/60 s" if direction == -1 else "+ 1/60 s"
		step_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		step_frame.custom_minimum_size.y = TOUCH_HEIGHT
		frame_row.add_child(step_frame)
		step_frame.pressed.connect(_step_time.bind(direction))
	contact_picker = OptionButton.new()
	contact_picker.fit_to_longest_item = false
	_long_picker(inspection_controls, "Osso de referência", contact_picker)
	contact_picker.item_selected.connect(func(_index): _update_inspection())
	contact_label = Label.new()
	contact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspection_controls.add_child(contact_label)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(details)
	_create_review_ui(sections[5], root)
	_create_choice_overlay(root)
	_set_menu_transparency(menu_transparency)
	_touch_sizes(root)
	_select_settings_section(1)
	_set_settings(false)

func _flat(color: Color, radius: int, inset: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	return style

func _mobile_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 23
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, _flat(Color("#253347"), 14))
		theme.set_stylebox("hover", type, _flat(Color("#304258"), 14))
		theme.set_stylebox("pressed", type, _flat(Color("#116b70"), 14))
		theme.set_stylebox("disabled", type, _flat(Color("#202936"), 14))
		theme.set_color("font_color", type, Color("#edf4f7"))
		theme.set_color("font_disabled_color", type, Color("#788594"))
		theme.set_color("font_pressed_color", type, Color.WHITE)
	theme.set_stylebox("panel", "PanelContainer", _flat(Color("#17212e"), 16, 10))
	theme.set_stylebox("normal", "LineEdit", _flat(Color("#243449"), 14))
	theme.set_stylebox("focus", "LineEdit", _flat(Color("#294251"), 14))
	theme.set_color("font_color", "Label", Color("#e5edf4"))
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	theme.set_constant("v_separation", "PopupMenu", 24)
	theme.set_constant("h_separation", "PopupMenu", 16)
	return theme

func _touch_sizes(node: Node) -> void:
	if node is BaseButton or node is LineEdit:
		var control := node as Control
		control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, TOUCH_HEIGHT)
	for child in node.get_children():
		_touch_sizes(child)

func _section_heading(parent: VBoxContainer, title: String, subtitle: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 30)
	parent.add_child(label)
	var hint := Label.new()
	hint.text = subtitle
	hint.modulate = Color("#afc1ce")
	hint.add_theme_font_size_override("font_size", 20)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(hint)

func _set_settings(open: bool) -> void:
	var was_open := settings_open
	settings_open = open
	if not open:
		if was_open:
			_save_menu_preferences()
		_close_choices()
	touches.clear()
	catalog_panel.visible = open
	hud_top.visible = not open
	hud_nav.visible = not open
	if open:
		_refresh_sections()
		_refresh_picker_labels()
		_refresh_scale_controls(0)
		_refresh_scale_controls(1)
		_refresh_equipped_scale()

func _select_settings_section(index: int) -> void:
	if index < 0 or index >= sections.size():
		return
	if item_mode and index != 0 and index != 5:
		index = 0
	settings_section = index
	_refresh_sections()
	settings_scroll.scroll_vertical = 0

func _refresh_sections() -> void:
	if item_mode and settings_section != 5:
		settings_section = 0
	for i in range(sections.size()):
		sections[i].visible = i == settings_section
		section_buttons[i].set_pressed_no_signal(i == settings_section)
		if i != 0:
			section_buttons[i].disabled = (item_mode and i != 5) or (i == 2 and (equipment_indices.is_empty() or not is_instance_valid(skeleton))) or (i == 3 and context_indices.is_empty())
	if picker_buttons.has(scene_picker):
		(picker_buttons[scene_picker]["group"] as Control).visible = not item_mode
	if picker_buttons.has(item_picker):
		(picker_buttons[item_picker]["group"] as Control).visible = item_mode
	if scale_controls.has(0):
		(scale_controls[0]["group"] as Control).visible = item_mode

func _long_picker(parent: VBoxContainer, title: String, picker: OptionButton) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 6)
	parent.add_child(group)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 20)
	group.add_child(label)
	group.add_child(picker)
	picker.hide()
	var button := Button.new()
	button.text = "Selecionar"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size.y = TOUCH_HEIGHT
	group.add_child(button)
	button.pressed.connect(_open_choices.bind(picker, title))
	picker_buttons[picker] = {"button": button, "group": group}

func _refresh_picker_labels() -> void:
	for picker in picker_buttons:
		var button: Button = picker_buttons[picker]["button"]
		button.disabled = picker.disabled or picker.item_count == 0
		button.text = (picker.get_item_text(picker.selected) if picker.selected >= 0 else "Selecionar") + "  ›"

func _create_choice_overlay(root: Control) -> void:
	choice_overlay = PanelContainer.new()
	root.add_child(choice_overlay)
	choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_overlay.theme = settings_theme
	choice_overlay.add_theme_stylebox_override("panel", _flat(Color("#151d28"), 0, 24))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	choice_overlay.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	choice_title = Label.new()
	choice_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_title.add_theme_font_size_override("font_size", 28)
	header.add_child(choice_title)
	var back := Button.new()
	back.text = "Voltar"
	header.add_child(back)
	back.pressed.connect(_close_choices)
	choice_search = LineEdit.new()
	choice_search.placeholder_text = "Pesquisar..."
	choice_search.clear_button_enabled = true
	layout.add_child(choice_search)
	choice_search.text_changed.connect(_rebuild_choices)
	choice_count = Label.new()
	layout.add_child(choice_count)
	choice_scroll = ScrollContainer.new()
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choice_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(choice_scroll)
	choice_list = VBoxContainer.new()
	choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_list.add_theme_constant_override("separation", 8)
	choice_scroll.add_child(choice_list)
	choice_overlay.hide()

func _open_choices(picker: OptionButton, title: String) -> void:
	if picker.item_count == 0:
		return
	choice_picker = picker
	choice_title.text = title
	choice_search.text = ""
	catalog_panel.hide()
	choice_overlay.show()
	_rebuild_choices("")

func _close_choices() -> void:
	if not is_instance_valid(choice_overlay):
		return
	choice_search.release_focus()
	choice_overlay.hide()
	choice_picker = null
	catalog_panel.visible = settings_open

func _fold_text(value: String) -> String:
	var text := value.to_lower().strip_edges()
	for pair in [["á", "a"], ["à", "a"], ["ã", "a"], ["â", "a"], ["é", "e"], ["ê", "e"], ["í", "i"], ["ó", "o"], ["ô", "o"], ["õ", "o"], ["ú", "u"], ["ç", "c"]]:
		text = text.replace(pair[0], pair[1])
	return text

func _rebuild_choices(query: String) -> void:
	for child in choice_list.get_children():
		choice_list.remove_child(child)
		child.queue_free()
	if not is_instance_valid(choice_picker):
		return
	var search := _fold_text(query)
	var count := 0
	for i in range(choice_picker.item_count):
		if choice_picker == clip_picker and compatible_only.button_pressed and not _compatible_clip(i):
			continue
		var name := choice_picker.get_item_text(i)
		if not search.is_empty() and not _fold_text(name).contains(search):
			continue
		var button := Button.new()
		button.text = ("✓  " if i == choice_picker.selected else "") + name
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.custom_minimum_size.y = TOUCH_HEIGHT
		button.disabled = choice_picker.is_item_disabled(i)
		choice_list.add_child(button)
		button.pressed.connect(_choose_search_result.bind(i))
		count += 1
	choice_count.text = "%d opções" % count
	choice_scroll.scroll_vertical = 0

func _choose_search_result(index: int) -> void:
	if not is_instance_valid(choice_picker) or index < 0 or index >= choice_picker.item_count or choice_picker.is_item_disabled(index):
		return
	var picker := choice_picker
	_close_choices()
	picker.select(index)
	picker.item_selected.emit(index)
	_refresh_picker_labels()

func _set_menu_transparency(value: float) -> void:
	menu_transparency = clampf(value, 0.0, 90.0)
	if is_instance_valid(transparency_slider):
		transparency_slider.set_value_no_signal(menu_transparency)
		transparency_label.text = "Transparência do menu: %d%%" % int(menu_transparency)
	var opacity := 1.0 - menu_transparency / 100.0
	for page in [catalog_panel, choice_overlay]:
		if is_instance_valid(page):
			var style := page.get_theme_stylebox("panel") as StyleBoxFlat
			if style != null:
				var color := style.bg_color
				color.a = opacity
				style.bg_color = color
	# Fade only the backgrounds: text and hit areas remain fully opaque/active.
	if settings_theme != null:
		for type in ["Button", "OptionButton", "LineEdit"]:
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				if not settings_theme.has_stylebox(state, type):
					continue
				var style := settings_theme.get_stylebox(state, type) as StyleBoxFlat
				if style != null:
					var color := style.bg_color
					color.a = maxf(0.18, opacity)
					style.bg_color = color
		for type in ["Label", "Button", "OptionButton", "CheckButton", "LineEdit"]:
			settings_theme.set_color("font_outline_color", type, Color("#101820"))
			settings_theme.set_constant("outline_size", type, 3)

func _load_menu_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(settings_preferences_path) == OK:
		var saved: Variant = config.get_value("interface", "transparency", 40.0)
		if (saved is float or saved is int) and is_finite(float(saved)):
			_set_menu_transparency(float(saved))

func _save_menu_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("interface", "transparency", menu_transparency)
	config.save(settings_preferences_path)

func _make_scale_controls(parent: VBoxContainer, target: int) -> void:
	var group := VBoxContainer.new()
	parent.add_child(group)
	_section_heading(group, "Tamanho do objeto", "100% corresponde ao tamanho original. Ajuste todos os eixos ou um eixo por vez.")
	var axis := OptionButton.new()
	for option in ["Uniforme (X, Y e Z)", "Largura (X)", "Altura (Y)", "Profundidade (Z)"]:
		axis.add_item(option)
	group.add_child(axis)
	var slider := HSlider.new()
	slider.min_value = MIN_OBJECT_SCALE * 100.0
	slider.max_value = MAX_OBJECT_SCALE * 100.0
	slider.step = 1.0
	slider.value = 100.0
	slider.custom_minimum_size.y = 60
	group.add_child(slider)
	var row := HBoxContainer.new()
	group.add_child(row)
	for direction in [-1, 1]:
		var step := Button.new()
		step.text = "− 5%" if direction == -1 else "+ 5%"
		step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(step)
		step.pressed.connect(func(): slider.value += direction * 5.0)
	var reset := Button.new()
	reset.text = "Tamanho original"
	group.add_child(reset)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group.add_child(label)
	scale_controls[target] = {"group": group, "axis": axis, "slider": slider, "label": label}
	axis.item_selected.connect(func(_index): _refresh_scale_controls(target))
	slider.value_changed.connect(_set_object_scale.bind(target))
	reset.pressed.connect(_reset_object_scale.bind(target))
	_refresh_scale_controls(target)

func _scale_record_index(target: int) -> int:
	if target == 0:
		return item_index if is_instance_valid(item_node) else -1
	return context_record_index if is_instance_valid(context_root) else -1

func _object_scale(index: int) -> Vector3:
	return object_scales.get(index, Vector3.ONE)

func _set_object_scale(percent: float, target: int) -> void:
	var index := _scale_record_index(target)
	if index < 0:
		return
	var axis: OptionButton = scale_controls[target]["axis"]
	var factor := clampf(percent / 100.0, MIN_OBJECT_SCALE, MAX_OBJECT_SCALE)
	var factors := _object_scale(index)
	if axis.selected == 0:
		factors = Vector3.ONE * factor
	else:
		factors[axis.selected - 1] = factor
	object_scales[index] = factors
	_apply_object_scales(index)

func _reset_object_scale(target: int) -> void:
	var index := _scale_record_index(target)
	if index >= 0:
		object_scales.erase(index)
		_apply_object_scales(index)

func _apply_object_scales(index: int) -> void:
	if context_record_index == index and is_instance_valid(context_root):
		_apply_context_scale()
	if item_index == index and is_instance_valid(item_node):
		_apply_item_scale(false)
	_refresh_scale_controls(0)
	_refresh_scale_controls(1)

func _refresh_scale_controls(target: int) -> void:
	if not scale_controls.has(target):
		return
	var ui: Dictionary = scale_controls[target]
	var index := _scale_record_index(target)
	var slider: HSlider = ui["slider"]
	var axis: OptionButton = ui["axis"]
	var label: Label = ui["label"]
	slider.editable = index >= 0
	if index < 0:
		label.text = "Selecione um objeto para ajustar."
		return
	var factors := _object_scale(index)
	var component := maxi(0, axis.selected - 1)
	slider.set_value_no_signal(factors[component] * 100.0)
	var size := (item_base_size if target == 0 else context_base_size) * factors
	label.text = "X %.0f%%  |  Y %.0f%%  |  Z %.0f%%\nL %.2f × A %.2f × P %.2f m" % [factors.x * 100.0, factors.y * 100.0, factors.z * 100.0, size.x, size.y, size.z]
	if axis.selected == 0 and (not is_equal_approx(factors.x, factors.y) or not is_equal_approx(factors.x, factors.z)):
		label.text += "\nEscalas diferentes; ajuste uniforme iguala os eixos."

func _apply_context_scale() -> void:
	if not is_instance_valid(context_root) or context_root.get_child_count() < 2:
		return
	var factors := _object_scale(context_record_index)
	var pivot := context_root.get_child(0) as Node3D
	var body := context_root.get_child(1) as StaticBody3D
	pivot.scale = factors
	var size := context_base_size * factors
	body.position = Vector3(0.0, size.y * 0.5, 0.0)
	var collision := body.get_child(0) as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	shape.size = size.max(Vector3(0.01, 0.01, 0.01))
	_update_context()

func _apply_item_scale(reframe: bool) -> void:
	if not is_instance_valid(item_pivot):
		return
	var factors := _object_scale(item_index)
	item_pivot.scale = factors
	var size := item_base_size * factors
	item_focus = Vector3(0, 0.12 + size.y * 0.5, 0)
	item_distance = clampf(size.length() * 2.0, 0.25, 12.0)
	if item_mode:
		focus = item_focus
		if reframe:
			distance = item_distance
		_update_camera()

func _set_equipped_scale(percent: float) -> void:
	if not is_instance_valid(grip):
		return
	grip.scale = Vector3.ONE * clampf(percent / 100.0, MIN_OBJECT_SCALE, MAX_OBJECT_SCALE)
	grip_source = "manual"
	grip_profiles[active_profile] = grip.transform
	_save_grip_profiles()
	_update_grip_label()

func _refresh_equipped_scale() -> void:
	if not is_instance_valid(equipped_scale_slider):
		return
	equipped_scale_slider.editable = is_instance_valid(grip)
	var percent := grip.scale.x * 100.0 if is_instance_valid(grip) else 100.0
	equipped_scale_slider.set_value_no_signal(percent)
	equipped_scale_label.text = "Tamanho do equipamento: %.0f%%" % percent

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
		status.text = "Falha ao importar modelo"
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
		status.text = "Sem animações importadas"
		return
	clips = player.get_animation_list()
	player.speed_scale = playback_speed
	for clip in clips:
		clip_picker.add_item(Labels.clip(clip, clip_picker.item_count))
		original_modes[clip] = player.get_animation(clip).loop_mode
	status.text = "%s movimentos" % clips.size()
	details.text = Labels.pack(str(record["pack"])) + " • CC0"
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
		bone_picker.add_item(Labels.bone(str(skeleton.get_bone_name(i)), i), i)
		contact_picker.add_item(Labels.bone(str(skeleton.get_bone_name(i)), i), i)
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
		"picker": equipment_picker.selected, "source": grip_source
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
	grip_source = str(state.get("source", ""))
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
	category_profiles.clear()
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
	for key in config.get_section_keys("categories") if config.has_section("categories") else PackedStringArray():
		var value: Variant = config.get_value("categories", key)
		if value is Transform3D and value.is_finite():
			category_profiles[key] = value
	profile_status = ""

func _save_grip_profiles() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "schema", 1)
	for key in grip_profiles:
		config.set_value("grips", key, grip_profiles[key])
	for key in category_profiles:
		config.set_value("categories", key, category_profiles[key])
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
	_apply_grip_default()
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
	grip_source = "manual"
	grip_profiles[active_profile] = grip.transform
	_save_grip_profiles()
	_update_grip_label()

func _reset_grip() -> void:
	if is_instance_valid(grip):
		grip_profiles.erase(active_profile)
		_apply_grip_default()
		_save_grip_profiles()
		_update_grip_label()

func _update_grip_label() -> void:
	_refresh_equipped_scale()
	if is_instance_valid(grip):
		equip_label.text = "%s | P %.2f %.2f %.2f m | R %.0f %.0f %.0f°" % [Labels.bone(str(attachment.bone_name), attachment.bone_idx), grip.position.x, grip.position.y, grip.position.z, grip.rotation_degrees.x, grip.rotation_degrees.y, grip.rotation_degrees.z] + profile_status + " | " + EquipmentRules.source_label(grip_source)

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
		clip_caption.text = "%d/%d\n%s" % [item_index + 1, items.size(), Labels.item(str(items[item_index]["name"]), item_index)] if item_index >= 0 else "—"
		return
	var available := clip_index >= 0 and clip_index < clips.size()
	previous_button.disabled = not available or clips.size() < 2
	next_button.disabled = not available or clips.size() < 2
	clip_caption.text = "%d/%d\n%s" % [clip_index + 1, clips.size(), Labels.clip(str(selected_clip), clip_index)] if available else "—"

func _set_mode(index: int) -> void:
	var new_mode := index == 1
	if new_mode == item_mode or (new_mode and items.is_empty()):
		return
	item_mode = new_mode
	mode_picker.select(index)
	_refresh_sections()
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
	context_record_index = -1
	context_base_size = Vector3.ZERO
	context_picker.select(index)
	context_offset = Vector3.ZERO
	context_label.text = "Sem objeto"
	_refresh_scale_controls(1)
	if index <= 0 or index > context_indices.size():
		return
	var record_index: int = context_indices[index - 1]
	var record: Dictionary = items[record_index]
	var packed := load(str(record["path"])) as PackedScene
	if packed == null:
		context_label.text = "Falha ao carregar objeto"
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		return
	context_root = Node3D.new()
	add_child(context_root)
	var pivot := Node3D.new()
	context_root.add_child(pivot)
	pivot.add_child(model)
	var boxes: Array[AABB] = []
	_collect_bounds(model, boxes)
	if boxes.is_empty():
		return
	var bounds: AABB = boxes[0]
	for i in range(1, boxes.size()):
		bounds = bounds.merge(boxes[i])
	model.position += Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
	context_record_index = record_index
	context_base_size = bounds.size
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
	_apply_context_scale()
	_refresh_scale_controls(1)

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
	item_pivot = null
	item_base_size = Vector3.ZERO

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
	item_node = Node3D.new()
	add_child(item_node)
	item_pivot = Node3D.new()
	item_node.add_child(item_pivot)
	item_pivot.add_child(node)
	item_index = index
	item_picker.select(index)
	var boxes: Array[AABB] = []
	_collect_bounds(item_node, boxes)
	if not boxes.is_empty():
		var bounds: AABB = boxes[0]
		for i in range(1, boxes.size()):
			bounds = bounds.merge(boxes[i])
		# Keep original mesh and floor anchor; scale the wrapper, not imported data.
		(node as Node3D).position += Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
		item_pivot.position = Vector3(0, 0.12, 0)
		item_base_size = bounds.size
		_apply_item_scale(true)
	else:
		item_focus = Vector3(0, 1, 0)
		item_distance = 4.0
	focus = item_focus
	distance = item_distance
	status.text = "%d peças" % items.size()
	details.text = Labels.item(str(record["name"]), index) + " | " + Labels.pack(str(record["pack"])) + " | CC0"
	_refresh_scale_controls(0)
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
	details.text = "%s | %.2f s | %d trilhas" % [Labels.clip(str(selected_clip), clip_index), animation.length, animation.get_track_count()]

func _process(delta: float) -> void:
	diagnostics_elapsed += delta
	if diagnostics_elapsed >= 0.10:
		diagnostics_elapsed = 0.0
		if is_instance_valid(catalog_panel) and catalog_panel.visible:
			_refresh_picker_labels()
			_refresh_equipped_scale()
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
	contact_label.text = "%s: %.1f cm (%s) | caixa aproximada" % [Labels.bone(str(skeleton.get_bone_name(bone)), bone), gap * 100.0, description]

func _update_camera() -> void:
	camera.position = focus + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))*distance
	camera.look_at(focus)

func _unhandled_input(event: InputEvent) -> void:
	if settings_open or choice_overlay.visible:
		return
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

# Equipment integration: preserve imported animations; suggestions are not visual approval.
func _category_key() -> String:
	if equipped_index < 0 or not is_instance_valid(attachment):
		return ""
	return "%s|%s|%s|%s" % [records[scene_picker.selected]["id"], items[equipped_index]["pack"], EquipmentRules.category(str(items[equipped_index]["name"])), attachment.bone_name]

func _apply_grip_default() -> void:
	grip.transform = Transform3D.IDENTITY
	grip_source = "pivot_unverified"
	if grip_profiles.has(active_profile):
		grip.transform = grip_profiles[active_profile]
		grip_source = "manual"
		return
	var marker := EquipmentRules.find_grip(grip.get_child(0))
	if is_instance_valid(marker):
		var local := grip.global_transform.affine_inverse() * marker.global_transform
		if local.is_finite() and absf(local.basis.determinant()) > 0.000001:
			grip.transform = local.affine_inverse()
			grip_source = "asset_marker_unverified"
			return
	var key := _category_key()
	if category_profiles.has(key):
		grip.transform = category_profiles[key]
		grip_source = "category_unverified"

func _save_category_grip() -> void:
	if not is_instance_valid(grip) or equipped_index < 0:
		return
	if EquipmentRules.category(str(items[equipped_index]["name"])) == "other":
		equip_label.text = "Categoria não identificada; use ajuste individual."
		return
	category_profiles[_category_key()] = grip.transform
	_save_grip_profiles()
	equip_label.text = "Encaixe salvo para peças da mesma categoria, coleção e rig. Revise cada resultado."

func _compatible_clip(index: int) -> bool:
	if index < 0 or index >= clips.size():
		return false
	for slot in [0, 1]:
		var idx := equipped_index if slot == active_slot else int(slot_states.get(slot, {}).get("item", -1))
		if idx >= 0 and EquipmentRules.matches(str(items[idx]["name"]), clips[index]):
			return true
	return false

func _equip_and_suggest(index: int) -> void:
	# Hand preference is applied only on user equipment selection; manual bone remains editable.
	if index > 0 and index <= equipment_indices.size():
		var category := EquipmentRules.category(str(items[equipment_indices[index - 1]]["name"]))
		if category in ["bow", "shield"] and active_slot == 0:
			var previous: Dictionary = slot_states.get(1, {})
			if not is_instance_valid(previous.get("attachment")) and hand_bones[1] >= 0:
				_switch_slot(1)
	_choose_equipment(index)
	if auto_action.button_pressed and is_instance_valid(grip) and not _compatible_clip(clip_index):
		for i in range(clips.size()):
			if _compatible_clip(i):
				_select_clip(i)
				break
	_refresh_picker_labels()

func _show_compatible() -> void:
	compatible_only.button_pressed = true
	_select_settings_section(1)
	_open_choices(clip_picker, "Movimentos compatíveis")

# Review/export: standard JSON, no Godot Variant strings or private device identifiers.
func _create_review_ui(parent: VBoxContainer, root: Control) -> void:
	_section_heading(parent, "Revisão do laboratório", "Registre cada combinação. Exporte todos os ajustes e observações em um arquivo.")
	review_verdict = OptionButton.new()
	for label in ["Não avaliado", "Aprovado", "Precisa de ajustes", "Incompatível"]:
		review_verdict.add_item(label)
	parent.add_child(review_verdict)
	review_notes = TextEdit.new()
	review_notes.placeholder_text = "Descreva o problema, o que ajustar ou o que foi aprovado…"
	review_notes.custom_minimum_size.y = 160
	review_notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	parent.add_child(review_notes)
	review_notes.text_changed.connect(_save_reviews)
	var add := Button.new()
	add.text = "Registrar teste atual"
	parent.add_child(add)
	add.pressed.connect(_record_review)
	var export := Button.new()
	export.text = "Exportar JSON"
	parent.add_child(export)
	export.pressed.connect(_export_review)
	var copy := Button.new()
	copy.text = "Copiar JSON para enviar"
	parent.add_child(copy)
	copy.pressed.connect(_copy_review)
	review_status = Label.new()
	review_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(review_status)
	review_dialog = FileDialog.new()
	root.add_child(review_dialog)
	review_dialog.access = FileDialog.ACCESS_FILESYSTEM
	review_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	review_dialog.use_native_dialog = true
	review_dialog.filters = PackedStringArray(["*.json ; JSON ; application/json"])
	review_dialog.file_selected.connect(_write_export_file)

func _vjson(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _tjson(t: Transform3D) -> Dictionary:
	return {"position": _vjson(t.origin), "basisColumns": [_vjson(t.basis.x), _vjson(t.basis.y), _vjson(t.basis.z)], "rotationDegrees": _vjson(t.basis.get_euler() * 180.0 / PI), "scale": _vjson(t.basis.get_scale())}

func _snapshot() -> Dictionary:
	var equipped: Array = []
	for slot in [0, 1]:
		var state: Dictionary = slot_states.get(slot, {})
		var idx := equipped_index if slot == active_slot else int(state.get("item", -1))
		var node: Node3D = grip if slot == active_slot else state.get("grip")
		var attached: BoneAttachment3D = attachment if slot == active_slot else state.get("attachment")
		if idx >= 0 and is_instance_valid(node) and is_instance_valid(attached):
			equipped.append({"slot": slot, "itemId": items[idx]["id"], "category": EquipmentRules.category(str(items[idx]["name"])), "bone": str(attached.bone_name), "gripSource": grip_source if slot == active_slot else state.get("source", ""), "transform": _tjson(node.transform)})
	var t := player.current_animation_position if is_instance_valid(player) else 0.0
	var length := _clip_length()
	return {"mode": "item" if item_mode else "actor", "sceneId": records[scene_picker.selected]["id"] if scene_picker.selected >= 0 and scene_picker.selected < records.size() else "", "clipId": str(selected_clip), "timeSeconds": t, "durationSeconds": length, "phase": t / length if length > 0.0 else 0.0, "loop": loop_toggle.button_pressed, "speed": playback_speed, "playing": is_instance_valid(player) and player.is_playing(), "equipment": equipped, "activeSlot": active_slot, "itemId": items[item_index]["id"] if item_index >= 0 and item_index < items.size() else "", "contextId": items[context_record_index]["id"] if context_record_index >= 0 else "", "contextOffset": _vjson(context_offset), "contactBone": str(skeleton.get_bone_name(contact_picker.get_selected_id())) if is_instance_valid(skeleton) and contact_picker.selected >= 0 else "", "camera": {"yaw": yaw, "pitch": pitch, "distance": distance, "focus": _vjson(focus)}, "menuTransparency": menu_transparency, "compatibleOnly": compatible_only.button_pressed, "autoAction": auto_action.button_pressed}

func _review_entry() -> Dictionary:
	var entry := _snapshot()
	entry["notes"] = review_notes.text
	entry["verdict"] = ["unreviewed", "approved", "needs_adjustment", "incompatible"][maxi(0, review_verdict.selected)]
	entry["reviewedAt"] = Time.get_datetime_string_from_system(true) + "Z"
	return entry

func _record_review() -> void:
	review_records.append(_review_entry())
	review_notes.text = ""
	_save_reviews()

func _save_reviews() -> void:
	var file := FileAccess.open(review_path, FileAccess.WRITE)
	if file == null:
		review_status.text = "Falha ao salvar avaliações."
		return
	file.store_string(JSON.stringify({"reviews": review_records, "draft": review_notes.text}))
	file.close()
	review_status.text = "%d testes registrados. Rascunho salvo." % review_records.size()

func _load_reviews() -> void:
	if not FileAccess.file_exists(review_path):
		return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(review_path))
	if value is Dictionary:
		var saved: Variant = value.get("reviews", [])
		if saved is Array:
			review_records = saved
		review_notes.text = str(value.get("draft", ""))
		review_status.text = "%d testes recuperados." % review_records.size()

func _report_json() -> String:
	var profiles := {}
	var categories := {}
	var scales := {}
	for key in grip_profiles:
		profiles[key] = _tjson(grip_profiles[key])
	for key in category_profiles:
		categories[key] = _tjson(category_profiles[key])
	for index in object_scales:
		if int(index) >= 0 and int(index) < items.size():
			scales[items[int(index)]["id"]] = _vjson(object_scales[index])
	return JSON.stringify({"schemaVersion": 1, "build": ProjectSettings.get_setting("application/config/version"), "exportedAt": Time.get_datetime_string_from_system(true) + "Z", "current": _review_entry(), "reviews": review_records, "gripProfiles": profiles, "categoryProfiles": categories, "objectScales": scales}, "\t")

func _write_export_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		review_status.text = "Falha ao gravar. Use Copiar JSON para enviar."
		return
	file.store_string(export_payload)
	file.close()
	review_status.text = "JSON exportado: " + path.get_file()

func _export_review() -> void:
	export_payload = _report_json()
	var filename := "MyGame-revisao-" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var backup := FileAccess.open("user://" + filename, FileAccess.WRITE)
	if backup != null:
		backup.store_string(export_payload)
		backup.close()
	review_dialog.current_file = filename
	review_dialog.popup_centered_ratio(0.9)

func _copy_review() -> void:
	DisplayServer.clipboard_set(_report_json())
	review_status.text = "JSON copiado. Cole na conversa."
