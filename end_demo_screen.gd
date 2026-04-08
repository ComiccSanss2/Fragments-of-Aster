extends Control

@onready var message_label = $CenterContainer/Label 

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	message_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	message_label.text = "Aster is still waiting for you, Lyra."
	
	var t = create_tween()
	t.set_ignore_time_scale(true) 
	
	# --- PHASE 1 ---
	t.tween_interval(1.5)
	t.tween_property(message_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 3.0).set_trans(Tween.TRANS_SINE)
	t.tween_interval(3.0)
	t.tween_property(message_label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 2.0).set_trans(Tween.TRANS_SINE)
	
	# --- PHASE 2 ---
	t.tween_interval(1.0)
	t.tween_callback(func(): message_label.text = "But the system is deeper than you thought.")
	t.tween_property(message_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 2.5).set_trans(Tween.TRANS_SINE)
	t.tween_interval(3.0)
	t.tween_property(message_label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 2.0).set_trans(Tween.TRANS_SINE)
	
	# --- PHASE 3 : CHAPTER 2 ---
	t.tween_interval(1.0)
	t.tween_callback(func(): message_label.text = "CHAPTER 2\nTHE SCRAPYARD")
	t.tween_property(message_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 3.0).set_trans(Tween.TRANS_SINE)
	t.tween_interval(3.0)
	t.tween_property(message_label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 2.0).set_trans(Tween.TRANS_SINE)
	
	t.tween_callback(transition_to_fall)

func transition_to_fall():
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		# Riaccendiamo Lyra e il mondo
		main.level_root.visible = true
		main.player.visible = true
		
		# CARICHIAMO DIRETTAMENTE IL LIVELLO 17!
		main.load_level("res://level_17.tscn")
		
		# Distruggiamo questa schermata di testo
		get_parent().queue_free()
