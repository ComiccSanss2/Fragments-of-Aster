extends CharacterBody2D

# ------------------------------------------------------------
# CONFIGURATION ET CONSTANTES
# ------------------------------------------------------------
const SPEED = 120.0
const GRAVITY = 800.0

# --- FEELING ---
const ACCELERATION = 15.0 
const FRICTION = 10.0     
const SQUASH_SPEED = 15.0 

# Saut
const JUMP_FORCE = -300.0
const JUMP_HOLD_FORCE = -250.0
const MAX_JUMP_HOLD_TIME = 0.18

# Wall
const WALL_GRAB_DURATION = 8.0
const WALL_CLIMB_SPEED = 80.0
const WALL_SLIDE_SPEED = 40.0
const WALL_JUMP_H = 280.0
const WALL_JUMP_V = -220.0
const WALL_COYOTE_TIME := 0.12

# Timers
const COYOTE_TIME = 0.12
const JUMP_BUFFER_TIME = 0.12

# Grappin
var grapple_speed := 500.0

# Dash
const DASH_SPEED = 400.0
const DASH_DURATION = 0.2
const DASH_ADJUST_WINDOW = 0.08 
var dash_ghost_scene = preload("res://dash_ghost.tscn")

# ------------------------------------------------------------
# VARIABLES D'ÉTAT
# ------------------------------------------------------------
var jump_held_time = 0.0
var is_jump_held = false

var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var wall_coyote_timer := 0.0

var wall_grab_time_left = WALL_GRAB_DURATION
var wall_grabbing = false
var wall_exhausted = false

var grappling := false
var grapple_target: Area2D = null
var grapple_unlocked: bool = false
var grapple_launch_timer := 0.0
var grapple_direction := Vector2.ZERO

# Dash Etat
var dash_unlocked: bool = false
var is_dashing: bool = false
var can_dash: bool = false
var dash_timer: float = 0.0
var dash_ghost_timer: float = 0.0
var dash_adjust_timer: float = 0.0

# Visuals
var was_on_floor: bool = false
var default_scale := Vector2(1, 1) 

var facing_dir := 1
var can_move := true
var is_dying := false

# ------------------------------------------------------------
# NOEUDS
# ------------------------------------------------------------
@onready var sprite = $AnimatedSprite2D
@onready var grapple_line = $GrappleLine
@onready var popup = $EchoText
@onready var jump_sfx = $JumpSFX
@onready var anim_player = get_node_or_null("AnimationPlayer")

func _ready():
	# --- CAPTURE DE LA TAILLE INITIALE ---
	default_scale = sprite.scale 
	# -------------------------------------
	
	grapple_line.visible = false
	grapple_line.points = [Vector2.ZERO, Vector2.ZERO]
	velocity = Vector2.ZERO
	play_anim("idle")
	if has_node("AnimationPlayer") and anim_player.has_animation("spawn"):
		start_respawn_sequence()

