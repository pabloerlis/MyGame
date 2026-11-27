extends Node
# Stable shell ABI 1. No preloads of lab assets before mounting the pack.
const ABI := 1
const CHANNEL := "https://api.github.com/repos/pabloerlis/MyGame/releases/tags/lab-content-v1"
const DOWNLOAD_ROOT := "https://github.com/pabloerlis/MyGame/releases/download/lab-content-v1/"
const STATE := "user://lab-update-v1.json"
const TEMP := "user://lab-download-v1.part"
const MAX_BYTES := 180 * 1024 * 1024
const LAB_SCENE := "res://lab/lab_room.tscn"
const MARKER := "res://assets/runtime/content-version.json"
var state: Dictionary = {}
var running: Dictionary = {}
var available: Dictionary = {}
var request: HTTPRequest
var panel: PanelContainer
var message: Label
var download_button: Button
var rollback_button: Button
var exit_button: Button
var close_button: Button
var stage := ""
var manual := false
var embedded_version := ""
var lab: Node
var boot_ok := false

func _ready() -> void:
	add_to_group("lab_runtime")
	embedded_version = str(ProjectSettings.get_setting("application/config/version"))
	state = _read_state()
	_create_ui()
	_boot()

func _read_state() -> Dictionary:
	if FileAccess.file_exists(STATE):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATE))
		if value is Dictionary:
			return value
	return {}

func _save_state() -> bool:
	var file := FileAccess.open(STATE + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state))
	file.close()
	return DirAccess.rename_absolute(STATE + ".tmp", STATE) == OK

func _entry(key: String) -> Dictionary:
	var v: Variant = state.get(key, {})
	return v if v is Dictionary else {}

func _version_number(v: String) -> int:
	var rx := RegEx.new()
	rx.compile("^0\\.1\\.0-alpha\\.([0-9]+)$")
	var match_result := rx.search(v)
	return int(match_result.get_string(1)) if match_result != null else -1

func _valid_digest(digest: String) -> bool:
	return digest.length() == 64 and digest.is_valid_hex_number(false)

func _pack_path(entry: Dictionary) -> String:
	return "user://lab-pack-" + str(entry.get("sha256", "")) + ".pck"

func _valid_pack(entry: Dictionary) -> bool:
	var digest := str(entry.get("sha256", ""))
	if not _valid_digest(digest) or _version_number(str(entry.get("version", ""))) < 0 or int(entry.get("abi", 0)) != ABI:
		return false
	var length := int(entry.get("size", 0))
	if length <= 0 or length > MAX_BYTES:
		return false
	var path := _pack_path(entry)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var actual := file.get_length()
	file.close()
	return actual == length and FileAccess.get_sha256(path) == digest

func _recover_interrupted() -> void:
	var attempt := _entry("attempt")
	if attempt.is_empty():
		return
	if str(_entry("active").get("sha256", "")) == str(attempt.get("sha256", "")):
		state["active"] = _entry("previous")
		state["previous"] = {}
	state["pending"] = {}
	state["attempt"] = {}
	state["rejected"] = str(attempt.get("sha256", ""))

