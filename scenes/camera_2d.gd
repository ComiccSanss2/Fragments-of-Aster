extends Camera2D

var bounds_shape: RectangleShape2D
var bounds_global_pos: Vector2
@export var follow_smoothness := 8.0
@export var cam_offset := Vector2(60, 0)
var target: Node2D


func _ready():
	target = get_node("../Player")


func set_bounds(bounds_node: Node):
	var shape = bounds_node.get_node("CollisionShape2D").shape

	if shape is RectangleShape2D:
		bounds_shape = shape
		bounds_global_pos = bounds_node.global_position
	else:
		push_error("LevelBounds doit utiliser RectangleShape2D !")


func _physics_process(delta):
	if not target or not bounds_shape:
		return

	# Follow smooth + offset
	var desired = target.global_position + cam_offset
	global_position = global_position.lerp(desired, delta * follow_smoothness)

	# Boundaries
	var ext = bounds_shape.extents

	var left   = bounds_global_pos.x - ext.x
	var right  = bounds_global_pos.x + ext.x
	var top    = bounds_global_pos.y - ext.y
	var bottom = bounds_global_pos.y + ext.y

	global_position.x = clamp(global_position.x, left, right)
	global_position.y = clamp(global_position.y, top, bottom)
