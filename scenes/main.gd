extends Node2D

@onready var player := $Player
@onready var level_root := $LevelRoot
@onready var camera := $Camera2D
@onready var transition_screen := $UI/TransitionScreen
@onready var ui_layer := $UI
@onready var dialogue_box := $UI/DialogueBox

# --- AUDIO ---
@onready var music_roots := $FragmentsOfRoots    
@onready var music_echoes := $FragmentsOfEchoes 
@onready var music_pulse := $FragmentsOfPulse   
@onready var ambiance_player := $AmbiancePlayer 
@onready var wind_layer := $WindLayer         

var current_level_path: String = ""
var intro_played := false
var grapple_collected := false
var dash_collected := false
var gravity_collected := false 
var shake_strength: float = 0.0

# --- VARIABLES CAMÉRA INTRO ---
var intro_camera_locked := false
var intro_camera_pos := Vector2.ZERO

func _ready():
	print("--- DEBUG: Main _ready start ---")
	var is_intro = SaveManager.has_meta("intro_sequence")
	if transition_screen:
		transition_screen.visible = true
		transition_screen.modulate.a = 1.0 if is_intro else 0.0
		transition_screen.color = Color.BLACK

	# Menu Pause
	if FileAccess.file_exists("res://pause_menu.tscn"):
		ui_layer.add_child(load("res://pause_menu.tscn").instantiate())

	# LOGIQUE
	if is_intro:
		check_music_progression() 
		
		SaveManager.remove_meta("intro_sequence")
		load_level("res://scenes/levels/level_1.tscn")
		_set_level_canvas_layers_visible(false)
		
		player.global_position.y = -2500 
		player.can_move = false 
		player.velocity = Vector2.ZERO
		
		# --- SETUP CAMERA INTRO ---
		intro_camera_pos = Vector2(player.global_position.x, -1200)
		camera.global_position = intro_camera_pos
		
		# On verrouille le script de la caméra (elle arrête de calculer)
		camera.is_locked = true 
		intro_camera_locked = true # On verrouille la logique Main
		
		var current_level_node = level_root.get_child(0)
		if current_level_node.has_method("start_intro_sequence"):
			current_level_node.start_intro_sequence()
		
		await get_tree().process_frame
		await get_tree().process_frame
		
		self.visible = true
		level_root.visible = true
		player.visible = true
		_set_level_canvas_layers_visible(true)
		
		var t = create_tween()
		t.tween_property(transition_screen, "modulate:a", 0.0, 4.0)
		
	elif SaveManager.has_meta("level_to_load"):
		var target_level = SaveManager.get_meta("level_to_load")
		SaveManager.remove_meta("level_to_load")
		if SaveManager.current_slot_id != -1:
			var data = SaveManager.load_data(SaveManager.current_slot_id)
			if data:
				# 1. On récupère les infos
				grapple_collected = data.get("grapple_unlocked", false)
				dash_collected = data.get("dash_unlocked", false)
				gravity_collected = data.get("gravity_unlocked", false) # --- CHARGEMENT GRAVITÉ
				intro_played = data.get("intro_played", false)
		
		# 2. IMPORTANT : On met à jour la musique MAINTENANT
		check_music_progression()
		
		load_level(target_level)
		self.visible = true
		level_root.visible = true
		player.visible = true
		
	else:
		# Démarrage standard
		check_music_progression() # Vérification par défaut
		
		load_level("res://scenes/levels/level_1.tscn")
		self.visible = true
		level_root.visible = true
		player.visible = true
		if not intro_played:
			var current_level_node = level_root.get_child(0)
			if current_level_node.has_method("start_tutorial_sequence"):
				current_level_node.start_tutorial_sequence()

func _process(delta):
	# --- 1. LOGIQUE CAMÉRA INTRO ---
	if intro_camera_locked:
		# On maintient la position fixe
		camera.global_position = intro_camera_pos
		
		# Seuil de déclenchement (basé sur la position FIXE de la caméra)
		# Quand le joueur arrive 300px au dessus du centre
		var catch_threshold = intro_camera_pos.y - 0
		
		if player.global_position.y >= catch_threshold:
			print("DEBUG: Caméra attrape le joueur !")
			
			# 1. On libère le Main
			intro_camera_locked = false 
			
			# 2. On libère le script de la caméra (elle reprend ses calculs)
			camera.is_locked = false 
			
			# 3. BOOST DE VITESSE ET OFFSET
			# On la rend très rapide pour rattraper le joueur (20.0 au lieu de 8.0)
			camera.follow_smoothness = 20.0 
			
			# On décale le cadre vers le bas pour que le joueur soit plus haut à l'écran
			camera.cam_offset.y = 100.0

	# --- 2. SCREEN SHAKE ---
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, 10.0 * delta)
		camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		if shake_strength < 0.1: shake_strength = 0.0; camera.offset = Vector2.ZERO

