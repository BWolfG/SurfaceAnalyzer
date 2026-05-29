# SurfaceAnalyzer

A Godot 4.2+ plugin for identifying surface materials on complex 3D meshes via raycast.

Designed to work alongside a detailed `ConcavePolygonShape3D`.

## Features

- Returns the **actually rendered** material (`get_surface_active_material`)
- Returns the **overridden** material from MeshInstance3D (`get_surface_override_material`)
- Works with multi-surface meshes
- Three cache modes: `AUTO`, `MANUAL`, `NONE`
- Manual cache management: add, remove, query by index or mesh
- No duplicate cache entries for shared mesh resources
- Automatic memory management in `AUTO` mode

## Requirements

- **Godot 4.2** or newer
- The detailed collision shape **must** be generated from the visual mesh
- **Jolt Physics:** If using Jolt, enable `physics/jolt_physics_3d/queries/enable_ray_cast_face_index` (requires **godot-jolt 0.14.0** or newer)
- If you use **Unwrap UV2 for Lightmap/AO**, regenerate the collision shape afterward. Godot rebuilds the mesh during unwrapping, causing triangle indices to mismatch.

- Custom node hierarchies may require manual adjustments.

## Installation

1. Copy the `addons/SurfaceAnalyzer` folder into your project's `addons/` directory
2. Enable the plugin in **Project Settings → Plugins** — the Autoload is registered automatically

## Usage

```gdscript
var material := SurfaceAnalyzer.get_surface_active_material(collider, face_index)
if material:
    print(material.resource_path)