extends Area2D

# --- MOUVEMENT OPPRESSANT ---
@export var speed := 240.0           # Vitesse de base un poil plus rapide
@export var boost_speed := 650.0     # Il va beaucoup plus vite quand il est en retard
@export var max_distance := 500.0    # S'énerve beaucoup plus tôt (avant c'était 635)
@export var safe_distance := 350.0   # Freine beaucoup plus près de Lyra (avant c'était 425)
@export var panic_distance := 850.0  # NOUVEAU : Si Lyra sort de l'écran, il passe en Hyper Vitesse
@export var smoothness := 2.0        # Il accélère plus nerveusement

# --- AUDIO ---
@export var audio_effect_distance := 450.0 
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
		# CALCUL DU BORD DROIT
		var shape_rect = collision_shape.shape.get_rect()
		var wall_right_edge = collision_shape.global_position.x + (shape_rect.size.x / 2 * collision_shape.global_scale.x)
		
		var distance_to_edge = player.global_position.x - wall_right_edge
		
		# --- LOGIQUE DE BOOST SANS PITIÉ ---
		if distance_to_edge > panic_distance:
			# Si Lyra est VRAIMENT trop loin, le mur casse la limite de vitesse
			is_boosting = true
			target_speed = boost_speed * 1.5 
		elif distance_to_edge > max_distance:
			# Boost normal pour coller au joueur
			is_boosting = true
			target_speed = boost_speed
		elif distance_to_edge < safe_distance:
			# Il a rattrapé Lyra, il arrête de booster juste derrière elle
			is_boosting = false
			target_speed = speed
		else:
			# Maintient l'état actuel dans la zone grise
			target_speed = boost_speed if is_boosting else speed
			
		# LOGIQUE AUDIO
		_update_underwater_effect(distance_to_edge)

	# --- LE FREINAGE ---
	var current_smoothness = smoothness
	if target_speed == speed and current_speed > speed:
		current_smoothness = smoothness * 3.0 

	# APPLICATION DU MOUVEMENT
	current_speed = lerp(current_speed, target_speed, current_smoothness * delta)
	position.x += current_speed * delta

func _update_underwater_effect(dist: float):
	var filter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(glitch_bus_idx, 0)
	
	if dist < audio_effect_distance:
		var ratio = clamp(dist / audio_effect_distance, 0.0, 1.0)
		filter.cutoff_hz = lerp(underwater_cutoff, normal_cutoff, ratio)
	else:
		filter.cutoff_hz = normal_cutoff

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("die"):
			body.die(global_position)
