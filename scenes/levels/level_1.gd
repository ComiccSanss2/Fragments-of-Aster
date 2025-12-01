extends Node2D

func _ready() -> void:
	await get_tree().process_frame 

	var player = get_tree().root.get_node("Main/Player")
	var dialog = get_tree().root.get_node("Main/UI/DialogueBox")

	# Figer le joueur
	player.can_move = false
	player.velocity = Vector2.ZERO
	player.play_anim("idle")

	# Lancer le dialogue d'intro
	await dialog.show_dialog("Press ARROW KEYS to MOVE")
	await dialog.show_dialog("Press SPACE to JUMP")
	await dialog.show_dialog("Press SHIFT to CLIMB")
	dialog.hide_dialog()


	# Rendre le contrôle au joueur
	player.can_move = true
	player.play_anim("idle")
