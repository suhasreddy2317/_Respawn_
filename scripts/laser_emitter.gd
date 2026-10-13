class_name LaserEmitter
extends Node2D

## LaserEmitter
## High-energy physics optical projector for:
## "Respawn: Parallax — Fractured Realities".
## Supports static beams, rotating sweeps, timed telegraph pulses, mouse aiming,
## prismatic mirror reflections, and optical receiver activation.
## Features configurable 'burn_player_on_touch' property (some lasers burn, some are safe optical beams).

enum LaserMode {
	STATIC,
	ROTATING,
	TIMED,
	MOUSE_AIMED
}

@export var mode: LaserMode = LaserMode.STATIC
@export var laser_direction: Vector2 = Vector2.RIGHT
@export var max_range: float = 1400.0

## When TRUE, touching this laser burns and vaporizes the player.
## When FALSE, this is a safe optical beam that does NOT harm the player.
@export var burn_player_on_touch: bool = true

## Core beam color (defaults to burning crimson or cool azure depending on lethality)
@export var beam_color: Color = Color(1.0, 0.22, 0.38, 1.0)
@export var max_bounces: int = 3

# Timed Mode Parameters
@export var cycle_dormant_time: float = 1.0
@export var cycle_telegraph_time: float = 1.2
@export var cycle_active_time: float = 1.8

# Rotating Mode Parameters
@export var sweep_speed: float = 1.2
@export var sweep_angle_degrees: float = 45.0

# Reality restriction (-1 = both realities)
@export var active_in_reality: int = -1

var _time_accumulator: float = 0.0
var _is_firing: bool = true
var _is_telegraphing: bool = false
var _segments: Array[Dictionary] = []
var _base_direction: Vector2 = Vector2.RIGHT
var _spark_time: float = 0.0

func _ready() -> void:
	_base_direction = laser_direction.normalized()
	# If non-burning optical laser and default ruby color, tint to calm azure
	if not burn_player_on_touch and beam_color == Color(1.0, 0.22, 0.38, 1.0):
		beam_color = Color(0.15, 0.85, 1.0, 1.0)

func _physics_process(delta: float) -> void:
	_spark_time += delta
	_time_accumulator += delta
	
	# Reality check
	var rm: Node = get_node_or_null("/root/RealityManager")
	if rm and active_in_reality != -1:
		if rm.current_reality != active_in_reality:
			_is_firing = false
			_is_telegraphing = false
			_segments.clear()
			queue_redraw()
			return

	# Handle Laser Modes
	match mode:
		LaserMode.STATIC:
			_is_firing = true
			_is_telegraphing = false
		LaserMode.MOUSE_AIMED:
			_is_firing = true
			_is_telegraphing = false
			var to_mouse: Vector2 = get_global_mouse_position() - global_position
			if to_mouse.length() > 5.0:
				laser_direction = to_mouse.normalized()
		LaserMode.ROTATING:
			_is_firing = true
			_is_telegraphing = false
			var angle_offset: float = sin(_time_accumulator * sweep_speed) * deg_to_rad(sweep_angle_degrees)
			laser_direction = _base_direction.rotated(angle_offset)
		LaserMode.TIMED:
			var total_cycle: float = cycle_dormant_time + cycle_telegraph_time + cycle_active_time
			var phase: float = fmod(_time_accumulator, total_cycle)
			if phase < cycle_dormant_time:
				_is_firing = false
				_is_telegraphing = false
			elif phase < cycle_dormant_time + cycle_telegraph_time:
				_is_firing = false
				_is_telegraphing = true
			else:
				_is_firing = true
				_is_telegraphing = false

	if not _is_firing and not _is_telegraphing:
		_segments.clear()
		queue_redraw()
		return

	_cast_laser_chain()
	queue_redraw()

