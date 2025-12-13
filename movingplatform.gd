extends AnimatableBody2D

# --- CONFIGURATION ---
# Liste de choix pour l'inspecteur
enum MoveType { HORIZONTAL, VERTICAL }

@export_group("Settings")
@export var move_type: MoveType = MoveType.HORIZONTAL # Choix du type
@export var distance: float = 200.0 # Distance de l'aller-retour
@export var speed: float = 3.0      # Durée d'un aller (en secondes)
@export var pause_time: float = 0.5 # Temps d'attente aux extrémités

# --- VARIABLES ---
var start_pos: Vector2

func _ready():
	# On mémorise la position de départ (celle que tu as mise dans le niveau)
	start_pos = global_position
	
	# On lance le mouvement
	start_tween()

func start_tween():
	# Création du Tween (Animation par code)
	var tween = create_tween().set_loops() # set_loops() = infini
	
	# On configure le lissage (Sine = mouvement doux, commence lent, accélère, finit lent)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Calcul de la destination
	var target_pos = Vector2.ZERO
	
	if move_type == MoveType.HORIZONTAL:
		target_pos = Vector2(distance, 0)
	else:
		target_pos = Vector2(0, distance) # Y positif = vers le bas
	
	# 1. Aller vers la destination
	# Note: on ajoute target_pos à start_pos pour savoir où aller
	tween.tween_property(self, "global_position", start_pos + target_pos, speed)
	
	# 2. Pause à l'arrivée
	tween.tween_interval(pause_time)
	
	# 3. Retour à la position de départ
	tween.tween_property(self, "global_position", start_pos, speed)
	
	# 4. Pause au départ
	tween.tween_interval(pause_time)
