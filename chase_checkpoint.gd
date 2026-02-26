extends Area2D

@onready var wall_respawn_point = $WallRespawnPoint

func _on_body_entered(body):
	if body.is_in_group("player"):
		# On cherche ton script Main (qui est la racine)
		var main = get_tree().root.get_node_or_null("Main")
		
		if main:
			# On sauvegarde les positions dans Main !
			main.has_checkpoint = true
			main.checkpoint_level_path = main.current_level_path
			main.checkpoint_player_pos = global_position
			main.checkpoint_wall_pos = wall_respawn_point.global_position
			
			# Désactive le checkpoint pour ne pas l'activer en boucle
			set_deferred("monitoring", false)
