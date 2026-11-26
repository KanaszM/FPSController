@icon("resources/icons/fps_controller.svg")
class_name FPSController extends CharacterBody3D

#region Constants
const PACK_UID: StringName = &"uid://dlsx5ttt5rpdj"

const MIN_STEP_HEIGHT: float = 0.01
const MIN_JUMP_CEILING_CLEARANCE: float = 0.001
#endregion

#region Signals
signal updated(state: bool)
signal disabled_changed(state: bool)
signal jumped
signal landed(fall_distance: float, impact_amplitude: float)
signal movement_started
signal movement_stopped
signal move_type_changed(move_type: FPSControllerData.MoveType)
#endregion

#region Exports
@export var data: FPSControllerData
@export var camera_data: FPSControllerCameraData

@export_group("Camera", "camera_")
@export var camera_independent_input: bool: set = _set_camera_independent_input
@export var camera_sync_motion: bool = true: set = _set_camera_sync_motion

@export_group("Movement", "movement_")
@export var movement_follows_camera: bool = true
@export var movement_requires_current_camera: bool = true
@export var movement_requires_mouse_capture: bool = true
#endregion

#region Public References
@onready var camera_rig := %CameraRig as FPSControllerCamera
@onready var camera := camera_rig.camera as Camera3D
@onready var hands := camera_rig.hands as FPSControllerHands

@onready var collision := %Collision as CollisionShape3D
@onready var ray_ceiling_above := %RayCeilingAbove as RayCast3D
#endregion

#region Private Variables
var _is_initialized: bool
var _is_disabled: bool
var _is_moving: bool
var _is_grounded: bool

var _step_snapped: bool

var _toggled_walk: bool
var _toggled_run: bool

var _current_move_type: FPSControllerData.MoveType = FPSControllerData.MoveType.NORMAL
var _current_speed: float

var _jump_cooldown_remaining: float

var _fall_tracking: bool
var _fall_peak: float

var _light_omni: OmniLight3D
var _light_spot: SpotLight3D
#endregion

#region Public Methods
static func instantiate(
	data_reference: FPSControllerData = null,
	camera_data_reference: FPSControllerCameraData = null,
	) -> FPSController:
		var pack: PackedScene = load(PACK_UID) as PackedScene
		
		if pack == null or not pack.can_instantiate():
			push_error(
				"FPSController scene could not be loaded: %s!"
				% ResourceUID.get_id_path(ResourceUID.text_to_id((PACK_UID)))
				)
			return null
		
		var instance := pack.instantiate() as FPSController
		
		if instance == null:
			push_error("FPSController scene must have an FPSController root!")
			return null
		
		instance.data = data_reference
		instance.camera_data = camera_data_reference
		
		return instance


