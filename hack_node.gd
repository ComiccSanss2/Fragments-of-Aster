extends Area2D
class_name HackNode

@onready var solid_body = $CorpoSolido
@onready var holo_sprite = $SpriteOlogramma
@onready var solid_sprite = $CorpoSolido/SpriteMaterializzato

var is_hacked: bool = false
var is_highlighted: bool = false # Nuova variabile

func _ready():
	add_to_group("hackable")
	solid_body.collision_layer = 0
	solid_body.collision_mask = 0
	solid_sprite.visible = false
	holo_sprite.modulate = Color(1, 1, 1, 0.5) # Trasparente base

# NUOVA FUNZIONE: Gestisce l'evidenziazione quando Lyra è vicina
func set_highlight(active: bool):
	if is_hacked: return # Se è solido, non ha senso evidenziarlo
	is_highlighted = active
	
	if active:
		# Diventa un po' più opaco e prende un colore neon (es: verde acqua acceso)
		# Puoi cambiare i valori di Color() a piacimento!
		holo_sprite.modulate = Color(0.5, 2.0, 1.5, 0.9) 
		holo_sprite.scale = Vector2(1.1, 1.1) # Si ingrandisce leggermente
	else:
		# Torna normale
		holo_sprite.modulate = Color(1, 1, 1, 0.5)
		holo_sprite.scale = Vector2(1.0, 1.0)

# Questa funzione gestisce lo switch on/off (Il Juice di prima)
func trigger_hack():
	if is_hacked:
		is_hacked = false
		solid_body.collision_layer = 0
		solid_body.collision_mask = 0
		
		var t = create_tween()
		t.tween_property(solid_sprite, "scale", Vector2(0.5, 0.5), 0.15)
		await t.finished
		solid_sprite.visible = false
		
		# Torna a verificare l'highlight
		if is_highlighted: set_highlight(true)
		else: set_highlight(false)
		
	else:
		is_hacked = true
		solid_body.collision_layer = 1
		solid_body.collision_mask = 1
		
		holo_sprite.modulate.a = 0.0
		solid_sprite.visible = true
		solid_sprite.scale = Vector2(0.2, 0.2) 
		
		solid_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0) 
		
		var t = create_tween().set_parallel(true)
		t.tween_property(solid_sprite, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		t.tween_property(solid_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
