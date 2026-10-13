extends Node

## RealityManager
## Global Autoload Singleton managing dual-reality states for:
## "Respawn: Parallax — Fractured Realities".
## Coordinates Reality A (Cyan/Blue) and Reality B (Magenta/Purple),
## broadcasting transitions and preventing geometry-entombment.

enum Reality {
	REALITY_A = 0,
	REALITY_B = 1,
	MATERIAL = 0,  # Compatibility alias
	FRACTURED = 1  # Compatibility alias
}

## Emitted whenever the active reality changes
signal reality_changed(new_reality: Reality)

## Emitted during the glitch/distortion transition (0.0 to 1.0)
signal transition_pulse(intensity: float)

## Current active reality state (Starts in Reality A)
var current_reality: Reality = Reality.REALITY_A

## Curated visual palettes specified for Respawn: Parallax
const COLOR_REALITY_A_PRIMARY: Color = Color(0.08, 0.82, 0.98, 1.0)   # Vivid Neon Cyan
const COLOR_REALITY_A_ACCENT: Color  = Color(0.15, 0.45, 0.95, 1.0)   # Deep Cobalt Blue
const COLOR_REALITY_B_PRIMARY: Color = Color(0.96, 0.18, 0.72, 1.0)   # Electric Magenta
const COLOR_REALITY_B_ACCENT: Color  = Color(0.68, 0.15, 0.95, 1.0)   # Ultraviolet Purple

# Backward compatibility aliases
const COLOR_MATERIAL: Color = COLOR_REALITY_A_PRIMARY
const COLOR_FRACTURED: Color = COLOR_REALITY_B_PRIMARY

var _glitch_timer: float = 0.0
var _active_player: CharacterBody2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if _glitch_timer > 0.0:
		_glitch_timer = maxf(0.0, _glitch_timer - delta * 4.0)
		transition_pulse.emit(_glitch_timer)

func register_player(player: CharacterBody2D) -> void:
	_active_player = player

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	if event.is_action_pressed("switch_reality"):
		toggle_reality()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q or event.physical_keycode == KEY_Q:
			toggle_reality()
			get_viewport().set_input_as_handled()

## Toggles between Reality A (Cyan) and Reality B (Magenta)
func toggle_reality() -> void:
	if current_reality == Reality.REALITY_A:
		set_reality(Reality.REALITY_B)
	else:
		set_reality(Reality.REALITY_A)

## Sets a specific reality, initiates chromatic glitch effect, and prevents player entombment
func set_reality(new_reality: Reality) -> void:
	if current_reality == new_reality:
		return
		
	current_reality = new_reality
	_glitch_timer = 1.0
	
	# Play procedural sound hook
	if SoundManager.instance:
		SoundManager.instance.play_reality_shift()
		
	reality_changed.emit(current_reality)
	
	# Safety check: Resolve entombment if player is inside new reality solid geometry
	if _active_player and is_instance_valid(_active_player):
		_prevent_entombment(_active_player)

## Anti-entombment collision solver: pushes player out of newly materialized geometry
func _prevent_entombment(body: CharacterBody2D) -> void:
	var space_state: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	if not space_state:
		return
		
	# Check 8 directional offsets (prioritizing up, then diagonals, then lateral)
	var nudge_dirs: Array[Vector2] = [
		Vector2.UP,
		Vector2(-0.7, -0.7),
		Vector2(0.7, -0.7),
		Vector2.LEFT,
		Vector2.RIGHT,
		Vector2.DOWN
	]
	
	for dist in [4.0, 12.0, 24.0, 40.0]:
		for dir in nudge_dirs:
			var test_offset: Vector2 = dir * dist
			if not body.test_move(body.global_transform, test_offset):
				# Found a valid nearby vacant position
				body.global_position += test_offset
				return

func get_reality_name() -> String:
	match current_reality:
		Reality.REALITY_A:
			return "REALITY A [CYAN]"
		Reality.REALITY_B:
			return "REALITY B [MAGENTA]"
		_:
			return "UNKNOWN"

func get_theme_color() -> Color:
	match current_reality:
		Reality.REALITY_A:
			return COLOR_REALITY_A_PRIMARY
		Reality.REALITY_B:
			return COLOR_REALITY_B_PRIMARY
		_:
			return Color.WHITE

func get_accent_color() -> Color:
	match current_reality:
		Reality.REALITY_A:
			return COLOR_REALITY_A_ACCENT
		Reality.REALITY_B:
			return COLOR_REALITY_B_ACCENT
		_:
			return Color.WHITE

func is_reality_a() -> bool:
	return current_reality == Reality.REALITY_A

func is_reality_b() -> bool:
	return current_reality == Reality.REALITY_B

# Compatibility methods
func is_material() -> bool: return is_reality_a()
func is_fractured() -> bool: return is_reality_b()
