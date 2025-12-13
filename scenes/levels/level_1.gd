extends Node2D

func _ready() -> void:
	# On récupère le Main
	var main = get_tree().root.get_node("Main")
	
	# SI l'intro a déjà été jouée, on arrête tout de suite !
	if main.intro_played:
		return
	
	# Sinon, on joue l'intro
	await get_tree().process_frame
	
	var player = main.get_node("Player")
	var dialog = main.get_node("UI/DialogueBox") # Attention au chemin vers UI

	# Figer le joueur
	player.can_move = false
	player.velocity = Vector2.ZERO
	player.play_anim("idle")

	# Dialogues
	await dialog.show_dialog("Press (ARROW KEYS) or (DPAD) to MOVE")
	await dialog.show_dialog("Press (SPACE) or (A) to JUMP")
	await dialog.show_dialog("Press (SHIFT) or (RB) to CLIMB")
	dialog.hide_dialog()

	# Rendre le contrôle
	player.can_move = true
	
	# On note dans le Main que c'est fait !
	main.intro_played = true
