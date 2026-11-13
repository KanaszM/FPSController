# Configuration reference

[Documentation map](index.md) | [Next: Scripting reference](scripting.md)

Defaults below come from the current scripts. Boolean properties without an
initializer default to false; float properties without one default to `0.0`.
Inspector ranges are editing hints, not a guarantee that arbitrary scripted
values are safe. Prefer finite, physically meaningful values.

## FPSController node

| Property | Default | Purpose |
| --- | --- | --- |
| `data` | null | `FPSControllerData`; created on update if missing |
| `camera_independent_input` | false | Keep rig input available when character disabled |
| `camera_sync_motion` | true | Feed rig movement state, FOV, steps, and landing animation |
| `movement_follows_camera` | true | Camera-relative rather than character-relative movement |
| `movement_requires_current_camera` | true | Reject movement with an inactive camera |
| `movement_requires_mouse_capture` | true | Reject movement with an uncaptured cursor |

The last three affect character movement/jump/toggle input, not rig mouse look.
Turning motion synchronization off sends a stationary motion state to the rig.

## FPSControllerData

### General and collision

| Property | Default | Meaning |
| --- | --- | --- |
| `general_start_disabled` | false | Initial input-disabled state; read on first successful update |
| `collision_radius` | 0.45 | Capsule radius; Inspector starts at 0.01 |
| `collision_height` | 1.95 | Total capsule height; must be at least twice radius |
| `collision_layer` | 1 | Character physics layer bitmask |
| `collision_mask` | 1 | Physics layers the character detects |
| `camera_eye_height` | 1.7 | Rig local Y applied on character update when following |

Invalid/nonfinite capsule dimensions emit `updated(false)`, disable character
physics/unhandled input, and block rig input. Correct dimensions and call
`update()` to re-enable processing. Eye height is independent of capsule height.

### Moving

| Property | Default | Meaning |
| --- | --- | --- |
| `move_enabled` | true | Accept movement and jump requests |
| `move_acceleration` | 2.5 | Velocity response rate while movement requested |
| `move_friction` | 5.0 | Velocity response rate without movement request |
| `move_walk_enabled` | true | Allow WALK selection |
| `move_walk_toggled` | false | Toggle walking instead of holding action |
| `move_run_enabled` | true | Allow RUN selection |
| `move_run_toggled` | false | Toggle running instead of holding action |
| `move_speed_normal` | 5.0 | NORMAL target speed |
| `move_speed_walk` | 2.0 | WALK target speed |
| `move_speed_run` | 10.0 | RUN target speed |

Speeds are units/second; acceleration/friction are exponential response rates.
Run wins over held walk if both are eligible. See [movement](movement.md).

### Jumping

| Property | Default | Meaning |
| --- | --- | --- |
| `jump_enabled` | true | Allow jump requests |
| `jump_continuous` | false | Repeated held-action jumping rather than just-pressed |
| `jump_velocity` | 10.0 | Upward velocity applied on jump |
| `jump_cooldown` | 0.25 | Seconds before another jump can be accepted |
| `jump_ceiling_clearance` | 0.15 | Upward ceiling ray length; minimum used is 0.001 |

### Stepping and falling

| Property | Default | Meaning |
| --- | --- | --- |
| `step_enabled` | true | Custom stair climbing and associated snap setting |
| `step_max_height` | 0.3 | Maximum stair rise and enabled floor-snap length |
| `fall_enabled` | true | Apply inherited/project gravity |
| `fall_fly_enabled` | false | Camera/body-directed flight; suppress gravity/jump |
| `fall_weight` | 2.0 | Nonnegative multiplier for gravity |
| `fall_impact_enabled` | true | Enable qualifying landing signals and animation requests |
| `fall_impact_min_height` | 0.3 | Minimum measured fall distance for impact |
| `fall_impact_max_amplitude` | 0.45 | Cap for landing dip amplitude |
| `fall_impact_amplitude_multiplier` | 0.225 | Convert fall distance to visual dip amplitude |

Landing animation timings/enabling live in camera Data. Character
`fall_impact_enabled` is also the gate for `landed`, not just a visual option.

### Input names

| Property | Default StringName |
| --- | --- |
| `input_move_left` | `fps_move_left` |
| `input_move_right` | `fps_move_right` |
| `input_move_forward` | `fps_move_forward` |
| `input_move_backward` | `fps_move_backward` |
| `input_walk` | `fps_walk` |
| `input_run` | `fps_run` |
| `input_jump` | `fps_jump` |

