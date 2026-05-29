## A tool for identifying materials on complex mesh surfaces using raycast data.
##
## SurfaceAnalyzer retrieves the material of the surface hit by a [RayCast3D].
## It is designed to work alongside a detailed [ConcavePolygonShape3D] for precise material detection.
## [br][br]
## [b]Requirements:[/b]
## [br][br]
##   The detailed collision shape must be generated from the visual mesh to ensure
##   face indices match between the collision and the rendered geometry.
##   If using [b]Jolt Physics[/b], the project setting
##   [code]physics/jolt_physics_3d/queries/enable_ray_cast_face_index[/code] must be set to [code]true[/code]
##   (requires godot-jolt 0.14.0 or newer). Without this, [method RayCast3D.get_collision_face_index]
##   always returns [code]-1[/code].
## [br][br]
##   If you use [b]Unwrap UV2 for Lightmap/AO[/b], regenerate the collision shape afterward.
##   Godot rebuilds the mesh during unwrapping, causing triangle indices to mismatch.
## [br][br]
##   Custom node hierarchies may require manual adjustments.
## [br][br]
## [b]Caching:[/b] 
## [br][br]
##   Triangle counts are cached per [Mesh] resource with three modes:
## [br][br]
##   [b]AUTO[/b]: automatically removes the oldest entries when the cache exceeds [method change_auto_cache_size].
## [br][br]
##   [b]MANUAL[/b]: the cache grows unbounded. Manage it yourself via [method clear_cache],
##   [method erase_mesh_from_cache], [method erase_mesh_from_cache_by_index],
##   [method get_cached_mesh_count], [method get_cached_mesh_index], and [method is_mesh_cached].
## [br][br]
##   [b]NONE[/b]: caching is disabled entirely.
## [br][br]
## [b]Performance:[/b]
## [br][br]
##   First access to a new mesh triggers [method Mesh.surface_get_arrays],
##   which copies geometry data from GPU to CPU. This may cause a spike. 
##   Subsequent raycasts on the same mesh are fast. Use [method cache_mesh_surface]
##   during scene loading to pre-warm the cache.
## [br][br]
## [b]Usage:[/b]
## [codeblock]
## var material: Material = SurfaceAnalyzer.get_surface_active_material(collider, face_index)
## if material:
##     print(material.resource_path)
## [/codeblock]
extends Node

#region Cache Settings
enum CacheMode {
	AUTO,   ## Automatically removes oldest entries when limit is exceeded.
	MANUAL, ## Requires manual management via clear_cache(), erase_mesh_from_cache(), etc.
	NONE,   ## Turns off caching entirely.
}

## Controls how the cache behaves: [enum CacheMode.AUTO], [enum CacheMode.MANUAL], or [enum CacheMode.NONE].
var cache_behavior: CacheMode = CacheMode.AUTO
var _auto_cache_size: int = 16
var _cached_data: Dictionary[Mesh, PackedInt32Array]
#endregion

#region Public API — Material Detection
## Returns the overridden material for the surface hit by the raycast.
## This returns the material set in [member MeshInstance3D.surface_override_material],
## not the material stored in the [Mesh] resource.
## [param collider] The [CollisionObject3D] hit by the raycast.
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
## which accounts for Surface Material Override, material from the [Mesh] resource,
## or the default material in that order of priority.
## [param collider] The [CollisionObject3D] hit by the raycast.
## [param face_index] The face index from [method RayCast3D.get_collision_face_index].
func get_surface_active_material(collider: CollisionObject3D, face_index: int) -> Material:
	if collider and collider.get_parent() and collider.get_parent() is MeshInstance3D:
		var mesh_instance: MeshInstance3D = collider.get_parent()

		if mesh_instance.mesh.get_surface_count() == 1:
			return mesh_instance.get_active_material(0)

		return _get_material_by_face(face_index, mesh_instance)

	return null
#endregion

#region Public API — Cache Management
## Removes all cached mesh data.
func clear_cache() -> void:
	_cached_data.clear()

## Sets the maximum number of meshes stored when [member cache_behavior] is [enum CacheMode.AUTO].
## Has no effect in [enum CacheMode.MANUAL] or [enum CacheMode.NONE].
## [br][br]
## If the new size is smaller than the current number of cached meshes, the oldest entries
## are automatically removed until the cache fits the new limit.
func change_auto_cache_size(size: int) -> void:
	_auto_cache_size = size

	if cache_behavior == CacheMode.AUTO:
		while _cached_data.size() > _auto_cache_size:
			_cached_data.erase(_cached_data.keys()[0])

