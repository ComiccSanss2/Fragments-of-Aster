extends Area2D

func _on_body_entered(body):
	# On vérifie si c'est le joueur
	if body.is_in_group("player"):
		# On appelle sa fonction de mort (qui va appeler le Main)
		if body.has_method("die"):
			body.die()
