extends Control

@onready var panel := $Panel
@onready var text_label := $Text 
@onready var portrait := $Panel/Portrait
@onready var space_hint := $Panel/SpaceHint 
@onready var voice_player := $VoicePlayer 

@export_group("Bouton Continuer")
@export var tex_prompt_key: Texture2D
@export var tex_prompt_pad: Texture2D

var waiting_for_space := false
var is_using_gamepad := false 

# --- NOUVEAU : Sauvegarde la phrase pour pouvoir la modifier en direct ---
var current_raw_text := "" 

const DEFAULT_PITCH = 2.5

func _ready():
	visible = false
	modulate.a = 1.0
	
	if space_hint:
		var t = create_tween().set_loops()
		var base_y = space_hint.position.y
		t.tween_property(space_hint, "position:y", base_y - 4, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(space_hint, "position:y", base_y, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _input(event):
	if event is InputEventKey or event is InputEventMouse:
		if is_using_gamepad:
			is_using_gamepad = false
			_update_dynamic_inputs()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not is_using_gamepad:
			is_using_gamepad = true
			_update_dynamic_inputs()

func _update_dynamic_inputs():
	# 1. Met à jour l'icône "Continuer" en bas à droite
	if space_hint:
		if is_using_gamepad and tex_prompt_pad:
			space_hint.texture = tex_prompt_pad
		elif not is_using_gamepad and tex_prompt_key:
			space_hint.texture = tex_prompt_key
	
	# 2. NOUVEAU : Met à jour le texte en direct si la boîte est ouverte !
	if visible and current_raw_text != "":
		_apply_text_and_images()

# --- LA MAGIE EST ICI ---
func _apply_text_and_images():
	var final_text = current_raw_text
	
	# On cherche notre balise custom : [input:chemin_manette|chemin_clavier]
	while "[input:" in final_text:
		var start_idx = final_text.find("[input:")
		var end_idx = final_text.find("]", start_idx)
		if end_idx == -1: break
		
		var inner = final_text.substr(start_idx + 7, end_idx - start_idx - 7)
		var paths = inner.split("|")
		
		if paths.size() >= 2:
			var pad_p = paths[0]
			var key_p = paths[1]
			# On choisit l'image en direct selon le contrôleur actuel
			var chosen = pad_p if is_using_gamepad else key_p
			var img_tag = "  [img=48]" + chosen + "[/img]  "
			
			# On remplace notre balise custom par la balise image de Godot
			final_text = final_text.replace("[input:" + inner + "]", img_tag)
		else:
			break
			
	# Comme la balise image compte toujours comme 1 seul caractère pour Godot, 
	# ça ne casse pas l'effet machine à écrire !
	text_label.text = final_text
# ------------------------

func show_dialog(text: String, portrait_tex: Texture2D = null, custom_pitch: float = -2.0) -> void:
	visible = true
	modulate.a = 1.0
	
	current_raw_text = text
	_update_dynamic_inputs() # Applica il testo al RichTextLabel

	if portrait_tex != null:
		portrait.texture = portrait_tex
		portrait.visible = true
	else:
		portrait.visible = false

	space_hint.visible = false
	waiting_for_space = false
	
	# ==========================================================
	# IL BYPASS DEFINITIVO: Contiamo le lettere in memoria!
	# ==========================================================
	var parsed_text = text_label.get_parsed_text()
	var total_chars = parsed_text.length()
	
	# Debug utile: Stampa nella console cosa sta per scrivere
	print("Inizio dialogo. Lettere totali da scrivere: ", total_chars)
	
	# Se per qualche assurdo motivo è 0, lo forziamo a 1 per evitare crash
	if total_chars <= 0:
		total_chars = 1
		
	text_label.visible_characters = 0 
	# ==========================================================
	
	var current_pitch = DEFAULT_PITCH
	if custom_pitch > 0.0:
		current_pitch = custom_pitch
	
	var wait_time = 0.05 
	if voice_player.stream:
		wait_time = voice_player.stream.get_length() / current_pitch
	wait_time = clamp(wait_time, 0.02, 0.1)

	var time_dialog_started = Time.get_ticks_msec()
	
	for i in range(total_chars):
		text_label.visible_characters = i + 1
		
		var is_fast_forward = (Time.get_ticks_msec() - time_dialog_started) > 250 and Input.is_action_pressed("ui_accept")
		
		if not is_fast_forward or i % 2 == 0:
			voice_player.pitch_scale = randf_range(current_pitch - 0.1, current_pitch + 0.1)
			voice_player.play()

		var current_wait = 0.03 if is_fast_forward else wait_time
		
		await get_tree().create_timer(current_wait).timeout

	text_label.visible_characters = -1 # Mostra tutto alla fine in modo sicuro
	space_hint.visible = true
	waiting_for_space = true

	await get_tree().create_timer(0.1).timeout

	while waiting_for_space:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):
			waiting_for_space = false

func hide_dialog():
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	await t.finished
	visible = false
	modulate.a = 1.0
