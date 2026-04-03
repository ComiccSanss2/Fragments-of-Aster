extends Node2D

@export var break_delay := 0.4
@export var fall_speed := 300.0
@export var shake_amount := 1.5
@export var regen_delay := 3.0

# --- NOUVEAU : Case à cocher dans l'éditeur ---
@export var fall_up := false 

var breaking := false
var falling := false
var player_on := false
var origin_pos: Vector2

# --- FIX FLICKERING: Prendiamo il nodo del disegno ---
@onready var sprite = $StaticBody2D/Sprite2D # Cambialo se il tuo si chiama "AnimatedSprite2D" o in altro modo

func _ready():
	origin_pos = global_position
	
	if fall_up:
		scale.y = -1 

	$StaticBody2D/BreakTimer.wait_time = break_delay
	$StaticBody2D/RegenTimer.wait_time = regen_delay

func _process(delta):
	# --- FIX FLICKERING: Trema solo il disegno! ---
	if breaking and not falling:
		sprite.position = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)

	# Chute (Questa va bene perché cade tutto il blocco)
	if falling:
		if fall_up:
			global_position.y -= fall_speed * delta
		else:
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
		sprite.position = Vector2.ZERO # Resetta lo sprite al centro prima di cadere
		$StaticBody2D/CollisionShape2D.disabled = true
		$StaticBody2D/RegenTimer.start()

# ------------------------------------------------------------
# RÉGÉNÉRATION
# ------------------------------------------------------------
func _on_RegenTimer_timeout():
	falling = false
	breaking = false
	player_on = false

	# Reset di tutto
	global_position = origin_pos
	sprite.position = Vector2.ZERO # Resetta il disegno
	
	$StaticBody2D.position = Vector2.ZERO
	$StaticBody2D/CollisionShape2D.disabled = false
