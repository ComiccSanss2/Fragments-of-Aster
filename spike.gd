extends Area2D

var player: CharacterBody2D

func _ready():
	# Toujours récupérer le player en live (jamais stocker des nodes qui vont être free)
	player = get_tree().root.get_node("Main/Player")

	# Assurer que le signal est connecté
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))


func _on_body_entered(body):
	if body.is_in_group("player"):
		respawn_player()


func respawn_player():
	# On récupère le PlayerStart *à l'instant*, dans le niveau ACTUEL
	var current_level := get_tree().root.get_node("Main/LevelRoot").get_child(0)

	if not current_level.has_node("PlayerStart"):
		push_error("⚠ Aucun PlayerStart dans ce niveau !")
		return

	var player_start = current_level.get_node("PlayerStart")

	player.velocity = Vector2.ZERO
	player.global_position = player_start.global_position
	player.spawn_dust()
