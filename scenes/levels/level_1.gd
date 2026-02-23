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
	
	# --- CORRECTION ICI : lerp_speed AU LIEU DE follow_smoothness ---
	if "lerp_speed" in main.camera:
		main.camera.lerp_speed = 8.0 
		
	# --- CORRECTION ICI : default_offset AU LIEU DE cam_offset ---
	if "default_offset" in main.camera:
		main.camera.default_offset.y = 15.0
	
	main.trigger_shake(50.0)
	
	await get_tree().create_timer(2.5).timeout
	start_tutorial_sequence()
