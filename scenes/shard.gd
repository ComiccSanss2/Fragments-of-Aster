extends Area2D

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
		camera.zoom_to(8.5, 1.2)   

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
			_on_collect_finished()


	if waiting_for_input:
		if Input.is_action_just_pressed("ui_accept"):
			end_cutscene()


func _on_collect_finished():

	var fx = fx_scene.instantiate()
	fx.global_position = player.global_position
	get_tree().current_scene.add_child(fx)

	player.grapple_unlocked = true

	var dialog := get_tree().root.get_node("Main/UI/DialogueBox")

	# 1 — Popup Grapple
	await dialog.show_dialog("Echo-Grapple Restored.")
	await dialog.show_dialog("Press E to use when near a grapple point.")

	# Tu peux cacher ton popup du joueur ici si tu veux
	player.hide_popup()

	# 2 — Dialogue Lyra
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


	# Après le dernier dialogue → entrée dans end_cutscene()
	waiting_for_input = true



func end_cutscene():

	var dialog := get_tree().root.get_node("Main/UI/DialogueBox")
	dialog.hide_dialog()

	waiting_for_input = false
	cutscene_running = false

	camera.zoom_to(7.0, 1.2)
	camera.end_cinematic()

	player.can_move = true
	player.play_anim("idle")

	queue_free()
