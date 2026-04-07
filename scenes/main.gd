extends Node2D

@onready var player := $Player
@onready var level_root := $LevelRoot
@onready var camera := $Camera2D

# --- NOUVEAUX ÉCRANS DE TRANSITION ---
@onready var level_transition := $UI/LevelTransition
@onready var death_transition := $UI/DeathTransition

@onready var ui_layer := $UI
@onready var dialogue_box := $UI/DialogueBox

# --- AUDIO ---
@onready var music_roots := $FragmentsOfRoots
@onready var music_echoes := $FragmentsOfEchoes
@onready var music_pulse := $FragmentsOfPulse
@onready var ambiance_player := $AmbiancePlayer
@onready var wind_layer := $WindLayer
@onready var music_boss_intro := $MusicBossIntro
@onready var music_boss_chase := $MusicBossChase
@onready var music_cinematic_final := $MusicCinematicFinal # <-- PISTE DE FIN

var current_level_path: String = ""
var intro_played := false
var grapple_collected := false
var dash_collected := false
var gravity_collected := false 
var shake_strength: float = 0.0

# --- ZOOM PAR DÉFAUT ---
const DEFAULT_ZOOM = Vector2(2.6, 2.6) 

# --- INPUT DETECTION ---
var is_using_gamepad: bool = false

# --- NOUVEAU : SYSTÈME DE CHECKPOINT POUR LE CHASE ---
var has_checkpoint := false
var checkpoint_level_path := ""
var checkpoint_player_pos := Vector2.ZERO
var checkpoint_wall_pos := Vector2.ZERO

func _ready():
	if FileAccess.file_exists("res://pause_menu.tscn"):
		ui_layer.add_child(load("res://pause_menu.tscn").instantiate())

	# --- VÉRIFICATION : Vient-on de l'intro textuelle ? ---
	var is_new_game_intro = false
	if SaveManager.has_meta("intro_sequence") and SaveManager.get_meta("intro_sequence") == true:
		is_new_game_intro = true

	# --- GESTION DES TRANSITIONS DE DÉPART ---
	if level_transition:
		level_transition.visible = true
		if is_new_game_intro:
			# Si c'est l'intro : on cache tout pour laisser le FadeRect de level_1.gd agir
			level_transition.material.set_shader_parameter("is_opening", false)
			level_transition.material.set_shader_parameter("cutoff", 0.0) 
		else:
			# Si c'est un chargement normal : on fait l'ouverture classique du shader
			level_transition.material.set_shader_parameter("is_opening", true)
			level_transition.material.set_shader_parameter("cutoff", 0.0)
			var t = create_tween()
			t.tween_property(level_transition, "material:shader_parameter/cutoff", 1.0, 1.0) # Ajuste la durée si besoin
			
	if death_transition:
		death_transition.visible = false
		death_transition.material.set_shader_parameter("cutoff", 0.0)

	# --- CHARGEMENT DU NIVEAU ---
	if SaveManager.has_meta("level_to_load"):
		var target_level = SaveManager.get_meta("level_to_load")
		SaveManager.remove_meta("level_to_load")
		if SaveManager.current_slot_id != -1:
			var data = SaveManager.load_data(SaveManager.current_slot_id)
			if data:
				grapple_collected = data.get("grapple_unlocked", false)
				dash_collected = data.get("dash_unlocked", false)
				gravity_collected = data.get("gravity_unlocked", false)
				intro_played = data.get("intro_played", false)
		
		check_music_progression()
		load_level(target_level)
		
	else:
		# Lancement standard (Nouvelle partie)
		check_music_progression()
		load_level("res://scenes/levels/level_1.tscn")
	
	self.visible = true
	level_root.visible = true
	player.visible = true