func _boot() -> void:
	_recover_interrupted()
	if not _save_state():
		_fail("Não foi possível gravar o estado do atualizador.")
		return
	var candidate := _entry("pending")
	if candidate.is_empty():
		candidate = _entry("active")
	if not candidate.is_empty():
		if not _valid_pack(candidate):
			state["attempt"] = candidate
			_recover_interrupted()
			if not _save_state():
				_fail("Falha ao registrar recuperação.")
				return
			# No pack has been mounted. Safe to use the embedded version now.
		else:
			state["attempt"] = candidate
			if not _save_state():
				_fail("Falha ao registrar tentativa.")
				return
			if not ProjectSettings.load_resource_pack(_pack_path(candidate), true):
				_recover_interrupted()
				_save_state()
				_fail("Pacote recusado. Feche e reabra para recuperar.")
				return
			var marker: Variant = JSON.parse_string(FileAccess.get_file_as_string(MARKER))
			if not marker is Dictionary or int(marker.get("abi", 0)) != ABI or str(marker.get("version", "")) != str(candidate.get("version", "")):
				_recover_interrupted()
				_save_state()
				_fail("Versão interna incompatível. Feche e reabra.")
				return
			running = candidate
			ProjectSettings.set_setting("application/config/version", str(running["version"]))
	var scene := ResourceLoader.load(LAB_SCENE, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if scene == null:
		_fail("Não foi possível abrir o laboratório. Feche e reabra.")
		return
	lab = scene.instantiate()
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(lab) or lab.get("demo_ready") != true:
		_fail("Inicialização incompleta. Feche e reabra para recuperar.")
		return
	if not running.is_empty():
		if str(_entry("active").get("sha256", "")) != str(running["sha256"]):
			state["previous"] = _entry("active")
		state["active"] = running
		state["pending"] = {}
		state["attempt"] = {}
		if not _save_state():
			_fail("Falha ao confirmar inicialização.")
			return
	boot_ok = true
	_prune_packs()
	if OS.has_feature("android"):
		_check(false)

func _create_ui() -> void:
	request = HTTPRequest.new()
	add_child(request)
	request.timeout = 30.0
	request.request_completed.connect(_response)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Theme.new()
	root.theme.default_font_size = 23
	panel = PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -190
	panel.offset_bottom = 190
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#17212e")
	style.set_corner_radius_all(16)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)
	var title := Label.new()
	title.text = "Atualizações do laboratório"
	layout.add_child(title)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(message)
	_button(layout, "Verificar atualizações", _check.bind(true))
	download_button = _button(layout, "Baixar atualização", _download)
	download_button.disabled = true
	rollback_button = _button(layout, "Restaurar versão anterior", _rollback)
	exit_button = _button(layout, "Fechar aplicativo para aplicar", func(): get_tree().quit())
	exit_button.hide()
	close_button = _button(layout, "Voltar ao laboratório", func(): panel.hide())
	panel.hide()