func update() -> void:
	if not is_node_ready():
		return
	
	#region Data Check
	if data == null:
		data = FPSControllerData.new()
	
	if camera_data == null:
		camera_data = FPSControllerCameraData.new()
	
	camera_rig.data = camera_data
	#endregion
	
	#region Initialization
	if not _is_initialized:
		_is_disabled = data.general_start_disabled
		_is_initialized = true
	#endregion
	
	#region Collision Update
	if (
		data.collision_radius <= 0.0
		or data.collision_height < data.collision_radius * 2.0
		or not is_finite(data.collision_radius)
		or not is_finite(data.collision_height)
		):
			push_error("FPSController capsule height must be at least twice its positive radius!")
			
			set_physics_process(false)
			set_process_unhandled_input(false)
			camera_rig.set_input_blocked(true)
			
			if camera.is_current() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				set_mouse_captured(false)
			
			updated.emit(false)
			return
	
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	
	capsule.radius = data.collision_radius
	capsule.height = data.collision_height
	
	collision.shape = capsule
	collision.position = Vector3(0.0, data.collision_height / 2.0, 0.0)
	collision_layer = data.collision_layer
	collision_mask = data.collision_mask
	#endregion
	
	#region Light Update
	var remove_omni_light: bool = (
		data.light_mode == FPSControllerData.LightMode.DISABLED
		or data.light_mode == FPSControllerData.LightMode.SPOT
		)
	var remove_spot_light: bool = (
		data.light_mode == FPSControllerData.LightMode.DISABLED
		or data.light_mode == FPSControllerData.LightMode.OMNI
		)
	var add_omni_light: bool = data.light_mode == FPSControllerData.LightMode.OMNI
	var add_spot_light: bool = data.light_mode == FPSControllerData.LightMode.SPOT
	
	for child: Node in get_children():
		if child is OmniLight3D:
			_light_omni = child as OmniLight3D
		
		elif child is SpotLight3D:
			_light_spot = child as SpotLight3D
	
	if remove_omni_light and _light_omni != null:
		_light_omni.queue_free()
	
	if remove_spot_light and _light_spot != null:
		_light_spot.queue_free()
	
	if add_omni_light:
		if _light_omni == null:
			_light_omni = OmniLight3D.new()
			add_child(_light_omni)
		
		_light_omni.light_color = data.light_color
		_light_omni.light_energy = data.light_size
		_light_omni.position.y = data.light_height
	
	if add_spot_light:
		if _light_spot == null:
			_light_spot = SpotLight3D.new()
			add_child(_light_spot)
		
		_light_spot.light_color = data.light_color
		_light_spot.light_energy = data.light_size
		_light_spot.position.y = data.light_height
	#endregion
	
	#region Ray and Snapping Update
	ray_ceiling_above.position.y = data.collision_height
	ray_ceiling_above.target_position = (
		Vector3.UP * maxf(MIN_JUMP_CEILING_CLEARANCE, data.jump_ceiling_clearance)
		)
	ray_ceiling_above.collision_mask = collision_mask
	ray_ceiling_above.add_exception(self)
	floor_snap_length = maxf(0.0, data.step_max_height) if data.step_enabled else 0.1
	#endregion
	
	#region Resets
	_toggled_walk = false
	_toggled_run = false
	_step_snapped = false
	_fall_tracking = false
	
	_jump_cooldown_remaining = 0.0
	_current_speed = maxf(0.0, data.move_speed_normal)
	_set_movement_state(false, FPSControllerData.MoveType.NORMAL)
	#endregion
	
	#region Camera Update
	if camera_rig.follow_parent:
		camera_rig.position.y = data.camera_eye_height
	
	camera_rig.update()
	camera_rig.set_input_blocked(_is_disabled and not camera_independent_input)
	#endregion
	
	set_physics_process(true)
	set_process_unhandled_input(true)
	updated.emit(true)


func set_disabled(state: bool) -> void:
	if _is_disabled == state:
		return
	
	_is_disabled = state
	_toggled_walk = false
	_toggled_run = false
	
	if is_node_ready():
		camera_rig.set_input_blocked(state and not camera_independent_input)
	
	if state:
		velocity.x = 0.0
		velocity.z = 0.0
		
		if is_node_ready():
			_set_movement_state(false, FPSControllerData.MoveType.NORMAL)
	
	disabled_changed.emit(state)


func is_disabled() -> bool:
	return _is_disabled


func is_grounded() -> bool:
	return _is_grounded


func is_moving() -> bool:
	return _is_moving


func get_move_type() -> FPSControllerData.MoveType:
	return _current_move_type


func get_current_speed() -> float:
	return _current_speed


func get_current_bobbing_origin() -> Vector3:
	return camera_rig.get_bobbing_origin()


func set_mouse_captured(state: bool) -> void:
	camera_rig.set_mouse_captured(state)


func attach_to_hands(
	attachment: Node3D,
	attachment_transform: Transform3D = Transform3D.IDENTITY,
	) -> bool:
		return hands.attach_node(attachment, attachment_transform)


func instantiate_in_hands(
	attachment_scene: PackedScene,
	attachment_transform: Transform3D = Transform3D.IDENTITY,
	) -> Node3D:
		return hands.instantiate_attachment(attachment_scene, attachment_transform)


func detach_from_hands(attachment: Node3D) -> Node3D:
	return hands.detach_node(attachment)


func shake_camera(strength: float, duration: float = 0.25) -> void:
	camera_rig.shake(strength, duration)
#endregion

#region Private Methods
func _ready() -> void:
	camera_rig.set_input_blocked(
		(_is_disabled if _is_initialized else data != null and data.general_start_disabled)
		and not camera_independent_input
		)
	
	update()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_initialized or not _can_receive_input():
		return
	
	if data.move_walk_toggled and _event_pressed(event, data.input_walk):
		_toggled_walk = not _toggled_walk
		
		if _toggled_walk:
			_toggled_run = false
	
	if data.move_run_toggled and _event_pressed(event, data.input_run):
		_toggled_run = not _toggled_run
		
		if _toggled_run:
			_toggled_walk = false


