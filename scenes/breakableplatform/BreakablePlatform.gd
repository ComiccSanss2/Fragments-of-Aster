extends Node2D

@export var break_delay := 1.0       # Temps avant la casse
@export var fall_speed := 300.0      # Vitesse de chute
@export var shake_amount := 1.5      # Tremblement
@export var regen_delay := 3.0       # Temps pour revenir après que le joueur part

var breaking := false
var falling := false
var player_on := false
var origin_pos: Vector2

func _ready():
	set_process(true)
	origin_pos = position

	# timers sont sous CharacterBody2D
	$CharacterBody2D/BreakTimer.wait_time = break_delay
	$CharacterBody2D/RegenTimer.wait_time = regen_delay


func _process(delta):
	# Effet de tremblement avant la chute
	if breaking and not falling:
		position = origin_pos + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)

	# Chute de la plateforme
	if falling:
		$CharacterBody2D.position.y += fall_speed * delta


# ------------------------------------------------------------
# DÉTECTION DU JOUEUR
# ------------------------------------------------------------
func _on_Area2D_body_entered(body):
	if body.is_in_group("player"):
		player_on = true

		if not breaking:
			breaking = true
			$CharacterBody2D/BreakTimer.start()


func _on_Area2D_body_exited(body):
	if body.is_in_group("player"):
		player_on = false

		if falling:
			$CharacterBody2D/RegenTimer.start()


# ------------------------------------------------------------
# LA PLATEFORME SE CASSE
# ------------------------------------------------------------
func _on_BreakTimer_timeout():
	if breaking:
		$CharacterBody2D/CollisionShape2D.disabled = true
		falling = true


# ------------------------------------------------------------
# LA PLATEFORME SE RÉGÈNÈRE
# ------------------------------------------------------------
func _on_RegenTimer_timeout():
	# Si le joueur est encore dessus → attendre
	if player_on:
		return

	# Reset complet
	falling = false
	breaking = false
	position = origin_pos

	# Réactiver la collision
	$CharacterBody2D/CollisionShape2D.disabled = false
