extends Area2D

# Vitesse du mur (à ajuster selon la vitesse de course du joueur)
@export var speed := 150.0 

func _physics_process(delta):
	# Le mur avance toujours vers la droite
	position.x += speed * delta

# Connecte le signal "body_entered" de l'Area2D à ce script
func _on_body_entered(body):
	if body.is_in_group("player"):
		# Au lieu d'appeler le Main directement, on appelle la vraie mort du joueur !
		# On lui passe global_position pour que le joueur soit repoussé dans le bon sens.
		if body.has_method("die"):
			body.die(global_position)
