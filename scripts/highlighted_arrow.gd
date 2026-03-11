extends Sprite2D

@export var threshold_ratio: float = 0.7
@export var check_interval_sec: float = 0.1
@export var flash_count: int = 3
@export var flash_half_duration: float = 1

var _baseline_ms: float = 0.0
var _has_triggered: bool = false


func _ready() -> void:
	_baseline_ms = LevelState.get_baseline_time_ms()

	# Start hidden.
	modulate.a = 0.0

	_watch_for_hint()


func _watch_for_hint() -> void:
	
	if(FirebaseManager.ab_group != 2):
		return
		
	while not _has_triggered:
		var elapsed_ms := RunTimer.get_level_elapsed_ms()

		if elapsed_ms >= _baseline_ms * threshold_ratio:
			FirebaseManager.log_hint()
			_has_triggered = true
			await _flash_three_times()

			# Leave the highlighted platforms visible after the flashing ends.
			modulate.a = 0.0
			return

		await get_tree().create_timer(check_interval_sec).timeout


func _flash_three_times() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	for i in range(flash_count):
		print("flash ", i)
		tween.tween_property(self, "modulate:a", 1.0, flash_half_duration)
		tween.tween_property(self, "modulate:a", 0.0, flash_half_duration)

	tween.tween_property(self, "modulate:a", 1.0, flash_half_duration)

	await tween.finished
