A Godot 4.2+ plugin for identifying surface materials on complex 3D meshes via raycast.

SurfaceAnalyzer maps a raycast face index to the material of the hit triangle using **MeshDataTool**. It works alongside a detailed `ConcavePolygonShape3D` for precise material detection

Features

- Returns the **actually rendered** material (`get_active_material`)
- Returns the **overridden** material from MeshInstance3D (`get_surface_override_material`)
- Works with multi-surface meshes

Requirements

- Godot 4.2 or newer
- The detailed collision shape **must** be generated from the visual mesh.
- Jolt Physics: If using Jolt, enable `physics/jolt/ray_cast/enable_face_index` (requires godot-jolt 0.14.0 or newer).

Installation

1. Copy the addon folder into your project's `addons/` directory.
2. Enable the plugin in **Project Settings → Plugins**. The Autoload will be registered automatically.

Usage

```gdscript
var material = SurfaceAnalyzer.get_active_material(collider, face_index)
if material:
    print(material.resource_path)
