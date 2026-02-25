extends Area2D

@onready var secret_tilemap = $"../SecretTileMap"

func _on_body_entered(body: Node2D) -> void:
	# On vérifie que c'est bien le joueur qui rentre
	if body.name == "Player":
		var t = create_tween()
		# On rend le faux toit presque transparent (0.2) en 0.4 seconde
		# (Tu peux mettre 0.0 si tu veux qu'il disparaisse complètement)
		t.tween_property(secret_tilemap, "modulate:a", 0.2, 0.4)

func _on_body_exited(body: Node2D) -> void:
	# Quand le joueur ressort, le mur redevient totalement opaque (1.0)
	if body.name == "Player":
		var t = create_tween()
		t.tween_property(secret_tilemap, "modulate:a", 1.0, 0.4)
