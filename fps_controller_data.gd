@icon("resources/icons/fps_controller_data.svg")
class_name FPSControllerData extends Resource

#region Enums
enum MoveType {NORMAL, WALK, RUN}
#endregion

#region Exports
@export_group("General", "general_")
@export var general_start_disabled: bool

@export_group("Collision", "collision_")
@export_range(0.01, 2.0, 0.01, "or_greater") var collision_radius: float = 0.45
@export_range(0.02, 4.0, 0.01, "or_greater") var collision_height: float = 1.95
@export_flags_3d_physics var collision_layer: int = 1
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Moving", "move_")
@export var move_enabled: bool = true
@export_range(0.0, 50.0, 0.01, "or_greater") var move_acceleration: float = 2.5
@export_range(0.0, 50.0, 0.01, "or_greater") var move_friction: float = 5.0

@export_subgroup("Walking", "move_walk_")
@export var move_walk_enabled: bool = true
@export var move_walk_toggled: bool

@export_subgroup("Running", "move_run_")
@export var move_run_enabled: bool = true
@export var move_run_toggled: bool

@export_subgroup("Speeds", "move_speed_")
@export_range(0.0, 25.0, 0.01, "or_greater") var move_speed_normal: float = 5.0
@export_range(0.0, 25.0, 0.01, "or_greater") var move_speed_walk: float = 2.0
@export_range(0.0, 25.0, 0.01, "or_greater") var move_speed_run: float = 10.0

@export_group("Jumping", "jump_")
@export var jump_enabled: bool = true
@export var jump_continuous: bool
@export_range(0.0, 50.0, 0.01, "or_greater") var jump_velocity: float = 10.0
@export_range(0.0, 1.0, 0.001, "or_greater") var jump_cooldown: float = 0.25
@export_range(0.0, 1.0, 0.01, "or_greater") var jump_ceiling_clearance: float = 0.15

@export_group("Camera", "camera_")
@export_range(0.01, 4.0, 0.01, "or_greater") var camera_eye_height: float = 1.7

@export_group("Stepping", "step_")
@export var step_enabled: bool = true
@export_range(0.0, 2.0, 0.01, "or_greater") var step_max_height: float = 0.3

@export_group("Falling", "fall_")
@export var fall_enabled: bool = true
@export var fall_fly_enabled: bool
@export_range(0.0, 10.0, 0.001, "or_greater") var fall_weight: float = 2.0

@export_subgroup("Impact", "fall_impact_")
@export var fall_impact_enabled: bool = true
@export_range(0.0, 10.0, 0.01, "or_greater") var fall_impact_min_height: float = 0.3
@export_range(0.0, 1.0, 0.001) var fall_impact_max_amplitude: float = 0.45
@export_range(0.0, 1.0, 0.001, "or_greater") var fall_impact_amplitude_multiplier: float = 0.225

@export_group("Input", "input_")
@export var input_move_left: StringName = &"fps_move_left"
@export var input_move_right: StringName = &"fps_move_right"
@export var input_move_forward: StringName = &"fps_move_forward"
@export var input_move_backward: StringName = &"fps_move_backward"
@export var input_walk: StringName = &"fps_walk"
@export var input_run: StringName = &"fps_run"
@export var input_jump: StringName = &"fps_jump"
#endregion
