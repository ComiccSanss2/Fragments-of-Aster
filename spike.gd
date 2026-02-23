extends Area2D

func _on_body_entered(body):
	# On vérifie si c'est le joueur
	if body.is_in_group("player"):
		# On appelle sa fonction de mort en lui envoyant la position du pic !
		if body.has_method("die"):
			body.die(global_position)
