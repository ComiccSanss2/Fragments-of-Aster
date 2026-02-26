extends Area2D

# Vitesse de base du mur
@export var speed := 240.0 
@export var boost_speed := 600.0
@export var max_distance := 700.0
@export var safe_distance := 400.0
@export var smoothness := 2.0

var current_speed := 240.0

func _physics_process(delta):
	var player = get_tree().get_first_node_in_group("player")
	var target_speed = speed 
	
	if player:
		var distance = player.global_position.x - global_position.x
		
		if distance > max_distance:
			target_speed = boost_speed

	current_speed = lerp(current_speed, target_speed, smoothness * delta)
	
	# Application du mouvement
	position.x += current_speed * delta

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("die"):
			body.die(global_position)
