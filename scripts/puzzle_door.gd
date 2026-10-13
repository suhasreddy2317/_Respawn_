class_name PuzzleDoor
extends StaticBody2D

## PuzzleDoor
## A StaticBody2D security barrier that opens and closes in response to power signals.
## Designed to receive signals directly from LaserReceiver.powered_changed or puzzle switches.

signal door_state_changed(is_open: bool)

## Whether the door starts open at level launch
@export var starts_open: bool = false

## When true, receiving power OPENS the door. When false, receiving power CLOSES it (inverted).
@export var open_on_power: bool = true

## Dimensions of the barrier
@export var door_size: Vector2 = Vector2(28, 110)

## Accent color of the door energy field
@export var door_color: Color = Color(0.2, 0.85, 0.75, 1.0)

var is_open: bool = false
var is_powered: bool = false

var _collision_shape: CollisionShape2D = null
var _original_layer: int = 1
var _original_mask: int = 1
var _open_transition: float = 0.0 # 0.0 = closed, 1.0 = fully open

func _ready() -> void:
	_original_layer = collision_layer
	_original_mask = collision_mask
	_ensure_collision_shape()
	
	is_open = starts_open
	_open_transition = 1.0 if is_open else 0.0
	_apply_collision_state()

func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			_collision_shape = child
			break
			
	if not _collision_shape:
		_collision_shape = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = door_size
		_collision_shape.shape = box
		add_child(_collision_shape)

func _process(delta: float) -> void:
	var target: float = 1.0 if is_open else 0.0
	if abs(_open_transition - target) > 0.01:
		_open_transition = move_toward(_open_transition, target, delta * 3.5)
		queue_redraw()

## Signal receiver slot: connects directly to LaserReceiver.powered_changed
func set_powered(powered: bool) -> void:
	is_powered = powered
	var desired_open: bool
	if open_on_power:
		desired_open = (is_powered != starts_open)
	else:
		desired_open = ((not is_powered) != starts_open)
	
	if desired_open != is_open:
		if desired_open:
			open_door()
		else:
			close_door()

func open_door() -> void:
	if is_open:
		return
	is_open = true
	_apply_collision_state()
	door_state_changed.emit(true)
	queue_redraw()

func close_door() -> void:
	if not is_open:
		return
	is_open = false
	_apply_collision_state()
	door_state_changed.emit(false)
	queue_redraw()

func _apply_collision_state() -> void:
	if _collision_shape:
		_collision_shape.set_deferred("disabled", is_open)
	set_deferred("collision_layer", 0 if is_open else _original_layer)
	set_deferred("collision_mask", 0 if is_open else _original_mask)

func _draw() -> void:
	# Custom visual rendering if no sprites are attached
	for child in get_children():
		if child is Sprite2D or child is ColorRect or child is Polygon2D:
			return
			
	var half_size: Vector2 = door_size / 2.0
	var full_rect: Rect2 = Rect2(-half_size, door_size)
	
	# Top and bottom mechanical anchor frames (always visible)
	var anchor_h: float = 12.0
	var top_anchor: Rect2 = Rect2(-half_size.x - 4, -half_size.y, door_size.x + 8, anchor_h)
	var bot_anchor: Rect2 = Rect2(-half_size.x - 4, half_size.y - anchor_h, door_size.x + 8, anchor_h)
	
	var frame_color: Color = Color(0.18, 0.20, 0.26, 1.0)
	draw_rect(top_anchor, frame_color, true)
	draw_rect(top_anchor, Color(0.35, 0.4, 0.5), false, 1.5)
	draw_rect(bot_anchor, frame_color, true)
	draw_rect(bot_anchor, Color(0.35, 0.4, 0.5), false, 1.5)
	
	# Retracting barrier segments based on _open_transition
	var closed_ratio: float = 1.0 - _open_transition
	if closed_ratio > 0.02:
		var barrier_h: float = (door_size.y - anchor_h * 2.0) * closed_ratio
		var barrier_rect: Rect2 = Rect2(-half_size.x + 2, -half_size.y + anchor_h, door_size.x - 4, barrier_h)
		
		# Solid high-tech gate fill
		var barrier_fill: Color = door_color.darkened(0.7)
		barrier_fill.a = 0.95
		draw_rect(barrier_rect, barrier_fill, true)
		
		# Border and energy lines
		draw_rect(barrier_rect, door_color, false, 2.0)
		
		# Energy grid lines
		var step_y: float = 16.0
		var cur_y: float = barrier_rect.position.y + step_y
		while cur_y < barrier_rect.end.y:
			draw_line(Vector2(barrier_rect.position.x + 3, cur_y), Vector2(barrier_rect.end.x - 3, cur_y), door_color * 0.8, 1.5)
			cur_y += step_y
	
	# Status Indicator Gem on top anchor
	var indicator_pos: Vector2 = Vector2(0, -half_size.y + anchor_h * 0.5)
	if is_open:
		draw_circle(indicator_pos, 4.0, Color(0.2, 0.95, 0.4)) # Active Green / Unlocked
	else:
		draw_circle(indicator_pos, 4.0, Color(0.95, 0.25, 0.25)) # Red / Locked
