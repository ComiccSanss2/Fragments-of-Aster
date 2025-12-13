extends Node2D

@onready var player := $Player
@onready var level_root := $LevelRoot
@onready var camera := $Camera2D
@onready var transition_screen := $UI/TransitionScreen

var current_level_path: String = ""
var intro_played := false 
var grapple_collected := false
var dash_collected := false

func _ready():
	# Initialisation de l'écran noir (Transparent au début)
	if transition_screen:
		transition_screen.visible = true
		transition_screen.modulate.a = 0.0
	
	load_level("res://scenes/levels/level_1.tscn")

func load_level(path: String):
	current_level_path = path
	
	# Nettoyage
	for c in level_root.get_children():
		c.queue_free()

	# Chargement
	var level_scene = load(path).instantiate()
	level_root.add_child(level_scene)

	# Setup Player
	if level_scene.has_node("PlayerStart"):
		var spawn = level_scene.get_node("PlayerStart")
		player.global_position = spawn.global_position
		player.velocity = Vector2.ZERO
		
		# Reset du joueur
		player.can_move = true
		player.is_dying = false
		player.visible = true
	
	# Setup Camera
	if level_scene.has_node("LevelBounds"):
		var bounds = level_scene.get_node("LevelBounds")
		camera.set_bounds(bounds)


# --- TRANSITION DE NIVEAU (Simple Fade) ---
func change_level_with_transition(next_level_path: String):
	# 1. Bloquer le joueur
	player.can_move = false
	player.velocity = Vector2.ZERO
	
	# 2. FADE OUT (L'écran devient NOIR)
	var t = create_tween()
	# On passe l'alpha à 1.0 en 0.5 secondes
	t.tween_property(transition_screen, "modulate:a", 1.0, 0.5)
	await t.finished
	
	# 3. CHARGEMENT DU NOUVEAU NIVEAU
	load_level(next_level_path)
	
	# Petite attente technique
	await get_tree().process_frame
	player.can_move = false
	player.velocity = Vector2.ZERO
	
	# 4. FADE IN (L'écran redevient TRANSPARENT)
	var t2 = create_tween()
	# On remet l'alpha à 0.0 en 0.5 secondes
	t2.tween_property(transition_screen, "modulate:a", 0.0, 0.5)
	await t2.finished
	
	# 5. C'est parti !
	player.can_move = true


# --- SÉQUENCE DE MORT (Simple Fade) ---
func play_death_sequence():
	player.can_move = false
	player.velocity = Vector2.ZERO
	
	# Attente dramatique
	await get_tree().create_timer(0.5).timeout
	
	# FADE OUT (Noir)
	var t = create_tween()
	t.tween_property(transition_screen, "modulate:a", 1.0, 0.5)
	await t.finished
	
	# RELOAD
	if current_level_path != "":
		load_level(current_level_path)
	
	await get_tree().process_frame
	player.can_move = false
	player.velocity = Vector2.ZERO
	
	# Attente Respawn
	await get_tree().create_timer(0.5).timeout
	
	# FADE IN (Transparent)
	var t2 = create_tween()
	t2.tween_property(transition_screen, "modulate:a", 0.0, 0.5)
	await t2.finished
	
	player.can_move = true
	player.is_dying = false

# UI Helpers (Garde ça si tu l'utilises pour le grappin)
func show_grapple_message(msg: String):
	var label = $UI/CenterContainer/EchoText
	if label:
		label.text = msg
		$UI.visible = true

func hide_grapple_message():
	$UI.visible = false
