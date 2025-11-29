extends CPUParticles2D

func _ready():
	emitting = true
	# S'efface automatiquement une fois joué
	await get_tree().create_timer(lifetime).timeout
	queue_free()