func trigger_shake(amount: float): shake_strength = amount
func _show_game_content(): level_root.visible = true; player.visible = true
func _set_level_canvas_layers_visible(is_visible: bool):
	for child in level_root.get_children():
		for subchild in child.get_children():
			if subchild is CanvasLayer or subchild is ParallaxBackground: subchild.visible = is_visible

func load_level(path: String):
	current_level_path = path
	for c in level_root.get_children(): c.queue_free()
	var level_scene = load(path).instantiate()
	level_root.add_child(level_scene)
	
	if level_scene.has_node("PlayerStart"):
		var spawn = level_scene.get_node("PlayerStart")
		player.global_position = spawn.global_position
		player.velocity = Vector2.ZERO
		player.can_move = true
		player.is_dying = false
		player.grapple_unlocked = grapple_collected
		player.dash_unlocked = dash_collected
		player.gravity_unlocked = gravity_collected # --- APPLICATION GRAVITÉ AU JOUEUR
		
		# Sécurité : On revérifie la musique à chaque niveau au cas où
		check_music_progression()
		
	if level_scene.has_node("LevelBounds"):
		var bounds = level_scene.get_node("LevelBounds")
		camera.set_bounds(bounds)
		
	if SaveManager.current_slot_id != -1:
		var data_to_save = { 
			"current_level": current_level_path, 
			"grapple_unlocked": grapple_collected, 
			"dash_unlocked": dash_collected, 
			"gravity_unlocked": gravity_collected, # --- SAUVEGARDE GRAVITÉ
			"intro_played": intro_played 
		}
		SaveManager.save_game(SaveManager.current_slot_id, data_to_save)

# ... (Le reste : change_level, play_death, popups reste identique) ...
func change_level_with_transition(next_level_path: String):
	player.can_move = false; player.velocity = Vector2.ZERO
	var t = create_tween(); t.tween_property(transition_screen, "modulate:a", 1.0, 0.5); await t.finished
	load_level(next_level_path)
	_show_game_content()
	await get_tree().process_frame; player.can_move = false; player.velocity = Vector2.ZERO
	var t2 = create_tween(); t2.tween_property(transition_screen, "modulate:a", 0.0, 0.5); await t2.finished
	player.can_move = true

func play_death_sequence():
	player.can_move = false; player.velocity = Vector2.ZERO
	await get_tree().create_timer(0.5).timeout
	var t = create_tween(); t.tween_property(transition_screen, "modulate:a", 1.0, 0.5); await t.finished
	if current_level_path != "": 
		level_root.visible = false; player.visible = false
		load_level(current_level_path)
		await get_tree().process_frame
		_show_game_content()
	await get_tree().process_frame; player.can_move = false; player.velocity = Vector2.ZERO
	await get_tree().create_timer(0.5).timeout
	var t2 = create_tween(); t2.tween_property(transition_screen, "modulate:a", 0.0, 0.5); await t2.finished
	player.can_move = true; player.is_dying = false

func show_grapple_message(msg: String):
	var label = $UI/CenterContainer/EchoText
	if label: label.text = msg; $UI.visible = true
func hide_grapple_message(): $UI.visible = false

# --- NOUVELLE FONCTION MUSIQUE ---
func check_music_progression():
	# PRIO 1 : Dash (Pulse)
	if dash_collected:
		if music_roots and music_roots.playing: music_roots.stop()
		if music_echoes and music_echoes.playing: music_echoes.stop()
		if music_pulse and not music_pulse.playing: music_pulse.play()
	
	# PRIO 2 : Grappin (Echoes)
	elif grapple_collected:
		if music_roots and music_roots.playing: music_roots.stop()
		if music_pulse and music_pulse.playing: music_pulse.stop()
		if music_echoes and not music_echoes.playing: music_echoes.play()
	
	# PRIO 3 : Début (Roots)
	else:
		if music_echoes and music_echoes.playing: music_echoes.stop()
		if music_pulse and music_pulse.playing: music_pulse.stop()
		if music_roots and not music_roots.playing: music_roots.play()
		
func cleanup_before_exit():
	
	# Musiques (On coupe tout)
	if music_roots: music_roots.stop()
	if music_echoes: music_echoes.stop()
	if music_pulse: music_pulse.stop() 
	
	if ambiance_player: ambiance_player.stop()
	
	if wind_layer:
		wind_layer.visible = false 
		for child in wind_layer.get_children():
			if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
				child.stop()

	self.visible = false
	if ui_layer: ui_layer.visible = false
	_set_level_canvas_layers_visible(false)
