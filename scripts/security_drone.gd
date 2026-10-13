class_name SecurityDrone
extends Node2D

## SecurityDrone
## Autonomous airborne patrol drone for "Respawn: Parallax — Fractured Realities".
## Features waypoint hovering, line-of-sight vision cone detection, alert telegraphing,
## cover/reality stealth evasion, and lethal plasma burst discharge.

enum DroneState {
	PATROL,
	ALERT,
	FIRING,
	COOLDOWN
}

@export var patrol_distance: float = 240.0
@export var patrol_speed: float = 75.0
@export var vision_range: float = 220.0
@export var vision_angle_degrees: float = 50.0
@export var active_reality: int = -1 # -1 = active in both realities

var current_state: DroneState = DroneState.PATROL

var _origin_pos: Vector2 = Vector2.ZERO
var _target_dir: float = 1.0 # 1 = right, -1 = left
var _hover_time: float = 0.0
var _alert_timer: float = 0.0
var _beam_timer: float = 0.0
var _detected_player: CharacterBody2D = null

func _ready() -> void:
	_origin_pos = global_position

func _physics_process(delta: float) -> void:
	_hover_time += delta
	
	# Reality check
	var rm: Node = get_node_or_null("/root/RealityManager")
	if rm and active_reality != -1:
		if rm.current_reality != active_reality:
			visible = false
			return
	visible = true

	match current_state:
		DroneState.PATROL:
			_process_patrol(delta)
			_scan_for_player()
		DroneState.ALERT:
			_process_alert(delta)
		DroneState.FIRING:
			_process_firing(delta)
		DroneState.COOLDOWN:
			_alert_timer -= delta
			if _alert_timer <= 0.0:
				current_state = DroneState.PATROL
				
	queue_redraw()

func _process_patrol(delta: float) -> void:
	# Horizontal patrol movement with sine-wave hovering bob
	var current_offset: float = global_position.x - _origin_pos.x
	if _target_dir > 0.0 and current_offset >= patrol_distance:
		_target_dir = -1.0
	elif _target_dir < 0.0 and current_offset <= -patrol_distance:
		_target_dir = 1.0
		
	global_position.x += _target_dir * patrol_speed * delta
	global_position.y = _origin_pos.y + sin(_hover_time * 3.5) * 6.0

func _scan_for_player() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_parent().get_node_or_null("Player")
	if not player or not is_instance_valid(player):
		return
		
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	
	if dist > vision_range:
		return
		
	# Check vision cone angle relative to facing direction
	var forward: Vector2 = Vector2(_target_dir, 0.0)
	var angle_to: float = abs(forward.angle_to(to_player))
	
	if angle_to <= deg_to_rad(vision_angle_degrees * 0.5):
		# Line-of-sight raycast check (player can hide behind walls/cover)
		var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
		var result: Dictionary = space.intersect_ray(query)
		
		if not result.is_empty() and result["collider"] == player:
			# Player spotted! Enter Alert
			current_state = DroneState.ALERT
			_alert_timer = 0.65 # Telegraph duration
			_detected_player = player as CharacterBody2D
			if SoundManager.instance:
				SoundManager.instance.play_drone_alert()

func _process_alert(delta: float) -> void:
	_alert_timer -= delta
	
	# Verify player is still in line of sight
	if _detected_player and is_instance_valid(_detected_player):
		var to_player: Vector2 = _detected_player.global_position - global_position
		if to_player.x * _target_dir < 0: # Turn towards player
			_target_dir = signf(to_player.x)
			
		var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, _detected_player.global_position)
		var result: Dictionary = space.intersect_ray(query)
		
		if result.is_empty() or result["collider"] != _detected_player:
			# Lost line of sight (player used cover or shifted reality)!
			current_state = DroneState.COOLDOWN
			_alert_timer = 0.5
			return
			
	if _alert_timer <= 0.0:
		# Fire lethal discharge!
		current_state = DroneState.FIRING
		_beam_timer = 0.25
		if _detected_player and is_instance_valid(_detected_player):
			if _detected_player.has_method("die"):
				_detected_player.call("die", "drone_attack")

func _process_firing(delta: float) -> void:
	_beam_timer -= delta
	if _beam_timer <= 0.0:
		current_state = DroneState.COOLDOWN
		_alert_timer = 1.0

func _draw() -> void:
	var forward: Vector2 = Vector2(_target_dir, 0.0)
	var half_cone: float = deg_to_rad(vision_angle_degrees * 0.5)
	
	# 1. Vision Detection Cone
	var cone_color: Color
	if current_state == DroneState.ALERT:
		var blink: float = (sin(_hover_time * 30.0) + 1.0) * 0.5
		cone_color = Color(1.0, 0.1, 0.2, 0.25 + blink * 0.25)
	else:
		cone_color = Color(0.1, 0.8, 1.0, 0.12)
		
	var cone_pts: PackedVector2Array = [Vector2.ZERO]
	var steps: int = 12
	for i in range(steps + 1):
		var a: float = -half_cone + (float(i) / float(steps)) * (half_cone * 2.0)
		cone_pts.append(forward.rotated(a) * vision_range)
	draw_polygon(cone_pts, [cone_color, cone_color, cone_color, cone_color, cone_color, cone_color, cone_color, cone_color, cone_color, cone_color, cone_color, cone_color, cone_color, cone_color])
	
	# 2. Drone Chassis (Sci-Fi Surveillance Hovercraft)
	var chassis_col: Color = Color(0.18, 0.21, 0.28)
	draw_circle(Vector2.ZERO, 14.0, chassis_col)
	draw_arc(Vector2.ZERO, 14.0, 0, TAU, 16, Color(0.35, 0.42, 0.55), 2.0)
	
	# Thruster Pods (Top & Bottom)
	draw_rect(Rect2(-8, -18, 16, 5), Color(0.28, 0.32, 0.42), true)
	draw_rect(Rect2(-8, 13, 16, 5), Color(0.28, 0.32, 0.42), true)
	
	# Central Optical Sensor Eye
	var eye_col: Color = Color(1.0, 0.2, 0.3) if (current_state == DroneState.ALERT or current_state == DroneState.FIRING) else Color(0.1, 0.85, 1.0)
	draw_circle(Vector2(_target_dir * 5, 0), 5.5, eye_col)
	draw_circle(Vector2(_target_dir * 5, 0), 2.0, Color.WHITE)
	
	# Lethal Energy Discharge Beam
	if current_state == DroneState.FIRING and _detected_player and is_instance_valid(_detected_player):
		var target_local: Vector2 = to_local(_detected_player.global_position)
		draw_line(Vector2.ZERO, target_local, Color(1.0, 0.2, 0.3, 0.9), 6.0)
		draw_line(Vector2.ZERO, target_local, Color.WHITE, 2.0)
