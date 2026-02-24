extends Node

var device_id := ""
var uid := ""
var device_ref

var current_level_id := ""
var level_start_time_ms := 0

var overall_time_played_ms: int = 0
var _last_flush_overall_ms: int = 0
var _flush_timer: Timer

const DEVICE_ID_PATH := "user://device_id.txt"
const _HEX := "0123456789abcdef"

func _ready() -> void:
	device_id = _get_or_create_device_id()
	print("DEVICE ID =", device_id, "persistent=", OS.is_userfs_persistent())
	print("ENV exists:", FileAccess.file_exists("res://addons/godot-firebase/.env"))
	print("FirebaseManager: starting anonymous login")

	Firebase.Auth.login_succeeded.connect(_on_auth_ok)
	Firebase.Auth.signup_succeeded.connect(_on_auth_ok)
	Firebase.Auth.login_failed.connect(_on_auth_fail)
	Firebase.Auth.login_anonymous()

	_flush_timer = Timer.new()
	_flush_timer.wait_time = 20.0
	_flush_timer.one_shot = false
	_flush_timer.autostart = true
	_flush_timer.timeout.connect(_flush_overall_time)
	add_child(_flush_timer)

func _on_auth_ok(auth_info: Dictionary) -> void:
	uid = str(auth_info.get("localid", auth_info.get("uid", "")))
	if uid == "":
		push_error("Auth ok but uid missing: %s" % [auth_info])
		return

	device_ref = Firebase.Database.get_database_reference("devices/%s" % device_id)
	print("AUTH OK uid=", uid, " device_ref=devices/%s" % device_id)

	device_ref.update("debug", {
		"connected": true,
		"ts_unix": Time.get_unix_time_from_system(),
		"last_uid": uid
	})

	device_ref.update("progress", {
		"overall_time_played_ms": overall_time_played_ms,
		"last_seen_unix": Time.get_unix_time_from_system()
	})
	_last_flush_overall_ms = overall_time_played_ms

func _on_auth_fail(code: int, message: String) -> void:
	push_error("AUTH FAIL %s: %s" % [code, message])

func on_level_started(level_id: String) -> void:
	_finalize_running_segment()

	current_level_id = level_id
	level_start_time_ms = Time.get_ticks_msec()

	if device_ref:
		device_ref.update("progress", {
			"current_level": level_id,
			"last_seen_unix": Time.get_unix_time_from_system(),
			"overall_time_played_ms": overall_time_played_ms
		})
		_last_flush_overall_ms = overall_time_played_ms

func on_level_ended(level_id: String) -> void:
	if level_start_time_ms == 0:
		return

	var now_ms := Time.get_ticks_msec()
	var delta_ms := now_ms - level_start_time_ms
	var delta_sec := float(delta_ms) / 1000.0

	level_start_time_ms = 0

	overall_time_played_ms += max(delta_ms, 0)

	if device_ref:
		device_ref.update("level_times/level_%s" % level_id, {
			"last_duration_sec": delta_sec,
			"last_played_unix": Time.get_unix_time_from_system()
		})

		device_ref.update("progress", {
			"overall_time_played_ms": overall_time_played_ms,
			"last_seen_unix": Time.get_unix_time_from_system(),
			"current_level": level_id
		})
		_last_flush_overall_ms = overall_time_played_ms

func on_game_paused() -> void:
	_finalize_running_segment()

func on_game_resumed() -> void:
	if current_level_id != "":
		level_start_time_ms = Time.get_ticks_msec()

func _flush_overall_time() -> void:
	if device_ref == null:
		return
	if level_start_time_ms == 0:
		return

	var now_ms := Time.get_ticks_msec()
	var delta_ms := now_ms - level_start_time_ms
	if delta_ms <= 0:
		return

	overall_time_played_ms += delta_ms
	level_start_time_ms = now_ms

	if overall_time_played_ms != _last_flush_overall_ms:
		device_ref.update("progress", {
			"overall_time_played_ms": overall_time_played_ms,
			"last_seen_unix": Time.get_unix_time_from_system(),
			"current_level": current_level_id
		})
		_last_flush_overall_ms = overall_time_played_ms

func _finalize_running_segment() -> void:
	if level_start_time_ms == 0:
		return

	var now_ms := Time.get_ticks_msec()
	var delta_ms := now_ms - level_start_time_ms
	if delta_ms > 0:
		overall_time_played_ms += delta_ms
	level_start_time_ms = 0

	if device_ref:
		device_ref.update("progress", {
			"overall_time_played_ms": overall_time_played_ms,
			"last_seen_unix": Time.get_unix_time_from_system(),
			"current_level": current_level_id
		})
		_last_flush_overall_ms = overall_time_played_ms

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_finalize_running_segment()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_finalize_running_segment()

func _get_or_create_device_id() -> String:
	if OS.is_userfs_persistent() and FileAccess.file_exists(DEVICE_ID_PATH):
		var existing := FileAccess.get_file_as_string(DEVICE_ID_PATH).strip_edges()
		if existing != "":
			return existing

	var new_id := _uuid_v4()

	if OS.is_userfs_persistent():
		var f := FileAccess.open(DEVICE_ID_PATH, FileAccess.WRITE)
		f.store_string(new_id)
		f.close()

	return new_id

func _uuid_v4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var b := PackedByteArray()
	b.resize(16)
	for i in range(16):
		b[i] = rng.randi_range(0, 255)

	b[6] = (b[6] & 0x0F) | 0x40
	b[8] = (b[8] & 0x3F) | 0x80

	var s := ""
	for i in range(16):
		s += _HEX[b[i] >> 4]
		s += _HEX[b[i] & 0x0F]

	return "%s-%s-%s-%s-%s" % [
		s.substr(0, 8),
		s.substr(8, 4),
		s.substr(12, 4),
		s.substr(16, 4),
		s.substr(20, 12)
	]