The host must configure the Input Map. No automatic registration is present.

## FPSControllerCamera node

| Property | Default | Purpose |
| --- | --- | --- |
| `data` | null | `FPSControllerCameraData`; created on update if missing |
| `camera_current` | true | Set the nested camera's current state at readiness/on assignment |
| `follow_parent` | true | Inherit parent transform; false uses top-level world transform |
| `effects_enabled` | true | Enable visual offsets; false clears them immediately |
| `input_enabled` | true | Allow automatic mouse look and click capture |
| `capture_mouse_on_ready` | true | Capture on readiness when current and input permitted |
| `capture_mouse_on_click` | true | Capture on unhandled left-button press |
| `movement_fov_enabled` | true | Permit character-driven FOV updates |

`input_enabled` does not stop scripted `look()`/`set_look()` commands or the
release-mouse action. `effects_enabled` does not stop FOV smoothing.
The current rig has no input-binding installer.

## FPSControllerCameraData

### Looking

| Property | Default | Meaning |
| --- | --- | --- |
| `look_enabled` | true | Handle captured mouse-motion look |
| `look_invert_horizontal_axis` | false | Reverse horizontal mouse delta |
| `look_invert_vertical_axis` | false | Reverse vertical mouse delta |
| `look_speed` | 0.005 | Radians per screen-relative mouse unit |
| `look_vertical_limit_up` | 80.0 | Maximum positive pitch, degrees |
| `look_vertical_limit_down` | 60.0 | Magnitude of maximum negative pitch, degrees |

Pitch-limit magnitudes are clamped to `0..89` internally. The methods accepting
look angles use radians, not these Inspector degree units.

### FOV

| Property | Default | Meaning |
| --- | --- | --- |
| `camera_fov_normal` | 65.0 | Normal movement target, degrees |
| `camera_fov_walk` | 60.0 | Walk movement target, degrees |
| `camera_fov_run` | 75.0 | Run movement target, degrees |
| `camera_fov_modifier` | 0.0 | Additive modifier applied to the stored target |
| `camera_fov_transition_speed` | 5.0 | Exponential FOV response rate |

Resulting FOV is clamped to `1..179`. Update resets the target to normal and
applies it instantly. Disable `movement_fov_enabled` for manual target ownership.

### Bobbing

| Property | Default | Meaning |
| --- | --- | --- |
| `bob_enabled` | true | Enable moving/grounded bobbing target |
| `bob_frequency` | 2.0 | Phase multiplier for accumulated horizontal distance |
| `bob_amplitude` | 0.08 | Scale of the X/Y bobbing offset |
| `bob_smoothing_horizontal` | 2.0 | Divisor of the sine phase on X |
| `bob_smoothing_vertical` | 1.0 | Divisor of the cosine phase on Y |

The two “smoothing” values alter phase rate, not interpolation response. Actual
offset interpolation uses a fixed exponential rate of `10`. Bobbing requires
grounded, moving motion state and horizontal speed greater than `0.01`.

### Step smoothing, landing, and input

| Property | Default | Meaning |
| --- | --- | --- |
| `step_smoothing_enabled` | true | Recover step-pivot Y offset toward zero |
| `step_max_smoothing` | 0.7 | Maximum magnitude of smoothed local step offset |
| `fall_impact_tween_enabled` | true | Allow landing dip tween |
| `fall_impact_contact_duration` | 0.05 | Seconds to reach dip |
| `fall_impact_rest_duration` | 0.75 | Seconds to recover |
| `input_release_mouse` | `fps_release_mouse` | Host Input Map action for releasing capture |

Both landing tween stages use `TRANS_BACK` with `EASE_OUT`; very small durations
are clamped to `0.001`. Tween easing may overshoot the requested amplitude.

## FPSControllerHands node

Hands has no custom exported settings or Data resource. Its transform is an
ordinary local `Node3D` transform. Each API attachment also accepts a local
transform, defaulting to identity.

## Resource sharing and update ownership

Neither Data class currently forces scene-local duplication. Reusing an assigned
resource intentionally shares settings. Use unique resources or duplicate them
when instances need different sensitivity, collision, or movement tuning.
Runtime toggles/locks/camera effects remain per-node.

Call updates deliberately: character update resets mode/toggles/cooldown/fall
tracking and invokes rig update; rig update resets FOV/offsets and reapplies pitch
limits. Do not call either every frame as a synchronization mechanism.
