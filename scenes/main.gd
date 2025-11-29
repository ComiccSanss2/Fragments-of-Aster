extends Node2D

@onready var player := $Player
@onready var level_root := $LevelRoot
@onready var camera := $Camera2D


func _ready():
	load_level("res://scenes/levels/level_1.tscn")


func load_level(path: String):
	# -----------------------------
	# 1. Nettoyer le level précédent
	# -----------------------------
	for c in level_root.get_children():
		c.queue_free()

	# -----------------------------
	# 2. Charger la nouvelle scène
	# -----------------------------
	var level_scene = load(path).instantiate()
	level_root.add_child(level_scene)

	# -----------------------------
	# 3. Placer le joueur
	# -----------------------------
	if level_scene.has_node("PlayerStart"):
		var spawn = level_scene.get_node("PlayerStart")
		player.global_position = spawn.global_position
	else:
		push_error("⚠ Aucun PlayerStart trouvé dans: " + path)

	# -----------------------------
	# 4. Régler les limites caméra
	# -----------------------------
	if level_scene.has_node("LevelBounds"):
		var bounds = level_scene.get_node("LevelBounds")
		camera.set_bounds(bounds)
	else:
		push_error("⚠ Aucun LevelBounds trouvé dans: " + path)
		
		
		