func _physics_process(delta):
	# 1. Mort / Cinématique
	if is_dying or not can_move:
		velocity = Vector2.ZERO
		if not is_dying: play_anim("idle")
		move_and_slide()
		return

	# --- LOGIQUE DASH (Prioritaire) ---
	if is_dashing:
		dash_timer -= delta
		dash_ghost_timer -= delta
		
		if dash_adjust_timer > 0:
			dash_adjust_timer -= delta
			update_dash_direction()
		
		if dash_ghost_timer <= 0:
			spawn_dash_ghost()
			dash_ghost_timer = 0.03
		
		if dash_timer <= 0:
			end_dash()
		
		move_and_slide()
		return 
	# ----------------------------------

	# --- GESTION DU JUICE (SQUASH & STRETCH) ---
	# Retour progressif à l'échelle PAR DÉFAUT (et non pas 1,1)
	sprite.scale = sprite.scale.lerp(default_scale, delta * SQUASH_SPEED)
	
	# Détection atterrissage "Boing"
	if not was_on_floor and is_on_floor():
		# On écrase par rapport à la taille de base
		sprite.scale = Vector2(default_scale.x * 1.5, default_scale.y * 0.7)
		spawn_dust()
	
	was_on_floor = is_on_floor()
	# -------------------------------------------

	# 2. Inputs & Direction
	var input_dir = Input.get_axis("ui_left", "ui_right")
	if input_dir != 0:
		facing_dir = input_dir
		sprite.flip_h = facing_dir < 0

	# 3. Grappin
	if grapple_unlocked and Input.is_action_just_pressed("grapple") and not grappling and grapple_launch_timer <= 0:
		grapple_target = find_grapple_point()
		if grapple_target:
			grappling = true
			wall_grabbing = false
			grapple_direction = (grapple_target.global_position - global_position).normalized()
			grapple_line.visible = true
			grapple_line.points = [Vector2.ZERO, Vector2.ZERO]

	if grappling and grapple_target:
		handle_grapple(delta)
		play_anim("jump")
		move_and_slide()
		return

	if grapple_launch_timer > 0:
		grapple_launch_timer -= delta
		velocity.y += GRAVITY * (0.12 if grapple_launch_timer > 0.05 else 0.6) * delta
		play_air_anim()
		move_and_slide()
		return

	# 4. Physique (Gravité)
	if not wall_grabbing and not is_on_floor():
		velocity.y += GRAVITY * delta

	# Timers
	if Input.is_action_just_pressed("ui_accept"): jump_buffer_timer = JUMP_BUFFER_TIME
	if jump_buffer_timer > 0: jump_buffer_timer -= delta
	
	if is_on_floor(): coyote_timer = COYOTE_TIME
	else: coyote_timer -= delta

	# --- MOUVEMENT FLUIDE (ACCEL/FRICTION) ---
	var target_speed = input_dir * SPEED
	if input_dir != 0:
		velocity.x = lerp(velocity.x, target_speed, delta * ACCELERATION)
	else:
		velocity.x = lerp(velocity.x, 0.0, delta * FRICTION)
	# -----------------------------------------

	# --- GESTION DU DASH ---
	if is_on_floor() or is_on_wall():
		can_dash = true
		
	if dash_unlocked and Input.is_action_just_pressed("dash") and can_dash:
		start_dash()
	# -----------------------

	# Actions
	handle_jump(delta)
	handle_wall_grab(delta)
	handle_wall_jump()

	update_animation(input_dir)
	move_and_slide()

# ------------------------------------------------------------
# FONCTIONS DASH
# ------------------------------------------------------------
func start_dash():
	is_dashing = true
	can_dash = false 
	dash_timer = DASH_DURATION
	
	dash_adjust_timer = DASH_ADJUST_WINDOW
	
	wall_grabbing = false 
	update_dash_direction()
	
	# Effet visuel : Étirement horizontal (Multiplicateur)
	sprite.scale = Vector2(default_scale.x * 1.4, default_scale.y * 0.6)
	
	if jump_sfx:
		jump_sfx.pitch_scale = 1.5
		jump_sfx.play()

func update_dash_direction():
	var dir_vec = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir_vec == Vector2.ZERO:
		velocity = Vector2(facing_dir * DASH_SPEED, 0)
	else:
		velocity = dir_vec.normalized() * DASH_SPEED

func end_dash():
	is_dashing = false
	velocity *= 0.5 

func spawn_dash_ghost():
	var ghost = dash_ghost_scene.instantiate()
	get_parent().add_child(ghost)
	ghost.global_position = global_position
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.flip_h = sprite.flip_h
	ghost.scale = sprite.scale

# ------------------------------------------------------------
# SAUT & WALL & GRAPPIN
# ------------------------------------------------------------
func handle_jump(delta):
	if jump_buffer_timer > 0 and coyote_timer > 0 and not wall_grabbing:
		velocity.y = JUMP_FORCE
		
		# Effet visuel : Étirement vertical (Multiplicateur)
		sprite.scale = Vector2(default_scale.x * 0.6, default_scale.y * 1.4)
		
		if jump_sfx:
			jump_sfx.pitch_scale = randf_range(0.9, 1.1)
			jump_sfx.play()
		is_jump_held = true
		jump_held_time = 0.0
		jump_buffer_timer = 0
		coyote_timer = 0
	
	if is_jump_held:
		if Input.is_action_pressed("ui_accept") and jump_held_time < MAX_JUMP_HOLD_TIME:
			velocity.y += JUMP_HOLD_FORCE * delta
			jump_held_time += delta
		else:
			is_jump_held = false

	if Input.is_action_just_released("ui_accept") and velocity.y < 0:
		velocity.y *= 0.45
		is_jump_held = false

