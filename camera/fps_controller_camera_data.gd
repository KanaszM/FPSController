@icon("../resources/icons/fps_controller_camera_data.svg")
class_name FPSControllerCameraData extends Resource

#region Exports
@export_group("Looking", "look_")
@export var look_enabled: bool = true
@export var look_invert_horizontal_axis: bool
@export var look_invert_vertical_axis: bool
@export_range(0.0, 0.02, 0.0001, "or_greater") var look_speed: float = 0.005
@export_range(0.0, 89.0, 1.0, "degrees") var look_vertical_limit_up: float = 80.0
@export_range(0.0, 89.0, 1.0, "degrees") var look_vertical_limit_down: float = 60.0

@export_group("Camera", "camera_")
@export_range(1.0, 179.0, 0.1, "degrees") var camera_fov_normal: float = 65.0
@export_range(1.0, 179.0, 0.1, "degrees") var camera_fov_walk: float = 60.0
@export_range(1.0, 179.0, 0.1, "degrees") var camera_fov_run: float = 75.0
@export_range(-100.0, 100.0, 0.1) var camera_fov_modifier: float
@export_range(0.0, 20.0, 0.01, "or_greater") var camera_fov_transition_speed: float = 5.0

@export_group("Bobbing", "bob_")
@export var bob_enabled: bool = true
@export_range(0.0, 10.0, 0.001) var bob_frequency: float = 2.0
@export_range(0.0, 1.0, 0.001) var bob_amplitude: float = 0.08
@export_range(0.001, 10.0, 0.01) var bob_smoothing_horizontal: float = 2.0
@export_range(0.001, 10.0, 0.01) var bob_smoothing_vertical: float = 1.0

@export_group("Stepping", "step_")
@export var step_smoothing_enabled: bool = true
@export_range(0.0, 2.0, 0.001, "or_greater") var step_max_smoothing: float = 0.7

@export_group("Landing", "fall_impact_")
@export var fall_impact_tween_enabled: bool = true
@export_range(0.001, 1.0, 0.001, "or_greater") var fall_impact_contact_duration: float = 0.05
@export_range(0.001, 2.0, 0.001, "or_greater") var fall_impact_rest_duration: float = 0.75

@export_group("Input", "input_")
@export var input_release_mouse: StringName = &"fps_release_mouse"
#endregion
