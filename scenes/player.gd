extends CharacterBody2D

# ------------------------------------------------------------
# CONFIGURATION ET CONSTANTES (VERSION 32x32)
# ------------------------------------------------------------
const SPEED = 170.0
const GRAVITY = 1200.0
# --- FEELING (VISUEL UNIQUEMENT) ---
const SQUASH_SPEED = 15.0

# Saut
const JUMP_FORCE = -400.0
const JUMP_HOLD_FORCE = -300.0
const MAX_JUMP_HOLD_TIME = 0.18

# Wall
const WALL_GRAB_DURATION = 8.0
const WALL_CLIMB_SPEED = 110.0
const WALL_SLIDE_SPEED = 70.0
const WALL_JUMP_H = 480.0
const WALL_JUMP_V = -400.0
const WALL_COYOTE_TIME := 0.12

# Timers
const COYOTE_TIME = 0.12
const JUMP_BUFFER_TIME = 0.12

# Grappin
var grapple_speed := 900.0

# Dash
const DASH_SPEED = 700.0
const DASH_DURATION = 0.2
const DASH_ADJUST_WINDOW = 0.08
var dash_ghost_scene = preload("res://dash_ghost.tscn")

# ------------------------------------------------------------
# VARIABLES D'ÉTAT
# ------------------------------------------------------------
var jump_held_time = 0.0
var is_jump_held = false
var current_hack_target: Area2D = null

var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var wall_coyote_timer := 0.0

var wall_grab_time_left = WALL_GRAB_DURATION
var wall_grabbing = false
var was_wall_grabbing = false 
var wall_exhausted = false

var grappling := false
var grapple_target: Area2D = null
var grapple_unlocked: bool = false
var grapple_launch_timer := 0.0
var grapple_direction := Vector2.ZERO

# État du zoom de la caméra
var is_grapple_zoomed_out := false

# Pour gérer proprement les tweens de distorsion
var active_distortion_tween: Tween = null

# Dash Etat
var dash_unlocked: bool = false
var is_dashing: bool = false
var can_dash: bool = false
var dash_timer: float = 0.0
var dash_ghost_timer: float = 0.0
var dash_adjust_timer: float = 0.0

# --- GRAVITÉ ---
var gravity_unlocked: bool = false
var gravity_dir: int = 1 # 1 = Normal (Bas), -1 = Inversé (Haut)
var gravity_cooldown: float = 0.0
var can_invert_gravity: bool = true 

# --- HACKING ---
var is_hacking: bool = false # Gardé pour compatibilité avec reset_from_cinematic
var can_hack_in_zone: bool = false # <--- ATTIVATA DALLA ZONA

# Visuals
var was_on_floor: bool = true
var default_scale := Vector2(1, 1)

var facing_dir := 1
var can_move := true
var is_dying := false

# Mémorisation du HandCheck
var default_hand_check_y := 0.0

# ------------------------------------------------------------
# NOEUDS
# ------------------------------------------------------------
@onready var sprite = $AnimatedSprite2D
@onready var grapple_line = $GrappleLine
@onready var popup = $EchoText
@onready var jump_sfx = $JumpSFX

# --- NOEUDS AUDIO ---
@onready var hit_sfx = get_node_or_null("HitSFX")
@onready var decay_sfx = get_node_or_null("DecaySFX")
@onready var grapple_sfx = get_node_or_null("GrappleSFX")
@onready var hack_sfx = get_node_or_null("HackSFX")

@onready var anim_player = get_node_or_null("AnimationPlayer")
@onready var hand_check = get_node_or_null("HandCheck")

# --- NOEUDS HACKING ---
@onready var hack_aura = get_node_or_null("HackAura")

# --- FX ---
@onready var grapple_trail = get_node_or_null("GrappleTrail")
@onready var gravity_distortion = get_node_or_null("GravityDistortion")

