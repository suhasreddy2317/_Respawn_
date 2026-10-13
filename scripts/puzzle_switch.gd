class_name PuzzleSwitch
extends Area2D

## PuzzleSwitch
## Floor pressure plate and terminal switch for environmental puzzle solving.
## Emits toggled signals to actuate doors, laser redirectors, and moving platforms.

signal toggled(is_active: bool)

@export var is_toggle_type: bool = false # If true, latches on/off; if false, acts as momentary pressure plate
@export var switch_width: float = 48.0

var is_pressed: bool = false
var _depression: float = 0.0 # 0.0 = up, 1.0 = down

func _ready() -> void:
	monitoring = true
	monitorable = true
	_ensure_collision_shape()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _ensure_collision_shape() -> void:
	var shape: CollisionShape2D = null
	for child in get_children():
		if child is CollisionShape2D:
			shape = child
			break
	if not shape:
		shape = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = Vector2(switch_width, 10.0)
		shape.shape = box
		shape.position = Vector2(0, -5.0)
		add_child(shape)

func _process(delta: float) -> void:
	var target: float = 1.0 if is_pressed else 0.0
	if abs(_depression - target) > 0.01:
		_depression = move_toward(_depression, target, delta * 8.0)
		queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		if is_toggle_type:
			is_pressed = not is_pressed
		else:
			is_pressed = true
		toggled.emit(is_pressed)
		if SoundManager.instance:
			SoundManager.instance.play_land()
		queue_redraw()

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and not is_toggle_type:
		is_pressed = false
		toggled.emit(false)
		queue_redraw()

func _draw() -> void:
	var half_w: float = switch_width / 2.0
	
	# Base plate
	draw_rect(Rect2(-half_w - 4, -4, switch_width + 8, 8), Color(0.18, 0.22, 0.28), true)
	draw_rect(Rect2(-half_w - 4, -4, switch_width + 8, 8), Color(0.35, 0.42, 0.52), false, 1.5)
	
	# Depressible pad
	var pad_y: float = -8.0 + _depression * 4.0
	var pad_col: Color = Color(0.2, 0.95, 0.6) if is_pressed else Color(0.4, 0.45, 0.55)
	draw_rect(Rect2(-half_w, pad_y, switch_width, 6), pad_col, true)
	draw_rect(Rect2(-half_w, pad_y, switch_width, 6), Color.WHITE if is_pressed else Color(0.6, 0.65, 0.75), false, 1.0)
