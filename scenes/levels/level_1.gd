extends Node2D

var is_waiting_for_landing = false

func _ready() -> void:
	# On ne fait RIEN ici. C'est Main qui commande.
	pass

# Appelée par Main pour l'intro
func start_intro_sequence():
	var main = get_tree().root.get_node("Main")
	var player = main.get_node("Player")
	
	is_waiting_for_landing = true
	player.can_move = false
	player.velocity = Vector2.ZERO

# Appelée par Main (ou fallback) pour le tuto standard
func start_tutorial_sequence():
	var main = get_tree().root.get_node("Main")
	var player = main.get_node("Player")
	var dialog = main.get_node("UI/DialogueBox")
	
	player.can_move = false
	player.play_anim("idle")
	
	await dialog.show_dialog("Press (ARROW KEYS) or (DPAD) to MOVE")
	await dialog.show_dialog("Press (SPACE) or (A) to JUMP")
	await dialog.show_dialog("Press (SHIFT) or (RB) to CLIMB")
	
	dialog.hide_dialog()
	player.can_move = true
	main.intro_played = true
	
	SaveManager.save_game(SaveManager.current_slot_id, {
		"current_level": main.current_level_path,
		"intro_played": true,
		"grapple_unlocked": player.grapple_unlocked,
		"dash_unlocked": player.dash_unlocked
	})

func _process(delta):
	if is_waiting_for_landing:
		var main = get_tree().root.get_node("Main")
		var player = main.get_node("Player")
		
		if player.is_on_floor():
			is_waiting_for_landing = false
			landing_impact()

func landing_impact():
	var main = get_tree().root.get_node("Main")
	main.trigger_shake(10.0)
	await get_tree().create_timer(2.0).timeout
	start_tutorial_sequence()
