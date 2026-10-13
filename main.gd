extends Node2D

## Main
## Level coordinator and facility architect for:
## "RESPAWN: PARALLAX — FRACTURED REALITIES".
## Builds a complete multi-chamber sci-fi research facility with natural movement testing,
## lethal lasers, rotatable mirrors, security drones, moving platforms, crumbling ledges,
## checkpoints, and dynamic HUD telemetry.

var reality_manager: Node = null
var player: CharacterBody2D = null
var backdrop: Node2D = null

# Chamber References
var chamber_doors: Array[PuzzleDoor] = []
var chamber_receivers: Array[LaserReceiver] = []
var chamber_mirrors: Array[LaserMirror] = []

# HUD References
var ui_layer: CanvasLayer = null
var reality_badge: PanelContainer = null
var reality_label: Label = null
var objective_label: Label = null
var chamber_title_label: Label = null
var checkpoint_banner: Label = null
var death_screen: CenterContainer = null
var victory_screen: CenterContainer = null
var pause_menu: CenterContainer = null

# Facility Progression Checkpoints (World coordinates)
var checkpoints: Array[Vector2] = [
	Vector2(140.0, 480.0),    # Chamber 1: Entry
	Vector2(780.0, 480.0),    # Chamber 2: Optical Matrix
	Vector2(1820.0, 480.0),   # Chamber 3: Drone Trench
	Vector2(2940.0, 480.0)    # Chamber 4: Reactor Vault
]

var _active_checkpoint_idx: int = 0
var _total_shifts: int = 0
var _level_timer: float = 0.0
var _checkpoint_banner_timer: float = 0.0
var _is_paused: bool = false

func _ready() -> void:
	_ensure_background()
	reality_manager = get_node_or_null("/root/RealityManager")
	if reality_manager:
		reality_manager.reality_changed.connect(_on_reality_changed)
		reality_manager.transition_pulse.connect(_on_reality_glitch)
		
	_build_facility_chambers()
	_spawn_player()
	_build_ui_hud()
	_update_hud_state()

func _ensure_background() -> void:
	backdrop = get_node_or_null("ParallaxBackdrop")
	if not backdrop:
		var scene: PackedScene = load("res://scenes/environment/parallax_backdrop.tscn")
		if scene:
			backdrop = scene.instantiate()
			backdrop.name = "ParallaxBackdrop"
			add_child(backdrop)
	if backdrop:
		move_child(backdrop, 0)

func _process(delta: float) -> void:
	_level_timer += delta
	if _checkpoint_banner_timer > 0.0:
		_checkpoint_banner_timer -= delta
		if checkpoint_banner:
			checkpoint_banner.modulate.a = clampf(_checkpoint_banner_timer * 2.0, 0.0, 1.0)
			
	_update_active_chamber_objective()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.physical_keycode == KEY_R:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE:
			_toggle_pause()

func _toggle_pause() -> void:
	_is_paused = not _is_paused
	get_tree().paused = _is_paused
	if pause_menu:
		pause_menu.visible = _is_paused

## ====================================================================
## FACILITY ARCHITECTURE GENERATION
## ====================================================================
func _build_facility_chambers() -> void:
	var facility: Node2D = Node2D.new()
	facility.name = "ResearchFacility"
	add_child(facility)

	# --- CHAMBER 1: Dimensional Calibration (X: 0 to 800) ---
	_build_chamber_1(facility)

	# --- CHAMBER 2: Optical Matrix & Mirror Puzzle (X: 800 to 1800) ---
	_build_chamber_2(facility)

	# --- CHAMBER 3: Surveillance Trench & Drones (X: 1800 to 2900) ---
	_build_chamber_3(facility)

	# --- CHAMBER 4: The Core Reactor Vault (X: 2900 to 3900) ---
	_build_chamber_4(facility)

