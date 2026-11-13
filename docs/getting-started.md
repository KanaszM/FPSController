# Getting started

[Documentation map](index.md) | [Next: Movement](movement.md)

## Requirements and installation

The project targets Godot **4.7.1**. Copy the entire `FPSController` directory
into the destination project, keeping the scenes, scripts, `.gd.uid` files, and
icons together. No game-specific autoload, editor plugin, or downloaded asset is
required.

The simplest initial location is `res://FPSController/`, matching the current
scene fallback paths. Open the destination project in Godot and allow import to
finish: the static factories load their scenes by UID. See
[portability](architecture.md#uids-and-relocation) before renaming/moving files
or copying only part of the folder.

These are instructions for the supplied components, not a claim that the
current character refactor is error-free. Its known initialization problems are
listed in [troubleshooting](troubleshooting.md#current-source-initialization-caveats).

## Build a first scene

Create a level containing:

```text
Level (Node3D)
  Floor (StaticBody3D)
    CollisionShape3D
    MeshInstance3D          optional visible floor
  FPSController            instance of fps_controller.tscn
    CameraRig              nested camera scene
    Collision
    RayCeilingAbove
```

Give the floor a box collision shape. Put the character on or slightly above
it, with its feet-origin root outside the floor. Use compatible collision
layers/masks; the character defaults to layer `1`, mask `1`.

The character should remain upright and unit-scaled. Change capsule dimensions
through Data rather than scaling the root. The implementation uses Y-up steps,
horizontal X/Z movement, and a Y-position fall-distance tracker.

## Assign resources

Select the character and create an `FPSControllerData` resource in `data`. Select
its `CameraRig` instance and create `FPSControllerCameraData` in that node's
`data`. Missing resources are created during `update()`.

| Resource | Owns |
| --- | --- |
| `FPSControllerData` | Capsule, movement, jumping, gravity, landing detection, eye height, movement action names |
| `FPSControllerCameraData` | Mouse look, pitch limits, FOV, bobbing, step smoothing, landing animation, release-mouse action |

The current Data classes do not automatically set `resource_local_to_scene`.
Create unique resources for per-character tuning; do not assume scene instances
always have separate assigned resources. Nodes do not store their disabled state
in these resources. Each character creates its own capsule shape on update.

## Input Map

Add these actions in **Project Settings > Input Map**. Bindings below are
recommendations, not automatically installed defaults.

| Resource property | Default action name | Suggested binding |
| --- | --- | --- |
| `input_move_left` | `fps_move_left` | A, Left |
| `input_move_right` | `fps_move_right` | D, Right |
| `input_move_forward` | `fps_move_forward` | W, Up |
| `input_move_backward` | `fps_move_backward` | S, Down |
| `input_walk` | `fps_walk` | Ctrl |
| `input_run` | `fps_run` | Shift |
| `input_jump` | `fps_jump` | Space |
| Camera Data: `input_release_mouse` | `fps_release_mouse` | Escape |

Rename the strings in Data to reuse existing project actions. The current code
contains no `input_add_default_actions` option and no runtime binding installer.
Missing actions return zero/false for movement; they are not created on update.
Mouse look uses mouse-motion events directly, rather than a look action.

Input actions can have other event types, but this package provides no dedicated
gamepad look implementation or touch interface.

## First-run checks

Once initialization succeeds, the rig makes its `Camera3D` current and captures
the mouse by default. With the recommended Input Map, W moves forward, Shift
selects run, Ctrl selects walk, Space jumps, and Escape releases the mouse.
Left-click recaptures it.

By default, releasing capture also rejects movement input; gravity and collision
continue. Clicking a UI control may consume the event before the rig's
`_unhandled_input()` sees it. Use a host UI script to control capture explicitly
when necessary.

## Applying edits

Call the character's `update()` after editing collision dimensions/masks, eye
height, or floor-snap settings. It also reapplies camera settings, clears camera
effects, resets movement toggles/cooldown/fall tracking, and emits `updated`.
It does not reset the character transform.

Call `camera_rig.update()` to reapply normal FOV, pitch limits, and reset camera
effects without rebuilding character collision. Most tuning values are read
during input/physics processing; neither update method registers input actions.

## Camera-only setup

Instance `camera/fps_controller_camera.tscn` directly under any `Node3D`. Assign
camera Data and position the rig as desired. It can handle mouse look, capture,
FOV, and procedural effects without a character. It has no collision shape and
does not translate itself.

See [camera recipes](camera.md#standalone-camera) for scripted use.
