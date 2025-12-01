extends Camera2D

var bounds_shape: RectangleShape2D
var bounds_global_pos: Vector2

@export var follow_smoothness := 8.0
@export var cam_offset := Vector2(60, 0)

var target: Node2D

# --- Nouveau ---
var is_cinematic := false
var cinematic_target: Node2D = null


func _ready():
	target = get_node("../Player")


# --- Nouveau : activer la caméra cinématique ---
func start_cinematic(target_node: Node2D):
	is_cinematic = true
	cinematic_target = target_node


# --- Nouveau : fin de la cinématique ---
func end_cinematic():
	is_cinematic = false
	cinematic_target = null


# --- Nouveau : zoom smooth ---
func zoom_to(value: float, time: float = 3.0):
	var tween = get_tree().create_tween()
	tween.tween_property(self, "zoom", Vector2(value, value), time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func set_bounds(bounds_node: Node):
	var shape = bounds_node.get_node("CollisionShape2D").shape

	if shape is RectangleShape2D:
		bounds_shape = shape
		bounds_global_pos = bounds_node.global_position
	else:
		push_error("LevelBounds doit utiliser RectangleShape2D !")


func _physics_process(delta):
	if not bounds_shape:
		return

	# --------- Sélection de la cible ---------
	var follow_node := target

	if is_cinematic and cinematic_target:
		follow_node = cinematic_target

	if not follow_node:
		return

	# Follow smooth + offset (UNIQUEMENT hors cinématique)
	var desired := follow_node.global_position

	if not is_cinematic:
		desired += cam_offset

	global_position = global_position.lerp(desired, delta * follow_smoothness)

	# --------- Boundaries ----------
	var ext = bounds_shape.extents

	var left   = bounds_global_pos.x - ext.x
	var right  = bounds_global_pos.x + ext.x
	var top    = bounds_global_pos.y - ext.y
	var bottom = bounds_global_pos.y + ext.y

	global_position.x = clamp(global_position.x, left, right)
	global_position.y = clamp(global_position.y, top, bottom)
