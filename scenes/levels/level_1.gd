extends Node2D

var is_waiting_for_landing = false

func _ready() -> void:
	pass

func start_intro_sequence():
	var main = get_tree().root.get_node("Main")
	var player = main.get_node("Player")
	
	is_waiting_for_landing = true
	player.can_move = false
	player.velocity = Vector2.ZERO

# --- GÉNÉRATEUR D'INPUT DYNAMIQUE ---
func get_input_name(action: String) -> String:
	var main = get_tree().root.get_node("Main")
	var is_pad = main.is_using_gamepad
	
	match action:
		"move":
			return "[color=#ffdd33](DPAD)[/color]" if is_pad else "[color=#ffdd33](ARROW KEYS)[/color]"
		"jump":
			return "[color=#ffdd33](A)[/color]" if is_pad else "[color=#ffdd33](SPACE)[/color]"
		"climb":
			return "[color=#ffdd33](RB)[/color]" if is_pad else "[color=#ffdd33](SHIFT)[/color]"
	return ""
# ------------------------------------

func start_tutorial_sequence():
	var main = get_tree().root.get_node("Main")
	var player = main.get_node("Player")
	var dialog = main.get_node("UI/DialogueBox")
	
	player.can_move = false
	player.play_anim("idle")
	
	# Utilisation de la fonction dynamique
	await dialog.show_dialog("Press " + get_input_name("move") + " to MOVE")
	await dialog.show_dialog("Press " + get_input_name("jump") + " to JUMP")
	await dialog.show_dialog("Press " + get_input_name("climb") + " to CLIMB")
	
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
	
	if "lerp_speed" in main.camera:
		main.camera.lerp_speed = 8.0 
		
	if "default_offset" in main.camera:
		main.camera.default_offset.y = 15.0
	
	main.trigger_shake(50.0)
	
	await get_tree().create_timer(2.5).timeout
	start_tutorial_sequence()
