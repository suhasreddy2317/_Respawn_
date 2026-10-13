class_name LaserMirror
extends StaticBody2D

## LaserMirror
## Prismatic reflective optical surface for laser redirection puzzles.
## Bounces incoming laser beams according to law of reflection.
## Supports player interaction ([E] key and mouse click) to rotate in 45-degree increments.

signal mirror_rotated(new_angle: float)

@export var mirror_angle_degrees: float = 45.0
@export var is_rotatable_by_player: bool = true
@export var mirror_width: float = 58.0
@export var interaction_radius: float = 160.0

var _collision_shape: CollisionShape2D = null
var _interaction_active: bool = false
var _target_angle: float = 45.0

func _ready() -> void:
	_target_angle = mirror_angle_degrees
	_ensure_collision_shape()
	input_pickable = true
	set_process_input(true)

func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			_collision_shape = child
			break
			
	if not _collision_shape:
		_collision_shape = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = Vector2(mirror_width, 16.0)
		_collision_shape.shape = box
		add_child(_collision_shape)
		
	rotation_degrees = mirror_angle_degrees

func _process(delta: float) -> void:
	# Smooth rotation interpolation
	if abs(rotation_degrees - _target_angle) > 0.1:
		rotation_degrees = move_toward(rotation_degrees, _target_angle, delta * 360.0)
		mirror_angle_degrees = rotation_degrees
		queue_redraw()

	# Check distance to player continuously
	var p: Node = get_tree().get_first_node_in_group("player")
	if not p:
		p = get_parent().get_node_or_null("Player")
	if p and is_instance_valid(p):
		var dist: float = (p.global_position - global_position).length()
		var was_active: bool = _interaction_active
		_interaction_active = (dist <= interaction_radius)
		if was_active != _interaction_active:
			queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_rotatable_by_player or not _interaction_active:
		return

	# Handle interact action (E key)
	if event.is_action_pressed("interact"):
		rotate_mirror(45.0)
		get_viewport().set_input_as_handled()
		return

	# Legacy direct key support
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.physical_keycode == KEY_E):
		rotate_mirror(45.0)
		get_viewport().set_input_as_handled()


## Mouse click support directly on mirror
func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not is_rotatable_by_player:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _interaction_active:
			rotate_mirror(45.0)

func rotate_mirror(angle_step: float = 45.0) -> void:
	_target_angle = fmod(_target_angle + angle_step, 360.0)
	mirror_rotated.emit(_target_angle)
	if SoundManager.instance:
		SoundManager.instance.play_checkpoint()
	queue_redraw()

## Calculates reflected ray direction given incoming beam vector
func get_reflection(incoming_dir: Vector2) -> Vector2:
	var normal: Vector2 = Vector2.UP.rotated(rotation)
	if incoming_dir.dot(normal) > 0.0:
		normal = -normal
	return incoming_dir.bounce(normal).normalized()

func _draw() -> void:
	# Rotary mechanical housing
	draw_circle(Vector2.ZERO, 18.0, Color(0.18, 0.22, 0.30))
	draw_arc(Vector2.ZERO, 18.0, 0, TAU, 16, Color(0.38, 0.46, 0.60), 2.0)
	
	# Prismatic Mirror Plate
	var half_w: float = mirror_width / 2.0
	var mirror_rect: Rect2 = Rect2(-half_w, -6.0, mirror_width, 12.0)
	draw_rect(mirror_rect, Color(0.12, 0.16, 0.24), true)
	
	# Reflective crystal face
	var glass_color: Color = Color(0.75, 0.95, 1.0, 0.95)
	draw_line(Vector2(-half_w, -6.0), Vector2(half_w, -6.0), glass_color, 3.5)
	draw_line(Vector2(-half_w, -6.0), Vector2(half_w, -6.0), Color.WHITE, 1.5)
	
	# Normal alignment arrow indicator
	draw_line(Vector2.ZERO, Vector2(0, -22), Color(0.3, 0.85, 1.0, 0.85), 2.0)
	
	# Prominent interaction prompt when player is nearby
	if _interaction_active and is_rotatable_by_player:
		# Pulsing interaction halo
		draw_arc(Vector2.ZERO, 28.0, 0, TAU, 16, Color(0.2, 0.95, 0.6), 2.0)