## Chamber 1: Teaches natural movement and basic Q phase-switching
func _build_chamber_1(parent: Node2D) -> void:
	# Main floor & boundary walls
	_create_static_block(parent, Vector2(400, 560), Vector2(800, 60))
	_create_static_block(parent, Vector2(10, 280), Vector2(20, 620))
	_create_static_block(parent, Vector2(400, 10), Vector2(800, 20))

	# Starting spawn platform
	_create_static_block(parent, Vector2(160, 480), Vector2(240, 24))

	# Reality A Platform (Solid in Cyan)
	var plat_a: ShiftableObject = ShiftableObject.new()
	plat_a.name = "Chamber1_PlatA"
	plat_a.position = Vector2(380, 430)
	plat_a.object_size = Vector2(110, 22)
	plat_a.active_reality = RealityManager.Reality.REALITY_A
	parent.add_child(plat_a)

	# Reality B Platform (Solid in Magenta)
	var plat_b: ShiftableObject = ShiftableObject.new()
	plat_b.name = "Chamber1_PlatB"
	plat_b.position = Vector2(560, 370)
	plat_b.object_size = Vector2(110, 22)
	plat_b.active_reality = RealityManager.Reality.REALITY_B
	parent.add_child(plat_b)

	# Checkpoint 1 Terminal
	_create_checkpoint_trigger(parent, Vector2(760, 500), 1)

## Chamber 2: Lethal lasers and rotatable mirror redirection
func _build_chamber_2(parent: Node2D) -> void:
	# Floor with lethal bottom pit gap
	_create_static_block(parent, Vector2(1000, 560), Vector2(360, 60))
	_create_static_block(parent, Vector2(1600, 560), Vector2(360, 60))
	_create_static_block(parent, Vector2(1300, 10), Vector2(1000, 20))

	# 1. Safe optical puzzle laser (does NOT burn the player on touch)
	var emitter_c2: LaserEmitter = LaserEmitter.new()
	emitter_c2.name = "Chamber2_OpticalLaser"
	emitter_c2.position = Vector2(880, 360)
	emitter_c2.laser_direction = Vector2.RIGHT
	emitter_c2.burn_player_on_touch = false # Safe puzzle beam!
	emitter_c2.beam_color = Color(0.15, 0.85, 1.0)
	emitter_c2.mode = LaserEmitter.LaserMode.STATIC
	parent.add_child(emitter_c2)

	# 2. Lethal burning hazard laser in bottom pit trench (incinerates falls into the abyss)
	var emitter_hazard: LaserEmitter = LaserEmitter.new()
	emitter_hazard.name = "Chamber2_BurningLaserHazard"
	emitter_hazard.position = Vector2(1170, 570) # Positioned down in the pit chasm, safe on floor
	emitter_hazard.laser_direction = Vector2.RIGHT
	emitter_hazard.max_range = 260.0
	emitter_hazard.burn_player_on_touch = true # Lethal burning laser!
	emitter_hazard.beam_color = Color(1.0, 0.2, 0.35)
	emitter_hazard.mode = LaserEmitter.LaserMode.STATIC
	parent.add_child(emitter_hazard)

	# Shiftable barrier blocking direct laser path in Reality A
	var laser_blocker: ShiftableObject = ShiftableObject.new()
	laser_blocker.name = "Chamber2_LaserBlocker"
	laser_blocker.position = Vector2(1060, 360)
	laser_blocker.object_size = Vector2(36, 140)
	laser_blocker.active_reality = RealityManager.Reality.REALITY_A
	parent.add_child(laser_blocker)

	# Rotatable Mirror (Player presses [E] to redirect laser upward to receiver)
	var mirror_c2: LaserMirror = LaserMirror.new()
	mirror_c2.name = "Chamber2_Mirror"
	mirror_c2.position = Vector2(1240, 360)
	mirror_c2.mirror_angle_degrees = 90.0 # Initially vertical, needs 45 deg rotation to 135 deg!
	parent.add_child(mirror_c2)
	chamber_mirrors.append(mirror_c2)

	# Intermediate safe stepping ledge from Floor 1 (Y=530 -> Y=480 -> Walkway Y=438)
	_create_static_block(parent, Vector2(1110, 490), Vector2(70, 20))

	# Mirror access walkway so player can comfortably stand and interact with mirror
	_create_static_block(parent, Vector2(1240, 440), Vector2(180, 24))
	_create_static_block(parent, Vector2(1420, 480), Vector2(120, 24)) # Bridge step towards door

	# Overhead Optical Receiver (at Y = 140 above the mirror)
	var receiver_c2: LaserReceiver = LaserReceiver.new()
	receiver_c2.name = "Chamber2_Receiver"
	receiver_c2.position = Vector2(1240, 140)
	receiver_c2.receiver_size = Vector2(56, 56)
	parent.add_child(receiver_c2)
	chamber_receivers.append(receiver_c2)

	# Blast Door blocking passage to Chamber 3
	var door_c2: PuzzleDoor = PuzzleDoor.new()
	door_c2.name = "Chamber2_Door"
	door_c2.position = Vector2(1740, 480)
	door_c2.door_size = Vector2(28, 110)
	parent.add_child(door_c2)
	chamber_doors.append(door_c2)

	# Visual power conduit line from receiver to door along the ceiling
	var conduit: Line2D = Line2D.new()
	conduit.name = "Chamber2_Conduit"
	conduit.width = 3.0
	conduit.default_color = Color(0.2, 0.4, 0.55, 0.7)
	conduit.points = PackedVector2Array([
		Vector2(1240, 140),
		Vector2(1240, 35),
		Vector2(1740, 35),
		Vector2(1740, 425)
	])
	parent.add_child(conduit)

	# Wire receiver to blast door and conduit visual feedback
	receiver_c2.powered_changed.connect(door_c2.set_powered)
	receiver_c2.powered_changed.connect(func(is_pow: bool):
		if conduit and is_instance_valid(conduit):
			conduit.default_color = Color(0.25, 0.95, 0.65, 0.95) if is_pow else Color(0.2, 0.4, 0.55, 0.7)
	)

	# Checkpoint 2 Terminal
	_create_checkpoint_trigger(parent, Vector2(1820, 500), 2)

