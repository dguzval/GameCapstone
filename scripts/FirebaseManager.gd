extends Node

var device_id := ""
var uid := ""
var session_id := ""

var _bootstrapped := false
var device_ref

var current_level_id := ""

var overall_time_played_ms: int = 0
var _last_flush_overall_ms: int = 0
var _flush_timer: Timer

var _level_elapsed_ms: int = 0
var _level_active_since_ms: int = 0
var _overall_active_since_ms: int = 0

var session_time_played_ms: int = 0
var _session_active_since_ms: int = 0
var _session_device_info: Dictionary = {}

var _pending_level_start_id := ""
var _pending_level_start_ms: int = 0

var _timing_suspended := false
var _close_logged := false

var _js_pagehide_cb = null
var _js_beforeunload_cb = null
var _js_visibility_cb = null
var _web_hooks_installed := false

var _app_is_hidden := false
var _last_visibility_event_unix_ms: int = 0

# 0 is not assigned, 1 and 2 are a and b
var ab_group: int = 0

const DEVICE_ID_PATH := "user://device_id.txt"
const RECOVERY_PATH := "user://firebase_progress_recovery.json"
const _HEX := "0123456789abcdef"
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
	_flush_timer.wait_time = 5.0 if OS.has_feature("web") else 20.0
	_flush_timer.one_shot = false
	_flush_timer.autostart = true
	_flush_timer.timeout.connect(_flush_overall_time)
	add_child(_flush_timer)

	_install_web_lifecycle_hooks()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_handle_window_close("wm_close")

	if OS.has_feature("web"):
		return

	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_handle_focus_out()

	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_handle_focus_in()

func _on_auth_ok(auth_info: Dictionary) -> void:
	uid = str(auth_info.get("localid", auth_info.get("uid", "")))
	if uid == "":
		push_error("Auth ok but uid missing: %s" % [auth_info])
		return

	session_id = "%d_%s" % [int(Time.get_unix_time_from_system()), str(randi())]
	session_time_played_ms = 0
	_session_active_since_ms = 0
	_session_device_info = _collect_session_device_info()

	device_ref = Firebase.Database.get_database_reference("devices/%s" % device_id)

	var once_ref = Firebase.Database.get_once_database_reference("devices/%s" % device_id)
	once_ref.once_successful.connect(_on_progress_loaded)
	once_ref.once_failed.connect(_on_progress_failed)
	once_ref.once("progress")

func _on_auth_fail(code: int, message: String) -> void:
	push_error("AUTH FAIL %s: %s" % [code, message])

func _on_progress_loaded(progress) -> void:
	var local_recovery := _load_local_recovery_snapshot()

	if progress == null:
		print("No existing progress found for device ", device_id, " - starting fresh.")

		overall_time_played_ms = int(local_recovery.get("overall_time_played_ms", 0))
		session_time_played_ms = 0
		_last_flush_overall_ms = overall_time_played_ms
		current_level_id = str(local_recovery.get("current_level", ""))
		_level_elapsed_ms = int(local_recovery.get("time_in_current_level_ms", 0))

		_level_active_since_ms = 0
		_overall_active_since_ms = 0
		_session_active_since_ms = 0
		_timing_suspended = (current_level_id != "")
		_close_logged = false

		_bootstrapped = true

		_write_open_event()
		_write_session_summary()
		_write_progress_state()
		_consume_pending_level_start()
		return

	if typeof(progress) != TYPE_DICTIONARY:
		print("Unexpected progress type: ", typeof(progress), " value=", progress)
		_on_progress_failed()
		return

	var remote_overall := int(progress.get("overall_time_played_ms", 0))
	var remote_level := str(progress.get("current_level", ""))
	var remote_level_ms := int(progress.get("time_in_current_level_ms", 0))
	var remote_last_seen := int(progress.get("last_seen_unix", 0))

	var local_overall := int(local_recovery.get("overall_time_played_ms", 0))
	var local_level := str(local_recovery.get("current_level", ""))
	var local_level_ms := int(local_recovery.get("time_in_current_level_ms", 0))
	var local_last_seen := int(local_recovery.get("last_seen_unix", 0))
	
	ab_group = int(local_recovery.get("ab_group", 0))
	if ab_group == 0:
		ab_group = randi_range(1, 2) # 1 or 2

	if local_last_seen > remote_last_seen:
		overall_time_played_ms = max(remote_overall, local_overall)
		current_level_id = local_level
		_level_elapsed_ms = local_level_ms
	else:
		overall_time_played_ms = remote_overall
		current_level_id = remote_level
		_level_elapsed_ms = remote_level_ms

	_last_flush_overall_ms = overall_time_played_ms

	_level_active_since_ms = 0
	_overall_active_since_ms = 0
	_session_active_since_ms = 0
	session_time_played_ms = 0
	_timing_suspended = (current_level_id != "")
	_close_logged = false

	_bootstrapped = true

	_write_open_event()
	_write_session_summary()
	_write_progress_state()
	_consume_pending_level_start()

	print("RESTORED current_level=", current_level_id, " restored_level_ms=", _level_elapsed_ms)