func handle_wall_grab(delta):
	var grabbing_button = Input.is_action_pressed("grab")
	var on_wall = is_on_wall() and not is_on_floor()

	if on_wall: wall_coyote_timer = WALL_COYOTE_TIME
	else: wall_coyote_timer -= delta

	if is_on_floor():
		wall_grab_time_left = WALL_GRAB_DURATION
		wall_exhausted = false

	if on_wall and grabbing_button and not wall_exhausted:
		wall_grabbing = true
		wall_grab_time_left -= delta
		if wall_grab_time_left <= 0:
			wall_exhausted = true
			wall_grabbing = false
			return
		velocity.y = 0
		if Input.is_action_pressed("ui_up"): velocity.y = -WALL_CLIMB_SPEED
		elif Input.is_action_pressed("ui_down"): velocity.y = WALL_CLIMB_SPEED
	else:
		wall_grabbing = false
		if wall_exhausted and on_wall: velocity.y = WALL_SLIDE_SPEED

func handle_wall_jump():
	var grabbing_button = Input.is_action_pressed("grab")
	
	if wall_coyote_timer > 0.0 and grabbing_button and not wall_exhausted and Input.is_action_just_pressed("ui_accept"):
		wall_grabbing = false
		jump_buffer_timer = 0
		
		# Effet visuel
		sprite.scale = Vector2(default_scale.x * 0.6, default_scale.y * 1.4)
		
		if jump_sfx:
			jump_sfx.pitch_scale = randf_range(1.1, 1.3)
			jump_sfx.play()
		
		if is_on_wall_left(): velocity.x = WALL_JUMP_H
		elif is_on_wall_right(): velocity.x = -WALL_JUMP_H
		velocity.y = WALL_JUMP_V

# FONCTIONS UTILITAIRES
func is_on_wall_left() -> bool:
	return is_on_wall() and get_wall_normal().x > 0

func is_on_wall_right() -> bool:
	return is_on_wall() and get_wall_normal().x < 0

func find_grapple_point() -> Area2D:
	var best_point: Area2D = null
	var best_dist: float = INF
	for p in get_tree().get_nodes_in_group("grapple_points"):
		var dist = global_position.distance_to(p.global_position)
		if dist < p.min_distance or dist > p.max_distance: continue
		if dist < best_dist:
			best_dist = dist
			best_point = p
	return best_point

func handle_grapple(delta):
	collision_layer = 0
	collision_mask = 0
	velocity = grapple_direction * grapple_speed
	grapple_line.points = [Vector2.ZERO, grapple_target.global_position - global_position]
	if global_position.distance_to(grapple_target.global_position) < 12: finish_grapple()

func finish_grapple():
	grappling = false
	collision_layer = 1
	collision_mask = 1
	velocity.x = facing_dir * 320
	velocity.y = -280
	grapple_launch_timer = 0.25
	grapple_target = null
	grapple_line.visible = false
	grapple_line.points = []
	can_dash = true 

func die():
	if is_dying: return
	is_dying = true
	can_move = false
	velocity = Vector2.ZERO
	if anim_player and anim_player.has_animation("death"): anim_player.play("death")
	var main = get_tree().root.get_node("Main")
	if main and main.has_method("play_death_sequence"): main.play_death_sequence()
	else: get_tree().reload_current_scene()

func start_respawn_sequence():
	can_move = false
	is_dying = false
	velocity = Vector2.ZERO
	play_anim("idle")
	sprite.visible = true
	if anim_player and anim_player.has_animation("spawn"):
		anim_player.play("spawn")
		await anim_player.animation_finished
	can_move = true

func play_anim(name: String):
	# On évite de relancer l'animation si elle joue déjà
	if sprite.animation != name:
		sprite.play(name)

func play_air_anim():
	if velocity.y < 0:
		play_anim("jump-fall") # On monte


func update_animation(input_dir):
	# Priorité 1 : En l'air
	if not is_on_floor():
		play_air_anim()
		return
	
	# Priorité 2 : Au sol
	if input_dir != 0:
		play_anim("walk")
	else:
		play_anim("idle")

func spawn_dust():
	var dust_scene = load("res://scenes/cpu_particles_2d.tscn")
	var d = dust_scene.instantiate()
	d.global_position = global_position
	get_tree().current_scene.add_child(d)

func show_popup(msg: String):
	popup.text = msg
	popup.visible = true
	popup.modulate.a = 0.0
	popup.scale = Vector2(0.8, 0.8)
	var t = create_tween()
	t.tween_property(popup, "modulate:a", 1.0, 0.25)
	t.tween_property(popup, "scale", Vector2(1,1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_popup():
	if popup.visible:
		var t = create_tween()
		t.tween_property(popup, "modulate:a", 0.0, 0.25)
		await t.finished
	popup.visible = false
