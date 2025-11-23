extends Area2D

func _on_body_entered(body):
	if body.is_in_group("player"):
		get_tree().root.get_node("Main").load_level("res://scenes/levels/level_2.tscn")
