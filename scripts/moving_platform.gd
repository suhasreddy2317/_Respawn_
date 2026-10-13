class_name MovingPlatform
extends AnimatableBody2D

## MovingPlatform
## Kinematic elevator and transport ledge built on AnimatableBody2D.
## Smoothly ferries the player across hazard chasms without physics jitter.

@export var travel_offset: Vector2 = Vector2(180.0, 0.0)
@export var travel_duration: float = 3.5
@export var platform_size: Vector2 = Vector2(100.0, 20.0)
@export var active_reality: int = -1 # -1 for both realities, or Reality A / B

var _origin_pos: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _collision_shape: CollisionShape2D = null

func _ready() -> void:
	_origin_pos = global_position
	sync_to_physics = true
	_ensure_collision_shape()

func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			_collision_shape = child
			break
	if not _collision_shape:
		_collision_shape = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = platform_size
		_collision_shape.shape = box
		add_child(_collision_shape)

func _physics_process(delta: float) -> void:
	_time += delta
	
	# Reality check
	var rm: Node = get_node_or_null("/root/RealityManager")
	var is_active: bool = true
	if rm and active_reality != -1:
		is_active = (rm.current_reality == active_reality)
		
	if _collision_shape:
		_collision_shape.set_deferred("disabled", not is_active)
	visible = is_active
	
	if not is_active:
		return
		
	# Smooth ping-pong easing between origin and target
	var progress: float = (sin((_time / travel_duration) * TAU - PI * 0.5) + 1.0) * 0.5
	global_position = _origin_pos + travel_offset * progress
	queue_redraw()

func _draw() -> void:
	var rect: Rect2 = Rect2(-platform_size / 2.0, platform_size)
	
	# Solid platform body
	draw_rect(rect, Color(0.18, 0.22, 0.30), true)
	draw_rect(rect, Color(0.35, 0.45, 0.60), false, 1.5)
	
	# Glowing hydraulic guide track
	var track_col: Color = RealityManager.COLOR_REALITY_A_PRIMARY if active_reality == 0 else (RealityManager.COLOR_REALITY_B_PRIMARY if active_reality == 1 else Color(0.3, 0.8, 1.0))
	draw_line(Vector2(rect.position.x + 8, 0), Vector2(rect.end.x - 8, 0), track_col, 2.0)
	
	# Direction arrow notches
	draw_circle(Vector2(-platform_size.x * 0.3, 0), 3.0, track_col)
	draw_circle(Vector2(platform_size.x * 0.3, 0), 3.0, track_col)
