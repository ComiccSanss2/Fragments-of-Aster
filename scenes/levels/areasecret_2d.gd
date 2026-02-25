extends Area2D

@onready var secret_tilemap = $"../SecretTileMap"

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		var t = create_tween()

		t.tween_property(secret_tilemap, "modulate:a", 0.2, 0.4)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		var t = create_tween()
		t.tween_property(secret_tilemap, "modulate:a", 1.0, 0.4)
