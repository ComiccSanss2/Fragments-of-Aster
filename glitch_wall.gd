extends Area2D

# Vitesse du mur (à ajuster selon la vitesse de course du joueur)
@export var speed := 150.0 

func _physics_process(delta):
	# Le mur avance toujours vers la droite
	position.x += speed * delta

# Connecte le signal "body_entered" de l'Area2D à ce script
func _on_body_entered(body):
	if body.is_in_group("player"):
		# On appelle la mort du joueur via le Main
		var main = get_tree().root.get_node("Main")
		if main:
			main.play_death_sequence()
