extends CharacterBody2D

# ------------------------------------------------------------
# MOVEMENT CONSTANTS
# ------------------------------------------------------------
const SPEED = 120.0
const JUMP_FORCE = -300.0
const GRAVITY = 800.0

# ------------------------------------------------------------
# WALL SYSTEM CONSTANTS
# ------------------------------------------------------------
const WALL_GRAB_DURATION = 8.0
const WALL_CLIMB_SPEED = 80.0
const WALL_SLIDE_SPEED = 40.0

const WALL_JUMP_H = 280.0
const WALL_JUMP_V = -220.0

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

var grapple_line: Line2D
var grapple_launch_timer := 0.0

# ------------------------------------------------------------
# READY
# ------------------------------------------------------------
func _ready():
	grapple_line = $GrappleLine
	grapple_line.visible = true
	grapple_line.points = [Vector2.ZERO, Vector2.ZERO]
# ------------------------------------------------------------
# MAIN LOOP
# ------------------------------------------------------------
func _physics_process(delta):
	var input_dir = Input.get_axis("ui_left", "ui_right")

	# UPDATE FACING DIR + FLIP
	if input_dir != 0:
		facing_dir = input_dir
		$AnimatedSprite2D.flip_h = facing_dir < 0

	# --- GRAPPLE ACTIVATION ---
	if Input.is_action_just_pressed("grapple") and not grappling and grapple_launch_timer <= 0:
		grapple_target = find_grapple_point()
		if grapple_target != null:
			grappling = true
			wall_grabbing = false
			grapple_line.visible = true
			grapple_line.points = [Vector2.ZERO, Vector2.ZERO]

	# --- GRAPPLE PULL ---
	if grappling and grapple_target:
		handle_grapple(delta)
		play_anim("jump")  # during grapple, use jump anim
		move_and_slide()
		return

	# --- GRAPPLE PARABOLIC EXIT ---
	if grapple_launch_timer > 0:
		grapple_launch_timer -= delta

		if grapple_launch_timer > 0.05:
			velocity.y += GRAVITY * 0.12 * delta
		else:
			velocity.y += GRAVITY * 0.6 * delta

		play_air_anim()
		move_and_slide()
		return

	# --- NORMAL GRAVITY ---
	if not wall_grabbing and not is_on_floor():
		velocity.y += GRAVITY * delta

	# --- INPUT JUMP BUFFER ---
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

	# --- COYOTE ---
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta

	# --- HORIZONTAL MOVE ---
	velocity.x = input_dir * SPEED

	# --- HANDLE JUMP ---
	handle_jump()

	# --- WALL SYSTEM ---
	handle_wall_grab(delta)
	handle_wall_jump()

	# --- ANIMATIONS ---
	update_animation(input_dir)

	move_and_slide()


# ------------------------------------------------------------
# ANIMATION HELPERS (idle, walk, jump, fall)
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
	# AIR
	if not is_on_floor():
		play_air_anim()
		return

	# WALK
	if input_dir != 0:
		play_anim("walk")
	else:
		play_anim("idle")


# ------------------------------------------------------------
# JUMP SYSTEM
# ------------------------------------------------------------
func handle_jump():
	if jump_buffer_timer > 0 and coyote_timer > 0 and not wall_grabbing:
		velocity.y = JUMP_FORCE
		jump_buffer_timer = 0
		coyote_timer = 0


# ------------------------------------------------------------
# WALL DETECTION
# ------------------------------------------------------------
func is_on_wall_left() -> bool:
	return is_on_wall() and get_wall_normal().x > 0.1

func is_on_wall_right() -> bool:
	return is_on_wall() and get_wall_normal().x < -0.1


# ------------------------------------------------------------
# WALL GRAB
# ------------------------------------------------------------
func handle_wall_grab(delta):
	var grabbing_button = Input.is_action_pressed("grab")
	var on_wall = is_on_wall() and not is_on_floor()

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
# WALL JUMP
# ------------------------------------------------------------
func handle_wall_jump():
	var grabbing_button = Input.is_action_pressed("grab")
	var on_wall = is_on_wall() and not is_on_floor()

	if on_wall and grabbing_button and not wall_exhausted and Input.is_action_just_pressed("ui_accept"):
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
func find_grapple_point():
	var closest = null
	var closest_dist = INF

	for p in get_tree().get_nodes_in_group("grapple_points"):
		var dist = global_position.distance_to(p.global_position)

		if dist < p.min_distance or dist > p.max_distance:
			continue

		var dir_to_point = sign(p.global_position.x - global_position.x)
		if dir_to_point != facing_dir:
			continue

		if dist < closest_dist:
			closest_dist = dist
			closest = p

	return closest


func handle_grapple(delta):
	var direction = (grapple_target.global_position - global_position).normalized()
	velocity = direction * grapple_speed

	grapple_line.visible = true
	grapple_line.points = [
		Vector2.ZERO,
		grapple_target.global_position - global_position
	]

	# Collision avec le point de grappin
	if global_position.distance_to(grapple_target.global_position) < 12:
		finish_grapple()


func finish_grapple():
	grappling = false

	# Impulsion finale
	velocity.x = facing_dir * 320
	velocity.y = -280

	grapple_launch_timer = 0.25
	grapple_target = null

	# 🔥 Reset propre du rope
	grapple_line.visible = false
	grapple_line.points = []
