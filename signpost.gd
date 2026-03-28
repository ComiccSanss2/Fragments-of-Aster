extends Area2D

@onready var prompt_sprite = $PromptSprite # L'icona "Interagisci" sopra il cartello

# --- ICONE PER INTERAGIRE COL CARTELLO ---
@export_group("Interaction Prompt")
@export var tex_interact_key: Texture2D
@export var tex_interact_pad: Texture2D

# --- ICONE DA MOSTRARE NEL TESTO (DINAMICHE) ---
@export_group("Dialogue Icons (In-Text)")
@export var tex_down_key: Texture2D
@export var tex_down_pad: Texture2D
@export var tex_up_key: Texture2D
@export var tex_up_pad: Texture2D

var player_in_zone := false
var is_reading := false
var current_player: CharacterBody2D = null 

var is_using_gamepad := false 

func _ready():
	prompt_sprite.visible = false
	
	# Effetto fluttuante per l'icona sopra il cartello
	var float_tween = create_tween().set_loops()
	var start_y = prompt_sprite.position.y
	float_tween.tween_property(prompt_sprite, "position:y", start_y - 4, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(prompt_sprite, "position:y", start_y, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _input(event):
	if event is InputEventKey or event is InputEventMouse:
		if is_using_gamepad:
			is_using_gamepad = false
			_update_prompt_image()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not is_using_gamepad:
			is_using_gamepad = true
			_update_prompt_image()

	if player_in_zone and not is_reading and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		read_sign()

func _update_prompt_image():
	if is_using_gamepad and tex_interact_pad:
		prompt_sprite.texture = tex_interact_pad
	elif not is_using_gamepad and tex_interact_key:
		prompt_sprite.texture = tex_interact_key

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_zone = true
		current_player = body 
		
		_update_prompt_image()
		prompt_sprite.visible = true
		prompt_sprite.modulate.a = 0.0
		
		var t = create_tween()
		t.tween_property(prompt_sprite, "modulate:a", 1.0, 0.2) 

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_zone = false
		if current_player == body:
			current_player = null
		
		var t_prompt = create_tween()
		t_prompt.tween_property(prompt_sprite, "modulate:a", 0.0, 0.2)
		t_prompt.tween_callback(func(): prompt_sprite.visible = false)

func read_sign():
	is_reading = true
	prompt_sprite.visible = false 
	
	if current_player:
		current_player.can_move = false
		current_player.velocity = Vector2.ZERO 
		current_player.jump_buffer_timer = 0.0 
		current_player.play_anim("idle")
	
	var dialog = get_tree().root.get_node_or_null("Main/UI/DialogueBox")
	if dialog:
		var font_start = "[font_size=28][color=#dddddd]"
		var font_end = "[/color][/font_size]"
		
		# --- COSTRUZIONE DEI TAG DINAMICI PER LA DIALOGUE BOX ---
		var tag_down = ""
		if tex_down_pad and tex_down_key:
			tag_down = "[input:" + tex_down_pad.resource_path + "|" + tex_down_key.resource_path + "]"
			
		var tag_up = ""
		if tex_up_pad and tex_up_key:
			tag_up = "[input:" + tex_up_pad.resource_path + "|" + tex_up_key.resource_path + "]"
		
		# La frase finale che viene mandata alla Dialogue Box
		var final_text = font_start + "Quick tip: hold " + tag_down + " or " + tag_up + " to peek ahead!" + font_end
		
		await dialog.show_dialog(final_text)
		await dialog.hide_dialog()
	
	if current_player:
		current_player.can_move = true
		
	if player_in_zone:
		prompt_sprite.visible = true
		prompt_sprite.modulate.a = 1.0
		
	await get_tree().create_timer(0.5).timeout
	is_reading = false
