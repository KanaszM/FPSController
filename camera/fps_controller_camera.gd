@icon("../resources/icons/fps_controller_camera.svg")
class_name FPSControllerCamera extends Node3D

#region Constants
const PACK_UID: StringName = &"uid://b16xsdj61gw6d"

const MAX_ANGLE: float = 89.0
const MAX_FOV: float = 179.0

const MIN_LANDING_IMPACT: float = 0.001
const MIN_BOBBING_SMOOTHING: float = 0.001
const MIN_HORIZONTAL_SPEED: float = 0.01

const PIVOT_BOBBING_POWER: float = -10.0
const SHAKE_INTERVAL: float = 30.0
const SHAKE_NOISE_STEP_1: float = 100.0
const SHAKE_NOISE_STEP_2: float = 200.0
#endregion

#region Signals
signal updated
signal look_changed(look_angles: Vector2)
#endregion

#region Exports
@export var data: FPSControllerCameraData

@export var camera_current: bool = true: set = _set_camera_current
@export var follow_parent: bool = true: set = _set_follow_parent
@export var effects_enabled: bool = true: set = _set_effects_enabled

@export_group("Input", "input_")
@export var input_enabled: bool = true

@export_group("Capture", "capture_")
@export var capture_mouse_on_ready: bool = true
@export var capture_mouse_on_click: bool = true

@export_group("Movement", "movement_")
@export var movement_fov_enabled: bool = true
#endregion

#region Public References
@onready var camera_rotation_h := %CameraRotationH as Node3D
@onready var camera_rotation_v := %CameraRotationV as Node3D
@onready var camera_pivot_stepping := %CameraPivotStepping as Node3D
@onready var camera_pivot_landing := %CameraPivotLanding as Node3D
@onready var camera_pivot_bobbing := %CameraPivotBobbing as Node3D
@onready var camera_pivot_shake := %CameraPivotShake as Node3D
@onready var camera := %Camera as Camera3D
@onready var hands := %Hands as FPSControllerHands
#endregion

#region Private Variables
var _input_is_blocked: bool

var _motion_velocity: Vector3
var _motion_grounded: bool
var _motion_moving: bool
var _motion_speed: float

var _fov_target: float
var _bobbing_distance: float
var _tween_landing: Tween

var _shake_noise: FastNoiseLite
var _shake_time: float
var _shake_strength: float
var _shake_remaining: float
var _shake_duration: float
#endregion

#region Public Methods
static func instantiate(camera_data: FPSControllerCameraData = null) -> FPSControllerCamera:
	var pack: PackedScene = load(PACK_UID) as PackedScene
	
	if pack == null or not pack.can_instantiate():
		push_error(
			"FPSControllerCamera scene could not be loaded: %s!"
			% ResourceUID.get_id_path(ResourceUID.text_to_id((PACK_UID)))
			)
		return null
	
	var instance: FPSControllerCamera = pack.instantiate() as FPSControllerCamera
	
	if instance == null:
		push_error("FPSControllerCamera scene must have an FPSControllerCamera root!")
		instance.free()
		return null
	
	instance.data = camera_data
	return instance


func update() -> void:
	if not is_node_ready():
		return
	
	if data == null:
		data = FPSControllerCameraData.new()
	
	set_target_fov(data.camera_fov_normal, true)
	set_look(get_look())
	reset_effects()
	
	updated.emit()


func set_input_blocked(state: bool) -> void:
	_input_is_blocked = state


