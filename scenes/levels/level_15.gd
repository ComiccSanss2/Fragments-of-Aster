extends Node2D

@onready var player_marker = $MarkerPlayerPos
@onready var boss = $MainEnemy
@onready var dialogue_box = $CanvasLayer/DialogueBox
@onready var parallax_bg = $Background

var player = null
var cutscene_started = false
var active_camera: Camera2D = null

# Pour gérer l'aberration chromatique
var main_env: Environment = null

# --- CONFIGURATION FONTS & STYLE ---
const FONT_BOSS = "res://assets/fonts/Evil Empire.otf"
const SIZE_BOSS = 54 
const BOSS_PORTRAIT = preload("res://assets/enemydialogue.png")

func _ready():
	boss.flip_h = true 
	
	var world_env_node = get_tree().root.get_node_or_null("Main/WorldEnvironment")
	if world_env_node and world_env_node.environment:
		main_env = world_env_node.environment

func _on_cutscene_trigger_body_entered(body):
	if body.is_in_group("player") and not cutscene_started:
		cutscene_started = true
		player = body
		start_cinematic()

func start_cinematic():
	# 1. SETUP
	player.can_move = false
	player.velocity = Vector2.ZERO
	player.play_anim("walk")
	
	# --- AJOUT MUSIQUE ---
	var main = get_tree().root.get_node("Main")
	if main and main.get("music_boss_intro"):
		main.music_boss_intro.play()
	# ---------------------
	
	active_camera = get_viewport().get_camera_2d()
	if active_camera:
		if active_camera.get_parent() == player:
			active_camera.top_level = true 
		active_camera.set_process(false)
		active_camera.set_physics_process(false)
		
		var t_zoom = create_tween()
		t_zoom.tween_property(active_camera, "zoom", Vector2(3.5, 3.5), 1.0)

	# --- MOUVEMENT JOUEUR ---
	var t_move = create_tween()
	t_move.tween_property(player, "global_position:x", player_marker.global_position.x, 1.5)
	t_move.tween_callback(func(): player.play_anim("idle"))
	
	if active_camera:
		var center_pos = (player_marker.global_position + boss.global_position) / 2
		center_pos.y -= 50 
		var t_cam = create_tween()
		t_cam.tween_property(active_camera, "global_position", center_pos, 2.0).set_trans(Tween.TRANS_SINE)
		
	
	await get_tree().create_timer(5.0).timeout
	
	# 2. DIALOGUES (Tout est dit par l'Architecte ici)
	
	await play_boss_dialog("Can you hear it?", 0.8)
	await play_boss_dialog("This world... it is weeping.", 0.75)
	
	await get_tree().create_timer(0.5).timeout
	
	await play_boss_dialog("You walk towards the Core like a hero...", 0.8)
	await play_boss_dialog("...but you are just a [color=#ff3333][shake rate=5 level=5]wrong note[/shake][/color] in a perfect symphony.", 0.7)
	
	await get_tree().create_timer(1.0).timeout

	# 3. MENACE
	boss.turn_around()
	
	if active_camera:
		var t_face = create_tween()
		t_face.tween_property(active_camera, "zoom", Vector2(3.8, 3.8), 0.5)
	
	await get_tree().create_timer(1.0).timeout
	
	await play_boss_dialog("I have watched your struggles.", 1.3)
	await play_boss_dialog("The [color=#ffdd33]grapple[/color]... The [color=#ffdd33]dash[/color]...", 0.7)
	await play_boss_dialog("You attempt to tame [color=#ffdd33]gravity[/color].", 0.7)
	
	await get_tree().create_timer(1.5).timeout
	
	# --- GLITCH ---
	trigger_glitch_effect() 
	
	await play_boss_dialog("But [color=#9b59b6]Aster[/color] does not belong to you, [color=#33d9ff]Lyra[/color].", 1.5)
	await play_boss_dialog("You are a [color=#ff3333][shake rate=20 level=10]virus[/shake][/color].", 0.3)

	# 4. ASCENSION
	boss.ascend_and_transform()
	
	if active_camera:
		var final_boss_pos = boss.global_position + Vector2(0, -150)
		var t_final = create_tween()
		t_final.parallel().tween_property(active_camera, "global_position", final_boss_pos, 4.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t_final.parallel().tween_property(active_camera, "zoom", Vector2(4.5, 4.5), 3.0)
	
	await get_tree().create_timer(1.5).timeout
	
	# Le final très menaçant
	await play_boss_dialog("[color=#ff3333][shake rate=15 level=10]The purge begins now.[/shake][/color]", 0.1)
	
	await get_tree().create_timer(1.0).timeout
	
	# 5. FIN
	dialogue_box.hide_dialog()
	reset_glitch_effect() 
	
	if main and main.has_method("change_level_with_transition"):
		main.change_level_with_transition("res://scenes/levels/level_16.tscn")

# -----------------------------------------------------------
# FONCTIONS DE DIALOGUE SPÉCIALISÉES
# -----------------------------------------------------------

# 1. Tuto / Narrateur (Blanc, Font par défaut, Taille 32)
func play_tuto_dialog(text: String):
	await dialogue_box.show_dialog(text, null, 1.0)
	await dialogue_box.hide_dialog()
	await get_tree().create_timer(0.2).timeout

# 2. Lyra (Cyan, Font par défaut, Taille 32)
func play_lyra_dialog(text: String):
	var formatted = "[color=#33d9ff]" + text + "[/color]"
	await dialogue_box.show_dialog(formatted, null, 1.2) 
	await dialogue_box.hide_dialog()
	await get_tree().create_timer(0.2).timeout

# 3. Architecte (Evil Empire, Taille 48, Pitch Grave)
func play_boss_dialog(text: String, pitch: float):
	var formatted = "[font=" + FONT_BOSS + "][font_size=" + str(SIZE_BOSS) + "]" + text + "[/font_size][/font]"
	
	await dialogue_box.show_dialog(formatted, BOSS_PORTRAIT, pitch)
	
	await dialogue_box.hide_dialog()
	await get_tree().create_timer(0.2).timeout

# -----------------------------------------------------------
# EFFETS VISUELS
# -----------------------------------------------------------

func trigger_glitch_effect():
	var main = get_tree().root.get_node("Main")
	if main and main.has_method("trigger_shake"):
		main.trigger_shake(5.0) 
	
	if main_env:
		main_env.adjustment_enabled = true
		var t = create_tween()
		t.tween_property(main_env, "adjustment_saturation", 4.0, 0.2)
		t.parallel().tween_property(main_env, "adjustment_contrast", 1.2, 0.2)
	
	if parallax_bg:
		var t_bg = create_tween()
		t_bg.tween_property(parallax_bg, "modulate", Color(0.7, 0.0, 0.0), 0.2)

	var t_color = create_tween()
	t_color.tween_property(boss, "modulate", Color(10, 0, 0), 0.1) 
	t_color.tween_property(boss, "modulate", Color(1, 1, 1), 0.1)

func reset_glitch_effect():
	if main_env:
		var t = create_tween()
		t.tween_property(main_env, "adjustment_saturation", 1.0, 0.5)
		t.parallel().tween_property(main_env, "adjustment_contrast", 1.0, 0.5)
	
	if parallax_bg:
		var t_bg = create_tween()
		t_bg.tween_property(parallax_bg, "modulate", Color(1, 1, 1), 0.5)