## Chamber 3: Surveillance trench, security drone, crumbling & moving platforms
func _build_chamber_3(parent: Node2D) -> void:
	# Trench floor and platforms
	_create_static_block(parent, Vector2(2000, 560), Vector2(320, 60))
	_create_static_block(parent, Vector2(2750, 560), Vector2(320, 60))
	_create_static_block(parent, Vector2(2350, 10), Vector2(1100, 20))

	# Moving Platform across middle trench
	var mover_c3: MovingPlatform = MovingPlatform.new()
	mover_c3.name = "Chamber3_Mover"
	mover_c3.position = Vector2(2120, 460)
	mover_c3.travel_offset = Vector2(160, 0)
	mover_c3.travel_duration = 3.2
	parent.add_child(mover_c3)

	# Crumbling Platform (Collapses upon step)
	var crumble_c3: CrumblingPlatform = CrumblingPlatform.new()
	crumble_c3.name = "Chamber3_Crumble"
	crumble_c3.position = Vector2(2420, 450)
	parent.add_child(crumble_c3)

	# Reality Cover Wall (Reality B Magenta - provides shelter from drone scan)
	var cover_wall: ShiftableObject = ShiftableObject.new()
	cover_wall.name = "Chamber3_Cover"
	cover_wall.position = Vector2(2300, 360)
	cover_wall.object_size = Vector2(36, 160)
	cover_wall.active_reality = RealityManager.Reality.REALITY_B
	parent.add_child(cover_wall)

	# Security Drone patrolling the airspace
	var drone_c3: SecurityDrone = SecurityDrone.new()
	drone_c3.name = "Chamber3_Drone"
	drone_c3.position = Vector2(2360, 300)
	drone_c3.patrol_distance = 180.0
	drone_c3.patrol_speed = 70.0
	parent.add_child(drone_c3)

	# Pressure Plate Switch opening security gate
	var switch_c3: PuzzleSwitch = PuzzleSwitch.new()
	switch_c3.name = "Chamber3_Switch"
	switch_c3.position = Vector2(2650, 530)
	switch_c3.is_toggle_type = true
	parent.add_child(switch_c3)

	# Security Gate 3
	var door_c3: PuzzleDoor = PuzzleDoor.new()
	door_c3.name = "Chamber3_Door"
	door_c3.position = Vector2(2850, 480)
	door_c3.door_size = Vector2(28, 110)
	parent.add_child(door_c3)
	chamber_doors.append(door_c3)

	switch_c3.toggled.connect(door_c3.set_powered)

	# Checkpoint 3 Terminal
	_create_checkpoint_trigger(parent, Vector2(2940, 500), 3)