func _button(parent: Control, title: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.custom_minimum_size.y = 60
	parent.add_child(b)
	b.pressed.connect(action)
	return b

func _current_version() -> String:
	return str(running.get("version", embedded_version))

func open_update_panel() -> void:
	panel.show()
	message.text = "Conteúdo: " + _current_version() + " | Motor ABI " + str(ABI)
	rollback_button.disabled = _entry("active").is_empty()
	if not _entry("pending").is_empty():
		message.text += "\nAtualização pronta. Feche e reabra o aplicativo."
		exit_button.show()

func _fail(reason: String) -> void:
	panel.show()
	message.text = reason
	exit_button.show()
	close_button.disabled = not boot_ok
	rollback_button.disabled = _entry("active").is_empty()

func _check(show_panel: bool) -> void:
	if not stage.is_empty() or not boot_ok:
		return
	manual = show_panel
	if show_panel:
		open_update_panel()
		message.text = "Consultando GitHub…"
	stage = "check"
	request.download_file = ""
	request.timeout = 30.0
	request.body_size_limit = 2 * 1024 * 1024
	var err := request.request(CHANNEL, PackedStringArray(["Accept: application/vnd.github+json", "X-GitHub-Api-Version: 2022-11-28"]))
	if err != OK:
		stage = ""
		if manual:
			message.text = "Sem conexão. A versão local continua disponível."

func _find_offer(release: Dictionary) -> Dictionary:
	if str(release.get("tag_name", "")) != "lab-content-v1" or release.get("draft", true) != false:
		return {}
	var assets: Variant = release.get("assets", [])
	if not assets is Array:
		return {}
	var rx := RegEx.new()
	rx.compile("^MyGame-content-(0\\.1\\.0-alpha\\.[0-9]+)-([0-9]+)\\.pck$")
	var best: Dictionary = {}
	var best_version := _version_number(_current_version())
	var best_run := -1
	for asset in assets:
		if not asset is Dictionary:
			continue
		var filename := str(asset.get("name", ""))
		var parsed := rx.search(filename)
		if parsed == null or str(asset.get("state", "")) != "uploaded":
			continue
		var version := parsed.get_string(1)
		var number := _version_number(version)
		var run_id := int(parsed.get_string(2))
		if number <= _version_number(_current_version()) or number < best_version or (number == best_version and run_id <= best_run):
			continue
		var digest := str(asset.get("digest", ""))
		var length := int(asset.get("size", 0))
		var url := str(asset.get("browser_download_url", ""))
		if not digest.begins_with("sha256:") or not _valid_digest(digest.substr(7)) or length <= 0 or length > MAX_BYTES or url != DOWNLOAD_ROOT + filename:
			continue
		if str(state.get("rejected", "")) == digest.substr(7):
			continue
		best = {"abi": ABI, "version": version, "sha256": digest.substr(7), "size": length, "url": url}
		best_version = number
		best_run = run_id
	return best

func _download() -> void:
	if not stage.is_empty() or available.is_empty():
		return
	stage = "download"
	download_button.disabled = true
	request.download_file = TEMP
	request.timeout = 300.0
	request.body_size_limit = int(available["size"])
	message.text = "Baixando " + str(available["version"]) + "…"
	if request.request(str(available["url"])) != OK:
		stage = ""
		download_button.disabled = false
		message.text = "Não foi possível iniciar o download."

func _response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var finished := stage
	stage = ""
	if finished == "check":
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			if manual:
				message.text = "Consulta indisponível (HTTP %d). Versão local preservada." % code
			return
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		available = _find_offer(parsed) if parsed is Dictionary else {}
		download_button.disabled = available.is_empty()
		if not available.is_empty():
			open_update_panel()
			message.text = "%s disponível — %.1f MB" % [available["version"], float(available["size"]) / 1000000.0]
		elif manual:
			message.text = "Nenhuma versão compatível mais recente."
	elif finished == "download":
		var f := FileAccess.open(TEMP, FileAccess.READ)
		var length := f.get_length() if f != null else -1
		if f != null:
			f.close()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200 or length != int(available["size"]) or FileAccess.get_sha256(TEMP) != str(available["sha256"]):
			DirAccess.remove_absolute(TEMP)
			download_button.disabled = false
			message.text = "Download incompleto ou hash inválido. Versão local preservada."
			return
		var path := _pack_path(available)
		if DirAccess.rename_absolute(TEMP, path) != OK:
			download_button.disabled = false
			message.text = "Falha ao gravar pacote."
			return
		state["pending"] = available.duplicate(true)
		if not _save_state():
			state["pending"] = {}
			message.text = "Falha ao registrar atualização."
			download_button.disabled = false
			return
		message.text = "Atualização verificada. Feche e reabra o aplicativo."
		exit_button.show()

func _rollback() -> void:
	if not stage.is_empty():
		return
	var active := _entry("active")
	if active.is_empty() and _entry("pending").is_empty():
		return
	state["rejected"] = str(active.get("sha256", ""))
	state["active"] = _entry("previous")
	state["previous"] = {}
	state["pending"] = {}
	state["attempt"] = {}
	if not _save_state():
		state = _read_state()
		message.text = "Não foi possível registrar restauração."
		return
	message.text = "Restauração registrada. Feche e reabra o aplicativo."
	exit_button.show()
	download_button.disabled = true

func _prune_packs() -> void:
	var keep: Array[String] = []
	for key in ["active", "previous", "pending"]:
		var entry := _entry(key)
		if not entry.is_empty():
			keep.append(_pack_path(entry).get_file())
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for filename in dir.get_files():
		if filename.begins_with("lab-pack-") and filename.ends_with(".pck") and not filename in keep:
			dir.remove(filename)
