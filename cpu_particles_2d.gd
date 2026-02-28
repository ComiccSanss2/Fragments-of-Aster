extends CPUParticles2D

func _ready():
	# On force l'explosion au moment où la scène apparaît
	emitting = true
	
	# Quand l'explosion est finie, on supprime la scène de la mémoire
	finished.connect(queue_free)
