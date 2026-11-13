# Scripting reference

[Documentation map](index.md) | [Next: Coordinates and effects](coordinates-and-effects.md)

This reference covers the current public API, not older revisions. Instantiate
the supplied scenes; `.new()` does not construct required child hierarchies.
Normal onready references and methods using them require a ready scene.

## Factories and readiness

| Static method | Result |
| --- | --- |
| `FPSController.instantiate(controller_data = null, camera_data = null)` | Character scene with optional resources assigned |
| `FPSControllerCamera.instantiate(camera_data = null)` | Independent camera scene with optional resource assigned |

Both factories load `PACK_UID`; Godot must have imported the scenes. Both return
their class type or null on load failure. The character's non-null `camera_data`
branch currently calls a removed accessor: see
[initialization caveats](troubleshooting.md#current-source-initialization-caveats).
Do not rely on that branch until the underlying refactor is corrected.

Set node export options before `add_child()`, and access normal onready fields
after readiness. Current character `_enter_tree()` also has an onready ordering
issue, so the example below is a normal post-initialization integration pattern,
not a workaround for it.

## FPSController

### Public references

| Reference | Type | Meaning |
| --- | --- | --- |
| `camera_rig` | `FPSControllerCamera` | Instanced rig |
| `camera` | `Camera3D` | Actual rendering camera |
| `hands` | `FPSControllerHands` | Rig attachment anchor |
| `collision` | `CollisionShape3D` | Runtime capsule |
| `ray_ceiling_above` | `RayCast3D` | Jump clearance ray |

### Methods

| Method | Result / behavior |
| --- | --- |
| `update()` | Apply capsule, masks, eye height, snap, movement resets, and rig update |
| `set_disabled(state: bool)` | Lock/unlock input; locking immediately zeros X/Z velocity |
| `is_disabled() -> bool` | Current node input lock |
| `is_grounded() -> bool` | Last computed floor/step state; false in flight |
| `is_moving() -> bool` | Accepted nonzero movement input |
| `get_move_type() -> FPSControllerData.MoveType` | `NORMAL`, `WALK`, or `RUN` |
| `get_current_speed() -> float` | Selected mode speed, not measured speed |
| `get_current_bobbing_origin() -> Vector3` | Rig bobbing-pivot local offset |
| `set_mouse_captured(state: bool)` | Forward explicit global mouse-mode change |
| `attach_to_hands(attachment: Node3D, attachment_transform = Transform3D.IDENTITY) -> bool` | Forward existing-node attachment |
| `instantiate_in_hands(attachment_scene: PackedScene, attachment_transform = Transform3D.IDENTITY) -> Node3D` | Instance/attach a custom scene |
| `detach_from_hands(attachment: Node3D) -> Node3D` | Detach without freeing; null when invalid |
| `shake_camera(strength: float, duration: float = 0.25)` | Forward fading positional shake |

Inherited `velocity` is the requested/slide-adjusted body velocity.
Inherited `get_real_velocity()` measures actual motion. The body does not expose
a dedicated teleport/reset API: after changing transform, consider whether to
clear `velocity` and reset camera effects/fall tracking.

### Signals

| Signal | Trigger |
| --- | --- |
| `updated(state: bool)` | True after configuration; false for invalid capsule dimensions |
| `disabled_changed(state: bool)` | Disabled flag actually changes |
| `jumped` | Jump velocity applied |
| `landed(fall_distance: float, impact_amplitude: float)` | Impact enabled and measured fall reaches threshold |
| `movement_started` | Input-driven moving state becomes true |
| `movement_stopped` | Input-driven moving state becomes false |
| `move_type_changed(move_type: FPSControllerData.MoveType)` | Selected movement mode changes |

Connect before a later explicit `update()` if you need that update's result.
A parent connecting in its `_ready()` will normally miss the child's initial
update signal because children become ready first.

```gdscript
extends Node3D

@onready var controller: FPSController = $FPSController

func _ready() -> void:
	controller.landed.connect(_on_landed)

func _on_landed(fall_distance: float, impact_amplitude: float) -> void:
	print("Landing distance: %s; visual amplitude: %s" % [
		fall_distance, impact_amplitude
	])
```

Attach gameplay effects here rather than adding game-global dependencies to the
controller. `landed` is not emitted for every tiny floor contact.

## FPSControllerCamera

### Public references

All are ready-time references: `camera_rotation_h`, `camera_rotation_v`,
`camera_pivot_stepping`, `camera_pivot_landing`, `camera_pivot_bobbing`,
`camera_pivot_shake` (`Node3D`); `camera` (`Camera3D`); and `hands`
(`FPSControllerHands`).

Prefer the rig's methods to editing procedural pivot offsets directly: its
physics processing will otherwise overwrite those offsets.

### Methods

| Method | Behavior |
| --- | --- |
| `update()` | Create missing Data, apply normal FOV, clamp pitch, clear effects, emit `updated` |
| `set_input_blocked(state: bool)` | Apply an external input lock; does not change `input_enabled` |
| `set_mouse_captured(state: bool)` | Set global mouse mode to captured/visible |
| `get_look() -> Vector2` | Local yaw/pitch in radians |
| `set_look(look_angles: Vector2)` | Set yaw and clamped pitch, emit `look_changed` |
| `look(look_delta: Vector2)` | Add radians to current yaw/pitch |
| `get_yaw_basis() -> Basis` | World basis of horizontal look pivot |
| `set_target_fov(field_of_view: float, instant: bool = false)` | Store target; optionally apply target plus modifier immediately |
| `set_motion_state(motion_velocity: Vector3, grounded: bool, moving: bool, selected_speed: float = 0.0)` | Supply bobbing and step-recovery inputs |
| `get_bobbing_origin() -> Vector3` | Current local bobbing offset |
| `get_step_height() -> float` | Current world Y of step pivot |
| `smooth_step_from(previous_height: float)` | Preserve previous step-pivot world Y when effects/smoothing/following permit |
| `animate_landing(impact_amplitude: float)` | Play enabled positive-amplitude landing dip |
| `shake(strength: float, duration: float = 0.25)` | Add fading positional noise if effects enabled and inputs positive |
| `reset_effects()` | Clear procedural offsets, bob phase, shake state, and landing tween |

`reset_effects()` does not reset yaw/pitch, FOV target, or motion-state feed.
If moving input remains supplied, bobbing starts again on subsequent frames.

`set_motion_state()` is a persistent latest-state feed, not a one-frame impulse.
Send a stationary state when your external motion stops. `selected_speed` assists
step recovery when actual horizontal speed is low.

### Signals

| Signal | Trigger |
| --- | --- |
| `updated` | Rig configuration reapplied |
| `look_changed(look_angles: Vector2)` | `set_look()`/`look()` or mouse look changes/reapplies angles |

Update calls `set_look()`, so `look_changed` can be emitted even if the numerical
angles did not change.

## FPSControllerHands

| Method | Behavior |
| --- | --- |
| `attach_node(attachment: Node3D, attachment_transform = Transform3D.IDENTITY) -> bool` | Validate, reparent, and apply local pose |
| `instantiate_attachment(attachment_scene: PackedScene, attachment_transform = Transform3D.IDENTITY) -> Node3D` | Instance a Node3D-root scene and attach it |
| `detach_node(attachment: Node3D) -> Node3D` | Remove direct child without freeing |
| `get_attachments() -> Array[Node3D]` | Direct, nonqueued Node3D children |
| `clear_attachments()` | Detach and queue-free all returned attachments |

Signals are `attachment_added(attachment: Node3D)` and
`attachment_removed(attachment: Node3D)`. See [Hands](hands.md) for reparenting,
world-pose preservation, rejection, and lifetime semantics.

## Removed APIs from earlier revisions

The current code no longer defines `get_camera_rig()`, `get_camera()`,
`get_hands()`, or `input_add_default_actions`. Use ready public references and
configure the Input Map in the host project. Scene factories now use UIDs rather
than a script-relative scene filename.
