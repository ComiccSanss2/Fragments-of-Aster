extends Control

@onready var message_label = $CenterContainer/Label 

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	message_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	message_label.text = "Aster is still waiting for you, Lyra."
	
	var t = create_tween()
	t.set_ignore_time_scale(true) 
	
	# --- PHASE 1 : ASTER ---
	t.tween_interval(1.5)
	t.tween_property(message_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 3.0).set_trans(Tween.TRANS_SINE)
	t.tween_interval(3.0)
	t.tween_property(message_label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 2.0).set_trans(Tween.TRANS_SINE)
	
	# --- PHASE 2 : THIS IS JUST THE BEGINNING ---
	t.tween_interval(1.0)
	t.tween_callback(func(): message_label.text = "This is just the beginning.")
	t.tween_property(message_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 2.5).set_trans(Tween.TRANS_SINE)
	t.tween_interval(3.0)
	t.tween_property(message_label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 2.0).set_trans(Tween.TRANS_SINE)
	
	# --- PHASE 3 : WISHLIST ---
	t.tween_interval(1.0)
	t.tween_callback(func(): message_label.text = "Wishlist now on Steam")
	t.tween_property(message_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 3.0).set_trans(Tween.TRANS_SINE)
	
	# CORRECTION ICI : On réduit l'attente à 8 secondes (au lieu de 12)
	# Comme ça, on est sûr à 100% que le fade-out de 3.5s se finira AVANT la fin de la musique !
	t.tween_interval(4.0)
	t.tween_property(message_label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 3.5).set_trans(Tween.TRANS_SINE)
