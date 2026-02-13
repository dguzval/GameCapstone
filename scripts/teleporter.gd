extends Area2D
# put the 2nd teleporter in this value through the inspector screen 
# this way you move from one teleporters location to anothers
@export var landing_zone : Area2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_body_entered(body: Node2D) -> void:
	if(body.is_in_group("player") && body.can_tp):
		body.can_tp = false
		var tp_point = landing_zone.get_node("Marker2D").global_position
		body.global_position = tp_point
		await get_tree().create_timer(1.00).timeout
		body.can_tp = true
