class_name PuzzlePlayer
extends CharacterBody2D

## PuzzlePlayer
## Commercial indie-quality platformer character controller for:
## "Respawn: Parallax — Fractured Realities".
## Features natural acceleration/friction, coyote time, jump buffering, variable jump,
## procedural skeletal/cloth animation, aim tracking, screen shake, and lethal disintegration respawn.

signal player_died(reason: String)
signal player_respawned()

enum State {
	IDLE,
	RUNNING,
	JUMPING,
	FALLING,
	LANDING,
	DYING
}

@export var max_speed: float = 260.0
@export var ground_accel: float = 1900.0
@export var ground_friction: float = 2200.0
@export var air_accel: float = 1200.0
@export var air_drag: float = 400.0
@export var jump_velocity: float = -460.0
@export var gravity: float = 1100.0
@export var max_fall_speed: float = 680.0

var current_state: State = State.IDLE
var current_checkpoint: Vector2 = Vector2(140.0, 480.0)

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _facing_direction: float = 1.0
var _was_on_floor: bool = true

# Procedural Animation Parameters
var _anim_time: float = 0.0
var _walk_cycle: float = 0.0
var _squash_stretch: Vector2 = Vector2.ONE
var _aim_angle: float = 0.0
var _death_timer: float = 0.0
var _disintegration_particles: Array[Dictionary] = []

# Camera & Screen Shake
var camera: Camera2D = null
var _shake_amount: float = 0.0
var _shake_timer: float = 0.0

var _collision_shape: CollisionShape2D = null

func _ready() -> void:
	_ensure_collision_shape()
	_setup_camera()
	current_checkpoint = global_position
	
	# Register with RealityManager
	var rm: Node = get_node_or_null("/root/RealityManager")
	if rm and rm.has_method("register_player"):
		rm.call("register_player", self)

func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			_collision_shape = child
			break
			
	if not _collision_shape:
		_collision_shape = CollisionShape2D.new()
		var capsule: CapsuleShape2D = CapsuleShape2D.new()
		capsule.radius = 12.0
		capsule.height = 42.0
		_collision_shape.shape = capsule
		add_child(_collision_shape)

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "PlayerCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.drag_horizontal_enabled = true
	camera.drag_vertical_enabled = true
	add_child(camera)

func add_screen_shake(amount: float, duration: float) -> void:
	_shake_amount = amount
	_shake_timer = duration

func set_checkpoint(pos: Vector2) -> void:
	current_checkpoint = pos
	if SoundManager.instance:
		SoundManager.instance.play_checkpoint()

func _unhandled_input(event: InputEvent) -> void:
	if current_state == State.DYING:
		var respawn_pressed: bool = (
			event.is_action_pressed("jump") or 
			(event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_R))
		)
		if respawn_pressed:
			request_respawn()
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_anim_time += delta
	_update_screen_shake(delta)
	
	if current_state == State.DYING:
		_process_death_sequence(delta)
		return

	# Aiming calculations (mouse tracking)
	var mouse_pos: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_pos - global_position
	if to_mouse.length() > 10.0:
		_aim_angle = to_mouse.angle()

	# Abyss kill boundary check: falling into pits
	if global_position.y > 610.0 and current_state != State.DYING:
		die("fell_into_abyss")
		return

	# Gravity & terminal velocity
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		_coyote_timer -= delta
		current_state = State.JUMPING if velocity.y < 0.0 else State.FALLING
	else:
		_coyote_timer = 0.14
		if not _was_on_floor and velocity.y >= 0.0:
			# Landed with impact
			_on_impact_land()
		_was_on_floor = true

	# Jump buffering
	var jump_pressed: bool = (
		Input.is_action_just_pressed("jump") or 
		Input.is_key_pressed(KEY_SPACE) or 
		Input.is_key_pressed(KEY_W) or 
		Input.is_key_pressed(KEY_UP)
	)
	if jump_pressed:
		_jump_buffer_timer = 0.12
	else:
		_jump_buffer_timer -= delta

	# Jump execution
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		_squash_stretch = Vector2(0.75, 1.3) # Vertical stretch on leap
		if SoundManager.instance:
			SoundManager.instance.play_jump()

	# Variable jump height cut
	if Input.is_action_just_released("jump") and velocity.y < jump_velocity * 0.4:
		velocity.y = jump_velocity * 0.4

	# Horizontal input & momentum
	var move_input: float = 0.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_input -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_input += 1.0

	if move_input != 0.0:
		_facing_direction = signf(move_input)
		var accel: float = ground_accel if is_on_floor() else air_accel
		velocity.x = move_toward(velocity.x, move_input * max_speed, accel * delta)
		_walk_cycle += delta * 14.0
		if is_on_floor():
			current_state = State.RUNNING
	else:
		var friction: float = ground_friction if is_on_floor() else air_drag
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		_walk_cycle = 0.0
		if is_on_floor():
			current_state = State.IDLE

	# Recover squash/stretch smoothly
	_squash_stretch = _squash_stretch.move_toward(Vector2.ONE, delta * 6.0)

	move_and_slide()
	_was_on_floor = is_on_floor()
	queue_redraw()

func _on_impact_land() -> void:
	_squash_stretch = Vector2(1.35, 0.7) # Horizontal squash on impact
	add_screen_shake(3.0, 0.15)
	if SoundManager.instance:
		SoundManager.instance.play_land()

