extends Control

@onready var panel := $Panel
# Assure-toi que "Text" est bien un RichTextLabel dans ta scène !
@onready var text_label := $Panel/Text 
@onready var portrait := $Panel/Portrait
@onready var space_hint := $Panel/SpaceHint
@onready var voice_player := $VoicePlayer 

var waiting_for_space := false
const DEFAULT_PITCH = 2.5

func _ready():
	visible = false
	modulate.a = 1.0

func show_dialog(text: String, portrait_tex: Texture2D = null, custom_pitch: float = -2.0) -> void:
	visible = true
	modulate.a = 1.0

	if portrait_tex != null:
		portrait.texture = portrait_tex
		portrait.visible = true
	else:
		portrait.visible = false

	# 1. PRÉPARATION DU TEXTE
	space_hint.visible = false
	waiting_for_space = false
	
	text_label.text = text
	text_label.visible_characters = 0
	
	# 2. CONFIGURATION VOIX
	var current_pitch = DEFAULT_PITCH
	if custom_pitch > 0.0:
		current_pitch = custom_pitch
	
	var wait_time = 0.05 
	if voice_player.stream:
		wait_time = voice_player.stream.get_length() / current_pitch
	wait_time = clamp(wait_time, 0.02, 0.1)

	var time_dialog_started = Time.get_ticks_msec()

	# 3. BOUCLE D'ÉCRITURE (Simplifiée et ralentie)
	var total_chars = text_label.get_total_character_count()
	
	for i in range(total_chars):
		text_label.visible_characters = i + 1
		
		# On vérifie si on a dépassé les 250ms de sécurité ET si le joueur appuie
		var is_fast_forward = (Time.get_ticks_msec() - time_dialog_started) > 250 and Input.is_action_pressed("ui_accept")
		
		# On joue le son (1 fois sur 2 si on est en rapide pour ne pas saturer)
		if not is_fast_forward or i % 2 == 0:
			voice_player.pitch_scale = randf_range(current_pitch - 0.1, current_pitch + 0.1)
			voice_player.play()

		# --- LE SECRET EST ICI ---
		# En rapide, on attend 0.03s (exactement la moitié de la vitesse d'avant).
		# En normal, on attend le wait_time habituel.
		var current_wait = 0.03 if is_fast_forward else wait_time
		
		await get_tree().create_timer(current_wait).timeout

	# Sécurité : on affiche tout à la fin pour être sûr
	text_label.visible_ratio = 1.0
	
	# 4. ATTENTE DU JOUEUR
	space_hint.visible = true
	waiting_for_space = true

	# Micro-pause avant d'autoriser la fermeture
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
