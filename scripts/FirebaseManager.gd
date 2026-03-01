extends Node

var device_id := ""
var uid := ""
var session_id := ""

var _bootstrapped := false
var device_ref

var current_level_id := ""
var level_start_time_ms := 0

var overall_time_played_ms: int = 0
var _last_flush_overall_ms: int = 0
var _flush_timer: Timer

const DEVICE_ID_PATH := "user://device_id.txt"
const _HEX := "0123456789abcdef"

# Update this to change what game version new database entries are associated with
const GAME_VERSION := "v1.0"

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_finalize_running_segment()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_finalize_running_segment()

func _on_auth_ok(auth_info: Dictionary) -> void:
	uid = str(auth_info.get("localid", auth_info.get("uid", "")))
	if uid == "":
		push_error("Auth ok but uid missing: %s" % [auth_info])
		return

	session_id = "%d_%s" % [int(Time.get_unix_time_from_system()), str(randi())]
	device_ref = Firebase.Database.get_database_reference("devices/%s" % device_id)

	var once_ref = Firebase.Database.get_once_database_reference("devices/%s" % device_id)
	once_ref.once_successful.connect(_on_progress_loaded)
	once_ref.once_failed.connect(_on_progress_failed)
	once_ref.once("progress")

func _on_auth_fail(code: int, message: String) -> void:
	push_error("AUTH FAIL %s: %s" % [code, message])

func _on_progress_loaded(progress: Dictionary) -> void:
	var local_so_far := overall_time_played_ms
	var remote := int(progress.get("overall_time_played_ms", 0))

	overall_time_played_ms = remote + local_so_far
	_last_flush_overall_ms = overall_time_played_ms
	_bootstrapped = true

	_write_open_event()
	_write_initial_progress()

func _on_progress_failed() -> void:
	_last_flush_overall_ms = overall_time_played_ms
	_bootstrapped = true
	_write_open_event()
	_write_initial_progress()

func on_level_started(level_id: String) -> void:
	_finalize_running_segment()
	
	_log_event("level_started", level_id)

	current_level_id = level_id
	level_start_time_ms = Time.get_ticks_msec()

	if not _bootstrapped or device_ref == null:
		return

	device_ref.update("progress", {
		"current_level": current_level_id,
		"last_seen_unix": Time.get_unix_time_from_system(),
		"overall_time_played_ms": overall_time_played_ms
	})
	_last_flush_overall_ms = overall_time_played_ms

func on_level_ended(level_id: String) -> void:
	if level_start_time_ms == 0:
		return

	_log_event("level_ended", level_id)

	var now_ms := Time.get_ticks_msec()
	var delta_ms := now_ms - level_start_time_ms
	var delta_sec := float(delta_ms) / 1000.0

	level_start_time_ms = 0
	overall_time_played_ms += max(delta_ms, 0)

	if not _bootstrapped or device_ref == null:
		return

	device_ref.update("level_times/level_%s" % level_id, {
		"last_duration_sec": delta_sec,
		"last_played_unix": Time.get_unix_time_from_system()
	})

	device_ref.update("progress", {
		"overall_time_played_ms": overall_time_played_ms,
		"last_seen_unix": Time.get_unix_time_from_system(),
		"current_level": current_level_id
	})
	_last_flush_overall_ms = overall_time_played_ms

func on_game_paused() -> void:
	_log_event("pause", current_level_id)
	_finalize_running_segment()

func on_game_resumed() -> void:
	_log_event("unpause", current_level_id)
	if current_level_id != "":
		level_start_time_ms = Time.get_ticks_msec()

func log_restart(level_id: String = "") -> void:
	var lid := level_id
	if lid == "":
		lid = current_level_id
	_log_event("restart", lid)
	
func log_key(level_id: String = "") -> void:
	var lid := level_id
	if lid == "":
		lid = current_level_id
	_log_event("key_collected", lid)

func log_exit(level_id: String = "") -> void:
	var lid := level_id
	if lid == "":
		lid = current_level_id
	_log_event("level_complete", lid)

func log_pressed_gravity_button(gravity_change: String = "", level_id: String = "") -> void:
	var lid := level_id
	if lid == "":
		lid = current_level_id
	_log_event("pressed_gravity_button", lid, {"gravity_change": gravity_change})

func _flush_overall_time() -> void:
	if level_start_time_ms == 0:
		return

	var now_ms := Time.get_ticks_msec()
	var delta_ms := now_ms - level_start_time_ms
	if delta_ms <= 0:
		return

	overall_time_played_ms += delta_ms
	level_start_time_ms = now_ms

	if not _bootstrapped or device_ref == null:
		return

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

	if not _bootstrapped or device_ref == null:
		return

	device_ref.update("progress", {
		"overall_time_played_ms": overall_time_played_ms,
		"last_seen_unix": Time.get_unix_time_from_system(),
		"current_level": current_level_id
	})
	_last_flush_overall_ms = overall_time_played_ms

func _write_initial_progress() -> void:
	if device_ref == null:
		return

	device_ref.update("debug", {
		"connected": true,
		"ts_unix": Time.get_unix_time_from_system(),
		"last_uid": uid
	})

	device_ref.update("progress", {
		"overall_time_played_ms": overall_time_played_ms,
		"last_seen_unix": Time.get_unix_time_from_system(),
		"session_id": session_id,
		"current_level": current_level_id
	})
	_last_flush_overall_ms = overall_time_played_ms

func _write_open_event() -> void:
	_log_event("open_page", current_level_id)

func _log_event(event_type: String, level_id: String = "", extra: Dictionary = {}) -> void:
	if device_ref == null or not _bootstrapped:
		return

	var payload := {
		"type": event_type,
		"unix": int(Time.get_unix_time_from_system()),
		"day": _today_yyyy_mm_dd(),
		"level_id": level_id,
		"session_id": session_id,
		"overall_time_played_ms": overall_time_played_ms,
		"game_version": GAME_VERSION
	}

	for k in extra.keys():
		payload[k] = extra[k]

	var eid := _event_id()
	device_ref.update("sessions/%s/events/%s" % [session_id, eid], payload)

func _today_yyyy_mm_dd() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func _event_id() -> String:
	return "%d_%s" % [Time.get_ticks_msec(), str(randi())]

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
