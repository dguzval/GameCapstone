# RunTimer.gd
extends Node

var elapsed_ms: int = 0
var running: bool = false
var _last_tick_ms: int = 0

func start_new_run() -> void:
	elapsed_ms = 0
	running = true
	_last_tick_ms = Time.get_ticks_msec()

func resume_from_elapsed(saved_elapsed_ms: int) -> void:
	elapsed_ms = saved_elapsed_ms
	running = true
	_last_tick_ms = Time.get_ticks_msec()

func pause_run() -> void:
	if not running:
		return
	var now := Time.get_ticks_msec()
	elapsed_ms += max(0, now - _last_tick_ms)
	running = false

func end_run() -> void:
	pause_run()

func get_elapsed_ms() -> int:
	if not running:
		return elapsed_ms
	var now := Time.get_ticks_msec()
	return elapsed_ms + max(0, now - _last_tick_ms)

func get_elapsed_seconds() -> float:
	return get_elapsed_ms() / 1000.0

func on_game_paused(is_paused: bool) -> void:
	# Call this when you pause/unpause your game
	if is_paused:
		pause_run()
	else:
		# keep same elapsed_ms, just restart the tick baseline
		running = true
		_last_tick_ms = Time.get_ticks_msec()
