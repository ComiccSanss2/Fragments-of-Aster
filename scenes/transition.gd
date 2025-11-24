extends Control

var duration := 0.4  # durée du slide

@onready var rect := $ColorRect


func play_transition(callback: Callable):
	# on rend visible
	rect.visible = true
	rect.modulate.a = 1.0  # noir opaque

	# Position départ = hors écran (en haut à gauche)
	rect.position = Vector2(-rect.size.x, -rect.size.y)

	# Tween fermeture (↘)
	var tween1 = get_tree().create_tween()
	tween1.tween_property(rect, "position", Vector2(0, 0), duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Quand c’est terminé, on change de niveau via callback
	tween1.finished.connect(func():
		callback.call()

		# ouverture (↗)
		play_open()
	)
	

func play_open():
	# Tween ouverture (↗)
	var tween2 = get_tree().create_tween()
	tween2.tween_property(rect, "position", Vector2(rect.size.x, rect.size.y), duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween2.finished.connect(func():
		rect.visible = false
	)
