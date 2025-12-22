extends Node2D

@onready var player := $Player
@onready var level_root := $LevelRoot
@onready var camera := $Camera2D
@onready var transition_screen := $UI/TransitionScreen
# Ajout d'une référence au CanvasLayer UI pour y mettre le menu pause
@onready var ui_layer := $UI 

var current_level_path: String = ""

# --- VARIABLES D'ÉTAT GLOBALES ---
var intro_played := false 
var grapple_collected := false
var dash_collected := false

func _ready():
	# Initialisation de l'écran noir (Transparent au début)
	if transition_screen:
		transition_screen.visible = true
		transition_screen.modulate.a = 0.0
	
	# --- AJOUT DU MENU PAUSE ---
	# Assure-toi que le chemin est bon (ex: res://scenes/PauseMenu.tscn)
	var pause_menu = load("res://pause_menu.tscn").instantiate()
	ui_layer.add_child(pause_menu)
	# Le script du pause_menu s'occupera de se cacher tout seul au démarrage
	# ---------------------------
	
	# --- INTÉGRATION SAVE SYSTEM ---
	if SaveManager.has_meta("level_to_load"):
		var target_level = SaveManager.get_meta("level_to_load")
		SaveManager.remove_meta("level_to_load")
		
		if SaveManager.current_slot_id != -1:
			var data = SaveManager.load_data(SaveManager.current_slot_id)
			if data:
				grapple_collected = data.get("grapple_unlocked", false)
				dash_collected = data.get("dash_unlocked", false)
				intro_played = data.get("intro_played", false)
		
		load_level(target_level)
	else:
		load_level("res://scenes/levels/level_1.tscn")

# ... (Le reste de ton script load_level, change_level, etc. reste identique)
func load_level(path: String):
	current_level_path = path
	for c in level_root.get_children():
		c.queue_free()
	var level_scene = load(path).instantiate()
	level_root.add_child(level_scene)
	if level_scene.has_node("PlayerStart"):
		var spawn = level_scene.get_node("PlayerStart")
		player.global_position = spawn.global_position
		player.velocity = Vector2.ZERO
		player.can_move = true
		player.is_dying = false
		player.visible = true
		player.grapple_unlocked = grapple_collected
		player.dash_unlocked = dash_collected
	if level_scene.has_node("LevelBounds"):
		var bounds = level_scene.get_node("LevelBounds")
		camera.set_bounds(bounds)
	if SaveManager.current_slot_id != -1:
		var data_to_save = {
			"current_level": current_level_path,
			"grapple_unlocked": grapple_collected,
			"dash_unlocked": dash_collected,
			"intro_played": intro_played
		}
		SaveManager.save_game(SaveManager.current_slot_id, data_to_save)

func change_level_with_transition(next_level_path: String):
	player.can_move = false
	player.velocity = Vector2.ZERO
	var t = create_tween()
	t.tween_property(transition_screen, "modulate:a", 1.0, 0.5)
	await t.finished
	load_level(next_level_path)
	await get_tree().process_frame
	player.can_move = false
	player.velocity = Vector2.ZERO
	var t2 = create_tween()
	t2.tween_property(transition_screen, "modulate:a", 0.0, 0.5)
	await t2.finished
	player.can_move = true

func play_death_sequence():
	player.can_move = false
	player.velocity = Vector2.ZERO
	await get_tree().create_timer(0.5).timeout
	var t = create_tween()
	t.tween_property(transition_screen, "modulate:a", 1.0, 0.5)
	await t.finished
	if current_level_path != "":
		load_level(current_level_path)
	await get_tree().process_frame
	player.can_move = false
	player.velocity = Vector2.ZERO
	await get_tree().create_timer(0.5).timeout
	var t2 = create_tween()
	t2.tween_property(transition_screen, "modulate:a", 0.0, 0.5)
	await t2.finished
	player.can_move = true
	player.is_dying = false

func show_grapple_message(msg: String):
	var label = $UI/CenterContainer/EchoText
	if label:
		label.text = msg
		$UI.visible = true

func hide_grapple_message():
	$UI.visible = false
