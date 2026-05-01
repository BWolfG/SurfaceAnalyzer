## A tool for identifying materials on complex mesh surfaces using raycast data.
##
## SurfaceAnalyzer uses [MeshDataTool] to map raycast face indices to their
## corresponding materials on a [MeshInstance3D]. It works alongside with
## a detailed [ConcavePolygonShape3D] for precise material detection via [RayCast3D].
##
## [b]Requirements:[/b]
## - The detailed collision shape must be generated from the visual mesh to ensure
##   face indices match between the collision and the rendered geometry.
## - If using [b]Jolt Physics[/b], the project setting
##   [code]physics/jolt/ray_cast/enable_face_index[/code] must be set to [code]true[/code]
##   (requires godot-jolt 0.14.0 or newer). Without this, [method RayCast3D.get_collision_face_index]
##   always returns [code]-1[/code].
##
## [b]Usage:[/b]
## [codeblock]
## var material = SurfaceAnalyzer.get_active_material(collider, face_index)
## if material:
##     print(material.resource_path)
## [/codeblock]
extends Node

var _mdt_array: Array[MeshDataTool] = []
var _last_mesh: Mesh = null
var _last_mesh_version: int = 0

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

func _build_mesh_data_tools(mesh_instance: MeshInstance3D) -> void:
	var mesh: Mesh = mesh_instance.mesh

	if not mesh:
		return

	var current_version = mesh.get_rid().get_id() 

	if mesh == _last_mesh and current_version == _last_mesh_version:
		return 

	_last_mesh = mesh
	_last_mesh_version = current_version

	var surface_count = mesh.get_surface_count()
	_mdt_array.resize(surface_count)

	for surface in surface_count:
		var mdt = _mdt_array[surface]
		if not mdt:
			mdt = MeshDataTool.new()
			_mdt_array[surface] = mdt
		mdt.create_from_surface(mesh, surface)

func _get_material_by_face(face_index: int, mesh_instance: MeshInstance3D, override_material: bool = false) -> Material:
	_build_mesh_data_tools(mesh_instance)

	var material_index: int = 0

	for mdt: MeshDataTool in _mdt_array:
		if face_index >= mdt.get_face_count():
			face_index -= mdt.get_face_count()
			material_index += 1
		else:
			break

	if override_material:
		return mesh_instance.get_surface_override_material(material_index)

	return mesh_instance.get_active_material(material_index)
