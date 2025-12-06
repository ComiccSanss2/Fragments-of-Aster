extends CharacterBody2D

# ------------------------------------------------------------
# MOVEMENT CONSTANTS
# ------------------------------------------------------------
const SPEED = 120.0
const JUMP_FORCE = -300.0
const GRAVITY = 800.0

# ------------------------------------------------------------
# VARIABLE JUMP (SAUT CHARGÉ)
# ------------------------------------------------------------
const JUMP_HOLD_FORCE = -250.0
const MAX_JUMP_HOLD_TIME = 0.18

var jump_held_time = 0.0
var is_jump_held = false

# ------------------------------------------------------------
# WALL SYSTEM CONSTANTS
# ------------------------------------------------------------
const WALL_GRAB_DURATION = 8.0
const WALL_CLIMB_SPEED = 80.0
const WALL_SLIDE_SPEED = 40.0

const WALL_JUMP_H = 280.0
const WALL_JUMP_V = -220.0

# ★ Nouveau : wall coyote time
const WALL_COYOTE_TIME := 0.12
var wall_coyote_timer := 0.0

var wall_grab_time_left = WALL_GRAB_DURATION
var wall_grabbing = false
var wall_exhausted = false

# ------------------------------------------------------------
# COYOTE TIME + JUMP BUFFER
# ------------------------------------------------------------
const COYOTE_TIME = 0.12
const JUMP_BUFFER_TIME = 0.12

var coyote_timer = 0.0
var jump_buffer_timer = 0.0

# ------------------------------------------------------------
# GRAPPLE SYSTEM
# ------------------------------------------------------------
var facing_dir := 1
var grappling := false
var grapple_target: Area2D = null
var grapple_speed := 500.0
var grapple_unlocked: bool = false
var can_move := true
var grapple_line: Line2D
var grapple_launch_timer := 0.0
var grapple_direction := Vector2.ZERO

# UI popup
@onready var popup := $EchoText


# ------------------------------------------------------------
# READY
# ------------------------------------------------------------
func _ready():
	grapple_line = $GrappleLine
	grapple_line.visible = false
	grapple_line.points = [Vector2.ZERO, Vector2.ZERO]


# ------------------------------------------------------------
# MAIN LOOP
# ------------------------------------------------------------
func _physics_process(delta):

	# Si bloqué (cinématique)
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_dir = Input.get_axis("ui_left", "ui_right")

	# -- Flip sprite --
	if input_dir != 0:
		facing_dir = input_dir
		$AnimatedSprite2D.flip_h = facing_dir < 0


	# ------------------------------------------------------------
	# GRAPPLE ACTIVATION
	# ------------------------------------------------------------
	if grapple_unlocked \
	and Input.is_action_just_pressed("grapple") \
	and not grappling \
	and grapple_launch_timer <= 0:

		grapple_target = find_grapple_point()

		if grapple_target:
			grappling = true
			wall_grabbing = false

			grapple_direction = (grapple_target.global_position - global_position).normalized()
			grapple_line.visible = true
			grapple_line.points = [Vector2.ZERO, Vector2.ZERO]


	# GRAPPLE PULL
	if grappling and grapple_target:
		handle_grapple(delta)
		play_anim("jump")
		move_and_slide()
		return


	# GRAPPLE EXIT MOMENTUM
	if grapple_launch_timer > 0:
		grapple_launch_timer -= delta
		velocity.y += GRAVITY * (0.12 if grapple_launch_timer > 0.05 else 0.6) * delta
		play_air_anim()
		move_and_slide()
		return


	# ------------------------------------------------------------
	# NORMAL GRAVITY
	# ------------------------------------------------------------
	if not wall_grabbing and not is_on_floor():
		velocity.y += GRAVITY * delta


	# ------------------------------------------------------------
	# JUMP BUFFER
	# ------------------------------------------------------------
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta


	# ------------------------------------------------------------
	# COYOTE TIME SOL
	# ------------------------------------------------------------
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta


	# ------------------------------------------------------------
	# MOVE
	# ------------------------------------------------------------
	velocity.x = input_dir * SPEED


	# ------------------------------------------------------------
	# JUMP
	# ------------------------------------------------------------
	handle_jump(delta)

	# ------------------------------------------------------------
	# WALL SYSTEM
	# ------------------------------------------------------------
	handle_wall_grab(delta)
	handle_wall_jump()

	# ------------------------------------------------------------
	# ANIMS
	# ------------------------------------------------------------
	update_animation(input_dir)

	move_and_slide()


