# RunTimer.gd
extends Node

var elapsed_ms: int = 0
var running: bool = false
var _last_tick_ms: int = 0

var level_elapsed_ms: int = 0
var level_running: bool = false
var _level_last_tick_ms: int = 0

func start_new_run() -> void:
	elapsed_ms = 0
	level_elapsed_ms = 0

	running = true
	level_running = true

	var now := Time.get_ticks_msec()
	_last_tick_ms = now
	_level_last_tick_ms = now

func resume_from_elapsed(saved_elapsed_ms: int) -> void:
	elapsed_ms = saved_elapsed_ms
	running = true
	_last_tick_ms = Time.get_ticks_msec()

	# Level time should usually restart fresh on load into a level
	level_elapsed_ms = 0
	level_running = true
	_level_last_tick_ms = Time.get_ticks_msec()

func pause_run() -> void:
	var now := Time.get_ticks_msec()

	if running:
		elapsed_ms += max(0, now - _last_tick_ms)
		running = false

	if level_running:
		level_elapsed_ms += max(0, now - _level_last_tick_ms)
		level_running = false

func end_run() -> void:
	pause_run()

func start_level() -> void:
	level_elapsed_ms = 0
	level_running = true
	_level_last_tick_ms = Time.get_ticks_msec()

func pause_level() -> void:
	if not level_running:
		return
	var now := Time.get_ticks_msec()
	level_elapsed_ms += max(0, now - _level_last_tick_ms)
	level_running = false

func resume_level() -> void:
	if level_running:
		return
	level_running = true
	_level_last_tick_ms = Time.get_ticks_msec()

func get_elapsed_ms() -> int:
	if not running:
		return elapsed_ms
	var now := Time.get_ticks_msec()
	return elapsed_ms + max(0, now - _last_tick_ms)

func get_elapsed_seconds() -> float:
	return get_elapsed_ms() / 1000.0

func get_level_elapsed_ms() -> int:
	if not level_running:
		return level_elapsed_ms
	var now := Time.get_ticks_msec()
	return level_elapsed_ms + max(0, now - _level_last_tick_ms)

func get_level_elapsed_seconds() -> float:
	return get_level_elapsed_ms() / 1000.0

func on_game_paused(is_paused: bool) -> void:
	if is_paused:
		pause_run()
	else:
		var now := Time.get_ticks_msec()

		running = true
		_last_tick_ms = now

		level_running = true
		_level_last_tick_ms = now
