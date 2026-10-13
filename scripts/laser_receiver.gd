class_name LaserReceiver
extends Area2D

## LaserReceiver
## Optical sensor that detects laser beams and emits powered_changed signals.
## Designed for signal-based decoupling with PuzzleDoor, switches, and triggers.

signal powered_changed(is_powered: bool)

## Dimensions of the receiver for hit detection and rendering
@export var receiver_size: Vector2 = Vector2(48, 48)

## Active powered indicator color
@export var powered_color: Color = Color(0.25, 0.95, 0.65, 1.0)

## Dormant unpowered color
@export var unpowered_color: Color = Color(0.35, 0.38, 0.45, 1.0)

## Current power state
var is_powered: bool = false

var _last_hit_frame: int = -100
var _collision_shape: CollisionShape2D = null
var _pulse_time: float = 0.0

func _ready() -> void:
	# Ensure Area2D monitors incoming laser collisions
	monitoring = true
	monitorable = true
	_ensure_collision_shape()

func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			_collision_shape = child
			break
			
	if not _collision_shape:
		_collision_shape = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = receiver_size
		_collision_shape.shape = box
		add_child(_collision_shape)

func _physics_process(delta: float) -> void:
	_pulse_time += delta
	
	# If no laser hit occurred within the last 2 physics frames, turn off
	if is_powered and (Engine.get_physics_frames() - _last_hit_frame > 2):
		_set_powered(false)
	
	if is_powered:
		queue_redraw()

## Called every frame a laser beam intersects this receiver
func receive_laser_hit() -> void:
	_last_hit_frame = Engine.get_physics_frames()
	if not is_powered:
		_set_powered(true)

func _set_powered(state: bool) -> void:
	if is_powered == state:
		return
	is_powered = state
	if is_powered and SoundManager.instance:
		SoundManager.instance.play_receiver_powered()
	powered_changed.emit(is_powered)
	queue_redraw()

func _draw() -> void:
	# Check if custom visual child is attached
	for child in get_children():
		if child is Sprite2D or child is ColorRect or child is Polygon2D:
			return

	var rect: Rect2 = Rect2(-receiver_size / 2.0, receiver_size)
	
	# Sensor housing backplate
	draw_rect(rect, Color(0.12, 0.14, 0.18, 0.95), true)
	draw_rect(rect, Color(0.3, 0.35, 0.45, 1.0), false, 2.0)
	
	# Central circular optical diode
	var center: Vector2 = Vector2.ZERO
	var radius: float = receiver_size.x * 0.32
	
	if is_powered:
		# Pulsing glow rings
		var pulse: float = (sin(_pulse_time * 8.0) + 1.0) * 0.5
		var glow_color: Color = powered_color
		glow_color.a = 0.3 + 0.3 * pulse
		draw_circle(center, radius + 6.0 + pulse * 4.0, glow_color)
		
		# Solid bright core
		draw_circle(center, radius, powered_color)
		draw_circle(center, radius * 0.5, Color.WHITE)
		
		# Active sensor reticle
		draw_arc(center, radius + 2.0, 0, TAU, 16, powered_color.lightened(0.3), 2.0)
	else:
		# Dark inactive lens with dormant status dot
		draw_circle(center, radius, unpowered_color.darkened(0.5))
		draw_circle(center, radius * 0.3, Color(0.85, 0.25, 0.25, 0.8)) # Red standby LED
		draw_arc(center, radius, 0, TAU, 16, unpowered_color, 1.5)
