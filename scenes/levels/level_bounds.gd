extends Node2D

@export var kill_y_offset := 200.0   # marge sous les bounds pour détecter la mort

var player_start: Node2D
var player: CharacterBody2D
var bounds_shape: RectangleShape2D


func _ready():
	# PlayerStart dans le niveau
	if get_parent().has_node("PlayerStart"):
		player_start = get_parent().get_node("PlayerStart")
	else:
		push_error("❌ PlayerStart introuvable dans ce niveau !")

	# Le Player dans la scène Main
	player = get_tree().get_root().get_node("Main/Player")

	# Forme rectangle des bounds
	bounds_shape = $CollisionShape2D.shape



# ------------------------------------------------------------
#  PHYSICS_PROCESS = vérifie si le joueur sort des limites
# ------------------------------------------------------------
func _physics_process(delta):
	if not player or not player_start or not bounds_shape:
		return

	var ext = bounds_shape.extents

	var left   = global_position.x - ext.x
	var right  = global_position.x + ext.x
	var top    = global_position.y - ext.y
	var bottom = global_position.y + ext.y

	var pos = player.global_position

	# Le joueur sort des limites ?
	if pos.x < left \
	or pos.x > right \
	or pos.y < top \
	or pos.y > bottom + kill_y_offset:
		respawn_player()



# ------------------------------------------------------------
#  RESPAWN DU JOUEUR
# ------------------------------------------------------------
func respawn_player():
	player.velocity = Vector2.ZERO
	player.global_position = player_start.global_position
