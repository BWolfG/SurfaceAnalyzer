## A tool for identifying materials on complex mesh surfaces using raycast data.
##
## SurfaceAnalyzer retrieves the material of the surface hit by a [RayCast3D].
## It is designed to work alongside a detailed [ConcavePolygonShape3D] for precise
## material detection without affecting player physics.
## [br][br]
## [b]Requirements:[/b]
## - The detailed collision shape must be generated from the visual mesh to ensure
##   face indices match between the collision and the rendered geometry.
## - If using [b]Jolt Physics[/b], the project setting
##   [code]physics/jolt_physics_3d/queries/enable_ray_cast_face_index[/code] must be set to [code]true[/code]
##   (requires godot-jolt 0.14.0 or newer). Without this, [method RayCast3D.get_collision_face_index]
##   always returns [code]-1[/code].
## [br][br]
##   Custom node hierarchies may require manual adjustments.
## [br][br]
## - [b]Caching behavior:[/b] Triangle counts are cached per [Mesh] resource.
##   If you dynamically replace meshes at runtime, the cache will retain the old data.
##   Call [method invalidate_cache] manually after changing a mesh.
## [br][br]
## - [b]Memory:[/b] The cache stores only the last accessed mesh to minimize memory usage.
##   Switching between many different meshes will repeatedly rebuild the cache.
## [br][br]
## - [b]Performance:[/b] First access to a new mesh triggers [method Mesh.surface_get_arrays],
##   which copies geometry data from GPU to CPU. This may cause a spike. 
##   Subsequent raycasts on the same mesh are fast.
## [br][br]
## [b]Usage:[/b]
## [codeblock]
## var material = SurfaceAnalyzer.get_active_material(collider, face_index)
## if material:
##     print(material.resource_path)
## [/codeblock]
extends Node

var _surface_triangle_counts: Dictionary[Mesh, Array]

## Returns the overridden material for the surface hit by the raycast.
## This returns the material set in MeshInstance3D's Surface Material Override,
## not the material stored in the Mesh resource.
## Use [method get_active_material] to get the material that is actually rendered,
## or [method get_base_material] to get the material from the Mesh resource.
## [param collider] The CollisionObject3D hit by the raycast.
## [param face_index] The face index from [method RayCast3D.get_collision_face_index].
func get_surface_override_material(collider: CollisionObject3D, face_index: int) -> Material:
	if collider and collider.get_parent() and collider.get_parent() is MeshInstance3D:
		var mesh_instance: MeshInstance3D = collider.get_parent()

		if mesh_instance.get_surface_override_material_count() == 1:
			return mesh_instance.get_surface_override_material(0)

		return _get_material_by_face(face_index, mesh_instance, true) 

	return null

## Returns the material that is actually rendered on the surface hit by the raycast.
## This returns the material from [method MeshInstance3D.get_active_material],
## which accounts for Surface Material Override, material from the Mesh resource,
## or the default material in that order of priority.
## This is the method you typically want for reading surface properties like friction or footstep sounds.
## [param collider] The CollisionObject3D hit by the raycast.
## [param face_index] The face index from [method RayCast3D.get_collision_face_index].
func get_active_material(collider: CollisionObject3D, face_index: int) -> Material:
	if collider and collider.get_parent() and collider.get_parent() is MeshInstance3D:
		var mesh_instance: MeshInstance3D = collider.get_parent()

		if mesh_instance.mesh.get_surface_count() == 1:
			return mesh_instance.get_active_material(0)

		return _get_material_by_face(face_index, mesh_instance)

	return null

func _get_triangle_counts(mesh: Mesh) -> Array:
	if _surface_triangle_counts.has(mesh):
		return _surface_triangle_counts[mesh]

	_surface_triangle_counts.clear()

	var counts: Array = []
	for surface_idx: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_idx)
		var index_array = arrays[Mesh.ARRAY_INDEX]
		var triangle_count: int = 0

		if index_array and index_array.size() > 0:
			triangle_count = index_array.size() / 3
		else:
			var vertex_array: Array = arrays[Mesh.ARRAY_VERTEX]
			if vertex_array:
				triangle_count = vertex_array.size() / 3

		counts.append(triangle_count)

	_surface_triangle_counts[mesh] = counts

	return counts

func _get_material_by_face(face_index: int, mesh_instance: MeshInstance3D, override_material: bool = false) -> Material:
	var mesh: Mesh = mesh_instance.mesh

	if not mesh:
		return null

	var triangle_counts: Array = _get_triangle_counts(mesh)

	for surface_idx: int in range(triangle_counts.size()):
		if face_index < triangle_counts[surface_idx]:
			if override_material:
				return mesh_instance.get_surface_override_material(surface_idx)
			else:
				return mesh_instance.get_active_material(surface_idx)
		face_index -= triangle_counts[surface_idx]

	return null
