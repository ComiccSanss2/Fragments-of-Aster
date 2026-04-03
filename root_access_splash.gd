extends Control

@onready var terminal_label = $VBoxContainer/TerminalLabel
@onready var logo_label = $VBoxContainer/LogoLabel

# --- AUDIO NODES ---
@onready var keyboard_sfx = $KeyboardSound
@onready var access_sfx = $AccessGrantedSound
@onready var impact_sfx = $LogoImpactSound

# Cambia con la scena che deve caricare dopo
const NEXT_SCENE = "res://gamepad_splash.tscn"

var is_transitioning := false

func _ready():
	# 1. Setup Iniziale 
	terminal_label.text = ""
	logo_label.modulate.a = 0.0
	logo_label.scale = Vector2(4.0, 4.0) # Parte ancora più gigantesco
	
	animate_logo()

func animate_logo():
	# --- FASE 1: AVVIO DEL SISTEMA E BYPASS ---
	terminal_label.text = "_"
	await get_tree().create_timer(0.5).timeout
	terminal_label.text = "> _"
	await get_tree().create_timer(0.6).timeout
	
	terminal_label.text = "> "
	await _type_text("init_system... ")
	await get_tree().create_timer(0.4).timeout
	terminal_label.text += "[OK]\n> "
	await get_tree().create_timer(0.6).timeout
	
	await _type_text("bypassing_security... ")
	await get_tree().create_timer(0.5).timeout
	terminal_label.text += "[OK]\n> "
	await get_tree().create_timer(0.8).timeout
	
	# --- FASE 2: ROOT ACCESS ---
	await _type_text("granting_root_access")
	await get_tree().create_timer(0.4).timeout
	
	# SUONO DI SUCCESSO! (Parte esattamente quando inizia a lampeggiare)
	if access_sfx.stream: access_sfx.play()
	
	# Il testo lampeggia come un allarme o un successo critico
	for i in range(3):
		terminal_label.modulate = Color("00ff99")
		await get_tree().create_timer(0.12).timeout
		terminal_label.modulate = Color(1, 1, 1)
		await get_tree().create_timer(0.12).timeout
		
	terminal_label.modulate = Color("00ff99")
	await get_tree().create_timer(1.0).timeout
	
	# Nascondiamo il terminale
	terminal_label.visible = false
	
	# --- FASE 3: L'IMPATTO DEL LOGO ---
	# Effetto "Flash" istantaneo 
	logo_label.modulate = Color(2.5, 2.5, 2.5, 1.0) 
	
	# SUONO DI IMPATTO! (Il "BOOM" che accompagna il rimbalzo)
	if impact_sfx.stream: impact_sfx.play()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(logo_label, "modulate:a", 1.0, 0.1)
	tween.tween_property(logo_label, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Screen Shake
	var shake_tween = create_tween()
	var shake_intensity = 15.0
	for i in range(12):
		shake_tween.tween_property(logo_label, "position", Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity)), 0.04)
		shake_intensity *= 0.75 
	shake_tween.tween_property(logo_label, "position", Vector2.ZERO, 0.05)
	
	# Ripristina il colore normale gradualmente 
	var color_tween = create_tween()
	color_tween.tween_property(logo_label, "modulate", Color(1, 1, 1, 1), 1.5)
	
	# --- FASE 4: PAUSA DRAMMATICA E TRANSIZIONE ---
	await get_tree().create_timer(4.0).timeout
	go_to_next_scene()

# Funzione Helper: scrive il testo una lettera alla volta e suona la tastiera
func _type_text(text_to_type: String):
	for i in range(text_to_type.length()):
		terminal_label.text += text_to_type[i]
		
		# SUONO MACCHINA DA SCRIVERE (con variazione di pitch per renderlo naturale)
		if keyboard_sfx.stream:
			keyboard_sfx.pitch_scale = randf_range(0.9, 1.1)
			keyboard_sfx.play()
			
		await get_tree().create_timer(0.05).timeout

func go_to_next_scene():
	if is_transitioning: return
	is_transitioning = true
	
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.8)
	await fade_out.finished
	
	get_tree().change_scene_to_file(NEXT_SCENE)