func _physics_process(delta: float) -> void:
	var was_grounded: bool = is_on_floor() or _step_snapped
	var previous_height: float = global_position.y
	var previous_camera_height: float = camera_rig.get_step_height()
	var flying: bool = data.fall_fly_enabled
	
	_is_grounded = was_grounded
	_jump_cooldown_remaining = maxf(0.0, _jump_cooldown_remaining - delta)
	
	if data.fall_enabled and not flying:
		velocity += get_gravity() * maxf(0.0, data.fall_weight) * delta
	
	_process_movement(delta, was_grounded)
	_process_jump(was_grounded)
	_step_snapped = false
	
	if not flying and data.step_enabled:
		_step_snapped = _try_step_up(delta, was_grounded)
	
	if not _step_snapped:
		move_and_slide()
		
		if data.step_enabled and not flying and was_grounded and velocity.y <= 0.0:
			apply_floor_snap()
	
	_is_grounded = (is_on_floor() or _step_snapped) and not flying
	
	if _is_grounded and velocity.y < 0.0:
		velocity.y = 0.0
	
	if data.step_enabled and was_grounded and _is_grounded and not flying:
		var height_difference: float = absf(global_position.y - previous_height)
		
		if height_difference > MIN_STEP_HEIGHT and camera_sync_motion:
			camera_rig.smooth_step_from(previous_camera_height)
	
	_process_landing(was_grounded, flying)
	
	if camera_sync_motion:
		camera_rig.set_motion_state(velocity, _is_grounded, _is_moving, _current_speed)


func _process_movement(delta: float, was_grounded: bool) -> void:
	var input_direction: Vector2 = Vector2.ZERO
	
	if _can_receive_input() and data.move_enabled:
		input_direction = Vector2(
			_action_strength(data.input_move_right) - _action_strength(data.input_move_left),
			_action_strength(data.input_move_backward) - _action_strength(data.input_move_forward)
			).limit_length()
	
	var moving: bool = not input_direction.is_zero_approx()
	var requested_type: FPSControllerData.MoveType = FPSControllerData.MoveType.NORMAL
	var walking: bool = _toggled_walk if data.move_walk_toggled else _action_held(data.input_walk)
	var running: bool = _toggled_run if data.move_run_toggled else _action_held(data.input_run)
	
	if moving and (was_grounded or data.fall_fly_enabled):
		if running and data.move_run_enabled:
			requested_type = FPSControllerData.MoveType.RUN
		
		elif walking and data.move_walk_enabled:
			requested_type = FPSControllerData.MoveType.WALK
	
	_set_movement_state(moving, requested_type)
	
	var target_fov: float = camera_rig.data.camera_fov_normal
	
	_current_speed = maxf(0.0, data.move_speed_normal)

	match _current_move_type:
		FPSControllerData.MoveType.WALK:
			_current_speed = maxf(0.0, data.move_speed_walk)
			target_fov = camera_rig.data.camera_fov_walk
		
		FPSControllerData.MoveType.RUN:
			_current_speed = maxf(0.0, data.move_speed_run)
			target_fov = camera_rig.data.camera_fov_run
	
	var move_basis: Basis = global_basis
	
	if movement_follows_camera:
		move_basis = camera.global_basis if data.fall_fly_enabled else camera_rig.get_yaw_basis()
	
	var move_direction: Vector3 = move_basis * Vector3(input_direction.x, 0.0, input_direction.y)
	
	if not data.fall_fly_enabled:
		move_direction.y = 0.0
	
	if not move_direction.is_zero_approx():
		move_direction = move_direction.normalized() * input_direction.length()
	
	var target_velocity: Vector3 = move_direction * _current_speed
	var transition_speed: float = data.move_acceleration if moving else data.move_friction
	var transition_weight: float = 1.0 - exp(-maxf(0.0, transition_speed) * delta)
	
	velocity.x = lerpf(velocity.x, target_velocity.x, transition_weight)
	velocity.z = lerpf(velocity.z, target_velocity.z, transition_weight)
	
	if data.fall_fly_enabled:
		velocity.y = lerpf(velocity.y, target_velocity.y, transition_weight)
	
	if camera_sync_motion and camera_rig.movement_fov_enabled:
		camera_rig.set_target_fov(target_fov)


func _process_jump(was_grounded: bool) -> void:
	if (
		not _can_receive_input() or not data.move_enabled or not data.jump_enabled
		or data.fall_fly_enabled or not was_grounded or _jump_cooldown_remaining > 0.0
		):
			return
	
	if not InputMap.has_action(data.input_jump):
		return
	
	var jump_requested: bool = (
		Input.is_action_pressed(data.input_jump)
		if data.jump_continuous else Input.is_action_just_pressed(data.input_jump)
		)
	
	ray_ceiling_above.force_raycast_update()
	
	if not jump_requested or ray_ceiling_above.is_colliding():
		return
	
	velocity.y = maxf(0.0, data.jump_velocity)
	_jump_cooldown_remaining = maxf(0.0, data.jump_cooldown)
	jumped.emit()


