extends AnimatedSprite2D

@export var transformation_color := Color(0.612, 0.0, 0.0, 1.0) 

var start_y : float
var idle_tween : Tween # On crée une variable pour stocker l'animation

func _ready():
	start_y = position.y
	start_idle_anim()

func start_idle_anim():
	# On stocke le tween dans la variable
	idle_tween = create_tween().set_loops()
	idle_tween.tween_property(self, "position:y", start_y - 10.0, 2.0).set_trans(Tween.TRANS_SINE)
	idle_tween.tween_property(self, "position:y", start_y + 10.0, 2.0).set_trans(Tween.TRANS_SINE)

func turn_around():
	flip_h = not flip_h

func ascend_and_transform():
	# 1. LE FIX EST ICI : On tue l'animation de flottement
	if idle_tween:
		idle_tween.kill()
	
	var t = create_tween()
	
	# 2. On monte (Assure-toi que la valeur est assez grande)
	var target_y = position.y - 150.0
	t.tween_property(self, "position:y", target_y, 4.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# 3. Changement couleur + Taille
	t.parallel().tween_property(self, "modulate", transformation_color, 4.0)
	t.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 4.0)
