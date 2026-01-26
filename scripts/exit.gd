extends Area2D


func _on_body_entered(_body: Node2D) -> void:
	print("exited level")
	queue_free()
