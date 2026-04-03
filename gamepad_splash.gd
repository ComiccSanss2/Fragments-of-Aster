extends Control

@onready var logo = $ControllerLogo
@onready var label = $CenterContainer/VBoxContainer/Label

# --- AUDIO NODES ---
@onready var whoosh_sfx = $WhooshPad
@onready var impact_sfx = $ImpactPad
@onready var confirm_sfx = $ConfirmationPad

const MAIN_MENU_PATH = "res://main_menu.tscn"

var is_transitioning := false

func _ready():
	# 1. Setup Iniziale
	modulate.a = 1.0 
	label.modulate.a = 0.0 
	
	# ==========================================================
	# FIX PIVOT POINT: Centriamo il perno per le animazioni
	# ==========================================================
	# Diciamo al logo di usare la sua dimensione per calcolare il centro
	# Nota: Assicurati che nell'editor il TextureRect abbia una dimensione (Size) definita.
	logo.pivot_offset = logo.size / 2
	# ==========================================================
	
	# Salviamo l'intera posizione (sia X che Y) per evitare che si teletrasporti a sinistra!
	var final_pos = logo.position
	logo.position.y -= 800 # Teletrasportiamo il controller molto in alto
	
	animate_gamepad(final_pos)

func animate_gamepad(final_pos: Vector2):
	# --- FASE 1: LA CADUTA ---
	if whoosh_sfx: whoosh_sfx.play()
	
	var drop_tween = create_tween()
	drop_tween.tween_property(logo, "position:y", final_pos.y, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	await drop_tween.finished
	
	# --- FASE 2: L'IMPATTO SECCO (Libri) ---
	if impact_sfx: impact_sfx.play()
	
	# Creiamo l'effetto "peso": il logo si schiaccia per l'impatto e fa un micro-balzo
	# Ora che il pivot è al centro, si schiaccerà uniformemente verso l'interno!
	var impact_tween = create_tween().set_parallel(true)
	impact_tween.tween_property(logo, "scale", Vector2(1.3, 0.7), 0.05) 
	impact_tween.tween_property(logo, "position:y", final_pos.y - 15, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Mini screen shake sulla X originale (evita di sbatterlo a sinistra)
	var shake_tween = create_tween()
	for i in range(4):
		shake_tween.tween_property(logo, "position:x", final_pos.x + randf_range(-10, 10), 0.03)
	shake_tween.tween_property(logo, "position:x", final_pos.x, 0.03)
	
	await get_tree().create_timer(0.1).timeout
	
	# Torna alla forma e posizione originale
	var settle_tween = create_tween().set_parallel(true)
	settle_tween.tween_property(logo, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	settle_tween.tween_property(logo, "position:y", final_pos.y, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# --- FASE 3: CONFERMA E TESTO ---
	await get_tree().create_timer(0.5).timeout
	
	if confirm_sfx: confirm_sfx.play()
	
	# ANIMAZIONE DI CONFERMA SUL POSTO: un "Pop" (si allarga e torna normale fluidamente dal centro)
	var pop_tween = create_tween()
	pop_tween.tween_property(logo, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(logo, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Il testo "Gamepad Recommended" appare dolcemente in contemporanea
	var text_tween = create_tween()
	text_tween.tween_property(label, "modulate:a", 1.0, 0.5)
	
	# --- FASE 4: ATTESA E TRANSIZIONE AL MENU ---
	await get_tree().create_timer(3.5).timeout
	_transition_to_menu()

func _input(event):
	# Skip della schermata se l'utente preme un tasto
	if event.is_pressed() and not event is InputEventMouseMotion:
		_transition_to_menu()

func _transition_to_menu():
	if is_transitioning: return
	is_transitioning = true
	
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.5)
	await fade_out.finished
	
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
