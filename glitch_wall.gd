extends Area2D

# --- MOUVEMENT ---
@export var speed := 220.0 
@export var boost_speed := 460.0     # Légèrement augmenté pour un retour un peu plus mordant
@export var max_distance := 650.0    # Laisse Lyra s'éloigner plus avant de paniquer
@export var safe_distance := 450.0   # Freine plus tôt pour ne pas écraser le joueur
@export var smoothness := 1.5        # Inertie de base (pour l'accélération)

# --- AUDIO ---
@export var audio_effect_distance := 400.0 
@export var underwater_cutoff := 500.0 
@export var normal_cutoff := 20000.0 

var current_speed := 220.0
var is_boosting := false

@onready var glitch_bus_idx = AudioServer.get_bus_index("GlitchEffect")
@onready var collision_shape = $CollisionShape2D 

func _physics_process(delta):
	var player = get_tree().get_first_node_in_group("player")
	var target_speed = speed 
	
	if player:
		# CALCUL DU BORD DROIT (Prend en compte l'échelle globale)
		var shape_rect = collision_shape.shape.get_rect()
		var wall_right_edge = collision_shape.global_position.x + (shape_rect.size.x / 2 * collision_shape.global_scale.x)
		
		var distance_to_edge = player.global_position.x - wall_right_edge
		
		# LOGIQUE DE BOOST AMÉLIORÉE
		if distance_to_edge > max_distance:
			is_boosting = true
		elif distance_to_edge < safe_distance:
			is_boosting = false
			
		target_speed = boost_speed if is_boosting else speed
		
		# LOGIQUE AUDIO
		_update_underwater_effect(distance_to_edge)

	# --- LE SECRET DU BON FREINAGE ---
	var current_smoothness = smoothness
	# Si le mur a fini son boost et doit ralentir, on multiplie le smoothness pour qu'il freine fort
	if target_speed == speed and current_speed > speed:
		current_smoothness = smoothness * 3.0 

	# APPLICATION DU MOUVEMENT
	current_speed = lerp(current_speed, target_speed, current_smoothness * delta)
	position.x += current_speed * delta

func _update_underwater_effect(dist: float):
	var filter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(glitch_bus_idx, 0)
	
	if dist < audio_effect_distance:
		# On utilise dist directement.
		var ratio = clamp(dist / audio_effect_distance, 0.0, 1.0)
		filter.cutoff_hz = lerp(underwater_cutoff, normal_cutoff, ratio)
	else:
		filter.cutoff_hz = normal_cutoff

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("die"):
			body.die(global_position)
