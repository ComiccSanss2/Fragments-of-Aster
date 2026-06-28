extends Area2D
class_name HackNode

@onready var solid_body = $CorpoSolido
@onready var holo_sprite = $SpriteOlogramma
@onready var solid_sprite = $CorpoSolido/SpriteMaterializzato

var is_hacked: bool = false

func _ready():
	add_to_group("hackable")
	# Stato iniziale: Ologramma
	solid_body.collision_layer = 0
	solid_body.collision_mask = 0
	solid_sprite.visible = false
	holo_sprite.modulate.a = 0.5

# Questa funzione ora gestisce lo switch on/off
func trigger_hack():
	if is_hacked:
		# --- DISATTIVA (Torna Ologramma) ---
		is_hacked = false
		solid_body.collision_layer = 0
		solid_body.collision_mask = 0
		
		# Animazione inversa
		var t = create_tween()
		t.tween_property(solid_sprite, "scale", Vector2(0.1, 1.0), 0.2)
		await t.finished
		solid_sprite.visible = false
		holo_sprite.modulate.a = 0.5
		print("Nodo disattivato: tornato ologramma.")
		
	else:
		# --- ATTIVA (Diventa Solido) ---
		is_hacked = true
		solid_body.collision_layer = 1
		solid_body.collision_mask = 1
		
		# Animazione attivazione
		holo_sprite.modulate.a = 0.0
		solid_sprite.visible = true
		solid_sprite.scale = Vector2(0.1, 1.0)
		var t = create_tween()
		t.tween_property(solid_sprite, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_ELASTIC)
		print("Nodo attivato: piattaforma solida.")
