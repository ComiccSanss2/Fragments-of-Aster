extends Area2D

@onready var sprite = $AnimatedSprite2D
@onready var light = $PointLight2D 
@onready var prompt_sprite = $PromptSprite # <-- L'icône de la touche

# --- IMAGES DES TOUCHES (À glisser dans l'Inspecteur) ---
@export var tex_keyboard: Texture2D
@export var tex_gamepad: Texture2D

var player_in_zone := false
var is_reading := false
var current_player: CharacterBody2D = null 

# Mémorise le dernier périphérique utilisé
var is_using_gamepad := false 

const TERMINAL_FONT = "res://assets/fonts/ThaleahFat.ttf"
const TERMINAL_PITCH = 0.8 

func _ready():
	sprite.stop()
	light.energy = 0.0 
	prompt_sprite.visible = false # L'icône est cachée au début
	
	# --- LE BONUS JUICE : Fait flotter l'icône de haut en bas ---
	var float_tween = create_tween().set_loops()
	var start_y = prompt_sprite.position.y
	float_tween.tween_property(prompt_sprite, "position:y", start_y - 4, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(prompt_sprite, "position:y", start_y, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- CHANGEMENT DYNAMIQUE DE L'ICÔNE ---
func _input(event):
	# 1. On vérifie quel périphérique le joueur est en train d'utiliser
	if event is InputEventKey or event is InputEventMouse:
		if is_using_gamepad:
			is_using_gamepad = false
			_update_prompt_image()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not is_using_gamepad:
			is_using_gamepad = true
			_update_prompt_image()

	# 2. L'interaction avec le terminal
	if player_in_zone and not is_reading and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		read_terminal()

func _update_prompt_image():
	if is_using_gamepad and tex_gamepad:
		prompt_sprite.texture = tex_gamepad
	elif not is_using_gamepad and tex_keyboard:
		prompt_sprite.texture = tex_keyboard

# --- DÉTECTION DU JOUEUR ---
func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_zone = true
		current_player = body 
		
		sprite.play("idle")
		
		# On affiche l'icône de touche et on met la bonne image
		_update_prompt_image()
		prompt_sprite.visible = true
		prompt_sprite.modulate.a = 0.0
		
		var t = create_tween()
		t.tween_property(light, "energy", 1.5, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(prompt_sprite, "modulate:a", 1.0, 0.2) # Fondu d'apparition de l'icône

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_zone = false
		if current_player == body:
			current_player = null
		
		sprite.stop()
		var t = create_tween()
		t.tween_property(light, "energy", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		# Cacher l'icône
		var t_prompt = create_tween()
		t_prompt.tween_property(prompt_sprite, "modulate:a", 0.0, 0.2)
		t_prompt.tween_callback(func(): prompt_sprite.visible = false)

# --- LECTURE DU TERMINAL ---
func read_terminal():
	is_reading = true
	prompt_sprite.visible = false # On cache l'icône pendant qu'on lit !
	
	if current_player:
		current_player.can_move = false
		current_player.velocity = Vector2.ZERO 
		current_player.jump_buffer_timer = 0.0 
		current_player.play_anim("idle")
	
	var dialog = get_tree().root.get_node_or_null("Main/UI/DialogueBox")
	if dialog:
		if sprite.sprite_frames.has_animation("active"):
			sprite.play("active")
			
		var t_flash = create_tween()
		t_flash.tween_property(light, "energy", 2.5, 0.1)
		t_flash.tween_property(light, "energy", 1.5, 0.2)
			
		var font_tag_start = "[font=\"" + TERMINAL_FONT + "\"][font_size=40]"
		var font_tag_end = "[/font_size][/font]"
		
		await dialog.show_dialog(font_tag_start + "[color=#00ff99]> INITIALIZING SECURE LOG...[/color]" + font_tag_end, null, TERMINAL_PITCH)
		await dialog.show_dialog(font_tag_start + "[color=#00ff99]> LOG #004: They don't know about the roots.[/color]" + font_tag_end, null, TERMINAL_PITCH)
		await dialog.show_dialog(font_tag_start + "[color=#00ff99]> LOG #004: The Architect is blind to this sector.[/color]" + font_tag_end, null, TERMINAL_PITCH)

		await dialog.show_dialog(
			"[color=#33d9ff]Who left this message here? The code feels... familiar.[/color]", 
			preload("res://assets/dialoguebox/portrait.png") 
		)
		
		await dialog.hide_dialog()
	
	sprite.play("idle")
	
	if current_player:
		current_player.can_move = true
		
	# On réaffiche l'icône à la fin si le joueur est toujours devant
	if player_in_zone:
		prompt_sprite.visible = true
		prompt_sprite.modulate.a = 1.0
		
	await get_tree().create_timer(0.5).timeout
	is_reading = false
