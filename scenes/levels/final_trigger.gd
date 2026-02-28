extends Area2D

# --- RÉFÉRENCES ---
@onready var fade_overlay = $"../CanvasLayer/FadeOverlay" 
@onready var architect = $"../Architect" 

# --- RÉGLAGES DU RÉALISATEUR ---
@export var cinematic_jump_velocity := Vector2(500.0, -600.0) # Ajuste ça pour qu'elle atteigne le boss depuis la plateforme
@export var cinematic_gravity := 1200.0 

@export var slow_mo_factor := 0.1 # Vitesse du ralenti
@export var camera_zoom_duration := 4.0 # Combien de temps la caméra met à zoomer
@export var end_zoom := 1.8 

# LE PLUS IMPORTANT : LE TIMING DU CUT (en secondes réelles, ajusté au ralenti)
# Si time_scale est à 0.1, 3 secondes de jeu prendront beaucoup plus de temps en vrai.
# Mais avec ce timer spécifique, tu choisis quand ça coupe.
@export var time_before_cut := 2.5 

var is_cinematic_started = false
var cinematic_player: CharacterBody2D = null
var current_sim_velocity := Vector2.ZERO

func _ready():
	set_physics_process(false) 
	if fade_overlay:
		fade_overlay.modulate.a = 0.0
		fade_overlay.visible = true

func _on_body_entered(body):
	if body.is_in_group("player") and not is_cinematic_started:
		is_cinematic_started = true
		start_final_sequence(body)

func _physics_process(delta):
	if cinematic_player:
		current_sim_velocity.y += cinematic_gravity * delta
		cinematic_player.global_position += current_sim_velocity * delta

func start_final_sequence(player):
	var main = get_tree().root.get_node_or_null("Main")
	var camera = main.camera if main else null
	
	if main and main.has_method("play_final_cinematic_music"):
		main.play_final_cinematic_music()
	
	var glitch_wall = get_tree().get_first_node_in_group("glitch_wall")
	if glitch_wall: glitch_wall.set_physics_process(false)
	
	# 1. On coupe les commandes et on force la pose de saut
	if player.has_method("prepare_cinematic"):
		player.prepare_cinematic()
	
	# 2. On fige le temps brutalement
	Engine.time_scale = 0.02 
	var timer = get_tree().create_timer(0.15, true, false, true)
	await timer.timeout
	
	# 3. On éjecte Lyra (c'est nous qui choisissons la trajectoire !)
	cinematic_player = player
	current_sim_velocity = cinematic_jump_velocity
	set_physics_process(true) 
	
	if camera: camera.is_locked = true 

	# 4. Le mouvement de caméra et le retour du temps (ralenti)
	var t = create_tween().set_parallel(true)
	t.tween_property(Engine, "time_scale", slow_mo_factor, camera_zoom_duration * 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if camera:
		t.tween_property(camera, "zoom", Vector2(end_zoom, end_zoom), camera_zoom_duration).set_trans(Tween.TRANS_SINE)
		t.tween_method(update_camera_pos.bind(camera), 0.0, 1.0, camera_zoom_duration)

	# --- 5. LE CUT ---
	# C'est ici que tu décides quand l'écran devient noir !
	# Ce timer est indépendant des animations.
	var cut_timer = get_tree().create_timer(time_before_cut, false, false, true)
	cut_timer.timeout.connect(cut_to_black)

func update_camera_pos(_weight: float, cam: Camera2D):
	if cinematic_player and architect:
		cam.global_position = (cinematic_player.global_position + architect.global_position) / 2.0

func cut_to_black():
	set_physics_process(false)
	
	# On appelle le Main IMMÉDIATEMENT, sans aucun "await"
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.has_method("show_outro_screen"):
		main.show_outro_screen()