func _on_progress_failed() -> void:
	push_warning("Progress load failed; preserving remote progress by skipping initial progress write.")

	_last_flush_overall_ms = overall_time_played_ms
	_level_elapsed_ms = 0
	_level_active_since_ms = 0
	_overall_active_since_ms = 0
	_session_active_since_ms = 0
	_timing_suspended = false
	_close_logged = false

	_bootstrapped = true

	_write_open_event()
	_write_session_summary()
	_consume_pending_level_start()

func _consume_pending_level_start() -> void:
	if _pending_level_start_id == "":
		return

	var pending_id := _pending_level_start_id
	var preboot_ms: int = 0

	if _pending_level_start_ms > 0:
		preboot_ms = max(Time.get_ticks_msec() - _pending_level_start_ms, 0)

	if current_level_id == pending_id:
		_level_elapsed_ms += preboot_ms
	else:
		current_level_id = pending_id
		_level_elapsed_ms = preboot_ms

	overall_time_played_ms += preboot_ms
	session_time_played_ms += preboot_ms

	_pending_level_start_id = ""
	_pending_level_start_ms = 0

	_close_logged = false
	_timing_suspended = false

	_log_event("level_started", current_level_id, {
		"restored_time_in_current_level_ms": _level_elapsed_ms
	}, false, "level_started_after_bootstrap")

	_resume_active_timing("level_started_after_bootstrap")
	_write_progress_state()

func on_level_started(level_id: String) -> void:
	if not _bootstrapped:
		current_level_id = level_id
		_close_logged = false
		_timing_suspended = false

		if _pending_level_start_id != level_id:
			_pending_level_start_id = level_id
			_pending_level_start_ms = Time.get_ticks_msec()

		print("Deferring level start until Firebase finishes loading for ", level_id)
		return

	if current_level_id == level_id and _is_timing_running():
		print("Ignoring duplicate level start for ", level_id)
		return

	if current_level_id != level_id:
		_level_elapsed_ms = 0

	current_level_id = level_id
	_close_logged = false
	_timing_suspended = false

	_log_event("level_started", level_id, {
		"restored_time_in_current_level_ms": _level_elapsed_ms
	}, false, "level_started")

	_resume_active_timing("level_started")
	_write_progress_state()

	print("STARTED: ", level_id, " restored_elapsed=", _level_elapsed_ms, " active_since=", _level_active_since_ms)

func on_level_ended(level_id: String) -> void:
	print("ENDING: ", level_id, " active_since=", _level_active_since_ms, " current_level_id=", current_level_id, " stored_elapsed=", _level_elapsed_ms)

	if current_level_id == "":
		print("Level ended but no current level is active")
		return

	if level_id != current_level_id:
		print("Ignoring level end mismatch. expected=", current_level_id, " got=", level_id)
		return

	_checkpoint_active_timing()

	var delta_ms := _level_elapsed_ms
	if delta_ms <= 0:
		print("Level ended with no tracked time")
		current_level_id = ""
		_level_elapsed_ms = 0
		_level_active_since_ms = 0
		_overall_active_since_ms = 0
		_session_active_since_ms = 0
		_timing_suspended = false
		_close_logged = false
		_write_progress_state()
		return

	var delta_sec := float(delta_ms) / 1000.0

	print("ENDED: ", level_id, " delta_ms=", delta_ms, " delta_sec=", delta_sec)

	_log_event("level_ended", level_id, {
		"level_time_seconds": delta_sec,
		"level_time_ms": delta_ms,
		"time_in_current_level_ms": _level_elapsed_ms
	})

	if _bootstrapped and device_ref != null:
		device_ref.update("level_times/level_%s" % level_id, {
			"last_duration_sec": delta_sec,
			"last_duration_ms": delta_ms,
			"last_played_unix": Time.get_unix_time_from_system()
		})

	current_level_id = ""
	_level_elapsed_ms = 0
	_level_active_since_ms = 0
	_overall_active_since_ms = 0
	_session_active_since_ms = 0
	_timing_suspended = false
	_close_logged = false

	_write_progress_state()

