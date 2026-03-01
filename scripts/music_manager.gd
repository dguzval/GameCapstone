extends Node2D

@onready var musicAudioStreamBM : AudioStreamPlayer2D = $Background
@onready var exitSFX : AudioStreamPlayer2D = $Exit
@onready var keySFX : AudioStreamPlayer2D = $Key
@onready var gravButtonSFX : AudioStreamPlayer2D = $Gravity_Button
var backgroundMusicOn : bool = true

func _process(_delta: float) -> void:
	update_music_stats()
	
func update_music_stats():
	if backgroundMusicOn:
		if !musicAudioStreamBM.playing:
			musicAudioStreamBM.play()
	else:
		musicAudioStreamBM.stop()
		
func exit_triggered():
	exitSFX.play()
	
func key_pickup():
	keySFX.play()
	
func gravButtonPressed():
	gravButtonSFX.play()
	
