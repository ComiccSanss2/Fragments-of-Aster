# dash_ghost.gd
extends Sprite2D

func _ready():
	# On devient un peu transparent et bleuté/violet
	modulate = Color(0.888, 0.656, 1.0, 0.6)
	
	var tween = create_tween()
	# On disparait totalement en 0.3 secondes
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