func on_game_paused() -> void:
	_pause_active_timing("pause")
	_log_event("pause", current_level_id, {
		"time_in_current_level_ms": _level_elapsed_ms
	})

func on_game_resumed() -> void:
	_resume_active_timing("unpause")
	_log_event("unpause", current_level_id, {
		"time_in_current_level_ms": _level_elapsed_ms
	})

func log_restart(level_id: String = "") -> void:
	var lid := level_id
	if lid == "":
		lid = current_level_id
	_log_event("restart", lid, {}, true, "after_restart_event")

func log_key(level_id: String = "") -> void:
	var lid := level_id
	if lid == "":
		lid = current_level_id
	_log_event("key_collected", lid, {}, true, "after_key_event")

func log_exit(level_id: String = "") -> void:
	var lid := level_id
	if lid == "":
		lid = current_level_id
	_log_event("level_complete", lid, {}, true, "after_level_complete_event")

func log_pressed_gravity_button(gravity_change: String = "", level_id: String = "") -> void:
	var lid := level_id
	if lid == "":
		lid = current_level_id
	_log_event("pressed_gravity_button", lid, {
		"gravity_change": gravity_change
	}, true, "after_gravity_button_event")

func _flush_overall_time() -> void:
	var was_running := _is_timing_running()

	if was_running:
		_checkpoint_active_timing()

	_write_local_recovery_snapshot()

	if not _bootstrapped or device_ref == null:
		if was_running and current_level_id != "" and not _timing_suspended:
			_resume_active_timing("flush_resume_no_db")
		return

	if overall_time_played_ms != _last_flush_overall_ms:
		_write_progress_state()

	if was_running and current_level_id != "" and not _timing_suspended:
		_resume_active_timing("flush_resume")

func _handle_window_close(reason: String) -> void:
	_checkpoint_active_timing()
	_timing_suspended = true

	_write_local_recovery_snapshot()

	if not _close_logged:
		_close_logged = true
		_log_event("close_page", current_level_id, {
			"close_reason": reason,
			"time_in_current_level_ms": _level_elapsed_ms
		})

		_write_progress_state()

	print("CLOSE logged reason=", reason, " level=", current_level_id, " level_elapsed=", _level_elapsed_ms)

	if not get_tree().is_auto_accept_quit():
		get_tree().quit()

func _handle_focus_out() -> void:
	if _app_is_hidden:
		return

	if current_level_id == "" and not _is_timing_running():
		_app_is_hidden = true
		return

	_app_is_hidden = true
	_last_visibility_event_unix_ms = Time.get_ticks_msec()

	_checkpoint_active_timing()
	_timing_suspended = true

	_write_local_recovery_snapshot()
	_write_progress_state()

	_log_event("app_hidden", current_level_id, {
		"time_in_current_level_ms": _level_elapsed_ms
	})

	print("FOCUS OUT level=", current_level_id, " level_elapsed=", _level_elapsed_ms)

func _handle_focus_in() -> void:
	if not _app_is_hidden:
		return

	_app_is_hidden = false
	_last_visibility_event_unix_ms = Time.get_ticks_msec()

	if current_level_id == "":
		return

	_log_event("app_visible", current_level_id, {
		"time_in_current_level_ms": _level_elapsed_ms
	})

	_resume_active_timing("focus_in")

func _pause_active_timing(reason: String = "") -> void:
	_checkpoint_active_timing()
	_timing_suspended = true
	_write_progress_state()

	print("PAUSE timing reason=", reason, " level=", current_level_id, " level_elapsed=", _level_elapsed_ms, " overall=", overall_time_played_ms)

