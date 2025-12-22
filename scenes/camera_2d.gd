extends Camera2D

# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------
@export_group("Follow Settings")
@export var follow_smoothness := 8.0
# Offset Y = -40 pour regarder un peu vers le haut
@export var cam_offset := Vector2(0, 15) 

@export_group("Look Ahead Settings")
@export var look_ahead_x_dist := 60.0   # Distance du regard horizontal
@export var look_ahead_y_dist := 150.0  # Distance du regard vertical
@export var look_ahead_speed := 2.0     # Vitesse douce de la caméra
@export var fall_threshold := 200.0     # Vitesse de chute pour activer le regard bas

# ------------------------------------------------------------
# VARIABLES INTERNES
# ------------------------------------------------------------
var bounds_shape: RectangleShape2D
var bounds_global_pos: Vector2

var target: Node2D

# On stocke les offsets dynamiques actuels pour le lissage
var current_look_ahead_x := 0.0 
var current_look_ahead_y := 0.0 

# État cinématique
var is_cinematic := false
var cinematic_target: Node2D = null

# --- NOUVEAU : Variable de verrouillage ---
var is_locked := false 

# ------------------------------------------------------------
# READY
# ------------------------------------------------------------
func _ready():
	target = get_node("../Player")

# ------------------------------------------------------------
# CINEMATIC METHODS
# ------------------------------------------------------------
func start_cinematic(target_node: Node2D):
	is_cinematic = true
	cinematic_target = target_node

func end_cinematic():
	is_cinematic = false
	cinematic_target = null
	current_look_ahead_x = 0.0
	current_look_ahead_y = 0.0 

func zoom_to(value: float, time: float = 3.0):
	var tween = get_tree().create_tween()
	tween.tween_property(self, "zoom", Vector2(value, value), time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------
# LEVEL BOUNDS
# ------------------------------------------------------------
func set_bounds(bounds_node: Node):
	var shape = bounds_node.get_node("CollisionShape2D").shape
	if shape is RectangleShape2D:
		bounds_shape = shape
		bounds_global_pos = bounds_node.global_position
	else:
		push_error("LevelBounds doit utiliser RectangleShape2D !")

# ------------------------------------------------------------
# PHYSICS PROCESS
# ------------------------------------------------------------
func _physics_process(delta):
	# --- MODIFICATION ICI : Si verrouillé, on laisse le Main contrôler ---
	if is_locked:
		return 
	# ---------------------------------------------------------------------

	if not bounds_shape:
		return

	# 1. Déterminer qui on suit
	var follow_node := target
	if is_cinematic and cinematic_target:
		follow_node = cinematic_target

	if not follow_node:
		return

	# 2. Position de base de la cible
	var desired := follow_node.global_position

	# 3. Logique dynamique (Hors cinématique)
	if not is_cinematic:
		
		# A. Offset Statique
		desired += cam_offset
		
		var target_x_offset = 0.0
		var target_y_offset = 0.0
		
		if follow_node is CharacterBody2D:
			# --- B. LOOK AHEAD HORIZONTAL ---
			if abs(follow_node.velocity.x) > 20.0:
				target_x_offset = sign(follow_node.velocity.x) * look_ahead_x_dist
			else:
				target_x_offset = 0.0

			# --- C. LOOK AHEAD VERTICAL ---
			if follow_node.velocity.y > fall_threshold:
				target_y_offset = look_ahead_y_dist

		# Lissage indépendant pour X et Y
		current_look_ahead_x = lerp(current_look_ahead_x, target_x_offset, delta * look_ahead_speed)
		current_look_ahead_y = lerp(current_look_ahead_y, target_y_offset, delta * look_ahead_speed)
		
		# Application des offsets dynamiques
		desired.x += current_look_ahead_x
		desired.y += current_look_ahead_y

	# 4. Mouvement fluide global
	# C'est ici que 'follow_smoothness' est utilisé
	global_position = global_position.lerp(desired, delta * follow_smoothness)

	# 5. Contrainte des limites (Clamping)
	var ext = bounds_shape.extents
	var left   = bounds_global_pos.x - ext.x
	var right  = bounds_global_pos.x + ext.x
	var top    = bounds_global_pos.y - ext.y
	var bottom = bounds_global_pos.y + ext.y
	
	var view_size = get_viewport_rect().size / zoom
	var half_w = view_size.x / 2
	var half_h = view_size.y / 2

	global_position.x = clamp(global_position.x, left + half_w, right - half_w)
	global_position.y = clamp(global_position.y, top + half_h, bottom - half_h)
