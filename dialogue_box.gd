extends Control

@onready var panel := $Panel
@onready var text_label := $Panel/Text
@onready var portrait := $Panel/Portrait
@onready var space_hint := $Panel/SpaceHint
@onready var voice_player := $VoicePlayer 

var waiting_for_space := false

# Pitch par défaut (Lyra)
const DEFAULT_PITCH = 2.5

func _ready():
	visible = false
	modulate.a = 1.0

# AJOUT : paramètre 'custom_pitch' (0.0 = par défaut)
func show_dialog(text: String, portrait_tex: Texture2D = null, custom_pitch: float = -2.0) -> void:
	visible = true
	modulate.a = 1.0

	# Gestion du portrait
	if portrait_tex != null:
		portrait.texture = portrait_tex
		portrait.visible = true
	else:
		portrait.visible = false

	text_label.text = ""
	space_hint.visible = false
	waiting_for_space = false

	# --- CONFIGURATION DE LA VOIX ---
	var current_pitch = DEFAULT_PITCH
	if custom_pitch > 0.0:
		current_pitch = custom_pitch
	
	# Calcul du temps d'attente (Vitesse d'écriture)
	# Note : Une voix grave (pitch bas) prend plus de temps à jouer, donc le texte s'écrira plus lentement,
	# ce qui donne un effet "imposant" au Boss.
	var wait_time = 0.05 
	if voice_player.stream:
		wait_time = voice_player.stream.get_length() / current_pitch
	
	# Pour éviter que le boss parle trop lentement si le son est long, on cap le wait_time
	wait_time = clamp(wait_time, 0.02, 0.1)

	# --- BOUCLE D'ÉCRITURE ---
	for i in text.length():
		text_label.text = text.substr(0, i + 1)
		var current_char = text[i]
		
		# On joue le son à chaque lettre (sauf espace)
		if current_char != " ":
			voice_player.pitch_scale = randf_range(current_pitch - 0.1, current_pitch + 0.1)
			voice_player.play()
		
		await get_tree().create_timer(wait_time).timeout

	# Fin
	space_hint.visible = true
	waiting_for_space = true

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