func _ready():
	default_scale = sprite.scale
	was_on_floor = true 
	
	if hand_check:
		default_hand_check_y = hand_check.position.y
	
	if gravity_distortion and gravity_distortion.material:
		gravity_distortion.material.set_shader_parameter("strength", 0.0)
	
	grapple_line.visible = false
	grapple_line.points = [Vector2.ZERO, Vector2.ZERO]
	velocity = Vector2.ZERO
	play_anim("idle")
	
	up_direction = Vector2.UP
	gravity_dir = 1
	
	if has_node("AnimationPlayer") and anim_player.has_animation("spawn"):
		start_respawn_sequence()
		
	if hack_aura:
		hack_aura.area_exited.connect(_on_hack_aura_exited)	

# ------------------------------------------------------------
# PROCESS
# ------------------------------------------------------------
func _process(delta):
	if is_dashing:
		dash_ghost_timer -= delta
		if dash_ghost_timer <= 0:
			spawn_dash_ghost()
			dash_ghost_timer = 0.03

# ------------------------------------------------------------
# PHYSICS PROCESS
# ------------------------------------------------------------
func _physics_process(delta):
	# ---> AGGIUNGI QUESTA RIGA QUI <---
	var main = get_tree().root.get_node_or_null("Main")

	if is_dying or not can_move:
		if has_node("RunParticles"): $RunParticles.emitting = false
		if has_node("WallGrabParticles"): $WallGrabParticles.emitting = false
		if has_node("WallClimbParticles"): $WallClimbParticles.emitting = false
			
		if is_dying: 
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		else:

			velocity.x = 0
			is_dashing = false
			grappling = false
			wall_grabbing = false
			sprite.scale = sprite.scale.lerp(default_scale, delta * SQUASH_SPEED * 2.0)
			
			if not is_on_floor():
				velocity.y += GRAVITY * gravity_dir * delta
				if gravity_dir == 1: velocity.y = min(velocity.y, 2000.0)
				else: velocity.y = max(velocity.y, -2000.0)
				play_air_anim()
			else:
				play_anim("idle")
		move_and_slide()
		return

