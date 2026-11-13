# Troubleshooting

[Documentation map](index.md) | [Setup](getting-started.md) | [API reference](scripting.md)

This page distinguishes configuration mistakes from caveats present in the
current source. The documentation task does not change those scripts.

## Current-source initialization caveats

### Character fails in `_enter_tree()`

The current character declares `camera_rig` with `@onready`, but reads it in
`_enter_tree()`. Godot has not evaluated onready fields yet, so the reference can
be null at that point. This is a source initialization-order issue, not a missing
Input Map binding or bad capsule setting.

The source needs an early node lookup or a lifecycle adjustment that preserves
the intended pre-capture input lock. Moving everything blindly to parent
`_ready()` changes ordering because the child rig becomes ready first.

### Factory with camera Data fails

`FPSController.instantiate(..., camera_data)` still calls
`instance.get_camera_rig()`, but that accessor is no longer defined in the
current character script. Passing non-null camera Data takes this branch.
This needs a source/API correction; the ready reference is `camera_rig`, but it
is not initialized immediately after scene instantiation.

Assigning camera Data through the editor avoids that factory branch, but does
not resolve the separate `_enter_tree()` issue.

### Wrong-root scene error is followed by a null access

Both current factories cast the root to their expected class, then call
`instance.free()` inside the `instance == null` branch. A failed cast leaves no
typed instance to free. This only concerns malformed/replaced factory scenes;
it requires retaining the original instantiated node for cleanup in source.

These are documented observations, not fixes applied by this guide.

## Scene or UID cannot be loaded

The factories use `PACK_UID`, not script-relative scene paths. Import the whole
folder in the destination editor, preserve `.gd.uid` files and scene UID
headers, and check that no second copy has conflicting UIDs/class names.
Current external resource fallback paths start at `res://FPSController/`.
See [relocation](architecture.md#uids-and-relocation).

Use the supplied PackedScenes rather than attaching the scripts to empty nodes.
Removing/renaming uniquely named children breaks script references.

## No movement

| Check | Reason |
| --- | --- |
| Initialization errors | The controller may never reach normal physics processing |
| Host Input Map | Current source does not install default actions |
| Data action strings | Names must exactly match configured actions |
| `is_disabled()` / `move_enabled` | Input can be locked or movement disabled |
| Active camera | Movement normally requires `camera.is_current()` |
| Mouse capture | Movement normally requires captured mouse |
| Acceleration/speed | Zero acceleration prevents approach to target; zero speed has no target motion |
| Collision layers/placement | Embedded capsule or blocking geometry can prevent actual motion |

If `is_moving()` is true but position does not change, it may simply be blocked:
that flag tracks accepted input, not displacement.

## Mouse look or capture does not work

Only the current rig handles mouse input. Check `input_enabled`,
`data.look_enabled`, any `set_input_blocked()` lock, and captured mouse mode.
UI may consume an event before `_unhandled_input()`. There is no gamepad-look
implementation.

If look stops when the character is disabled, that is the default policy.
Set `camera_independent_input = true` for look during a character lock.

If Escape does nothing, add/configure `data.input_release_mouse` in the host
Input Map. The action is not automatically bound. Capture is global, not private
to one camera or viewport.

## Invalid capsule

Radius must be positive and finite. Total height must be finite and at least
twice radius. An invalid shape disables character physics/input, blocks rig
input, and emits `updated(false)`. Fix settings and call `update()`.
Do not nonuniformly scale the character to change collision dimensions.

## Stairs do not climb

Check `step_enabled`, step height greater than `0.01`, compatible masks, a
static/animatable target, walkable top angle, and enough upward/forward
clearance. The character must have been grounded, not rising, and actually
moving horizontally. Rigid-body obstacles are not accepted as custom stairs.

A visual mesh without collision is not a step. Changing `step_max_height`
requires update to reapply floor-snap length.

## Jump is blocked

Check grounding, jump action, enabled movement/jump, cooldown, and flight mode.
The upward ceiling ray can reject jumping under an overhang. Its mask follows
the character mask. Holding jump only repeats when `jump_continuous` is true.

## FOV snaps back or ignores direct changes

Character synchronization overwrites the rig target while both
`camera_sync_motion` and `movement_fov_enabled` are true. Disable movement FOV
for manual control and call `set_target_fov()`.

Direct edits to `camera.fov` are blended back toward the stored target.
Rig update reapplies normal FOV instantly. A zero transition rate prevents
noninstant blending. The additive modifier is applied even to instant commands.

## Detached camera still shakes or is freed with the character

`follow_parent = false` only stops transform inheritance. Disable
`camera_sync_motion` to stop character motion feeds; call `reset_effects()` for
an immediate procedural reset or set `effects_enabled = false`.

Top-level transform mode does not remove the rig from the scene tree. It remains
owned by its parent for lifetime and process hierarchy purposes.

## Landing signal or dip is missing

The signal needs `fall_impact_enabled` and a measured fall at least
`fall_impact_min_height`. A dip additionally needs character synchronization,
rig effects, rig landing tween enabled, and positive amplitude.

Turning off the rig tween does not suppress qualifying landing signals.
Flight does not track/emit normal landing impacts. The system does not apply
fall damage.

## Attachment disappears, clips, or has the wrong pose

Use a Node3D-root PackedScene and check the returned value. Attachment transforms
are local to Hands, with `-Z` forward, and replace the old local pose. A detached
node must be reparented or freed; the API does not preserve world pose.

Configure model scale, near-plane clipping, and colliders yourself. Hands has no
automatic collision exclusion, special render layer, or wall-clipping solver.
`clear_attachments()` queues deletion; do not keep using the returned children
after that operation.

## Settings unexpectedly change on another instance

The current Data classes do not automatically force local-to-scene resources.
Make assigned settings unique when necessary. Runtime disabled flags/effects
are separate, but changing a shared Data resource changes shared configuration.

## Older examples mention missing methods

Use ready fields `controller.camera_rig`, `camera_rig.camera`, and
`camera_rig.hands`. The current public source no longer defines
`get_camera_rig()`, `get_camera()`, `get_hands()`, or an automatic input-binding
option. See the [API reference](scripting.md).