func _resume_active_timing(reason: String = "") -> void:
	if current_level_id == "":
		return

	if _is_timing_running():
		return

	_timing_suspended = false

	var now_ms := Time.get_ticks_msec()
	_level_active_since_ms = now_ms
	_overall_active_since_ms = now_ms
	_session_active_since_ms = now_ms

	print("RESUME timing reason=", reason, " level=", current_level_id, " at=", now_ms)

func _checkpoint_active_timing() -> void:
	var now_ms := Time.get_ticks_msec()

	if _level_active_since_ms > 0:
		var level_delta := now_ms - _level_active_since_ms
		if level_delta > 0:
			_level_elapsed_ms += level_delta
		_level_active_since_ms = 0

	if _overall_active_since_ms > 0:
		var overall_delta := now_ms - _overall_active_since_ms
		if overall_delta > 0:
			overall_time_played_ms += overall_delta
		_overall_active_since_ms = 0

	if _session_active_since_ms > 0:
		var session_delta := now_ms - _session_active_since_ms
		if session_delta > 0:
			session_time_played_ms += session_delta
		_session_active_since_ms = 0

func _is_timing_running() -> bool:
	return _level_active_since_ms > 0 or _overall_active_since_ms > 0 or _session_active_since_ms > 0

func _write_progress_state() -> void:
	if not _bootstrapped or device_ref == null:
		_write_local_recovery_snapshot()
		return

	device_ref.update("progress", {
		"overall_time_played_ms": overall_time_played_ms,
		"last_seen_unix": Time.get_unix_time_from_system(),
		"session_id": session_id,
		"current_level": current_level_id,
		"time_in_current_level_ms": _level_elapsed_ms,
		"ab_group": ab_group
	})
	_last_flush_overall_ms = overall_time_played_ms

	_write_local_recovery_snapshot()
	_write_session_summary()

func _write_initial_progress() -> void:
	if device_ref == null:
		return

	device_ref.update("debug", {
		"connected": true,
		"ts_unix": Time.get_unix_time_from_system(),
		"last_uid": uid
	})

	_write_session_summary()

func _write_open_event() -> void:
	_log_event("open_page", current_level_id, {
		"time_in_current_level_ms": _level_elapsed_ms
	})

func _log_event(event_type: String, level_id: String = "", extra: Dictionary = {}, checkpoint_first: bool = false, resume_reason: String = "resume_after_event") -> void:
	if device_ref == null or not _bootstrapped:
		return

	var was_running := false

	if checkpoint_first:
		was_running = _is_timing_running()
		if was_running:
			_checkpoint_active_timing()

	print("Logging event %s" % event_type)

	var payload := {
		"type": event_type,
		"unix": int(Time.get_unix_time_from_system()),
		"day": _today_yyyy_mm_dd(),
		"level_id": level_id,
		"session_id": session_id,
		"session_time_played_ms": session_time_played_ms,
		"overall_time_played_ms": overall_time_played_ms,
		"game_version": GAME_VERSION
	}

	if checkpoint_first:
		payload["time_in_current_level_ms"] = _level_elapsed_ms

	for k in extra.keys():
		payload[k] = extra[k]

	var eid := _event_id()
	device_ref.update("sessions/%s/events/%s" % [session_id, eid], payload)

	if checkpoint_first:
		_write_local_recovery_snapshot()

	if checkpoint_first and was_running and current_level_id != "" and not _timing_suspended:
		_resume_active_timing(resume_reason)

func _get_web_host_platform() -> String:
	if OS.has_feature("web_windows"):
		return "windows"
	if OS.has_feature("web_macos"):
		return "macos"
	if OS.has_feature("web_linuxbsd"):
		return "linuxbsd"
	if OS.has_feature("web_android"):
		return "android"
	if OS.has_feature("web_ios"):
		return "ios"
	return ""

