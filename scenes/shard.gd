extends Area2D

enum ShardType { GRAPPLE, DASH, INVERSION }
@export var shard_type: ShardType = ShardType.GRAPPLE

@onready var sprite: AnimatedSprite2D = $Sprite2D
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
	# --- VÉRIFICATION DE LA MÉMOIRE ---
	var main = get_tree().root.get_node("Main")
	
	if shard_type == ShardType.GRAPPLE and main.grapple_collected:
		queue_free()
		return
		
	if shard_type == ShardType.DASH and main.dash_collected:
		queue_free()
		return
		
	if shard_type == ShardType.INVERSION and main.get("gravity_collected"):
		queue_free()
		return
	# ------------------------------------------

	sprite.play("idle")
	
	if anim.has_animation("breath"):
		anim.play("breath")
		
	camera = get_tree().root.get_node("Main/Camera2D")

# --- GÉNÉRATEUR D'INPUT DYNAMIQUE ---
func get_input_name(action: String) -> String:
	var main = get_tree().root.get_node_or_null("Main")
	var is_pad = false
	if main and "is_using_gamepad" in main:
		is_pad = main.is_using_gamepad
	
	match action:
		"grapple":
			return "[color=#ffdd33](X)[/color]" if is_pad else "[color=#ffdd33](E)[/color]"
		"dash":
			return "[color=#ffdd33](B)[/color]" if is_pad else "[color=#ffdd33](F)[/color]"
		"inversion":
			return "[color=#ffdd33](Y)[/color]" if is_pad else "[color=#ffdd33](R)[/color]"
	return ""
# ------------------------------------

func _on_TriggerArea_body_entered(body):
	if body.is_in_group("player") and not cutscene_running:

		cutscene_running = true
		player = body

		# --- NETTOYAGE COMPLET DES ÉTATS DU JOUEUR ---
		player.can_move = false
		player.is_dashing = false
		player.wall_grabbing = false
		if player.grappling:
			player.grappling = false
			player.grapple_line.visible = false
			
		player.velocity.x = 0
		# Si le joueur montait, on tue son élan pour qu'il retombe de suite. 
		# S'il tombait déjà, on le laisse finir sa chute.
		if player.velocity.y * player.gravity_dir < 0:
			player.velocity.y = 0 
		# ----------------------------------------------

		camera.start_cinematic(self)
		camera.zoom_to(5.0, 1.2)

		var main = get_tree().root.get_node("Main")
		var roots_music = main.get_node_or_null("FragmentsOfRoots")
		var echoes_music = main.get_node_or_null("FragmentsOfEchoes")
		var pulse_music = main.get_node_or_null("FragmentsOfPulse")
		
		var t = create_tween()
		if roots_music and roots_music.playing:
			t.tween_property(roots_music, "volume_db", -30.0, 2.0)
		elif echoes_music and echoes_music.playing:
			t.tween_property(echoes_music, "volume_db", -30.0, 2.0)
		elif pulse_music and pulse_music.playing:
			t.tween_property(pulse_music, "volume_db", -30.0, 2.0)

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

	# --- SYSTEM MESSAGE AVEC INPUT DYNAMIQUE ---
	if shard_type == ShardType.GRAPPLE:
		player.grapple_unlocked = true
		main.grapple_collected = true
		
		await dialog.show_dialog("Echo-Grapple Restored.")
		await dialog.show_dialog("Press " + get_input_name("grapple") + " to use when near a grapple point.")
		
	elif shard_type == ShardType.DASH:
		player.dash_unlocked = true
		main.dash_collected = true
		
		await dialog.show_dialog("Pulse-Dash Restored.")
		await dialog.show_dialog("Press " + get_input_name("dash") + " to Dash.")
		
	elif shard_type == ShardType.INVERSION:
		player.gravity_unlocked = true
		main.set("gravity_collected", true) 
		
		await dialog.show_dialog("Reality Anchor Destabilized.")
		await dialog.show_dialog("Press " + get_input_name("inversion") + " to Invert Reality.")
	# ----------------------------------------

	player.hide_popup()

	# --- TRANSITION MUSICALE ---
	var roots_music = main.get_node_or_null("FragmentsOfRoots")
	var echoes_music = main.get_node_or_null("FragmentsOfEchoes")
	var pulse_music = main.get_node_or_null("FragmentsOfPulse")

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
			if roots_music: t_music.parallel().tween_property(roots_music, "volume_db", -80.0, 4.0)
			t_music.parallel().tween_property(echoes_music, "volume_db", -80.0, 4.0)
			t_music.parallel().tween_property(pulse_music, "volume_db", -10.0, 4.0)
			
			t_music.chain().tween_callback(func():
				if roots_music: roots_music.stop()
				echoes_music.stop()
			)

	# --- DIALOGUES LYRA (EN CYAN) ---
	if shard_type == ShardType.DASH:
		await dialog.show_dialog(
			"[color=#33d9ff]I feel lighter... quicker...[/color]",
			preload("res://assets/dialoguebox/portrait.png")
		)
		await dialog.show_dialog(
			"[color=#33d9ff]What is going on here in this place ?[/color]",
			preload("res://assets/dialoguebox/portrait.png")
		)
		await dialog.show_dialog(
			"[color=#33d9ff]What are these strange objects ?[/color]",
			preload("res://assets/dialoguebox/portrait.png")
		)
		await dialog.show_dialog(
			"[color=#33d9ff]Hmm... I have to keep going forward.[/color]",
			preload("res://assets/dialoguebox/portrait.png")
		)
		
	elif shard_type == ShardType.INVERSION:
		await dialog.show_dialog(
			"[color=#33d9ff]Ugh... a wave of nausea...[/color]",
			preload("res://assets/dialoguebox/portrait.png")
		)
		await dialog.show_dialog(
			"[color=#33d9ff]This one feels... heavy. Unstable.[/color]",
			preload("res://assets/dialoguebox/portrait.png")
		)
		await dialog.show_dialog(
			"[color=#33d9ff]It's like the ground is trying to push me away.[/color]",
			preload("res://assets/dialoguebox/portrait.png")
		)
		await dialog.show_dialog(
			"[color=#33d9ff]I must be careful. Reality feels... thin here.[/color]",
			preload("res://assets/dialoguebox/portrait.png")
		)

	else: # GRAPPLE
		await dialog.show_dialog(
			"[color=#33d9ff]Hm... this might be useful.[/color]",
			preload("res://assets/dialoguebox/portrait.png")
		)
		await dialog.show_dialog(
			"[color=#33d9ff]I felt a strange power in that object.[/color]",
			preload("res://assets/dialoguebox/portrait.png")
		)
		await dialog.show_dialog(
			"[color=#33d9ff]Even though it was weird...[/color]",
			preload("res://assets/dialoguebox/portrait.png")
		)
	
	waiting_for_input = true

func end_cutscene():
	var dialog := get_tree().root.get_node("Main/UI/DialogueBox")
	dialog.hide_dialog()

	waiting_for_input = false
	cutscene_running = false

	camera.zoom_to(2.6, 1.2)
	camera.end_cinematic()

	player.can_move = true

	queue_free()