## Chamber 4: The Core Reactor Vault (Climax Chamber)
func _build_chamber_4(parent: Node2D) -> void:
	# Vault floor and outer boundary
	_create_static_block(parent, Vector2(3400, 560), Vector2(1000, 60))
	_create_static_block(parent, Vector2(3900, 280), Vector2(20, 620)) # Final right wall
	_create_static_block(parent, Vector2(3400, 10), Vector2(1000, 20))

	# Timed Laser Hazard Grid (passes overhead at Y=330 with clear telegraph)
	var timed_laser: LaserEmitter = LaserEmitter.new()
	timed_laser.name = "Chamber4_TimedLaser"
	timed_laser.position = Vector2(3040, 330) # Adjusted up from 380 to prevent platform clipping
	timed_laser.laser_direction = Vector2.RIGHT
	timed_laser.mode = LaserEmitter.LaserMode.TIMED
	timed_laser.cycle_dormant_time = 1.8 # Generous 3.0s total safe window (1.8s dormant + 1.2s telegraph)
	timed_laser.cycle_telegraph_time = 1.2
	timed_laser.cycle_active_time = 1.5
	parent.add_child(timed_laser)

	# Rotating Sweep Laser (calibrated sweep angle creating safe observation zones on bridge perimeters)
	var sweep_laser: LaserEmitter = LaserEmitter.new()
	sweep_laser.name = "Chamber4_SweepLaser"
	sweep_laser.position = Vector2(3400, 160)
	sweep_laser.laser_direction = Vector2.DOWN
	sweep_laser.mode = LaserEmitter.LaserMode.ROTATING
	sweep_laser.sweep_angle_degrees = 25.0 # Calibrated from 35.0 to provide safe standing pockets
	sweep_laser.sweep_speed = 0.9 # Fair, readable rhythm
	parent.add_child(sweep_laser)

	# Dual Reality Elevated Bridges (Comfortably clear overhead timed laser at Y=330)
	var bridge_c4_a: ShiftableObject = ShiftableObject.new()
	bridge_c4_a.name = "Chamber4_BridgeA"
	bridge_c4_a.position = Vector2(3240, 440) # Platform surface at Y=429
	bridge_c4_a.object_size = Vector2(130, 22)
	bridge_c4_a.active_reality = RealityManager.Reality.REALITY_A
	parent.add_child(bridge_c4_a)

	var bridge_c4_b: ShiftableObject = ShiftableObject.new()
	bridge_c4_b.name = "Chamber4_BridgeB"
	bridge_c4_b.position = Vector2(3520, 395) # Platform surface at Y=384 (clear of Y=330 beam)
	bridge_c4_b.object_size = Vector2(130, 22)
	bridge_c4_b.active_reality = RealityManager.Reality.REALITY_B
	parent.add_child(bridge_c4_b)

	# Reactor Overload Terminal (Exit Portal)
	var exit_vault: Area2D = Area2D.new()
	exit_vault.name = "ReactorCoreTerminal"
	exit_vault.position = Vector2(3800, 480)
	var col: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(80, 110)
	col.shape = box
	exit_vault.add_child(col)

	var visual: ColorRect = ColorRect.new()
	visual.color = Color(0.1, 0.95, 0.6, 0.3)
	visual.size = Vector2(80, 110)
	visual.position = Vector2(-40, -55)
	exit_vault.add_child(visual)

	var lbl: Label = Label.new()
	lbl.text = "CORE\nTERMINAL"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-38, -20)
	exit_vault.add_child(lbl)

	exit_vault.body_entered.connect(_on_reactor_terminal_reached)
	parent.add_child(exit_vault)