func _collect_session_device_info() -> Dictionary:
	var info := {
		"runtime_platform": OS.get_name(),
		"is_web": OS.has_feature("web"),
		"web_host_platform": _get_web_host_platform(),
		"is_mobile_web": OS.has_feature("web_android") or OS.has_feature("web_ios"),
		"browser_user_agent": "",
		"browser_platform": "",
		"device_type": "desktop"
	}

	if info["is_mobile_web"]:
		info["device_type"] = "mobile"

	if OS.has_feature("web"):
		var ua = JavaScriptBridge.eval("navigator.userAgent || ''")
		if ua != null:
			info["browser_user_agent"] = str(ua)

		var platform = JavaScriptBridge.eval("navigator.platform || ''")
		if platform != null:
			info["browser_platform"] = str(platform)

		var mobile_guess = JavaScriptBridge.eval("""
			(function () {
				if (navigator.userAgentData && typeof navigator.userAgentData.mobile === 'boolean') {
					return navigator.userAgentData.mobile;
				}
				return /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent || '');
			})()
		""")
		if mobile_guess != null and bool(mobile_guess):
			info["device_type"] = "mobile"
			info["is_mobile_web"] = true

	return info

func _write_session_summary() -> void:
	if not _bootstrapped or device_ref == null or session_id == "":
		return

	device_ref.update("sessions/%s/summary" % session_id, {
		"session_id": session_id,
		"started_unix": int(session_id.split("_")[0]),
		"last_seen_unix": Time.get_unix_time_from_system(),
		"session_time_played_ms": session_time_played_ms,
		"overall_time_played_ms": overall_time_played_ms,
		"current_level": current_level_id,
		"game_version": GAME_VERSION,
		"runtime_platform": _session_device_info.get("runtime_platform", ""),
		"is_web": _session_device_info.get("is_web", false),
		"web_host_platform": _session_device_info.get("web_host_platform", ""),
		"is_mobile_web": _session_device_info.get("is_mobile_web", false),
		"browser_user_agent": _session_device_info.get("browser_user_agent", ""),
		"browser_platform": _session_device_info.get("browser_platform", ""),
		"device_type": _session_device_info.get("device_type", "desktop")
	})

func _write_local_recovery_snapshot() -> void:
	if not OS.is_userfs_persistent():
		return

	var data := {
		"overall_time_played_ms": overall_time_played_ms,
		"session_time_played_ms": session_time_played_ms,
		"current_level": current_level_id,
		"time_in_current_level_ms": _level_elapsed_ms,
		"last_seen_unix": int(Time.get_unix_time_from_system()),
		"session_id": session_id,
		"ab_group": ab_group
	}

	var f := FileAccess.open(RECOVERY_PATH, FileAccess.WRITE)
	if f == null:
		return

	f.store_string(JSON.stringify(data))
	f.close()

func _load_local_recovery_snapshot() -> Dictionary:
	if not OS.is_userfs_persistent():
		return {}

	if not FileAccess.file_exists(RECOVERY_PATH):
		return {}

	var raw := FileAccess.get_file_as_string(RECOVERY_PATH)
	if raw.strip_edges() == "":
		return {}

	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	return parsed

func _clear_local_recovery_snapshot() -> void:
	if not OS.is_userfs_persistent():
		return

	if FileAccess.file_exists(RECOVERY_PATH):
		DirAccess.remove_absolute(RECOVERY_PATH)

func _install_web_lifecycle_hooks() -> void:
	if not OS.has_feature("web"):
		return

	if _web_hooks_installed:
		return

	var window = JavaScriptBridge.get_interface("window")
	var document = JavaScriptBridge.get_interface("document")

	if window == null or document == null:
		return

	_js_pagehide_cb = JavaScriptBridge.create_callback(_on_js_pagehide)
	_js_beforeunload_cb = JavaScriptBridge.create_callback(_on_js_beforeunload)
	_js_visibility_cb = JavaScriptBridge.create_callback(_on_js_visibility_change)

	window.addEventListener("pagehide", _js_pagehide_cb)
	window.addEventListener("beforeunload", _js_beforeunload_cb)
	document.addEventListener("visibilitychange", _js_visibility_cb)

	_web_hooks_installed = true

func _on_js_pagehide(_args = []) -> void:
	_handle_window_close("pagehide")

func _on_js_beforeunload(_args = []) -> void:
	_handle_window_close("beforeunload")

func _on_js_visibility_change(_args = []) -> void:
	var document = JavaScriptBridge.get_interface("document")
	if document == null:
		return

	var state = str(document.visibilityState)

	if state == "hidden":
		_handle_focus_out()
	elif state == "visible":
		_handle_focus_in()

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
