extends Node2D

@export var level_title := "ACT I: THE ILLUSION"

# Riferimenti alla UI
@onready var fade_rect = $CinematicUI/FadeRect
@onready var title_label = $CinematicUI/TitleLabel

func _ready() -> void:
	# 1. SETUP INIZIALE
	if title_label: title_label.modulate.a = 0.0
	if fade_rect: fade_rect.modulate.a = 1.0 
	
	# 2. CONTROLLO SÉCURISÉ : Veniamo dall'Intro Testuale?
	if SaveManager.has_meta("intro_sequence") and SaveManager.get_meta("intro_sequence") == true:
		SaveManager.set_meta("intro_sequence", false) # On consomme le flag
		start_cinematic_wake_up()
	else:
		# Lancement sans intro (ex: respawn)
		if fade_rect: fade_rect.queue_free()
		if title_label: title_label.queue_free()
		# On attend la fin de la frame pour être sûr que le joueur est bien apparu
		call_deferred("_enable_player_movement")

func _enable_player_movement():
	var main = get_tree().current_scene
	if main and main.has_node("Player"):
		main.get_node("Player").can_move = true

func start_cinematic_wake_up():
	await get_tree().process_frame
	
	# BEAUCOUP PLUS SÛR : on prend la scène actuelle au lieu de chercher le mot "Main"
	var main = get_tree().current_scene 
	
	if not main or not main.has_node("Player"): 
		print("ERREUR : Impossible de trouver le Player pour la cinématique.")
		return
	
	var player = main.get_node("Player")
	
	# --- FASE 1: BLOCCO E RISVEGLIO ---
	player.can_move = false
	player.velocity = Vector2.ZERO
	player.play_anim("idle") 
	
	var t = create_tween()
	
	# --- FASE 2: FADE IN ---
	if fade_rect:
		t.tween_property(fade_rect, "modulate:a", 0.0, 3.0)
	
	t.tween_interval(1.5)
	
	# --- FASE 3: TITLE DROP ---
	if title_label:
		title_label.text = "[center]" + level_title + "[/center]"
		t.tween_property(title_label, "modulate:a", 1.0, 2.0)
		t.tween_interval(3.0)
		t.tween_property(title_label, "modulate:a", 0.0, 2.0)
	
	# --- FASE 4: LIBERTÀ ---
	await t.finished
	
	player.can_move = true
	
	if "intro_played" in main:
		main.intro_played = true
	
	if fade_rect: fade_rect.queue_free()
	if title_label: title_label.queue_free()
	
	SaveManager.save_game(SaveManager.current_slot_id, {
		"current_level": main.current_level_path,
		"intro_played": true,
		"grapple_unlocked": player.grapple_unlocked,
		"dash_unlocked": player.dash_unlocked
	})