## Helper to create solid dark sci-fi architecture blocks
func _create_static_block(parent: Node2D, pos: Vector2, size: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos
	
	var col: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	
	var rect_vis: ColorRect = ColorRect.new()
	rect_vis.color = Color(0.11, 0.13, 0.18)
	rect_vis.size = size
	rect_vis.position = -size / 2.0
	body.add_child(rect_vis)
	
	var border: ReferenceRect = ReferenceRect.new()
	border.border_color = Color(0.24, 0.28, 0.38)
	border.border_width = 1.5
	border.editor_only = false
	border.size = size
	border.position = -size / 2.0
	body.add_child(border)
	
	parent.add_child(body)

## Checkpoint terminal placement helper
func _create_checkpoint_trigger(parent: Node2D, pos: Vector2, idx: int) -> void:
	var trig: Area2D = Area2D.new()
	trig.name = "Checkpoint_%d" % idx
	trig.position = pos
	
	var col: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(48, 80)
	col.shape = box
	trig.add_child(col)
	
	trig.body_entered.connect(func(body):
		if body is CharacterBody2D and _active_checkpoint_idx < idx:
			_active_checkpoint_idx = idx
			if body.has_method("set_checkpoint"):
				body.call("set_checkpoint", pos)
			_show_checkpoint_banner("CHECKPOINT ACTIVATED — CHAMBER 0%d" % (idx + 1))
	)
	parent.add_child(trig)

func _spawn_player() -> void:
	player = PuzzlePlayer.new()
	player.name = "Player"
	player.position = checkpoints[0]
	player.player_died.connect(_on_player_died)
	player.player_respawned.connect(_on_player_respawned)
	add_child(player)
	# Add to group for easy lookup by Mirror and other systems
	player.add_to_group("player")

## ====================================================================
## SCI-FI HUD & GAME FEEL TELEMETRY
## ====================================================================
func _build_ui_hud() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "SciFiHUD"
	add_child(ui_layer)

	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	# Top Navigation Header Bar
	var top_bar: MarginContainer = MarginContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.add_theme_constant_override("margin_top", 14)
	top_bar.add_theme_constant_override("margin_left", 20)
	top_bar.add_theme_constant_override("margin_right", 20)
	root.add_child(top_bar)

	var hbox: HBoxContainer = HBoxContainer.new()
	top_bar.add_child(hbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "RESPAWN: PARALLAX"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	hbox.add_child(title_lbl)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Reality Indicator Badge (Cyan vs Magenta)
	reality_badge = PanelContainer.new()
	var b_style: StyleBoxFlat = StyleBoxFlat.new()
	b_style.bg_color = Color(0.08, 0.1, 0.15, 0.9)
	b_style.corner_radius_top_left = 6
	b_style.corner_radius_top_right = 6
	b_style.corner_radius_bottom_left = 6
	b_style.corner_radius_bottom_right = 6
	b_style.content_margin_left = 16
	b_style.content_margin_right = 16
	b_style.content_margin_top = 6
	b_style.content_margin_bottom = 6
	b_style.border_width_left = 2
	b_style.border_width_right = 2
	b_style.border_width_top = 2
	b_style.border_width_bottom = 2
	b_style.border_color = RealityManager.COLOR_REALITY_A_PRIMARY
	reality_badge.add_theme_stylebox_override("panel", b_style)
	hbox.add_child(reality_badge)

	reality_label = Label.new()
	reality_label.text = "REALITY A [CYAN]  —  [PRESS Q TO SHIFT]"
	reality_label.add_theme_font_size_override("font_size", 14)
	reality_label.add_theme_color_override("font_color", RealityManager.COLOR_REALITY_A_PRIMARY)
	reality_badge.add_child(reality_label)

	# Dynamic Objective Card (Top Left)
	var obj_box: VBoxContainer = VBoxContainer.new()
	obj_box.position = Vector2(24, 60)
	root.add_child(obj_box)

	chamber_title_label = Label.new()
	chamber_title_label.text = "CHAMBER 01: DIMENSIONAL CALIBRATION"
	chamber_title_label.add_theme_font_size_override("font_size", 12)
	chamber_title_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
	obj_box.add_child(chamber_title_label)

	objective_label = Label.new()
	objective_label.text = "• Objective: Master momentum & Phase Shift [Q] across chasms"
	objective_label.add_theme_font_size_override("font_size", 14)
	objective_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	obj_box.add_child(objective_label)

	# Checkpoint Pop-in Banner
	checkpoint_banner = Label.new()
	checkpoint_banner.text = "CHECKPOINT ACTIVATED"
	checkpoint_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	checkpoint_banner.position = Vector2(400, 120)
	checkpoint_banner.add_theme_font_size_override("font_size", 18)
	checkpoint_banner.add_theme_color_override("font_color", Color(0.2, 0.95, 0.6))
	checkpoint_banner.modulate.a = 0.0
	root.add_child(checkpoint_banner)

	# Death Screen Overlay
	death_screen = CenterContainer.new()
	death_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_screen.visible = false
	# Ensure overlay appears on top of UI
	death_screen.z_index = 1000
	root.add_child(death_screen)

	var death_panel: PanelContainer = PanelContainer.new()
	var d_style: StyleBoxFlat = StyleBoxFlat.new()
	d_style.bg_color = Color(0.12, 0.04, 0.06, 0.95)
	d_style.border_color = Color(1.0, 0.2, 0.3)
	d_style.border_width_left = 2
	d_style.border_width_right = 2
	d_style.border_width_top = 2
	d_style.border_width_bottom = 2
	d_style.content_margin_left = 32
	d_style.content_margin_right = 32
	d_style.content_margin_top = 20
	d_style.content_margin_bottom = 20
	death_panel.add_theme_stylebox_override("panel", d_style)
	death_screen.add_child(death_panel)

	var d_vbox: VBoxContainer = VBoxContainer.new()
	death_panel.add_child(d_vbox)

	var d_title: Label = Label.new()
	d_title.text = "GAME OVER"
	d_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d_title.add_theme_font_size_override("font_size", 30)
	d_title.add_theme_color_override("font_color", Color(1.0, 0.22, 0.35))
	d_vbox.add_child(d_title)

	var d_sub: Label = Label.new()
	d_sub.name = "DeathSubtitle"
	d_sub.text = "You fell into the abyss or were vaporized by a burning laser."
	d_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d_sub.add_theme_font_size_override("font_size", 14)
	d_sub.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	d_vbox.add_child(d_sub)

	var d_spacer: Control = Control.new()
	d_spacer.custom_minimum_size = Vector2(0, 10)
	d_vbox.add_child(d_spacer)

	var play_again_btn: Button = Button.new()
	play_again_btn.text = "PLAY AGAIN"
	play_again_btn.custom_minimum_size = Vector2(180, 42)
	play_again_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_again_btn.add_theme_font_size_override("font_size", 16)
	play_again_btn.pressed.connect(func():
		if player and is_instance_valid(player) and player.has_method("request_respawn"):
			player.call("request_respawn")
		death_screen.visible = false
	)
	d_vbox.add_child(play_again_btn)

	# Victory Overlay
	victory_screen = CenterContainer.new()
	victory_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	victory_screen.visible = false
	root.add_child(victory_screen)

	var vic_panel: PanelContainer = PanelContainer.new()
	var v_style: StyleBoxFlat = StyleBoxFlat.new()
	v_style.bg_color = Color(0.06, 0.12, 0.15, 0.95)
	v_style.border_color = Color(0.2, 0.95, 0.6)
	v_style.border_width_left = 3
	v_style.border_width_right = 3
	v_style.border_width_top = 3
	v_style.border_width_bottom = 3
	v_style.content_margin_left = 40
	v_style.content_margin_right = 40
	v_style.content_margin_top = 28
	v_style.content_margin_bottom = 28
	vic_panel.add_theme_stylebox_override("panel", v_style)
	victory_screen.add_child(vic_panel)

	var v_vbox: VBoxContainer = VBoxContainer.new()
	vic_panel.add_child(v_vbox)

	var v_title: Label = Label.new()
	v_title.text = "REACTOR CORE STABILIZED!"
	v_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_title.add_theme_font_size_override("font_size", 28)
	v_title.add_theme_color_override("font_color", Color(0.2, 0.95, 0.6))
	v_vbox.add_child(v_title)

	var v_desc: Label = Label.new()
	v_desc.text = "Dimensional breach neutralized. All chamber hazards cleared.\nPress [R] to replay facility test."
	v_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_desc.add_theme_font_size_override("font_size", 15)
	v_vbox.add_child(v_desc)

	# Bottom Controls Hint
	var bot_margin: MarginContainer = MarginContainer.new()
	bot_margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_margin.add_theme_constant_override("margin_bottom", 12)
	root.add_child(bot_margin)

	var hint_lbl: Label = Label.new()
	hint_lbl.text = "[A / D] Move   |   [W / Space] Jump   |   [Q] Shift Reality (Cyan / Magenta)   |   [E] Rotate Mirrors   |   [ESC] Pause"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	bot_margin.add_child(hint_lbl)

func _update_active_chamber_objective() -> void:
	if not player or not is_instance_valid(player):
		return
		
	var px: float = player.global_position.x
	if px < 800:
		chamber_title_label.text = "CHAMBER 01: DIMENSIONAL CALIBRATION"
		objective_label.text = "• Objective: Master momentum & Phase Shift [Q] across chasms"
	elif px < 1800:
		chamber_title_label.text = "CHAMBER 02: OPTICAL MATRIX & MIRRORS"
		objective_label.text = "• Objective: Phase out barrier, press [E] to rotate mirror and power blast door"
	elif px < 2900:
		chamber_title_label.text = "CHAMBER 03: SURVEILLANCE TRENCH"
		objective_label.text = "• Objective: Evade Security Drone using reality cover, traverse crumbling ledges"
	else:
		chamber_title_label.text = "CHAMBER 04: THE CORE REACTOR VAULT"
		objective_label.text = "• Objective: Navigate timed laser matrix and breach the Core Terminal"

func _show_checkpoint_banner(text: String) -> void:
	if checkpoint_banner:
		checkpoint_banner.text = text
		_checkpoint_banner_timer = 2.0

func _on_reality_changed(_new_reality: RealityManager.Reality) -> void:
	_total_shifts += 1
	_update_hud_state()

func _on_reality_glitch(intensity: float) -> void:
	if reality_badge:
		reality_badge.scale = Vector2.ONE * (1.0 + intensity * 0.1)

func _update_hud_state() -> void:
	if not reality_manager or not reality_label:
		return
		
	var is_a: bool = reality_manager.is_reality_a()
	var theme_col: Color = reality_manager.get_theme_color()
	
	reality_label.text = "%s  —  [PRESS Q TO SHIFT]" % reality_manager.get_reality_name()
	reality_label.add_theme_color_override("font_color", theme_col)
	
	if reality_badge:
		var st: StyleBoxFlat = reality_badge.get_theme_stylebox("panel") as StyleBoxFlat
		if st:
			st.border_color = theme_col

func _on_player_died(_reason: String) -> void:
	if death_screen:
		death_screen.visible = true

func _on_player_respawned() -> void:
	if death_screen:
		death_screen.visible = false

func _on_reactor_terminal_reached(body: Node2D) -> void:
	if body is PuzzlePlayer or body.name == "Player":
		if victory_screen:
			victory_screen.visible = true
			if SoundManager.instance:
				SoundManager.instance.play_checkpoint()