func _try_step_up(delta: float, was_grounded: bool) -> bool:
	var step_height: float = maxf(0.0, data.step_max_height)
	var horizontal_motion: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * delta
	
	if (
		not was_grounded or velocity.y > 0.0 or step_height <= MIN_STEP_HEIGHT
		or horizontal_motion.is_zero_approx()
		):
			return false
	
	if not test_move(global_transform, horizontal_motion):
		return false
	
	var upward_motion: Vector3 = Vector3.UP * step_height
	
	if test_move(global_transform, upward_motion):
		return false
	
	var raised_transform: Transform3D = global_transform.translated(upward_motion)
	
	if test_move(raised_transform, horizontal_motion):
		return false
	
	raised_transform.origin += horizontal_motion
	
	var step_collision: KinematicCollision3D = KinematicCollision3D.new()
	
	if not test_move(raised_transform, -upward_motion, step_collision):
		return false
	
	if not step_collision.get_collider() is StaticBody3D:
		return false
	
	var probe_start: Vector3 = (
		step_collision.get_position() + upward_motion + horizontal_motion.normalized() * 0.1
		)
	var surface_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		probe_start, probe_start - upward_motion * 2.0, collision_mask, [get_rid()]
		)
	var surface_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(surface_query)
	
	if surface_hit.is_empty():
		return false
	
	if surface_hit.normal.angle_to(up_direction) > floor_max_angle:
		return false
	
	var target_position: Vector3 = raised_transform.origin + step_collision.get_travel()
	var detected_height: float = target_position.y - global_position.y
	
	if detected_height <= MIN_STEP_HEIGHT or detected_height > step_height:
		return false
	
	global_position = target_position
	velocity.y = 0.0
	apply_floor_snap()
	
	return true


func _process_landing(was_grounded: bool, flying: bool) -> void:
	if flying:
		_fall_tracking = false
		return
	
	if not _is_grounded:
		if not _fall_tracking:
			_fall_peak = global_position.y
			_fall_tracking = true
		
		_fall_peak = maxf(_fall_peak, global_position.y)
		return
	
	if not was_grounded and _fall_tracking:
		var fall_distance: float = maxf(0.0, _fall_peak - global_position.y)
		var impact_amplitude: float = clampf(
			fall_distance * maxf(0.0, data.fall_impact_amplitude_multiplier),
			0.0, maxf(0.0, data.fall_impact_max_amplitude)
			)
		
		if data.fall_impact_enabled and fall_distance >= data.fall_impact_min_height:
			if camera_sync_motion:
				camera_rig.animate_landing(impact_amplitude)
			
			landed.emit(fall_distance, impact_amplitude)
	
	_fall_tracking = false


func _set_movement_state(moving: bool, requested_type: FPSControllerData.MoveType) -> void:
	var previous_moving: bool = _is_moving
	var previous_type: FPSControllerData.MoveType = _current_move_type
	
	_is_moving = moving
	_current_move_type = requested_type
	
	if previous_moving != _is_moving:
		if _is_moving:
			movement_started.emit()
		
		else:
			movement_stopped.emit()
	
	if previous_type != _current_move_type:
		move_type_changed.emit(_current_move_type)


func _can_receive_input() -> bool:
	return (
		not _is_disabled
		and (not movement_requires_current_camera or camera.is_current())
		and (not movement_requires_mouse_capture or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
		)


func _action_strength(action_name: StringName) -> float:
	return Input.get_action_strength(action_name) if InputMap.has_action(action_name) else 0.0


func _action_held(action_name: StringName) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_pressed(action_name)


func _event_pressed(event: InputEvent, action_name: StringName) -> bool:
	return (
		InputMap.has_action(action_name)
		and event.is_action_pressed(action_name)
		and not event.is_echo()
		)


func _set_camera_independent_input(state: bool) -> void:
	camera_independent_input = state
	
	if is_node_ready():
		camera_rig.set_input_blocked(_is_disabled and not state)


func _set_camera_sync_motion(state: bool) -> void:
	camera_sync_motion = state
	
	if is_node_ready() and not state:
		camera_rig.set_motion_state(Vector3.ZERO, false, false)
#endregion
