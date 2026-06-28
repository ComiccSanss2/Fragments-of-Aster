extends Camera2D

# ------------------------------------------------------------
# CONFIGURATION "SMOOTH & JUICY" (32x32)
# ------------------------------------------------------------
@export_group("Follow Settings")
@export var lerp_speed := 6.0 
@export var default_offset := Vector2(0, -20)

@export_group("Look Ahead Settings")
@export var look_ahead_dist_x := 120.0 
@export var look_ahead_dist_y := 80.0

# TEMPS D'ATTENTE AVANT DE SE RETOURNER :
@export var look_ahead_delay := 0.10

# Vitesse du mouvement des "yeux" de la caméra 
@export var look_ahead_smoothness := 4.0 

@export var fall_threshold := 450.0

@export_group("Peek Settings (Regarder en haut/bas)")
@export var peek_delay := 0.5 # Temps (en secondes) à maintenir avant de regarder
@export var peek_dist_y := 160.0 # Distance de la caméra vers le haut ou le bas

# ------------------------------------------------------------
# VARIABLES INTERNES
# ------------------------------------------------------------
var target: Node2D
var bounds_shape: RectangleShape2D
var bounds_global_pos: Vector2

# Gestion du Look Ahead
var current_look_ahead_x := 0.0
var current_look_ahead_y := 0.0
var target_look_x := 0.0 
var target_look_y := 0.0

var look_ahead_timer := 0.0
var vertical_peek_timer := 0.0 
var last_facing_dir := 0

# États
var is_cinematic := false
var cinematic_target: Node2D = null
var is_locked := false
var hack_target: Node2D = null

# ------------------------------------------------------------
# INITIALISATION
# ------------------------------------------------------------
func _ready():
	position_smoothing_enabled = false
	zoom = Vector2(2.5, 2.5)
	
	target = get_tree().root.get_node_or_null("Main/Player")
	if not target: target = get_node_or_null("../Player")

	if target:
		global_position = target.global_position + default_offset
		if "facing_dir" in target:
			last_facing_dir = target.facing_dir
			target_look_x = last_facing_dir * look_ahead_dist_x
			current_look_ahead_x = target_look_x

# ------------------------------------------------------------
# PHYSICS PROCESS
# ------------------------------------------------------------
func _physics_process(delta):
	if is_locked: return
	
	var follow_node = target
	if is_cinematic and cinematic_target:
		follow_node = cinematic_target
	elif "hack_target" in self and hack_target != null:
		follow_node = hack_target
		
	if not follow_node: return

	var ideal_pos = follow_node.global_position
	
	if not is_cinematic:
		ideal_pos += default_offset
		
		# --- GESTION INTELLIGENTE DU LOOK AHEAD (DIGITAL FIX) ---
		var input_x := 0
		if Input.is_action_pressed("ui_right"): input_x += 1
		if Input.is_action_pressed("ui_left"): input_x -= 1
		
		# A. Horizontal
		if input_x != 0:
			# Si c'est notre tout premier mouvement ou qu'on va dans la même direction : instantané
			if last_facing_dir == 0 or sign(input_x) == sign(last_facing_dir):
				last_facing_dir = input_x
				look_ahead_timer = 0.0
			# Si on change de direction : on attend un tout petit peu
			elif input_x != last_facing_dir:
				look_ahead_timer += delta
				if look_ahead_timer >= look_ahead_delay:
					last_facing_dir = input_x
					look_ahead_timer = 0.0
					
			# On met à jour la position cible avec une valeur entière garantie (1 ou -1)
			target_look_x = last_facing_dir * look_ahead_dist_x
		else:
			look_ahead_timer = 0.0
			
		# B. Vertical : Chute libre OU Regarder en haut/bas (Peek)
		var is_falling = follow_node is CharacterBody2D and follow_node.velocity.y > fall_threshold
		
		if is_falling:
			# Si on tombe très vite, on regarde vers le bas quoi qu'il arrive
			target_look_y = look_ahead_dist_y
			vertical_peek_timer = 0.0 # Reset du timer
		else:
			# On check les inputs Haut et Bas
			var input_y := 0
			if Input.is_action_pressed("ui_down"): input_y += 1
			if Input.is_action_pressed("ui_up"): input_y -= 1
			
			# CONDITION DE PEEK : Être au sol et (presque) à l'arrêt
			var can_peek = true
			if follow_node is CharacterBody2D:
				can_peek = follow_node.is_on_floor() and abs(follow_node.velocity.x) < 10.0
			
			if input_y != 0 and can_peek:
				vertical_peek_timer += delta
				if vertical_peek_timer >= peek_delay:
					# On déplace la cible de la caméra vers le haut (-1) ou le bas (1)
					target_look_y = input_y * peek_dist_y
			else:
				# Si on lâche la touche ou qu'on se met à bouger, on annule tout
				vertical_peek_timer = 0.0
				target_look_y = 0.0
		
		# C. Lissage du regard 
		current_look_ahead_x = lerp(current_look_ahead_x, target_look_x, look_ahead_smoothness * delta)
		current_look_ahead_y = lerp(current_look_ahead_y, target_look_y, look_ahead_smoothness * delta)
		
		ideal_pos.x += current_look_ahead_x
		ideal_pos.y += current_look_ahead_y

	# 3. MOUVEMENT FLUIDE DE LA CAMÉRA
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
	
	if right - left > view_size.x:
		global_position.x = clamp(global_position.x, left + half_w, right - half_w)
	else:
		global_position.x = (left + right) / 2
	
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
	
func zoom_to(value: float, time: float = 2.0):
	var tween = get_tree().create_tween()
	tween.tween_property(self, "zoom", Vector2(value, value), time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
