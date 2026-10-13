class_name CrumblingPlatform
extends StaticBody2D

## CrumblingPlatform
## Unstable structural ledge that begins vibrating upon player contact,
## disintegrates into energy particles, and regenerates after a cooldown.

@export var platform_size: Vector2 = Vector2(84.0, 18.0)
@export var collapse_delay: float = 0.65
@export var respawn_delay: float = 2.8

enum PlatformState {
	INTACT,
	SHAKING,
	COLLAPSED,
	REGENERATING
}

var current_state: PlatformState = PlatformState.INTACT
var _timer: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _collision_shape: CollisionShape2D = null

func _ready() -> void:
	_ensure_collision_shape()
	_setup_trigger()

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

func _setup_trigger() -> void:
	var trigger: Area2D = Area2D.new()
	trigger.name = "StepTrigger"
	var col: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(platform_size.x - 4.0, 8.0)
	col.shape = box
	col.position = Vector2(0, -platform_size.y * 0.5 - 4.0)
	trigger.add_child(col)
	trigger.body_entered.connect(_on_stepped_on)
	add_child(trigger)

func _on_stepped_on(body: Node2D) -> void:
	if body is CharacterBody2D and current_state == PlatformState.INTACT:
		current_state = PlatformState.SHAKING
		_timer = collapse_delay

func _physics_process(delta: float) -> void:
	match current_state:
		PlatformState.SHAKING:
			_timer -= delta
			_shake_offset = Vector2(randf_range(-2.5, 2.5), randf_range(-1.5, 1.5))
			if _timer <= 0.0:
				current_state = PlatformState.COLLAPSED
				_timer = respawn_delay
				if _collision_shape:
					_collision_shape.set_deferred("disabled", true)
				visible = false
				if SoundManager.instance:
					SoundManager.instance.play_laser_hit()
		PlatformState.COLLAPSED:
			_timer -= delta
			if _timer <= 0.0:
				current_state = PlatformState.INTACT
				if _collision_shape:
					_collision_shape.set_deferred("disabled", false)
				visible = true
				_shake_offset = Vector2.ZERO
		_:
			_shake_offset = Vector2.ZERO
			
	queue_redraw()

func _draw() -> void:
	var rect: Rect2 = Rect2(-platform_size / 2.0 + _shake_offset, platform_size)
	
	# Fractured stone/composite ledge
	var base_col: Color = Color(0.24, 0.26, 0.32)
	if current_state == PlatformState.SHAKING:
		base_col = Color(0.38, 0.22, 0.26) # Glows warning amber/red
		
	draw_rect(rect, base_col, true)
	draw_rect(rect, Color(0.5, 0.55, 0.65), false, 1.5)
	
	# Fracture stress fault lines
	draw_line(rect.position + Vector2(16, 0), rect.position + Vector2(28, rect.size.y), Color(0.8, 0.3, 0.3, 0.8), 1.5)
	draw_line(rect.position + Vector2(50, 0), rect.position + Vector2(42, rect.size.y), Color(0.8, 0.3, 0.3, 0.8), 1.5)