func _process(delta):
	# On gère uniquement le Camera Shake ici maintenant
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
	if has_checkpoint and checkpoint_level_path != path:
		has_checkpoint = false

	current_level_path = path
	
	for c in level_root.get_children(): c.queue_free()
	
	var level_scene = load(path).instantiate()
	level_root.add_child(level_scene)
	
	if level_scene.has_node("PlayerStart"):
		var spawn = level_scene.get_node("PlayerStart")
		
		if has_checkpoint and checkpoint_level_path == path:
			player.global_position = checkpoint_player_pos
			var wall = level_scene.find_child("GlitchWall", true, false)
			if wall:
				wall.global_position = checkpoint_wall_pos
				if "is_boosting" in wall: wall.is_boosting = false
				if "current_speed" in wall: wall.current_speed = wall.speed
		else:
			player.global_position = spawn.global_position
		
		player.velocity = Vector2.ZERO
		
		# On rend le contrôle au joueur PAR DÉFAUT (level_1 le bloquera si c'est l'intro)
		player.can_move = true
		player.is_dying = false
		player.collision_layer = 1
		player.collision_mask = 1
		
		player.grapple_unlocked = grapple_collected
		player.dash_unlocked = dash_collected
		player.gravity_unlocked = gravity_collected
		
		camera.global_position = player.global_position
		camera.zoom = DEFAULT_ZOOM 
		if "lerp_speed" in camera: camera.lerp_speed = 5.0
		if "default_offset" in camera: camera.default_offset = Vector2(0, -20)
		
		camera.set_process(true)
		camera.set_physics_process(true)
		camera.is_locked = false
		camera.end_cinematic()
		
		if "current_look_ahead_x" in camera: camera.current_look_ahead_x = 0.0
		if "current_look_ahead_y" in camera: camera.current_look_ahead_y = 0.0
		
		camera.offset = Vector2.ZERO
		camera.make_current()
		

		# ==========================================
		# GESTIONE EFFETTI ATMOSFERICI
		# ==========================================
		var path_lower = path.to_lower()
		var is_chase_level = "level16" in path_lower or "level_16" in path_lower
		
		# 1. Spegniamo il WindLayer principale
		if wind_layer:
			wind_layer.visible = not is_chase_level
			for child in wind_layer.get_children():
				if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
					if is_chase_level: child.stop()
					
		# 2. Spegniamo anche il WindLayer2 (se esiste)
		var wind_layer_2 = get_node_or_null("WindLayer2")
		if wind_layer_2:
			wind_layer_2.visible = not is_chase_level
			for child in wind_layer_2.get_children():
				if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
					if is_chase_level: child.stop()
		# ==========================================
		
		check_music_progression()
		
	if level_scene.has_node("LevelBounds"):
		var bounds = level_scene.get_node("LevelBounds")
		camera.set_bounds(bounds)
		
	if SaveManager.current_slot_id != -1:
		var data_to_save = {
			"current_level": current_level_path,
			"grapple_unlocked": grapple_collected,
			"dash_unlocked": dash_collected,
			"gravity_unlocked": gravity_collected,
			"intro_played": intro_played
		}
		SaveManager.save_game(SaveManager.current_slot_id, data_to_save)

func change_level_with_transition(next_level_path: String):
	player.can_move = false
	player.velocity = Vector2.ZERO
	
	level_transition.material.set_shader_parameter("is_opening", false)
	level_transition.material.set_shader_parameter("cutoff", 0.0)
	
	var t = create_tween()
	t.tween_property(level_transition, "material:shader_parameter/cutoff", 1.0, 0.5)
	await t.finished
	
	load_level(next_level_path)
	_show_game_content()
	
	await get_tree().process_frame
	player.can_move = false
	player.velocity = Vector2.ZERO
	
	await get_tree().create_timer(1.0).timeout
	
	level_transition.material.set_shader_parameter("is_opening", true)
	level_transition.material.set_shader_parameter("cutoff", 0.0)
	
	var t2 = create_tween()
	t2.tween_property(level_transition, "material:shader_parameter/cutoff", 1.0, 0.5)
	await t2.finished
	
	level_transition.material.set_shader_parameter("is_opening", false)
	level_transition.material.set_shader_parameter("cutoff", 0.0)
	
	player.can_move = true

