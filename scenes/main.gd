extends Node2D

@onready var player := $Player
@onready var level_root := $LevelRoot

func _ready():
	load_level("res://scenes/levels/level_1.tscn")

func load_level(path):
	# nettoyer le level actuel
	for c in level_root.get_children():
		c.queue_free()

	# charger la nouvelle scène
	var level_scene = load(path).instantiate()
	level_root.add_child(level_scene)

	# placer le player au PlayerStart du niveau
	var ps = level_scene.get_node("PlayerStart")
	player.global_position = ps.global_position
