extends Area2D

enum ShardType { GRAPPLE, DASH }
@export var shard_type: ShardType = ShardType.GRAPPLE

@onready var sprite := $Sprite2D
@onready var light := $PointLight2D
@onready var anim := $AnimationPlayer
@onready var trigger := $TriggerArea

var player: CharacterBody2D
var camera
var fx_scene := preload("res://scenes/shard_impact_fx.tscn")

var cutscene_running := false
var moving_to_player := false
var waiting_for_input := false

const MOVE_SPEED := 100.0


func _ready():
	# --- AJOUT : VÉRIFICATION DE LA MÉMOIRE ---
	var main = get_tree().root.get_node("Main")
	
	if shard_type == ShardType.GRAPPLE and main.grapple_collected:
		# Si on a déjà le grappin, ce shard n'existe plus
		queue_free()
		return
		
	if shard_type == ShardType.DASH and main.dash_collected:
		# Si on a déjà le dash, ce shard n'existe plus
		queue_free()
		return
	# ------------------------------------------

	anim.play("breath")
	camera = get_tree().root.get_node("Main/Camera2D")


func _on_TriggerArea_body_entered(body):
	if body.is_in_group("player") and not cutscene_running:

		cutscene_running = true
		player = body

		player.velocity = Vector2.ZERO
		player.can_move = false
		player.play_anim("idle")

		camera.start_cinematic(self)
		camera.zoom_to(7.0, 1.2)

		var main = get_tree().root.get_node("Main")
		var roots_music = main.get_node_or_null("FragmentsOfRoots")
		var echoes_music = main.get_node_or_null("FragmentsOfEchoes")
		
		# On baisse la musique active pour l'ambiance mystique
		var t = create_tween()
		if roots_music and roots_music.playing:
			t.tween_property(roots_music, "volume_db", -30.0, 2.0)
		elif echoes_music and echoes_music.playing:
			t.tween_property(echoes_music, "volume_db", -30.0, 2.0)

		anim.play("pickup")


func start_move_to_player():
	moving_to_player = true


func stop_move_to_player():
	moving_to_player = false


func _process(delta):
	if moving_to_player and player:
		var dir := player.global_position - global_position
		var dist := dir.length()

		global_position += dir.normalized() * MOVE_SPEED * delta
		camera.start_cinematic(self)

		if dist < 0.0:
			moving_to_player = false
			visible = false 
			_on_collect_finished()

	if waiting_for_input:
		if Input.is_action_just_pressed("ui_accept"):
			end_cutscene()


func _on_collect_finished():
	var fx = fx_scene.instantiate()
	fx.global_position = player.global_position
	get_tree().current_scene.add_child(fx)
	
	# FLASH BLANC
	var main_ui = get_tree().root.get_node("Main/UI")
	var flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE    
	main_ui.add_child(flash)

	var t_flash = create_tween()
	t_flash.tween_interval(1.0) 
	t_flash.tween_property(flash, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t_flash.tween_callback(flash.queue_free)

	await t_flash.finished 

	var dialog := get_tree().root.get_node("Main/UI/DialogueBox")
	var main = get_tree().root.get_node("Main")

	# --- SYSTEM MESSAGE & SAUVEGARDE ÉTAT ---
	if shard_type == ShardType.GRAPPLE:
		player.grapple_unlocked = true
		main.grapple_collected = true # <--- ON SAUVEGARDE DANS MAIN
		
		await dialog.show_dialog("Echo-Grapple Restored.")
		await dialog.show_dialog("Press (E) to use when near a grapple point.")
		
	elif shard_type == ShardType.DASH:
		player.dash_unlocked = true 
		main.dash_collected = true # <--- ON SAUVEGARDE DANS MAIN
		
		await dialog.show_dialog("Pulse-Dash Restored.")
		await dialog.show_dialog("Press (F) to Dash.")
	# ----------------------------------------

	player.hide_popup()

	# --- TRANSITION MUSICALE ---
	var roots_music = main.get_node_or_null("FragmentsOfRoots")
	var echoes_music = main.get_node_or_null("FragmentsOfEchoes")
	var pulse_music = main.get_node_or_null("FragmentsOfPulse") # Récupération Pulse

	# CAS 1 : GRAPPIN (On passe de Roots -> Echoes)
	if shard_type == ShardType.GRAPPLE:
		if roots_music and echoes_music:
			if not echoes_music.playing:
				echoes_music.volume_db = -80.0
				echoes_music.play()
			
			var t_music = main.create_tween()
			t_music.tween_property(roots_music, "volume_db", -80.0, 4.0)
			t_music.parallel().tween_property(echoes_music, "volume_db", -10.0, 4.0)
			t_music.chain().tween_callback(roots_music.stop)

	elif shard_type == ShardType.DASH:
		if echoes_music and pulse_music:
			if not pulse_music.playing:
				pulse_music.volume_db = -80.0
				pulse_music.play()
			
			var t_music = main.create_tween()
			# On fade out Echoes (et Roots par sécurité)
			if roots_music: t_music.parallel().tween_property(roots_music, "volume_db", -80.0, 4.0)
			t_music.parallel().tween_property(echoes_music, "volume_db", -80.0, 4.0)
			
			# On fade in Pulse
			t_music.parallel().tween_property(pulse_music, "volume_db", -10.0, 4.0)
			
			# On stop les autres à la fin
			t_music.chain().tween_callback(func():
				if roots_music: roots_music.stop()
				echoes_music.stop()
			)

	# --- DIALOGUES LYRA ---
	
	if shard_type == ShardType.DASH:
		await dialog.show_dialog(
			"I feel lighter... quicker...",
			preload("res://assets/dialoguebox/portrait.png")
		)
		await dialog.show_dialog(
			"What is going on here in this place ?",
			preload("res://assets/dialoguebox/portrait.png")
		)
		await dialog.show_dialog(
			"What are these strange objects ?",
			preload("res://assets/dialoguebox/portrait.png")
		)
		await dialog.show_dialog(
			"Hmm... I have to keep going forward.",
			preload("res://assets/dialoguebox/portrait.png")
		)

	else:
		await dialog.show_dialog(
			"Hm... this might be useful.",
			preload("res://assets/dialoguebox/portrait.png")
		)
		await dialog.show_dialog(
			"I felt a strange power in that object.",
			preload("res://assets/dialoguebox/portrait.png")
		)
		await dialog.show_dialog(
			"Even though it was weird...",
			preload("res://assets/dialoguebox/portrait.png")
		)
	
	waiting_for_input = true


func end_cutscene():
	var dialog := get_tree().root.get_node("Main/UI/DialogueBox")
	dialog.hide_dialog()

	waiting_for_input = false
	cutscene_running = false

	camera.zoom_to(4.0, 1.2)
	camera.end_cinematic()

	player.can_move = true
	player.play_anim("idle")

	queue_free()