func play_death_sequence():
	player.can_move = false
	
	# --- ON S'ASSURE QUE LA TRANSITION EST VISIBLE ---
	if death_transition:
		death_transition.visible = true
	
	var screen_size = get_viewport().get_visible_rect().size
	
	death_transition.material.set_shader_parameter("aspect_ratio", screen_size.x / screen_size.y)
	var player_screen_pos = player.get_global_transform_with_canvas().origin / screen_size
	death_transition.material.set_shader_parameter("center", player_screen_pos)
	
	var t = create_tween()
	t.tween_property(death_transition, "material:shader_parameter/cutoff", 1.0, 0.5)
	await t.finished
	
	if current_level_path != "":
		level_root.visible = false
		player.visible = false
		load_level(current_level_path)
		await get_tree().process_frame
		_show_game_content()
		
	await get_tree().process_frame
	player.can_move = false
	player.velocity = Vector2.ZERO
	
	await get_tree().create_timer(0.3).timeout 
	
	player_screen_pos = player.get_global_transform_with_canvas().origin / screen_size
	death_transition.material.set_shader_parameter("center", player_screen_pos)
	
	var t2 = create_tween()
	t2.tween_property(death_transition, "material:shader_parameter/cutoff", 0.0, 0.4)
	await t2.finished
	
	# --- ON LA CACHE APRÈS L'ANIMATION POUR NE PAS GÊNER ---
	if death_transition:
		death_transition.visible = false
	
	player.can_move = true
	player.is_dying = false

func show_grapple_message(msg: String):
	var label = $UI/CenterContainer/EchoText
	if label: label.text = msg; $UI.visible = true
func hide_grapple_message(): $UI.visible = false

func check_music_progression():
	if "level15" in current_level_path or "level_15" in current_level_path:
		_stop_exploration_music()
		if music_boss_chase.playing: music_boss_chase.stop()
		if music_boss_intro.playing: music_boss_intro.stop()
		return

	elif "level16" in current_level_path or "level_16" in current_level_path:
		_stop_exploration_music()
		if music_boss_intro.playing: music_boss_intro.stop()
		if not music_boss_chase.playing:
			music_boss_chase.play()
		return

	if music_boss_intro.playing: music_boss_intro.stop()
	if music_boss_chase.playing: music_boss_chase.stop()

	if dash_collected:
		if music_roots.playing: music_roots.stop()
		if music_echoes.playing: music_echoes.stop()
		if not music_pulse.playing: music_pulse.play()
	elif grapple_collected:
		if music_roots.playing: music_roots.stop()
		if music_pulse.playing: music_pulse.stop()
		if not music_echoes.playing: music_echoes.play()
	else:
		if music_echoes.playing: music_echoes.stop()
		if music_pulse.playing: music_pulse.stop()
		if not music_roots.playing: music_roots.play()

func _stop_exploration_music():
	if music_roots.playing: music_roots.stop()
	if music_echoes.playing: music_echoes.stop()
	if music_pulse.playing: music_pulse.stop()

func cleanup_before_exit():
	_stop_exploration_music()
	if music_boss_intro: music_boss_intro.stop()
	if music_boss_chase: music_boss_chase.stop()
	if music_cinematic_final: music_cinematic_final.stop()
	if ambiance_player: ambiance_player.stop()
	if wind_layer:
		wind_layer.visible = false
		for child in wind_layer.get_children():
			if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
				child.stop()

	self.visible = false
	if ui_layer: ui_layer.visible = false
	_set_level_canvas_layers_visible(false)

func play_final_cinematic_music():
	_stop_exploration_music()
	if music_boss_intro.playing: music_boss_intro.stop()
	if music_boss_chase.playing: music_boss_chase.stop()
	
	if music_cinematic_final and not music_cinematic_final.playing:
		music_cinematic_final.play()

func _input(event):
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and abs(event.axis_value) < 0.2:
			return 
		is_using_gamepad = true
		
	elif event is InputEventKey or event is InputEventMouse:
		is_using_gamepad = false

func show_outro_screen():
	Engine.time_scale = 1.0 
	
	if level_root: level_root.visible = false
	if player: player.visible = false
	if ambiance_player: ambiance_player.stop()
		
	if wind_layer: wind_layer.queue_free()
	if ui_layer: ui_layer.queue_free()
	
	var outro_scene = load("res://end_demo_screen.tscn")
	if outro_scene:
		var outro_instance = outro_scene.instantiate()
		var top_canvas = CanvasLayer.new()
		top_canvas.layer = 128
		add_child(top_canvas)
		top_canvas.add_child(outro_instance)
		
	if music_cinematic_final and music_cinematic_final.playing:
		await music_cinematic_final.finished
		
	cleanup_before_exit()
	SaveManager.set_meta("skip_main_menu_intro", true)
	get_tree().change_scene_to_file("res://main_menu.tscn")
