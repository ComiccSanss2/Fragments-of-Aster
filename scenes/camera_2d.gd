extends Camera2D

# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------
@export_group("Follow Settings")
@export var follow_smoothness := 8.0
@export var cam_offset := Vector2(60, 0) # Offset de base (souvent pour centrer un peu devant)

@export_group("Look Ahead Settings")
@export var look_ahead_y_dist := 150.0  # Distance vers le bas quand on tombe
@export var look_ahead_speed := 2.0     # Vitesse de transition du regard (plus bas = plus "onirique")
@export var fall_threshold := 200.0     # Vitesse de chute minimale pour activer le regard vers le bas

# ------------------------------------------------------------
# VARIABLES INTERNES
# ------------------------------------------------------------
var bounds_shape: RectangleShape2D
var bounds_global_pos: Vector2

var target: Node2D
var current_look_ahead_y := 0.0 # Variable pour lisser le mouvement vertical

# État cinématique
var is_cinematic := false
var cinematic_target: Node2D = null

# ------------------------------------------------------------
# READY
# ------------------------------------------------------------
func _ready():
	# On cherche le player (qui est frère de la caméra dans Main)
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
	# On reset l'anticipation pour éviter un saut de caméra
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
	# Pas de bornes ? On ne fait rien (ou on pourrait suivre sans borne)
	if not bounds_shape:
		return

	# 1. Déterminer qui on suit
	var follow_node := target
	if is_cinematic and cinematic_target:
		follow_node = cinematic_target

	if not follow_node:
		return

	# 2. Calculer la position désirée
	var desired := follow_node.global_position

	# 3. Logique dynamique (UNIQUEMENT hors cinématique)
	if not is_cinematic:
		# A. Offset de base
		desired += cam_offset
		
		# B. Look Ahead Vertical (Anticipation de chute)
		# On vérifie si la cible a une vélocité (Player)
		var target_y_offset = 0.0
		
		if follow_node is CharacterBody2D:
			# Si on tombe plus vite que le seuil (ex: 200px/s)
			if follow_node.velocity.y > fall_threshold:
				target_y_offset = look_ahead_y_dist
			# Optionnel : Regarder un peu en haut si on grimpe très vite ? 
			# Souvent déconseillé car désorientant, on laisse à 0.
		
		# Lissage indépendant pour le regard (Lerp)
		current_look_ahead_y = lerp(current_look_ahead_y, target_y_offset, delta * look_ahead_speed)
		
		# On applique l'offset vertical calculé
		desired.y += current_look_ahead_y

	# 4. Mouvement fluide vers la position finale
	global_position = global_position.lerp(desired, delta * follow_smoothness)

	# 5. Contrainte des limites (Clamping)
	var ext = bounds_shape.extents
	var left   = bounds_global_pos.x - ext.x
	var right  = bounds_global_pos.x + ext.x
	var top    = bounds_global_pos.y - ext.y
	var bottom = bounds_global_pos.y + ext.y
	
	# On prend en compte la taille de l'écran (viewport) pour ne pas voir le vide
	var view_size = get_viewport_rect().size / zoom
	var half_w = view_size.x / 2
	var half_h = view_size.y / 2

	global_position.x = clamp(global_position.x, left + half_w, right - half_w)
	global_position.y = clamp(global_position.y, top + half_h, bottom - half_h)
