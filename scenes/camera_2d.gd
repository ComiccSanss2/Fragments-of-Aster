extends Camera2D

# ------------------------------------------------------------
# CONFIGURATION "SMOOTH & JUICY" (32x32)
# ------------------------------------------------------------
@export_group("Follow Settings")
# Plus c'est bas, plus c'est lourd/cinématique. Plus c'est haut, plus c'est collé.
# 5.0 est une bonne valeur "organique".
@export var lerp_speed := 5.0
@export var default_offset := Vector2(0, -20)

@export_group("Look Ahead Settings")
@export var look_ahead_dist_x := 140.0
@export var look_ahead_dist_y := 80.0
# TEMPS D'ATTENTE avant de déplacer le regard (en secondes).
# Empêche la caméra de bouger si on fait juste gauche-droite vite fait.
@export var look_ahead_delay := 0.6
# Vitesse à laquelle le regard se déplace (plus doux = moins de mal de mer)
@export var look_ahead_smoothness := 1.5

@export var fall_threshold := 450.0

# ------------------------------------------------------------
# VARIABLES INTERNES
# ------------------------------------------------------------
var target: Node2D
var bounds_shape: RectangleShape2D
var bounds_global_pos: Vector2

# Gestion du Look Ahead
var current_look_ahead_x := 0.0
var current_look_ahead_y := 0.0
var look_ahead_timer := 0.0
var last_facing_dir := 0

# États
var is_cinematic := false
var cinematic_target: Node2D = null
var is_locked := false

# ------------------------------------------------------------
# INITIALISATION
# ------------------------------------------------------------
func _ready():
	# On désactive le lissage Godot, on gère tout nous-mêmes
	position_smoothing_enabled = false
	
	# Zoom pour 32x32 (Sera écrasé par Main.gd, mais bonne pratique)
	zoom = Vector2(2.5, 2.5)
	
	target = get_tree().root.get_node_or_null("Main/Player")
	if not target: target = get_node_or_null("../Player")

	# Téléportation initiale
	if target:
		global_position = target.global_position + default_offset

# ------------------------------------------------------------
# PHYSICS PROCESS
# ------------------------------------------------------------
func _physics_process(delta):
	if is_locked: return
	
	# 1. Cible
	var follow_node = target
	if is_cinematic and cinematic_target:
		follow_node = cinematic_target
	if not follow_node: return

	# 2. Calcul de la Position de BASE
	var ideal_pos = follow_node.global_position
	
	if not is_cinematic:
		ideal_pos += default_offset
		
		# --- GESTION INTELLIGENTE DU LOOK AHEAD ---
		var input_x = Input.get_axis("ui_left", "ui_right")
		var target_look_x = 0.0
		var target_look_y = 0.0
		
		# A. Horizontal : On attend avant de regarder
		if input_x != 0:
			# Si on change de direction, on reset le timer
			if input_x != last_facing_dir:
				look_ahead_timer = 0.0
				last_facing_dir = input_x
			
			look_ahead_timer += delta
			
			# Seulement si on maintient la direction assez longtemps
			if look_ahead_timer >= look_ahead_delay:
				target_look_x = input_x * look_ahead_dist_x
		else:
			look_ahead_timer = 0.0
			# Optionnel : Si tu veux que la caméra revienne au centre quand on s'arrête
			# target_look_x = 0.0 
			# Si tu veux qu'elle reste décalée (style Mario), commente la ligne ci-dessus.
			
		# B. Vertical : Seulement en chute libre
		if follow_node is CharacterBody2D and follow_node.velocity.y > fall_threshold:
			target_look_y = look_ahead_dist_y
		
		# C. Lissage indépendant du Look Ahead (Très doux)
		# On utilise lerp pour une transition "crémeuse" du regard
		current_look_ahead_x = lerp(current_look_ahead_x, target_look_x, look_ahead_smoothness * delta)
		current_look_ahead_y = lerp(current_look_ahead_y, target_look_y, look_ahead_smoothness * delta)
		
		ideal_pos.x += current_look_ahead_x
		ideal_pos.y += current_look_ahead_y

	# 3. MOUVEMENT FLUIDE (Formule exponentielle indépendante du framerate)
	# C'est cette formule qui enlève l'effet "brusque"
	var smooth_factor = 1.0 - exp(-lerp_speed * delta)
	global_position = global_position.lerp(ideal_pos, smooth_factor)

	# 4. Limites (Bounds)
	_apply_bounds()

# ------------------------------------------------------------
# UTILITAIRES
# ------------------------------------------------------------
func _apply_bounds():
	if not bounds_shape: return
	
	var view_size = get_viewport_rect().size / zoom
	var half_w = view_size.x / 2
	var half_h = view_size.y / 2
	
	var ext = bounds_shape.extents
	var left   = bounds_global_pos.x - ext.x
	var right  = bounds_global_pos.x + ext.x
	var top    = bounds_global_pos.y - ext.y
	var bottom = bounds_global_pos.y + ext.y
	
	# Clamp X
	if right - left > view_size.x:
		global_position.x = clamp(global_position.x, left + half_w, right - half_w)
	else:
		global_position.x = (left + right) / 2
	
	# Clamp Y
	if bottom - top > view_size.y:
		global_position.y = clamp(global_position.y, top + half_h, bottom - half_h)
	else:
		global_position.y = (top + bottom) / 2

func set_bounds(bounds_node: Node):
	if bounds_node.has_node("CollisionShape2D"):
		var shape = bounds_node.get_node("CollisionShape2D").shape
		if shape is RectangleShape2D:
			bounds_shape = shape
			bounds_global_pos = bounds_node.global_position

func start_cinematic(target_node: Node2D):
	is_cinematic = true
	cinematic_target = target_node

func end_cinematic():
	is_cinematic = false
	cinematic_target = null
	# On garde le look ahead actuel pour pas faire de saut brutal
	
func zoom_to(value: float, time: float = 2.0):
	var tween = get_tree().create_tween()
	tween.tween_property(self, "zoom", Vector2(value, value), time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
