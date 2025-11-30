extends Area2D

@onready var sprite := $Sprite2D
@onready var light := $PointLight2D
@onready var anim := $AnimationPlayer

var player: CharacterBody2D
var fx_scene := preload("res://scenes/shard_impact_fx.tscn")

var cutscene_running := false
var moving_to_player := false
var waiting_for_input := false

# vitesse du déplacement vers le joueur
const MOVE_SPEED := 100.0


func _ready():
	anim.play("breath")  # idle loop


func _on_TriggerArea_body_entered(body):
	if body.is_in_group("player") and not cutscene_running:

		cutscene_running = true
		player = body

		# Freeze total du joueur
		player.velocity = Vector2.ZERO
		player.can_move = false
		player.play_anim("idle")

		# Début animation flottante → puis mouvement
		anim.play("pickup")


# Appelé depuis la timeline à t=3.0
func start_move_to_player():
	moving_to_player = true


# Appelé depuis timeline à t=4.5
func stop_move_to_player():
	moving_to_player = false


func _process(delta):

	# --- Mouvement fluide vers le joueur ---
	if moving_to_player and player:

		var dir := (player.global_position - global_position)
		var dist := dir.length()

		# mouvement normalisé
		global_position += dir.normalized() * MOVE_SPEED * delta

		# Si on est suffisement proche → fin auto
		if dist < 0.0:
			moving_to_player = false
			_on_collect_finished()


	# --- Attente espace pour clore la cinématique ---
	if waiting_for_input:
		if Input.is_action_just_pressed("ui_accept"):
			end_cutscene()


func _on_collect_finished():
	print("FIN COLLECT — OK")
	# FX explosion sur player
	var fx = fx_scene.instantiate()
	fx.global_position = player.global_position
	get_tree().current_scene.add_child(fx)

	# Débloque le grappin
	player.grapple_unlocked = true
	# Affiche texte
	player.show_popup("Echo-Grapple Restored")

	# maintenant on attend espace
	waiting_for_input = true


func end_cutscene():
	waiting_for_input = false
	cutscene_running = false

	# cacher le popup
	player.hide_popup()

	# rendre le contrôle
	player.can_move = true
	player.play_anim("idle")

	queue_free()