func set_mouse_captured(state: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if state else Input.MOUSE_MODE_VISIBLE


func get_look() -> Vector2:
	return Vector2(camera_rotation_h.rotation.y, camera_rotation_v.rotation.x)


func set_look(look_angles: Vector2) -> void:
	camera_rotation_h.rotation.y = look_angles.x
	camera_rotation_v.rotation.x = clampf(
		look_angles.y,
		-deg_to_rad(clampf(data.look_vertical_limit_down, 0.0, MAX_ANGLE)),
		deg_to_rad(clampf(data.look_vertical_limit_up, 0.0, MAX_ANGLE))
		)
	look_changed.emit(get_look())


func look(look_delta: Vector2) -> void:
	set_look(get_look() + look_delta)


func get_yaw_basis() -> Basis:
	return camera_rotation_h.global_basis


func set_target_fov(field_of_view: float, instant: bool = false) -> void:
	_fov_target = clampf(field_of_view, 1.0, MAX_FOV)
	
	if instant:
		camera.fov = clampf(_fov_target + data.camera_fov_modifier, 1.0, MAX_FOV)


func set_motion_state(
	motion_velocity: Vector3,
	grounded: bool,
	moving: bool,
	selected_speed: float = 0.0,
	) -> void:
		_motion_velocity = motion_velocity
		_motion_grounded = grounded
		_motion_moving = moving
		_motion_speed = maxf(0.0, selected_speed)


func get_bobbing_origin() -> Vector3:
	return camera_pivot_bobbing.position


func get_step_height() -> float:
	return camera_pivot_stepping.global_position.y


func smooth_step_from(previous_height: float) -> void:
	if effects_enabled and data.step_smoothing_enabled and follow_parent:
		camera_pivot_stepping.global_position.y = previous_height


func animate_landing(impact_amplitude: float) -> void:
	if not effects_enabled or not data.fall_impact_tween_enabled or impact_amplitude <= 0.0:
		return
	
	_reset_landing()
	
	_tween_landing = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween_landing.tween_property(
		camera_pivot_landing, ^"position:y", -impact_amplitude,
		maxf(MIN_LANDING_IMPACT, data.fall_impact_contact_duration)
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_landing.tween_property(
		camera_pivot_landing, ^"position:y", 0.0,
		maxf(MIN_LANDING_IMPACT, data.fall_impact_rest_duration)
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func shake(strength: float, duration: float = 0.25) -> void:
	if not effects_enabled or strength <= 0.0 or duration <= 0.0:
		return
	
	if _shake_noise == null:
		_shake_noise = FastNoiseLite.new()
		_shake_noise.seed = randi()
		_shake_noise.frequency = 1.0
	
	_shake_strength = maxf(_shake_strength, strength)
	_shake_remaining = maxf(_shake_remaining, duration)
	_shake_duration = _shake_remaining


func reset_effects() -> void:
	camera_pivot_stepping.position = Vector3.ZERO
	camera_pivot_bobbing.position = Vector3.ZERO
	camera_pivot_shake.position = Vector3.ZERO
	
	_bobbing_distance = 0.0
	_shake_remaining = 0.0
	_shake_strength = 0.0
	
	_reset_landing()
#endregion

#region Private Methods
func _ready() -> void:
	follow_parent = follow_parent
	update()
	camera.current = camera_current
	
	if capture_mouse_on_ready and _can_receive_input(false):
		set_mouse_captured(true)


func _unhandled_input(event: InputEvent) -> void:
	if not is_node_ready() or not camera.is_current():
		return
	
	if (
		InputMap.has_action(data.input_release_mouse)
		and event.is_action_pressed(data.input_release_mouse)
		and not event.is_echo()
		):
			set_mouse_captured(false)
			get_viewport().set_input_as_handled()
			return
	
	if not _can_receive_input(false):
		return
	
	if (
		capture_mouse_on_click
		and event is InputEventMouseButton
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		and event.is_pressed()
		and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
		):
			set_mouse_captured(true)
			get_viewport().set_input_as_handled()
			return
	
	if event is InputEventMouseMotion and data.look_enabled and _can_receive_input():
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		var look_delta: Vector2 = -mouse_motion.screen_relative * maxf(0.0, data.look_speed)
		
		if data.look_invert_horizontal_axis:
			look_delta.x = -look_delta.x
		
		if data.look_invert_vertical_axis:
			look_delta.y = -look_delta.y
		
		look(look_delta)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	camera.fov = lerpf(
		camera.fov, clampf(_fov_target + data.camera_fov_modifier, 1.0, MAX_FOV),
		1.0 - exp(-maxf(0.0, data.camera_fov_transition_speed) * delta)
		)
	
	if effects_enabled:
		_process_step_camera(delta)
		_process_bobbing(delta)
		_process_shake(delta)


func _can_receive_input(require_capture: bool = true) -> bool:
	return (
		input_enabled and not _input_is_blocked and camera.is_current()
		and (not require_capture or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
		)


func _process_step_camera(delta: float) -> void:
	if not data.step_smoothing_enabled:
		camera_pivot_stepping.position = Vector3.ZERO
		return
	
	var smoothing_limit: float = maxf(0.0, data.step_max_smoothing)
	var smoothing_speed: float = maxf(
		Vector2(_motion_velocity.x, _motion_velocity.z).length(), _motion_speed / 2.0
		)
	
	camera_pivot_stepping.position.y = move_toward(
		clampf(camera_pivot_stepping.position.y, -smoothing_limit, smoothing_limit),
		0.0,
		maxf(0.1, smoothing_speed) * delta
		)


func _process_bobbing(delta: float) -> void:
	var horizontal_speed: float = Vector2(_motion_velocity.x, _motion_velocity.z).length()
	var target_offset: Vector3
	
	if (
		data.bob_enabled
		and _motion_grounded
		and _motion_moving
		and horizontal_speed > MIN_HORIZONTAL_SPEED
		):
			_bobbing_distance += horizontal_speed * delta
			
			var frequency: float = _bobbing_distance * maxf(0.0, data.bob_frequency)
			
			target_offset = Vector3(
				sin(frequency / maxf(MIN_BOBBING_SMOOTHING, data.bob_smoothing_horizontal)),
				cos(frequency / maxf(MIN_BOBBING_SMOOTHING, data.bob_smoothing_vertical)),
				0.0
				) * maxf(0.0, data.bob_amplitude)
	
	camera_pivot_bobbing.position = camera_pivot_bobbing.position.lerp(
		target_offset, 1.0 - exp(PIVOT_BOBBING_POWER * delta)
		)


func _process_shake(delta: float) -> void:
	_shake_remaining = maxf(0.0, _shake_remaining - delta)
	
	if _shake_remaining <= 0.0:
		_shake_strength = 0.0
		camera_pivot_shake.position = Vector3.ZERO
		return
	
	_shake_time += delta * SHAKE_INTERVAL
	
	var intensity: float = _shake_strength * _shake_remaining / _shake_duration
	
	camera_pivot_shake.position = Vector3(
		_shake_noise.get_noise_1d(_shake_time),
		_shake_noise.get_noise_1d(_shake_time + SHAKE_NOISE_STEP_1),
		_shake_noise.get_noise_1d(_shake_time + SHAKE_NOISE_STEP_2)
		) * intensity


func _reset_landing() -> void:
	if _tween_landing != null and _tween_landing.is_valid():
		_tween_landing.kill()
	
	camera_pivot_landing.position = Vector3.ZERO


func _set_camera_current(state: bool) -> void:
	camera_current = state
	
	if is_node_ready():
		camera.current = state


func _set_follow_parent(state: bool) -> void:
	follow_parent = state
	
	if is_inside_tree():
		var previous_pose: Transform3D = global_transform
		
		top_level = not state
		global_transform = previous_pose


func _set_effects_enabled(state: bool) -> void:
	effects_enabled = state
	
	if is_node_ready() and not state:
		reset_effects()
#endregion