## Caches triangle data for the given mesh.
## [br][br]
## [param mesh] A [Mesh] resource or a [MeshInstance3D] node.
## If a [MeshInstance3D] is provided and is inside the tree, its [member MeshInstance3D.mesh] will be used.
func cache_mesh_surface(mesh: Variant) -> void:
	if mesh is MeshInstance3D and mesh.is_inside_tree():
		_cached_data[mesh.mesh] = _calculate_triangle_data(mesh.mesh)
	elif mesh is Mesh:
		_cached_data[mesh] = _calculate_triangle_data(mesh)

## Removes the specified mesh from the cache.
## [param mesh] A [Mesh] resource or a [MeshInstance3D] node.
## If a [MeshInstance3D] is provided and is inside the tree, its [member MeshInstance3D.mesh] will be used.
func erase_mesh_from_cache(mesh: Variant) -> void:
	if mesh is MeshInstance3D and mesh.is_inside_tree():
		_cached_data.erase(mesh.mesh)
	elif mesh is Mesh:
		_cached_data.erase(mesh)

## Removes the mesh at the given index from the cache.
func erase_mesh_from_cache_by_index(idx: int) -> void:
	if idx >= 0 and idx < get_cached_mesh_count():
		_cached_data.erase(_cached_data.keys()[idx])

## Returns the index of the specified mesh in the cache, or [code]-1[/code] if not found.
## [param mesh] A [Mesh] resource or a [MeshInstance3D] node.
## If a [MeshInstance3D] is provided and is inside the tree, its [member MeshInstance3D.mesh] will be used.
func get_cached_mesh_index(mesh: Variant) -> int:
	if mesh is MeshInstance3D and mesh.is_inside_tree():
		return _cached_data.keys().find(mesh.mesh)
	elif mesh is Mesh:
		return _cached_data.keys().find(mesh)
	return -1

## Returns the number of meshes currently stored in the cache.
func get_cached_mesh_count() -> int:
	return _cached_data.size()

## Returns [code]true[/code] if the specified mesh is cached.
## [param mesh] A [Mesh] resource or a [MeshInstance3D] node.
## If a [MeshInstance3D] is provided and is inside the tree, its [member MeshInstance3D.mesh] will be used.
func is_mesh_cached(mesh: Variant) -> bool:
	if mesh is MeshInstance3D and mesh.is_inside_tree():
		return _cached_data.has(mesh.mesh)
	elif mesh is Mesh:
		return _cached_data.has(mesh)
	return false
#endregion

#region Private Implementation
func _get_triangle_counts(mesh: Mesh) -> PackedInt32Array:
	if _cached_data.has(mesh):
		var counts: PackedInt32Array = _cached_data.get(mesh)
		_cached_data.erase(mesh)
		_cached_data[mesh] = counts
		return _cached_data[mesh]

	return _calculate_triangle_data(mesh)

func _auto_cache_clear() -> void:
	if _cached_data.size() > _auto_cache_size:
		_cached_data.erase(_cached_data.keys()[0])

func _calculate_triangle_data(mesh: Variant) -> PackedInt32Array:
	if not mesh:
		return PackedInt32Array()

	var counts: PackedInt32Array = []
	for surface_idx: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_idx)
		var triangle_count: int = 0

		if arrays[Mesh.ARRAY_INDEX] != null:
			var index_array: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangle_count = index_array.size() / 3
		elif arrays[Mesh.ARRAY_VERTEX] != null:
			var vertex_array: Array = arrays[Mesh.ARRAY_VERTEX]
			if vertex_array:
				triangle_count = vertex_array.size() / 3
		counts.append(triangle_count)

	if cache_behavior == CacheMode.AUTO:
		_cached_data[mesh] = counts
		_auto_cache_clear()

	return counts

func _get_material_by_face(face_index: int, mesh_instance: MeshInstance3D, override_material: bool = false) -> Material:
	var mesh: Mesh = mesh_instance.mesh

	if not mesh:
		return null

	var triangle_counts: PackedInt32Array = _get_triangle_counts(mesh)

	for surface_idx: int in range(triangle_counts.size()):
		if face_index < triangle_counts[surface_idx]:
			if override_material:
				return mesh_instance.get_surface_override_material(surface_idx)
			else:
				return mesh_instance.get_active_material(surface_idx)
		face_index -= triangle_counts[surface_idx]

	return null
#endregion
