class_name ShiftableObject
extends StaticBody2D

## ShiftableObject
## Static geometry that materializes conditionally in either Reality A or Reality B.
## Manages physical collision, visual ghosting, and phase-alignment rendering.

@export var active_reality: RealityManager.Reality = RealityManager.Reality.REALITY_A
@export var ghost_mode_when_inactive: bool = true
@export var inactive_alpha: float = 0.22
@export var object_size: Vector2 = Vector2(80, 80)
@export var custom_color: Color = Color(0, 0, 0, 0)
@export var debug_label: String = ""

var _collision_shape: CollisionShape2D = null
var _original_layer: int = 1
var _original_mask: int = 1
var _is_currently_active: bool = true

func _ready() -> void:
	_original_layer = collision_layer
	_original_mask = collision_mask
	_ensure_collision_shape()
	
	var rm: Node = get_node_or_null("/root/RealityManager")
	if rm:
		rm.reality_changed.connect(_on_reality_changed)
		_apply_reality_state(rm.current_reality)
	else:
		_apply_reality_state(RealityManager.Reality.REALITY_A)

func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			_collision_shape = child
			break
			
	if not _collision_shape:
		_collision_shape = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = object_size
		_collision_shape.shape = box
		add_child(_collision_shape)

func _on_reality_changed(new_reality: RealityManager.Reality) -> void:
	_apply_reality_state(new_reality)

func _apply_reality_state(current_reality: RealityManager.Reality) -> void:
	_is_currently_active = (current_reality == active_reality)
	
	# Safe collision toggle
	if _collision_shape:
		_collision_shape.set_deferred("disabled", not _is_currently_active)
	set_deferred("collision_layer", _original_layer if _is_currently_active else 0)
	set_deferred("collision_mask", _original_mask if _is_currently_active else 0)
	
	if ghost_mode_when_inactive:
		visible = true
		modulate.a = 1.0 if _is_currently_active else inactive_alpha
	else:
		visible = _is_currently_active
		modulate.a = 1.0
		
	queue_redraw()

func is_active() -> bool:
	return _is_currently_active

func _draw() -> void:
	# Avoid procedural draw if custom sprites attached
	for child in get_children():
		if child is Sprite2D or child is ColorRect or child is Polygon2D:
			return

	var rect: Rect2 = Rect2(-object_size / 2.0, object_size)
	var is_a: bool = (active_reality == RealityManager.Reality.REALITY_A)
	var primary_col: Color = RealityManager.COLOR_REALITY_A_PRIMARY if is_a else RealityManager.COLOR_REALITY_B_PRIMARY
	var accent_col: Color = RealityManager.COLOR_REALITY_A_ACCENT if is_a else RealityManager.COLOR_REALITY_B_ACCENT
	
	if custom_color.a > 0.01:
		primary_col = custom_color

	if _is_currently_active:
		# Solid body fill
		var fill_col: Color = accent_col.darkened(0.7)
		fill_col.a = 0.95
		draw_rect(rect, fill_col, true)
		
		# Glowing boundary border
		draw_rect(rect, primary_col, false, 2.5)
		
		# Inner bevel trim
		draw_rect(rect.grow(-4.0), primary_col * 0.5, false, 1.0)
		
		# Reality signature emblem
		if is_a:
			# Reality A: Quantum Circuit bars
			var step: float = 14.0
			var cy: float = rect.position.y + step
			while cy < rect.end.y - step * 0.5:
				draw_line(Vector2(rect.position.x + 8, cy), Vector2(rect.end.x - 8, cy), primary_col * 0.6, 1.5)
				cy += step
		else:
			# Reality B: Crystalline Shards
			var c: Vector2 = Vector2.ZERO
			var d_w: float = min(object_size.x, object_size.y) * 0.3
			var pts: PackedVector2Array = [
				c + Vector2(0, -d_w),
				c + Vector2(d_w, 0),
				c + Vector2(0, d_w),
				c + Vector2(-d_w, 0),
				c + Vector2(0, -d_w)
			]
			draw_polyline(pts, primary_col, 2.0)
	else:
		# Ghost outline with dashed/translucent styling
		var ghost_col: Color = primary_col
		ghost_col.a = 0.4
		draw_rect(rect, ghost_col * 0.15, true)
		draw_rect(rect, ghost_col, false, 1.5)
