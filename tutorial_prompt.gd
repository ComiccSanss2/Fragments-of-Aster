extends Area2D

@export var target_alpha: float = 1.0  # Transparence max quand Lyra est proche
@export var fade_duration: float = 0.5 # Temps pour apparaître/disparaître en secondes
@export var float_amplitude: float = 5.0 # Hauteur du flottement (pixels)
@export var float_speed: float = 3.0   # Vitesse du flottement

@export_group("Textures Dynamiques")
@export var tex_keyboard: Texture2D # Image de la touche Clavier
@export var tex_gamepad: Texture2D  # Image de la touche Manette

@onready var sprite: Sprite2D = $Sprite2D
var base_y: float
var time_passed: float = 0.0
var tween: Tween

# Référence au Main pour lire la variable is_using_gamepad
var main_node: Node

func _ready():
	# On cherche le noeud Main à la racine du jeu
	main_node = get_tree().root.get_node_or_null("Main")
	
	if sprite:
		sprite.modulate.a = 0.0
		base_y = sprite.position.y
		
		# On assigne une texture par défaut au cas où
		if tex_keyboard:
			sprite.texture = tex_keyboard
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta):
	# --- 1. CHANGEMENT DYNAMIQUE DE L'IMAGE ---
	if main_node and sprite:
		if main_node.is_using_gamepad and tex_gamepad:
			sprite.texture = tex_gamepad
		elif not main_node.is_using_gamepad and tex_keyboard:
			sprite.texture = tex_keyboard

	# --- 2. ANIMATION DE FLOTTEMENT ---
	if sprite and sprite.modulate.a > 0.01: 
		time_passed += delta
		sprite.position.y = base_y + sin(time_passed * float_speed) * float_amplitude

func _on_body_entered(body):
	if body.is_in_group("player"):
		if tween and tween.is_running():
			tween.kill()
		
		tween = create_tween()
		tween.tween_property(sprite, "modulate:a", target_alpha, fade_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_body_exited(body):
	if body.is_in_group("player"):
		if tween and tween.is_running():
			tween.kill()
			
		tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, fade_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
