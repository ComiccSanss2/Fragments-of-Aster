extends Area2D

var speed = 800.0
var direction = Vector2.ZERO

func _physics_process(delta):
	position += direction * speed * delta

func _on_area_entered(area):
	if area.is_in_group("hackable") and area.has_method("trigger_hack"):
		area.trigger_hack()
		queue_free() # Il proiettile si distrugge dopo l'impatto