func _cast_laser_chain() -> void:
	_segments.clear()
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if not space_state:
		return

	var current_origin: Vector2 = global_position
	var current_dir: Vector2 = laser_direction.normalized()
	var remaining_dist: float = max_range
	var bounces_left: int = max_bounces
	var excluded_rids: Array[RID] = []

	while bounces_left >= 0 and remaining_dist > 5.0:
		var target_pos: Vector2 = current_origin + current_dir * remaining_dist
		
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			current_origin + current_dir * 3.0,
			target_pos
		)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = excluded_rids
		
		var result: Dictionary = space_state.intersect_ray(query)
		
		if result.is_empty():
			_segments.append({
				"start": to_local(current_origin),
				"end": to_local(target_pos),
				"is_hit": false,
				"hit_point": target_pos
			})
			break
		else:
			var hit_pos: Vector2 = result["position"]
			var collider: Object = result["collider"]
			
			_segments.append({
				"start": to_local(current_origin),
				"end": to_local(hit_pos),
				"is_hit": true,
				"hit_point": hit_pos
			})
			
			if _is_firing:
				# Trigger optical receiver
				if collider.has_method("receive_laser_hit"):
					collider.call("receive_laser_hit")
				elif collider is Node and (collider as Node).get_parent() and (collider as Node).get_parent().has_method("receive_laser_hit"):
					(collider as Node).get_parent().call("receive_laser_hit")
					
				# BURN CHECK: Only burns the player if burn_player_on_touch is enabled!
				if burn_player_on_touch and collider is CharacterBody2D:
					if collider.has_method("die"):
						collider.call("die", "laser_burn")
			
			# Check Mirror Reflection
			if collider is LaserMirror or (collider is Node and (collider as Node).get_parent() is LaserMirror):
				var mirror: LaserMirror = collider if collider is LaserMirror else (collider as Node).get_parent() as LaserMirror
				var reflected_dir: Vector2 = mirror.get_reflection(current_dir)
				var traveled: float = current_origin.distance_to(hit_pos)
				remaining_dist -= traveled
				current_origin = hit_pos
				current_dir = reflected_dir
				bounces_left -= 1
				excluded_rids = [mirror.get_rid()]
			else:
				break

func _draw() -> void:
	var forward: Vector2 = laser_direction.normalized()
	var normal: Vector2 = Vector2(-forward.y, forward.x)
	var cannon_col: Color = Color(0.24, 0.28, 0.36)
	
	# Cannon mount geometry
	var base_pts: PackedVector2Array = [
		-forward * 14.0 - normal * 10.0,
		forward * 10.0 - normal * 6.0,
		forward * 10.0 + normal * 6.0,
		-forward * 14.0 + normal * 10.0
	]
	draw_polygon(base_pts, [cannon_col, cannon_col, cannon_col, cannon_col])
	
	# Border color reflects lethality: Red = Burning, Cyan = Safe Optical
	var trim_col: Color = Color(1.0, 0.3, 0.3) if burn_player_on_touch else Color(0.3, 0.85, 1.0)
	draw_polyline(base_pts, trim_col, 1.5)
	
	# Telegraph indicator
	if _is_telegraphing:
		var blink: float = (sin(_spark_time * 24.0) + 1.0) * 0.5
		var tele_color: Color = beam_color
		tele_color.a = 0.2 + blink * 0.4
		for seg in _segments:
			draw_line(seg["start"], seg["end"], tele_color, 2.0)
		return

	if not _is_firing or _segments.is_empty():
		return

	# Draw beam segments
	for seg in _segments:
		var p1: Vector2 = seg["start"]
		var p2: Vector2 = seg["end"]
		
		# 1. Outer radiant corona
		var outer_col: Color = beam_color
		outer_col.a = 0.25
		draw_line(p1, p2, outer_col, 10.0 if burn_player_on_touch else 6.0)
		
		# 2. Main coherent beam
		var mid_col: Color = beam_color
		mid_col.a = 0.85
		draw_line(p1, p2, mid_col, 4.0 if burn_player_on_touch else 3.0)
		
		# 3. Core white plasma
		draw_line(p1, p2, Color(1.0, 1.0, 1.0, 0.95), 1.5)
		
		# Hit point effect: crackling burning sparks if lethal, calm lens flare if safe
		if seg["is_hit"]:
			var flare_r: float = 6.0 + sin(_spark_time * 28.0) * 2.0
			draw_circle(p2, flare_r, beam_color)
			draw_circle(p2, flare_r * 0.4, Color.WHITE)
			
			if burn_player_on_touch:
				# Extra burning hazard sparks
				var spark_ang: float = _spark_time * 20.0
				var spark_off: Vector2 = Vector2(cos(spark_ang), sin(spark_ang)) * (flare_r + 3.0)
				draw_circle(p2 + spark_off, 1.5, Color.WHITE)