# ------------------------------------------------------------
# ANIMATION HELPERS
# ------------------------------------------------------------
func play_anim(name: String):
	if $AnimatedSprite2D.animation != name:
		$AnimatedSprite2D.play(name)

func play_air_anim():
	if velocity.y < 0:
		play_anim("jump")
	else:
		play_anim("fall")

func update_animation(input_dir):
	if not is_on_floor():
		play_air_anim()
		return
	if input_dir != 0:
		play_anim("walk")
	else:
		play_anim("idle")


# ------------------------------------------------------------
# VARIABLE JUMP
# ------------------------------------------------------------
func handle_jump(delta):
	if jump_buffer_timer > 0 and coyote_timer > 0 and not wall_grabbing:
		velocity.y = JUMP_FORCE
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


# ------------------------------------------------------------
# WALL SYSTEM
# ------------------------------------------------------------
func is_on_wall_left() -> bool:
	return is_on_wall() and get_wall_normal().x > 0.1

func is_on_wall_right() -> bool:
	return is_on_wall() and get_wall_normal().x < -0.1


func handle_wall_grab(delta):
	var grabbing_button = Input.is_action_pressed("grab")
	var on_wall = is_on_wall() and not is_on_floor()

	# --- Wall coyote timer ---
	if on_wall:
		wall_coyote_timer = WALL_COYOTE_TIME
	else:
		wall_coyote_timer -= delta

	# Reset normal wall grab
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

		if Input.is_action_pressed("ui_up"):
			velocity.y = -WALL_CLIMB_SPEED
		elif Input.is_action_pressed("ui_down"):
			velocity.y = WALL_CLIMB_SPEED

	else:
		wall_grabbing = false
		if wall_exhausted and on_wall:
			velocity.y = WALL_SLIDE_SPEED


# ------------------------------------------------------------
# WALL JUMP (avec wall coyote)
# ------------------------------------------------------------
func handle_wall_jump():
	var grabbing_button = Input.is_action_pressed("grab")

	if wall_coyote_timer > 0.0 \
	and grabbing_button \
	and not wall_exhausted \
	and Input.is_action_just_pressed("ui_accept"):

		wall_grabbing = false
		jump_buffer_timer = 0

		if is_on_wall_left():
			velocity.x = WALL_JUMP_H
		elif is_on_wall_right():
			velocity.x = -WALL_JUMP_H

		velocity.y = WALL_JUMP_V


# ------------------------------------------------------------
# GRAPPLE SYSTEM
# ------------------------------------------------------------
func find_grapple_point() -> Area2D:
	var best_point: Area2D = null
	var best_dist: float = INF

	for p in get_tree().get_nodes_in_group("grapple_points"):
		var dist = global_position.distance_to(p.global_position)
		if dist < p.min_distance or dist > p.max_distance:
			continue
		if dist < best_dist:
			best_dist = dist
			best_point = p

	return best_point


func handle_grapple(delta):
	collision_layer = 0
	collision_mask = 0

	velocity = grapple_direction * grapple_speed

	grapple_line.points = [
		Vector2.ZERO,
		grapple_target.global_position - global_position
	]

	if global_position.distance_to(grapple_target.global_position) < 12:
		finish_grapple()


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


# ------------------------------------------------------------
# FX & POPUP
# ------------------------------------------------------------
func spawn_dust():
	var dust_scene = load("res://scenes/cpu_particles_2d.tscn")
	var d = dust_scene.instantiate()
	d.global_position = global_position
	get_tree().current_scene.add_child(d)


func show_popup(msg: String):
	var lbl = $EchoText
	lbl.text = msg
	lbl.visible = true

	lbl.modulate.a = 0.0
	lbl.scale = Vector2(0.8, 0.8)

	var t = create_tween()
	t.tween_property(lbl, "modulate:a", 1.0, 0.25)
	t.tween_property(lbl, "scale", Vector2(1,1), 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_popup():
	var lbl = $EchoText
	if lbl.visible:
		var t = create_tween()
		t.tween_property(lbl, "modulate:a", 0.0, 0.25)
		await t.finished
	lbl.visible = false
