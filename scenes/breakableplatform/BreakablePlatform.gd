extends Node2D

@export var break_delay := 1.0       # Temps avant la casse
@export var fall_speed := 300.0      # Vitesse de chute
@export var shake_amount := 1.5      # Tremblement
@export var regen_delay := 3.0       # Temps avant reset

var breaking := false
var falling := false
var player_on := false
var origin_pos: Vector2

func _ready():
	origin_pos = position

	# Timers dans StaticBody2D ✔
	$StaticBody2D/BreakTimer.wait_time = break_delay
	$StaticBody2D/RegenTimer.wait_time = regen_delay


func _process(delta):
	# Tremblement avant chute
	if breaking and not falling:
		position = origin_pos + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)

	# Chute
	if falling:
		$StaticBody2D.position.y += fall_speed * delta


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

		if falling:
			$StaticBody2D/RegenTimer.start()


# ------------------------------------------------------------
# CHUTE
# ------------------------------------------------------------
func _on_BreakTimer_timeout():
	if breaking:
		$StaticBody2D/CollisionShape2D.disabled = true
		falling = true


# ------------------------------------------------------------
# RÉGÉNÉRATION
# ------------------------------------------------------------
func _on_RegenTimer_timeout():
	if player_on:
		return

	# Reset
	falling = false
	breaking = false
	
	position = origin_pos
	$StaticBody2D.position = Vector2.ZERO

	# Collision activée
	$StaticBody2D/CollisionShape2D.disabled = false
