extends Node2D

@export var kill_y_offset := 200.0

var player: CharacterBody2D
var bounds_shape: RectangleShape2D

func _ready():
	# On cherche le joueur dans le Main
	player = get_tree().root.get_node("Main/Player")
	
	# On récupère la forme
	if has_node("CollisionShape2D"):
		bounds_shape = $CollisionShape2D.shape
	else:
		push_error("LevelBounds n'a pas de CollisionShape2D !")

func _physics_process(delta):
	# Sécurités
	if not player or not bounds_shape: return
	if player.is_dying: return # Si déjà mort, on ne fait rien

	var ext = bounds_shape.extents
	var global_pos = $CollisionShape2D.global_position

	# Calcul des limites
	var left   = global_pos.x - ext.x
	var right  = global_pos.x + ext.x
	var top    = global_pos.y - ext.y
	var bottom = global_pos.y + ext.y

	var pos = player.global_position

	# Si le joueur sort du cadre
	if pos.x < left or pos.x > right or pos.y < top or pos.y > bottom + kill_y_offset:
		# ON TUE LE JOUEUR
		print("Joueur hors limites -> Mort")
		player.die()
