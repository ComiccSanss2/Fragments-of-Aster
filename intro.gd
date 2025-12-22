extends Control

@onready var label = $Label
@onready var wind_player = $AmbiancePlayer

func _ready():
	# Setup
	label.modulate.a = 0.0
	if wind_player and not wind_player.playing:
		wind_player.play()
	
	# Séquence de texte
	play_line("Aster... a fractured memory floating in the void.")
	await get_tree().create_timer(6.0).timeout
	
	play_line("The roots have gone silent. Only fragments remain.")
	await get_tree().create_timer(6.0).timeout
	
	play_line("Awaken, Lyra. The Shards are calling.")
	await get_tree().create_timer(6.0).timeout
	
	# --- FIN DE L'INTRO ---
	finish_intro()

func play_line(text: String):
	label.text = text
	var t = create_tween()
	t.tween_property(label, "modulate:a", 1.0, 2.0)
	t.tween_interval(2.0)
	# Fade out un peu plus long pour le style
	t.tween_property(label, "modulate:a", 0.0, 1.5)

func finish_intro():
	# 1. On s'assure que tout est noir (le texte est déjà parti)
	
	# 2. On baisse le son du vent doucement
	var t = create_tween()
	if wind_player: t.tween_property(wind_player, "volume_db", -80.0, 2.0)
	
	# 3. On note l'info pour le Main
	SaveManager.set_meta("intro_sequence", true)
	
	# 4. Attente pour la synchro
	await t.finished
	
	# 5. CHANGEMENT DIRECT (Pas de LoadingScreen)
	# Comme le niveau est léger, ce sera instantané.
	get_tree().change_scene_to_file("res://scenes/main.tscn")