# ========================================================
	# --- HACKING SYSTEM (SMART HIGHLIGHT & INSTANT HACK) ---
	# ========================================================
	
	# 1. Trova il bersaglio migliore ogni frame
	var new_target = get_best_hack_target()
	
	# 2. Aggiorna gli effetti visivi (Highlight) se il bersaglio cambia
	if current_hack_target != new_target:
		if current_hack_target and current_hack_target.has_method("set_highlight"):
			current_hack_target.set_highlight(false) # Spegni il vecchio
			
		current_hack_target = new_target
		
		if current_hack_target and current_hack_target.has_method("set_highlight"):
			current_hack_target.set_highlight(true) # Accendi il nuovo

	# 3. Attivazione
	if Input.is_action_just_pressed("hack") and current_hack_target:
		current_hack_target.trigger_hack()
		
		if hack_sfx: 
			hack_sfx.pitch_scale = randf_range(0.9, 1.1)
			hack_sfx.play()
			
		if main and main.has_method("trigger_shake"):
			main.trigger_shake(2.5) 
		
		if not is_on_floor():
			velocity.y = min(velocity.y, -150.0 * gravity_dir)
			
	# ========================================================
				


	# ========================================================

	# --- DASH EN COURS ---
	if is_dashing:
		dash_timer -= delta
		if dash_adjust_timer > 0:
			dash_adjust_timer -= delta
			update_dash_direction()
		if dash_timer <= 0:
			end_dash()
		move_and_slide()
		return

	# --- SQUASH & STRETCH ET ATTERRISSAGE ---
	sprite.scale = sprite.scale.lerp(default_scale, delta * SQUASH_SPEED)
	
	if not was_on_floor and is_on_floor():
		sprite.scale = Vector2(default_scale.x * 1.5, default_scale.y * 0.7)
		spawn_dust() 
		
		if is_grapple_zoomed_out:
			reset_camera_zoom()
			
		if gravity_distortion and gravity_distortion.material:
			var mat = gravity_distortion.material as ShaderMaterial
			var current_strength = mat.get_shader_parameter("strength")
			if current_strength != null and current_strength > 0.001:
				if active_distortion_tween: active_distortion_tween.kill()
				active_distortion_tween = create_tween()
				active_distortion_tween.tween_method(func(val): mat.set_shader_parameter("strength", val), current_strength, 0.0, 0.2).set_trans(Tween.TRANS_SINE)
		
	was_on_floor = is_on_floor()

	# --- INPUTS: FEELING DIGITAL PUR (JOYPAD = DPAD) ---
	var input_dir := 0
	if Input.is_action_pressed("ui_right"): input_dir += 1
	if Input.is_action_pressed("ui_left"): input_dir -= 1
	
	if input_dir != 0:
		facing_dir = input_dir
		sprite.flip_h = facing_dir < 0
		
		if hand_check:
			hand_check.target_position.x = facing_dir * 15.0

	# --- GRAPPIN ---
	if grapple_unlocked and Input.is_action_just_pressed("grapple") and not grappling and grapple_launch_timer <= 0:
		grapple_target = find_grapple_point()
		if grapple_target:
			grappling = true
			wall_grabbing = false
			grapple_direction = (grapple_target.global_position - global_position).normalized()
			grapple_line.visible = true
			grapple_line.points = [Vector2.ZERO, Vector2.ZERO]
			
			if grapple_trail: grapple_trail.emitting = true
			if grapple_sfx:
				grapple_sfx.pitch_scale = randf_range(0.9, 1.2)
				grapple_sfx.play()
				
			is_grapple_zoomed_out = true
			if main and main.camera:
				var t = create_tween()
				t.tween_property(main.camera, "zoom", main.DEFAULT_ZOOM * 0.90, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if grappling and grapple_target:
		handle_grapple(delta)
		play_anim("grapple")
		move_and_slide()
		return

	if grapple_launch_timer > 0:
		grapple_launch_timer -= delta
		velocity.y += GRAVITY * gravity_dir * (0.12 if grapple_launch_timer > 0.05 else 0.6) * delta
		play_air_anim()
		move_and_slide()
		return

	if not wall_grabbing and not is_on_floor():
		velocity.y += GRAVITY * gravity_dir * delta

	# --- TIMERS ---
	if Input.is_action_just_pressed("ui_accept"): jump_buffer_timer = JUMP_BUFFER_TIME
	if jump_buffer_timer > 0: jump_buffer_timer -= delta
	if is_on_floor(): coyote_timer = COYOTE_TIME
	else: coyote_timer -= delta

	# --- MOUVEMENT ---
	velocity.x = input_dir * SPEED

	if is_on_floor() or is_on_wall(): 
		can_dash = true
		can_invert_gravity = true
		
	if gravity_unlocked:
		if gravity_cooldown > 0: gravity_cooldown -= delta
		if Input.is_action_just_pressed("gravity") and gravity_cooldown <= 0 and can_invert_gravity:
			invert_gravity()
			can_invert_gravity = false 

	if dash_unlocked and Input.is_action_just_pressed("dash") and can_dash: 
		start_dash()
		move_and_slide()
		return 

	handle_jump(delta)
	handle_wall_grab(delta)
	handle_wall_jump()
	
	# =========================================================
	# GESTION DES PARTICULES CONTINUES (COURSE ET MURS)
	# =========================================================
	if has_node("RunParticles"):
		if is_on_floor() and abs(velocity.x) > 10.0:
			$RunParticles.emitting = true
			$RunParticles.position.y = 7 * gravity_dir
			var y_dir = -0.5 * gravity_dir 
			if facing_dir == 1: $RunParticles.direction = Vector2(-1, y_dir) 
			else: $RunParticles.direction = Vector2(1, y_dir)  
		else:
			$RunParticles.emitting = false

	if has_node("WallGrabParticles") and has_node("WallClimbParticles"):
		if is_on_wall() and not is_on_floor():
			var wall_side = -1 if is_on_wall_left() else 1
			var pos_x = 5.5 * wall_side
			
			$WallGrabParticles.position = Vector2(pos_x, 0)
			$WallClimbParticles.position = Vector2(pos_x, 0)

			if wall_grabbing and abs(velocity.y) < 10.0:
				$WallGrabParticles.emitting = true
				$WallClimbParticles.emitting = false
			else:
				$WallGrabParticles.emitting = false
				if abs(velocity.y) > 10.0:
					$WallClimbParticles.emitting = true
					var y_dir = 1.0 if velocity.y < 0 else -1.0
					$WallClimbParticles.direction = Vector2(0, y_dir)
				else:
					$WallClimbParticles.emitting = false
		else:
			$WallGrabParticles.emitting = false
			$WallClimbParticles.emitting = false

	update_animation(input_dir)
	was_wall_grabbing = wall_grabbing
	move_and_slide()

# ------------------------------------------------------------
# FONCTIONS ACTIONS
# ------------------------------------------------------------

func reset_camera_zoom():
	is_grapple_zoomed_out = false
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.camera:
		var t = create_tween()
		t.tween_property(main.camera, "zoom", main.DEFAULT_ZOOM, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func invert_gravity():
	gravity_dir *= -1
	gravity_cooldown = 0.5
	up_direction = Vector2.UP * gravity_dir
	sprite.flip_v = (gravity_dir == -1)
	sprite.scale = Vector2(default_scale.x * 0.5, default_scale.y * 1.5)
	if jump_sfx:
		jump_sfx.pitch_scale = 0.5
		jump_sfx.play()
		
	if hand_check:
		hand_check.position.y = default_hand_check_y * gravity_dir

	if gravity_distortion and gravity_distortion.material:
		var mat = gravity_distortion.material as ShaderMaterial
		if active_distortion_tween: active_distortion_tween.kill()
		active_distortion_tween = create_tween()
		active_distortion_tween.tween_method(func(val): mat.set_shader_parameter("strength", val), 0.0, 0.03, 0.2).set_trans(Tween.TRANS_SINE)

func start_dash():
	is_dashing = true
	can_dash = false
	dash_timer = DASH_DURATION
	dash_adjust_timer = DASH_ADJUST_WINDOW
	wall_grabbing = false
	update_dash_direction()
	sprite.scale = Vector2(default_scale.x * 1.4, default_scale.y * 0.6)
	if jump_sfx:
		jump_sfx.pitch_scale = 1.5
		jump_sfx.play()

	var main = get_tree().root.get_node_or_null("Main")
	if main:
		if main.has_method("trigger_shake"):
			main.trigger_shake(3.5) 
		
		if main.camera:
			var base_zoom = main.DEFAULT_ZOOM * 0.90 if is_grapple_zoomed_out else main.DEFAULT_ZOOM
			var punch_zoom = base_zoom * 1.020 
			var t = create_tween()
			t.tween_property(main.camera, "zoom", punch_zoom, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t.tween_property(main.camera, "zoom", base_zoom, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func update_dash_direction():
	# Forziamo il dash a 8 vie digitali, identico al D-Pad
	var dx = 0
	var dy = 0
	if Input.is_action_pressed("ui_right"): dx += 1
	if Input.is_action_pressed("ui_left"): dx -= 1
	if Input.is_action_pressed("ui_down"): dy += 1
	if Input.is_action_pressed("ui_up"): dy -= 1
	
	var dir_vec = Vector2(dx, dy)
	
	if dir_vec == Vector2.ZERO: 
		velocity = Vector2(facing_dir * DASH_SPEED, 0)
	else:
		dir_vec = dir_vec.normalized()
		var angle = snapped(dir_vec.angle(), PI / 4.0)
		velocity = Vector2(cos(angle), sin(angle)) * DASH_SPEED

func end_dash():
	is_dashing = false
	velocity *= 0.5

func spawn_dash_ghost():
	var ghost = dash_ghost_scene.instantiate()
	get_parent().add_child(ghost)
	ghost.global_position = global_position
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v
	ghost.scale = sprite.scale
	if ghost.has_method("reset_physics_interpolation"):
		ghost.reset_physics_interpolation()

func handle_jump(delta):
	if jump_buffer_timer > 0 and coyote_timer > 0 and not wall_grabbing:
		velocity.y = JUMP_FORCE * gravity_dir
		sprite.scale = Vector2(default_scale.x * 0.6, default_scale.y * 1.4)
		spawn_dust()
		
		if jump_sfx:
			jump_sfx.pitch_scale = randf_range(0.9, 1.1)
			jump_sfx.play()
		is_jump_held = true
		jump_held_time = 0.0
		jump_buffer_timer = 0
		coyote_timer = 0
	
	if is_jump_held:
		if Input.is_action_pressed("ui_accept") and jump_held_time < MAX_JUMP_HOLD_TIME:
			velocity.y += JUMP_HOLD_FORCE * gravity_dir * delta
			jump_held_time += delta
		else:
			is_jump_held = false

	if Input.is_action_just_released("ui_accept"):
		if (gravity_dir == 1 and velocity.y < 0) or (gravity_dir == -1 and velocity.y > 0):
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
		
		# ==========================================================
		# FIX DEL FLICKERING SUL MURO
		# ==========================================================
		var wall_normal_x = get_wall_normal().x
		var input_x := 0
		if Input.is_action_pressed("ui_right"): input_x += 1
		if Input.is_action_pressed("ui_left"): input_x -= 1
		
		if input_x == 0 or sign(input_x) == sign(-wall_normal_x):
			velocity.x = -wall_normal_x * 10.0 
		# ==========================================================
		
		if not was_wall_grabbing:
			var main = get_tree().root.get_node_or_null("Main")
			if main:
				if main.has_method("trigger_shake"):
					main.trigger_shake(2.5) 
				
				if main.camera and not is_grapple_zoomed_out:
					var base_zoom = main.DEFAULT_ZOOM
					var punch_zoom = base_zoom * 1.025
					var t = create_tween()
					t.tween_property(main.camera, "zoom", punch_zoom, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					t.tween_property(main.camera, "zoom", base_zoom, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			
			sprite.scale = Vector2(default_scale.x * 0.6, default_scale.y * 1.4)
		
		if is_grapple_zoomed_out:
			reset_camera_zoom()
		
		wall_grab_time_left -= delta
		if wall_grab_time_left <= 0:
			wall_exhausted = true
			wall_grabbing = false
			return
		
		velocity.y = 0
		
		if Input.is_action_pressed("ui_up"):
			if hand_check and not hand_check.is_colliding():
				velocity.y = 0 
			else:
				velocity.y = -WALL_CLIMB_SPEED * gravity_dir
		elif Input.is_action_pressed("ui_down"):
			velocity.y = WALL_CLIMB_SPEED * gravity_dir
	else:
		wall_grabbing = false
		if wall_exhausted and on_wall: 
			velocity.y = WALL_SLIDE_SPEED * gravity_dir

func handle_wall_jump():
	var grabbing_button = Input.is_action_pressed("grab")
	if wall_coyote_timer > 0.0 and grabbing_button and not wall_exhausted and Input.is_action_just_pressed("ui_accept"):
		wall_grabbing = false
		jump_buffer_timer = 0
		sprite.scale = Vector2(default_scale.x * 0.6, default_scale.y * 1.4)
		if jump_sfx:
			jump_sfx.pitch_scale = randf_range(1.1, 1.3)
			jump_sfx.play()
		if is_on_wall_left(): velocity.x = WALL_JUMP_H
		elif is_on_wall_right(): velocity.x = -WALL_JUMP_H
		
		velocity.y = WALL_JUMP_V * gravity_dir

# ------------------------------------------------------------
# UTILITAIRES
# ------------------------------------------------------------
func is_on_wall_left() -> bool: return is_on_wall() and get_wall_normal().x > 0
func is_on_wall_right() -> bool: return is_on_wall() and get_wall_normal().x < 0

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
	if global_position.distance_to(grapple_target.global_position) < 24: finish_grapple()

func finish_grapple():
	grappling = false
	collision_layer = 1
	collision_mask = 1
	velocity.x = facing_dir * 640
	velocity.y = -560 * gravity_dir
	grapple_launch_timer = 0.25
	grapple_target = null
	grapple_line.visible = false
	grapple_line.points = []
	can_dash = true
	can_invert_gravity = true 
	
	if grapple_trail: grapple_trail.emitting = false
	if grapple_sfx: grapple_sfx.stop()

func die(hazard_pos := Vector2.ZERO):
	if is_dying: return
	is_dying = true
	can_move = false
	wall_grabbing = false 
	
	if grapple_trail: grapple_trail.emitting = false
	if grapple_sfx: grapple_sfx.stop()
	if is_grapple_zoomed_out: reset_camera_zoom()
		
	if active_distortion_tween: active_distortion_tween.kill()
	if gravity_distortion and gravity_distortion.material:
		gravity_distortion.material.set_shader_parameter("strength", 0.0)
	
	sprite.scale = default_scale
	
	if hit_sfx:
		hit_sfx.pitch_scale = randf_range(0.9, 1.1)
		hit_sfx.play()
	if decay_sfx:
		decay_sfx.play()
	
	velocity.y = -170.0 * gravity_dir
	if hazard_pos != Vector2.ZERO:
		var dir = sign(global_position.x - hazard_pos.x)
		if dir == 0: dir = -facing_dir
		velocity.x = dir * 200.0
	else:
		velocity.x = -facing_dir * 200.0
		
	collision_mask = 0

	if anim_player and anim_player.has_animation("death"):
		anim_player.play("death")
		await anim_player.animation_finished
	elif sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout

	gravity_dir = 1
	up_direction = Vector2.UP
	sprite.flip_v = false
	gravity_cooldown = 0.0
	can_invert_gravity = true 
	if hand_check:
		hand_check.position.y = default_hand_check_y

	var main = get_tree().root.get_node_or_null("Main")
	if main and main.has_method("play_death_sequence"): 
		main.play_death_sequence()
	else: 
		get_tree().reload_current_scene()

func start_respawn_sequence():
	can_move = false
	is_dying = false
	velocity = Vector2.ZERO
	collision_mask = 1 
	
	sprite.scale = default_scale
	was_on_floor = true 
	
	play_anim("idle")
	sprite.visible = true
	
	gravity_dir = 1
	up_direction = Vector2.UP
	sprite.flip_v = false
	can_invert_gravity = true 
	
	if hand_check:
		hand_check.position.y = default_hand_check_y
		
	if active_distortion_tween: active_distortion_tween.kill()
	if gravity_distortion and gravity_distortion.material:
		gravity_distortion.material.set_shader_parameter("strength", 0.0)
		
	if anim_player and anim_player.has_animation("spawn"):
		anim_player.play("spawn")
		await anim_player.animation_finished
	can_move = true

func play_anim(name: String):
	if sprite.sprite_frames.has_animation(name):
		if sprite.animation != name: sprite.play(name)

func play_air_anim():
	if grappling: return
	
	if velocity.y * gravity_dir < 0:
		play_anim("jump")
	else:
		play_anim("fall")

func update_animation(input_dir):
	if wall_grabbing:
		if abs(velocity.y) > 0:
			play_anim("climb")
		else:
			play_anim("grab")
		return
		
	if not is_on_floor():
		play_air_anim()
		return
	
	if input_dir != 0: 
		play_anim("walk")
	else: 
		play_anim("idle")

func spawn_dust():
	if not can_move: return
	var dust_scene = load("res://cpu_particles_2d.tscn")
	var d = dust_scene.instantiate()
	d.global_position = global_position + Vector2(0, 16 * gravity_dir)
	if gravity_dir == -1: d.rotation = PI 
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
	
func prepare_cinematic():
	if "can_move" in self: can_move = false
	set_physics_process(false) 
	velocity = Vector2.ZERO 
	
	is_dying = true 
	collision_layer = 0
	collision_mask = 0
	
	var spr = get_node_or_null("Sprite2D")
	if not spr: spr = get_node_or_null("AnimatedSprite2D")
	
	if spr: 
		spr.scale = Vector2(0.5, 0.5) 
		spr.rotation = 0.0 
		
	if has_node("GhostTimer"): $GhostTimer.stop()
		
	for child in get_children():
		if child is CPUParticles2D or child is GPUParticles2D: child.emitting = false
			
	if has_node("AnimationPlayer"): $AnimationPlayer.play("jump")
	elif has_node("AnimatedSprite2D"): $AnimatedSprite2D.play("jump")

# ==========================================
# LA CURA DEFINITIVA E "HARDCORE"
# ==========================================
func reset_from_cinematic():
	print("PLAYER: Esecuzione reset_from_cinematic...")
	is_dying = false
	can_move = true
	grappling = false
	wall_grabbing = false
	is_dashing = false
	is_hacking = false
	
	set_physics_process(true)
	set_process(true)
	
	collision_layer = 1
	collision_mask = 1
	
	if has_node("AnimationPlayer"): 
		$AnimationPlayer.stop()
	
	var spr = get_node_or_null("Sprite2D")
	if not spr: spr = get_node_or_null("AnimatedSprite2D")
	if spr:
		spr.scale = default_scale
		spr.rotation = 0.0
		spr.visible = true
		spr.play("fall")
	
	velocity = Vector2(0, 150)
	gravity_dir = 1
	up_direction = Vector2.UP
	print("PLAYER: Reset completato. Gravità riattivata.")


func get_best_hack_target() -> Area2D:
	if not can_hack_in_zone or not hack_aura: return null
	
	var areas = hack_aura.get_overlapping_areas()
	var best_node = null
	var best_score = INF
	
	# Calcoliamo dove sta puntando il giocatore
	var aim_x = 0
	if Input.is_action_pressed("ui_right"): aim_x += 1
	if Input.is_action_pressed("ui_left"): aim_x -= 1
	var aim_y = 0
	if Input.is_action_pressed("ui_down"): aim_y += 1
	if Input.is_action_pressed("ui_up"): aim_y -= 1
	
	var aim_dir = Vector2(aim_x, aim_y).normalized()
	# Se non sta premendo direzioni, usa la direzione in cui guarda Lyra
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2(facing_dir, 0)
		
	for area in areas:
		if area.is_in_group("hackable") and not area.is_hacked:
			var to_target = area.global_position - global_position
			var distance = to_target.length()
			
			# Più lo score è BASSO, migliore è il bersaglio. Partiamo dalla distanza.
			var score = distance
			
			# Modifichiamo lo score in base a dove stiamo guardando (Dot Product)
			if distance > 0:
				var dot = aim_dir.dot(to_target.normalized())
				if dot > 0.5: # Lo stiamo guardando quasi dritto
					score *= 0.3 # Punteggio eccellente!
				elif dot < 0: # È dietro di noi
					score *= 5.0 # Punteggio pessimo, sceglilo solo se è l'unico
					
			if score < best_score:
				best_score = score
				best_node = area
				
	return best_node
	
	
func _on_hack_aura_exited(area: Area2D):
	# Se un nodo esce dalla nostra aura ed è attualmente solido, si spegne da solo!
	if area.is_in_group("hackable") and area.get("is_hacked") == true:
		area.trigger_hack()
