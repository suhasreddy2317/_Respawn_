class_name ParallaxBackdrop
extends Node2D

## ParallaxBackdrop
## Multi-layered 2D side-view cinematic background for:
## "RESPAWN: PARALLAX — FRACTURED REALITIES".
##
## Implements:
## - Layered depth parallax (Sky, Celestial Body, Distant Ridges, Midground Skyline, Near Framework, Atmospheric Mist).
## - Seamless horizontal tiling across infinite / wide level bounds.
## - Dynamic reality palette crossfading listening to RealityManager.reality_changed.
## - Reality A: Moonlit celestial deep indigo & neon cyan atmospheric palette.
## - Reality B: Fractured dimensional rift & warm sunset amber/magenta palette.
## - Zero physics interference, zero collision impact, safe z_index = -100 rendering.

@export var parallax_enabled: bool = true
@export var transition_duration: float = 0.45

# Layer Node References
@onready var sky_layer: Parallax2D = $SkyLayer
@onready var sky_sprite: Sprite2D = $SkyLayer/SkySprite
@onready var moon_sprite: Sprite2D = $SkyLayer/MoonSprite
@onready var rift_sprite: Sprite2D = $SkyLayer/RiftSprite

@onready var distant_layer: Parallax2D = $DistantLayer
@onready var distant_sprite: Sprite2D = $DistantLayer/DistantSprite

@onready var midground_layer: Parallax2D = $MidgroundLayer
@onready var midground_sprite: Sprite2D = $MidgroundLayer/MidgroundSprite

@onready var near_layer: Parallax2D = $NearLayer
@onready var near_sprite: Sprite2D = $NearLayer/NearSprite

@onready var atmosphere_layer: Parallax2D = $AtmosphereLayer
@onready var atmosphere_sprite: Sprite2D = $AtmosphereLayer/AtmosphereSprite

# Palette Definitions: Reality A (Cool Moonlit Night & Cyan Aurora)
const COLOR_A_SKY: Color = Color(0.85, 0.95, 1.0, 1.0)
const COLOR_A_DISTANT: Color = Color(0.70, 0.85, 1.0, 0.85)
const COLOR_A_MIDGROUND: Color = Color(0.60, 0.80, 1.0, 1.0)
const COLOR_A_NEAR: Color = Color(0.65, 0.75, 0.95, 1.0)
const COLOR_A_MIST: Color = Color(0.20, 0.85, 1.0, 0.40)

# Palette Definitions: Reality B (Warm Sunset & Fractured Magenta)
const COLOR_B_SKY: Color = Color(1.10, 0.75, 0.90, 1.0)
const COLOR_B_DISTANT: Color = Color(1.05, 0.60, 0.80, 0.85)
const COLOR_B_MIDGROUND: Color = Color(1.05, 0.55, 0.70, 1.0)
const COLOR_B_NEAR: Color = Color(0.95, 0.50, 0.65, 1.0)
const COLOR_B_MIST: Color = Color(0.95, 0.30, 0.65, 0.45)

var _tween: Tween = null
var _reality_manager: Node = null

func _ready() -> void:
	# Ensure background renders strictly behind all gameplay geometry
	z_index = -100
	z_as_relative = false

	# Hook into confirmed global RealityManager singleton safely
	_reality_manager = get_node_or_null("/root/RealityManager")
	if _reality_manager:
		if _reality_manager.has_signal("reality_changed"):
			if not _reality_manager.reality_changed.is_connected(_on_reality_changed):
				_reality_manager.reality_changed.connect(_on_reality_changed)
		else:
			push_warning("[ParallaxBackdrop] RealityManager found at /root/RealityManager but lacks 'reality_changed' signal.")

		if _reality_manager.has_signal("transition_pulse"):
			if not _reality_manager.transition_pulse.is_connected(_on_transition_pulse):
				_reality_manager.transition_pulse.connect(_on_transition_pulse)
		else:
			push_warning("[ParallaxBackdrop] RealityManager found at /root/RealityManager but lacks 'transition_pulse' signal.")
		
		# Set initial state immediately on first frame
		var start_reality: int = int(_reality_manager.get("current_reality"))
		_apply_reality_palette(start_reality, 0.0)
	else:
		push_warning("[ParallaxBackdrop] RealityManager autoload not found at /root/RealityManager. Falling back to default Reality A.")
		_apply_reality_palette(0, 0.0)

func _exit_tree() -> void:
	# Cleanly disconnect signals to prevent duplicate connection warnings on scene re-entry / reload
	if _reality_manager and is_instance_valid(_reality_manager):
		if _reality_manager.has_signal("reality_changed") and _reality_manager.reality_changed.is_connected(_on_reality_changed):
			_reality_manager.reality_changed.disconnect(_on_reality_changed)
		if _reality_manager.has_signal("transition_pulse") and _reality_manager.transition_pulse.is_connected(_on_transition_pulse):
			_reality_manager.transition_pulse.disconnect(_on_transition_pulse)

func _on_reality_changed(new_reality: int) -> void:
	_apply_reality_palette(new_reality, transition_duration)

func _on_transition_pulse(intensity: float) -> void:
	# Subtle atmospheric luminescence surge during reality shift glitch
	if atmosphere_sprite:
		atmosphere_sprite.modulate.a = lerpf(0.35, 0.70, clampf(intensity, 0.0, 1.0))

## Smoothly tweens all background layers to target reality palette
func _apply_reality_palette(reality_index: int, duration: float) -> void:
	var is_reality_a: bool = (reality_index == 0)

	var target_sky: Color = COLOR_A_SKY if is_reality_a else COLOR_B_SKY
	var target_distant: Color = COLOR_A_DISTANT if is_reality_a else COLOR_B_DISTANT
	var target_midground: Color = COLOR_A_MIDGROUND if is_reality_a else COLOR_B_MIDGROUND
	var target_near: Color = COLOR_A_NEAR if is_reality_a else COLOR_B_NEAR
	var target_mist: Color = COLOR_A_MIST if is_reality_a else COLOR_B_MIST

	var moon_alpha: float = 1.0 if is_reality_a else 0.0
	var rift_alpha: float = 0.0 if is_reality_a else 1.0

	if duration <= 0.0:
		if sky_sprite: sky_sprite.modulate = target_sky
		if distant_sprite: distant_sprite.modulate = target_distant
		if midground_sprite: midground_sprite.modulate = target_midground
		if near_sprite: near_sprite.modulate = target_near
		if atmosphere_sprite: atmosphere_sprite.modulate = target_mist
		if moon_sprite: moon_sprite.modulate.a = moon_alpha
		if rift_sprite: rift_sprite.modulate.a = rift_alpha
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if sky_sprite:
		_tween.tween_property(sky_sprite, "modulate", target_sky, duration)
	if distant_sprite:
		_tween.tween_property(distant_sprite, "modulate", target_distant, duration)
	if midground_sprite:
		_tween.tween_property(midground_sprite, "modulate", target_midground, duration)
	if near_sprite:
		_tween.tween_property(near_sprite, "modulate", target_near, duration)
	if atmosphere_sprite:
		_tween.tween_property(atmosphere_sprite, "modulate", target_mist, duration)
	if moon_sprite:
		_tween.tween_property(moon_sprite, "modulate:a", moon_alpha, duration)
	if rift_sprite:
		_tween.tween_property(rift_sprite, "modulate:a", rift_alpha, duration)

## Integration helper: Allows external callers or test rigs to force a reality palette
func set_reality_palette(reality_index: int, duration: float = 0.45) -> void:
	_apply_reality_palette(reality_index, duration)
