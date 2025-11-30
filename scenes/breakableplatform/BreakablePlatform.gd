extends Node2D

@export var break_delay := 0.4
@export var fall_speed := 300.0
@export var shake_amount := 1.5
@export var regen_delay := 3.0

var breaking := false
var falling := false
var player_on := false
var origin_pos: Vector2

func _ready():
	origin_pos = global_position

	$StaticBody2D/BreakTimer.wait_time = break_delay
	$StaticBody2D/RegenTimer.wait_time = regen_delay


func _process(delta):
	# Tremblement
	if breaking and not falling:
		global_position = origin_pos + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)

	# Chute
	if falling:
		global_position.y += fall_speed * delta


# ------------------------------------------------------------
# DÉTECTION JOUEUR
# ------------------------------------------------------------
func _on_Area2D_body_entered(body):
	if body.is_in_group("player"):
		player_on = true

		if not breaking:
			breaking = true
			$StaticBody2D/BreakTimer.start()


func _on_Area2D_body_exited(body):
	if body.is_in_group("player"):
		player_on = false


# ------------------------------------------------------------
# LA PLATEFORME SE CASSE
# ------------------------------------------------------------
func _on_BreakTimer_timeout():
	if breaking:
		falling = true
		$StaticBody2D/CollisionShape2D.disabled = true
		$StaticBody2D/RegenTimer.start()


# ------------------------------------------------------------
# RÉGÉNÉRATION
# ------------------------------------------------------------
func _on_RegenTimer_timeout():
	# Respawn même si le joueur est tombé sans exit()
	falling = false
	breaking = false
	player_on = false

	# Reset position
	global_position = origin_pos

	# Reset collisions
	$StaticBody2D.position = Vector2.ZERO
	$StaticBody2D/CollisionShape2D.disabled = false
