extends Control

@onready var speed_lines = $SpeedLines # Il nodo CPUParticles2D che hai creato
@onready var camera = $Camera2D
@onready var parallax_layer = $ParallaxBackground/ParallaxLayer # Opzionale, per lo sfondo
@onready var crash_sfx = $CrashSound

var is_falling = true
var fall_speed = 2500.0 # Velocità ESTREMA per far scorrere lo sfondo
var player: CharacterBody2D = null

func _ready():
	# 1. Carichiamo il Main per ottenere i riferimenti
	var main = get_tree().root.get_node_or_null("Main")
	if not main:
		push_error("Main non trovato!")
		return
	
	player = main.player # Otteniamo il Player reale
	var camera_follower = player.get_node_or_null("CameraFollower") # Il RemoteTransform2D

	# 2. Carichiamo il primo livello dello Scrapyard
	# (Cambia il percorso col nome reale del tuo livello)
	var level_scene = load("res://scenes/levels/level_17.tscn")
	if level_scene:
		var level_instance = level_scene.instantiate()
		add_child(level_instance) # Aggiungiamo il livello a questa scena
		
		# Troviamo lo spawn point del livello e posizioniamo Lyra
		if level_instance.has_node("PlayerStart"):
			player.global_position = level_instance.get_node("PlayerStart").global_position
		
		# Assicuriamoci che la telecamera principale segua Lyra
		if camera_follower:
			camera_follower.remote_path = main.camera.get_path() # Pontiamo alla telecamera principale
	
	# 3. Cadiamo per 4 secondi, poi ci schiantiamo
	var timer = get_tree().create_timer(4.0)
	timer.timeout.connect(land_in_scrapyard)

func _process(delta):
	if is_falling:
		# Muoviamo lo sfondo in alto per far sembrare che cadiamo in basso
		if parallax_layer:
			parallax_layer.motion_offset.y -= fall_speed * delta

func land_in_scrapyard():
	is_falling = false
	speed_lines.emitting = false
	
	if crash_sfx and crash_sfx.stream:
		crash_sfx.play()
	
	# CAMERA SHAKE VIOLENTO (Usa la Camera principale nel Main!)
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.camera:
		var shake_tween = create_tween()
		var shake_strength = 50.0
		for i in range(15):
			shake_tween.tween_property(main.camera, "offset", Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength)), 0.04)
			shake_strength *= 0.75
		shake_tween.tween_property(main.camera, "offset", Vector2.ZERO, 0.05)
	
	# Pausa a schermo fermo (fa elaborare l'impatto al giocatore)
	await get_tree().create_timer(2.5).timeout
	
	# Sfuma tutto a nero dolcemente e torna a Main
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 1.0)
	await fade_out.finished
	
	go_to_scrapyard_level()

func go_to_scrapyard_level():
	# Diciamo al SaveManager di caricare il livello 17
	# (Sostituisci il percorso col nome reale del tuo livello giocabile)
	SaveManager.set_meta("level_to_load", "res://scenes/levels/level_17.tscn") 
	
	# Ricarichiamo il Main. Lui leggerà il meta e avvierà il gioco!
	get_tree().change_scene_to_file("res://main.tscn")
