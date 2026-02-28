extends Area2D

# --- RÉFÉRENCES ---
@onready var fade_overlay = $"../CanvasLayer/FadeOverlay" 
@onready var architect = $"../Architect" 

# Le Point B que Lyra doit atteindre dans les airs
@export var jump_target: Node2D 

@export var slow_mo_factor := 0.1
@export var cinematic_duration := 4.0
@export var end_zoom := 1.8

var is_cinematic_started = false

func _ready():
	if fade_overlay:
		fade_overlay.modulate.a = 0.0
		fade_overlay.visible = true

func _on_body_entered(body):
	if body.is_in_group("player") and not is_cinematic_started:
		is_cinematic_started = true
		start_final_sequence(body)

func start_final_sequence(player):
	# 1. RÉCUPÉRER LA CAMÉRA VIA LE MAIN
	var main = get_tree().root.get_node_or_null("Main")
	var camera = main.camera if main else null
	
	# --- NOUVEAU : LANCER LA MUSIQUE ÉPIQUE ---
	if main and main.has_method("play_final_cinematic_music"):
		main.play_final_cinematic_music()
	
	# 2. DÉSACTIVER LES MENACES ET LES CONTRÔLES
	var glitch_wall = get_tree().get_first_node_in_group("glitch_wall")
	if glitch_wall: glitch_wall.set_physics_process(false)
	
	# 3. PRÉPARER LYRA (Reset Visuel & Physique via player.gd)
	if player.has_method("prepare_cinematic"):
		player.prepare_cinematic()

	# 4. VERROUILLER LA CAMÉRA
	if camera:
		camera.is_locked = true 

	# 5. ORCHESTRER LE RALENTI ET LE SAUT
	var t = create_tween().set_parallel(true)
	
	# Le temps ralentit
	t.tween_property(Engine, "time_scale", slow_mo_factor, cinematic_duration * 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# LE SAUT SCRIPTÉ (POINT A VERS POINT B)
	if jump_target:
		t.tween_property(player, "global_position", jump_target.global_position, cinematic_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if camera:
		# La caméra zoom sur l'action
		t.tween_property(camera, "zoom", Vector2(end_zoom, end_zoom), cinematic_duration).set_trans(Tween.TRANS_SINE)
		
		# La caméra se décale pour encadrer le Point B et l'Architecte
		var target_camera_pos = (jump_target.global_position + architect.global_position) / 2.0 if jump_target else (player.global_position + architect.global_position) / 2.0
		t.tween_property(camera, "global_position", target_camera_pos, cinematic_duration).set_trans(Tween.TRANS_SINE)

	# 6. LE CUT FINAL
	t.chain().tween_callback(cut_to_black)

func cut_to_black():
	if fade_overlay:
		fade_overlay.modulate.a = 1.0
	
	# Coupure du son net
	AudioServer.set_bus_mute(0, true) 
	
	# On remet le temps normal !
	Engine.time_scale = 1.0
	
	# Petit délai dans le noir pour laisser le joueur en panique
	await get_tree().create_timer(1.5).timeout
	
	# Transition vers la nouvelle scène !
	get_tree().change_scene_to_file("res://scenes/ui/end_demo_screen.tscn")
