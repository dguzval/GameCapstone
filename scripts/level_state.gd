extends Node

const save_location = "user://SaveFile.tres"

var has_key: bool = false
var key_required: bool = false
var amount_key: int = 0
var key_acquired: int = 0
var plates_exists: bool = false
var all_plates_pressed: bool = false
var plate_amount: int = 0
var plates_pressed: int = 0
var curr_level: int = 1
var loadedFile = false
var save_data: SceneData

var level_end_committed: bool = false

func ensure_save_data() -> void:
	if save_data == null:
		save_data = SceneData.new()

func start_level_after_scene_change(scene_path: String, level_number: int) -> void:
	get_tree().call_deferred("change_scene_to_file", scene_path)
	await get_tree().scene_changed
	on_level_started(level_number)

func save_progress() -> void:
	ensure_save_data()

	save_data.last_level_played = curr_level
	save_data.elapsed_ms = RunTimer.get_elapsed_ms()

	var err := ResourceSaver.save(save_data, save_location)
	if err == OK:
		print("saved!")
	else:
		print("save failed: ", err)

func load_progress() -> void:
	if not ResourceLoader.exists(save_location):
		save_data = SceneData.new()
		curr_level = 1
		loadedFile = false
		RunTimer.start_new_run()
		return

	save_data = ResourceLoader.load(save_location) as SceneData
	if save_data == null:
		save_data = SceneData.new()
		curr_level = 1
		loadedFile = false
		RunTimer.start_new_run()
		return

	curr_level = save_data.last_level_played
	RunTimer.resume_from_elapsed(save_data.elapsed_ms)
	print("loaded!")
	loadedFile = true

func reset_for_level() -> void:
	has_key = false
	key_required = false
	amount_key = 0
	key_acquired = 0
	plates_exists = false
	all_plates_pressed = false
	plate_amount = 0
	plates_pressed = 0

func update_key_count() -> void:
	key_acquired += 1
	if key_acquired == amount_key:
		has_key = true

func check_plates_pressed() -> void:
	all_plates_pressed = (plates_pressed == plate_amount)

func get_level() -> int:
	return curr_level

func on_level_started(level_id: int) -> void:
	ensure_save_data()

	level_end_committed = false
	reset_for_level()
	curr_level = level_id
	RunTimer.start_level()

	if FirebaseManager:
		FirebaseManager.on_level_started(str(level_id))

func on_level_ended() -> void:
	ensure_save_data()

	if level_end_committed:
		return

	level_end_committed = true
	RunTimer.pause_level()

	save_data.level_times_ms[curr_level] = RunTimer.get_level_elapsed_ms()
	save_data.elapsed_ms = RunTimer.get_elapsed_ms()
	save_data.last_level_played = curr_level + 1

	var err := ResourceSaver.save(save_data, save_location)
	if err == OK:
		print("saved!")
	else:
		print("save failed: ", err)

	if FirebaseManager:
		print("level ended. Update firebase")
		FirebaseManager.on_level_ended(str(curr_level))

func record_restart() -> void:
	ensure_save_data()

	if not save_data.level_restarts.has(curr_level):
		save_data.level_restarts[curr_level] = 0

	save_data.level_restarts[curr_level] += 1
	save_progress()

func mark_assist_triggered() -> void:
	ensure_save_data()
	save_data.assist_triggered_levels[curr_level] = true
	save_progress()

func get_baseline_time_ms() -> float:
	ensure_save_data()

	if curr_level <= 3:
		return 0.0

	var total := 0.0
	var count := 0

	for i in range(3, curr_level):
		if save_data.level_times_ms.has(i):
			total += float(save_data.level_times_ms[i])
			count += 1

	if count == 0:
		return 0.0

	return total / count

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		RunTimer.on_game_paused(true)

		if typeof(FirebaseManager) != TYPE_NIL:
			FirebaseManager.on_level_ended(str(curr_level))

		save_progress()

	if what == NOTIFICATION_APPLICATION_RESUMED:
		RunTimer.on_game_paused(false)

		if typeof(FirebaseManager) != TYPE_NIL:
			FirebaseManager.on_level_started(str(curr_level))