func _update_screen_shake(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		if camera:
			camera.offset = Vector2(
				randf_range(-_shake_amount, _shake_amount),
				randf_range(-_shake_amount, _shake_amount)
			)
	elif camera:
		camera.offset = Vector2.ZERO

## Lethal Hazard Contact: Sci-Fi Energy Disintegration
func die(reason: String = "laser_burn") -> void:
	if current_state == State.DYING:
		return
		
	current_state = State.DYING
	velocity = Vector2.ZERO
	_death_timer = 0.9
	add_screen_shake(8.0, 0.4)
	
	if SoundManager.instance:
		SoundManager.instance.play_player_death()
		
	# Spawn 24 sci-fi energy disintegration embers
	_disintegration_particles.clear()
	var rm: Node = get_node_or_null("/root/RealityManager")
	var spark_color: Color = rm.get_theme_color() if rm else Color(0.1, 0.9, 1.0)
	
	for i in range(24):
		var angle: float = randf() * TAU
		var spd: float = randf_range(80.0, 240.0)
		_disintegration_particles.append({
			"pos": Vector2(randf_range(-10, 10), randf_range(-25, 5)),
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"alpha": 1.0,
			"color": spark_color if randf() > 0.3 else Color.WHITE,
			"size": randf_range(2.5, 5.0)
		})
		
	player_died.emit(reason)
	queue_redraw()

func _process_death_sequence(delta: float) -> void:
	for p in _disintegration_particles:
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.94 # Air friction
		p["alpha"] = maxf(0.0, p["alpha"] - delta * 1.2)
	queue_redraw()

func request_respawn() -> void:
	if current_state == State.DYING:
		_respawn_at_checkpoint()

func _respawn_at_checkpoint() -> void:
	global_position = current_checkpoint
	velocity = Vector2.ZERO
	current_state = State.IDLE
	_squash_stretch = Vector2(0.5, 1.5) # Re-materialize stretch
	_disintegration_particles.clear()
	player_respawned.emit()
	queue_redraw()

func _draw() -> void:
	# 1. Death Disintegration State Rendering
	if current_state == State.DYING:
		for p in _disintegration_particles:
			if p["alpha"] > 0.02:
				var col: Color = p["color"]
				col.a = p["alpha"]
				draw_circle(p["pos"], p["size"] * p["alpha"], col)
				draw_circle(p["pos"], p["size"] * 0.4 * p["alpha"], Color.WHITE)
		return

	# 2. Living Articulated Procedural Character
	var rm: Node = get_node_or_null("/root/RealityManager")
	var aura_col: Color = rm.get_theme_color() if rm else Color(0.1, 0.85, 1.0)
	var accent_col: Color = rm.get_accent_color() if rm else Color(0.1, 0.4, 0.9)
	var face: float = _facing_direction
	
	# Squash & Stretch scaling matrix
	draw_set_transform(Vector2.ZERO, 0.0, _squash_stretch)
	
	# Dynamic Cloth Cape (Trails horizontal velocity)
	var cape_lag: float = -velocity.x * 0.06
	var cape_pts: PackedVector2Array = [
		Vector2(-face * 6, -14),
		Vector2(-face * 18 + cape_lag, 10),
		Vector2(-face * 8 + cape_lag * 0.5, 14),
		Vector2(-face * 2, -6)
	]
	var cape_color: Color = accent_col.darkened(0.5)
	draw_polygon(cape_pts, [cape_color, cape_color, cape_color, cape_color])
	draw_polyline(cape_pts, aura_col * 0.7, 1.2)

	# Articulated Legs (running stride cycle)
	var stride: float = sin(_walk_cycle) * 7.0 if current_state == State.RUNNING else 0.0
	var leg_color: Color = Color(0.14, 0.16, 0.22)
	draw_rect(Rect2(-8 + stride, 4, 6, 16), leg_color, true)
	draw_rect(Rect2(2 - stride, 4, 6, 16), leg_color, true)
	# Knee armor joints
	draw_circle(Vector2(-5 + stride, 11), 3.0, Color(0.25, 0.28, 0.38))
	draw_circle(Vector2(5 - stride, 11), 3.0, Color(0.25, 0.28, 0.38))

	# Torso & Powered Armor
	var torso_box: Rect2 = Rect2(-10, -16, 20, 22)
	draw_rect(torso_box, Color(0.20, 0.23, 0.30), true)
	draw_rect(torso_box, Color(0.35, 0.40, 0.52), false, 1.5)

	# Chest Energy Conduit / Power Core
	draw_circle(Vector2(0, -6), 4.0, aura_col)
	draw_circle(Vector2(0, -6), 1.8, Color.WHITE)

	# Tactical Arm / Laser Targeting Pointer (aims towards mouse)
	var shoulder: Vector2 = Vector2(face * 2, -8)
	var arm_dir: Vector2 = Vector2(cos(_aim_angle), sin(_aim_angle))
	var hand_pos: Vector2 = shoulder + arm_dir * 14.0
	draw_line(shoulder, hand_pos, Color(0.28, 0.32, 0.42), 3.5)
	draw_circle(hand_pos, 2.5, aura_col)
	# Subtle targeting laser dot
	draw_line(hand_pos, hand_pos + arm_dir * 28.0, aura_col * 0.4, 1.0)

	# Head Helmet & Breathing Gear
	var head_c: Vector2 = Vector2(0, -22)
	draw_circle(head_c, 9.5, Color(0.16, 0.18, 0.25))
	draw_arc(head_c, 9.5, 0, TAU, 16, Color(0.38, 0.42, 0.54), 1.5)

	# Glowing Cyber Visor
	var visor_r: Rect2 = Rect2(face * 1.5 - 2.0, -25, face * 7.5, 5.0)
	draw_rect(visor_r, aura_col, true)
	draw_rect(visor_r, Color.WHITE, false, 1.0)
