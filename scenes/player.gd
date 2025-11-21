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

# Celeste-style wall jump
const WALL_JUMP_H = 280.0
const WALL_JUMP_V = -220.0

var wall_grab_time_left = WALL_GRAB_DURATION
var wall_grabbing = false
var wall_exhausted = false

# ------------------------------------------------------------
# COYOTE TIME + JUMP BUFFER
# ------------------------------------------------------------
const COYOTE_TIME = 0.12          # Time after leaving ground where jump is still allowed
const JUMP_BUFFER_TIME = 0.12     # Time before landing where jump is stored

var coyote_timer = 0.0
var jump_buffer_timer = 0.0


# ------------------------------------------------------------
# MAIN LOOP
# ------------------------------------------------------------
func _physics_process(delta):
	var input_dir = Input.get_axis("ui_left", "ui_right")

	# ------------------------------
	# GRAVITY (unless grabbing)
	# ------------------------------
	if not wall_grabbing:
		if not is_on_floor():
			velocity.y += GRAVITY * delta

	# ------------------------------
	# STORE JUMP INPUT (jump buffer)
	# ------------------------------
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

	# ------------------------------
	# UPDATE COYOTE TIMER
	# ------------------------------
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta

	# ------------------------------
	# HORIZONTAL MOVEMENT
	# ------------------------------
	velocity.x = input_dir * SPEED

	# ------------------------------
	# NORMAL + BUFFERED + COYOTE JUMP
	# ------------------------------
	handle_jump()

	# ------------------------------
	# WALL SYSTEM
	# ------------------------------
	handle_wall_grab(delta)
	handle_wall_jump()

	move_and_slide()


# ------------------------------------------------------------
# JUMP HANDLING (ground jump + coyote time + jump buffer)
# ------------------------------------------------------------
func handle_jump():
	# Trigger jump if:
	# 1. jump buffer > 0  AND  (on ground or coyote time still active)
	if jump_buffer_timer > 0 and coyote_timer > 0 and not wall_grabbing:
		velocity.y = JUMP_FORCE
		jump_buffer_timer = 0  # consume the buffer
		coyote_timer = 0        # prevent double jump on same coyote


# ------------------------------------------------------------
# DETECT WALL SIDE
# ------------------------------------------------------------
func is_on_wall_left() -> bool:
	return is_on_wall() and get_wall_normal().x > 0.1

func is_on_wall_right() -> bool:
	return is_on_wall() and get_wall_normal().x < -0.1


# ------------------------------------------------------------
# WALL GRAB + ENDURANCE + CLIMBING
# ------------------------------------------------------------
func handle_wall_grab(delta):
	var grabbing_button = Input.is_action_pressed("grab")
	var on_wall = is_on_wall() and not is_on_floor()

	# Reset endurance on floor
	if is_on_floor():
		wall_grab_time_left = WALL_GRAB_DURATION
		wall_exhausted = false

	# Start wall grabbing
	if on_wall and grabbing_button and not wall_exhausted:
		wall_grabbing = true
		wall_grab_time_left -= delta

		if wall_grab_time_left <= 0:
			wall_grab_time_left = 0
			wall_exhausted = true
			wall_grabbing = false
			return

		# Gravity disabled
		velocity.y = 0

		# Climb movement
		if Input.is_action_pressed("ui_up"):
			velocity.y = -WALL_CLIMB_SPEED
		elif Input.is_action_pressed("ui_down"):
			velocity.y = WALL_CLIMB_SPEED

	else:
		wall_grabbing = false

		# If exhausted → slow slide
		if wall_exhausted and on_wall:
			velocity.y = WALL_SLIDE_SPEED


# ------------------------------------------------------------
# CELESTE-STYLE WALL JUMP
# ------------------------------------------------------------
func handle_wall_jump():
	var grabbing_button = Input.is_action_pressed("grab")
	var on_wall = is_on_wall() and not is_on_floor()

	if on_wall and grabbing_button and not wall_exhausted and Input.is_action_just_pressed("ui_accept"):
		wall_grabbing = false  # exit grab instantly
		jump_buffer_timer = 0  # consume jump buffer

		# Direction
		if is_on_wall_left():
			velocity.x = WALL_JUMP_H   # push right
		elif is_on_wall_right():
			velocity.x = -WALL_JUMP_H  # push left

		velocity.y = WALL_JUMP_V
