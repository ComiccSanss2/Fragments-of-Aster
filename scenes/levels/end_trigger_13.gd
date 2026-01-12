extends Area2D

@export var next_level_path := "res://scenes/levels/level_14.tscn"

func _on_body_entered(body):
	if body.is_in_group("player"):
		var main = get_tree().root.get_node("Main")
		# Appel de la version simple sans shader
		main.change_level_with_transition(next_level_path)
