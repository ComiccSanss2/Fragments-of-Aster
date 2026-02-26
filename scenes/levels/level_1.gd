extends Node2D

var is_waiting_for_landing = false

# --- IMAGES DES TOUCHES (À glisser dans l'Inspecteur) ---
@export_group("Touches de Mouvement")
@export var tex_move_key: Texture2D
@export var tex_move_pad: Texture2D

@export_group("Touches de Saut")
@export var tex_jump_key: Texture2D
@export var tex_jump_pad: Texture2D

@export_group("Touches de Grimpette")
@export var tex_climb_key: Texture2D
@export var tex_climb_pad: Texture2D
# --------------------------------------------------------

func _ready() -> void:
	pass

func start_intro_sequence():
	var main = get_tree().root.get_node("Main")
	var player = main.get_node("Player")
	
	is_waiting_for_landing = true
	player.can_move = false
	player.velocity = Vector2.ZERO

# --- GÉNÉRATEUR D'INPUT DYNAMIQUE AVEC INSPECTEUR ---
func get_input_name(action: String) -> String:
	var tex_pad: Texture2D = null
	var tex_key: Texture2D = null
	
	match action:
		"move":
			tex_pad = tex_move_pad
			tex_key = tex_move_key
		"jump":
			tex_pad = tex_jump_pad
			tex_key = tex_jump_key
		"climb":
			tex_pad = tex_climb_pad
			tex_key = tex_climb_key
			
	if tex_pad and tex_key:
		# On envoie les DEUX chemins à la DialogueBox via notre balise custom
		return "[input:" + tex_pad.resource_path + "|" + tex_key.resource_path + "]"
	
	return ""
	return ""
# ------------------------------------

func start_tutorial_sequence():
	var main = get_tree().root.get_node("Main")
	var player = main.get_node("Player")
	var dialog = main.get_node("UI/DialogueBox")
	
	player.can_move = false
	player.play_anim("idle")
	
	# --- AJOUT DE LA TAILLE DE POLICE ---
	var size_start = "[font_size=40]" # Modifie ce nombre pour ajuster la taille globale
	var size_end = "[/font_size]"
	
	await dialog.show_dialog(size_start + "Press" + get_input_name("move") + "to MOVE" + size_end)
	await dialog.show_dialog(size_start + "Press" + get_input_name("jump") + "to JUMP" + size_end)
	await dialog.show_dialog(size_start + "Press" + get_input_name("climb") + "to CLIMB" + size_end)
	
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
