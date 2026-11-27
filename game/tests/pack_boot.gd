extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	var path := args[0]
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		quit(1)
		return
	var length := f.get_length()
	f.close()
	var sha := FileAccess.get_sha256(path)
	var target := "user://lab-pack-" + sha + ".pck"
	if DirAccess.copy_absolute(path, target) != OK:
		quit(1)
		return
	var version := str(ProjectSettings.get_setting("application/config/version"))
	var state_file := FileAccess.open("user://lab-update-v1.json", FileAccess.WRITE)
	state_file.store_string(JSON.stringify({"pending": {"abi": 1, "version": version, "sha256": sha, "size": length}}))
	state_file.close()
	var shell := load("res://bootstrap/runtime.tscn") as PackedScene
	var runtime = shell.instantiate()
	root.add_child(runtime)
	for i in range(10):
		await process_frame
	if not runtime.boot_ok or str(runtime.running.get("sha256", "")) != sha or not runtime._entry("pending").is_empty() or str(runtime._entry("active").get("sha256", "")) != sha:
		push_error("PCK boot or activation failed")
		quit(1)
		return
	runtime._rollback()
	if not runtime._entry("active").is_empty() or not runtime._entry("pending").is_empty():
		push_error("Rollback state failed")
		quit(1)
		return
	var interrupted := {"abi": 1, "version": version, "sha256": sha, "size": length}
	runtime.state = {"pending": interrupted, "attempt": interrupted}
	runtime._recover_interrupted()
	if not runtime._entry("pending").is_empty() or str(runtime.state.get("rejected", "")) != sha:
		push_error("Interrupted activation recovery failed")
		quit(1)
		return
	print("PACK_BOOT_OK")
	quit()
