extends Control

@onready var panel := $Panel
@onready var text_label := $Panel/Text
@onready var portrait := $Panel/Portrait
@onready var space_hint := $Panel/SpaceHint
@onready var voice_player := $VoicePlayer 

var waiting_for_space := false

# REGLAGES
# Plus le pitch est haut, plus le son est court et aigu (Chipmunk).
# 1.0 = Son normal (0.24s) -> Texte très lent
# 2.0 = Son 2x plus rapide (0.12s) -> Texte moyen (Recommandé)
const VOICE_PITCH = 2.5

func _ready():
	visible = false
	modulate.a = 1.0

func show_dialog(text: String, portrait_tex: Texture2D = null) -> void:
	visible = true
	modulate.a = 1.0

	var is_lyra_talking = false
	if portrait_tex != null:
		portrait.texture = portrait_tex
		portrait.visible = true
		is_lyra_talking = true
	else:
		portrait.visible = false
		is_lyra_talking = false

	text_label.text = ""
	space_hint.visible = false
	waiting_for_space = false

	# Calcul du temps d'attente exact
	var wait_time = 0.02 # Vitesse par défaut (rapide pour le système)
	
	if is_lyra_talking:
		# Si le son fait 0.24s et le pitch est 2.0, le nouveau temps est 0.12s
		# On récupère la durée du fichier audio directement
		if voice_player.stream:
			wait_time = voice_player.stream.get_length() / VOICE_PITCH
		else:
			wait_time = 0.1

	# --- Boucle d'écriture ---
	for i in text.length():
		text_label.text = text.substr(0, i + 1)
		var current_char = text[i]
		
		# On joue le son à chaque lettre (sauf espace)
		if is_lyra_talking and current_char != " ":
			voice_player.pitch_scale = randf_range(VOICE_PITCH - 0.1, VOICE_PITCH + 0.1)
			voice_player.play()
		
		# On attend exactement la durée du son avant d'afficher la lettre suivante
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
