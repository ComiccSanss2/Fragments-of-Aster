extends Area2D

@export var next_level_path := "res://scenes/levels/level_3.tscn"

func _on_body_entered(body):
	if body.is_in_group("player"):
		get_node("/root/Main").load_level(next_level_path)
