extends Area2D

func _ready():
	# Si connette automaticamente quando Lyra entra ed esce
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		print("--- HACK ZONE: Lyra è entrata nella rete! ---")
		body.can_hack_in_zone = true

func _on_body_exited(body):
	if body.name == "Player" or body.is_in_group("player"):
		print("--- HACK ZONE: Segnale perso! ---")
		body.can_hack_in_zone = false
