extends Node

#TODO: Add a bit of documentation

var _mdt_array: Array[MeshDataTool] = []
var _last_mesh: Mesh = null
var _last_mesh_version: int = 0

func get_surface_meta(collider: Node3D, face_index: int, meta_name: StringName, default: Variant = null) -> Variant:
	var material: Material = get_surface_material(collider, face_index)

	if material and material.has_meta(meta_name):
		return material.get_meta(meta_name)

	return default

func get_surface_material(collider: Node3D, face_index: int) -> Material:
	if collider and collider.get_parent() and collider.get_parent() is MeshInstance3D:
		var current_colliding_surface: MeshInstance3D = collider.get_parent()
		if current_colliding_surface.get_surface_override_material_count() == 1:
			return current_colliding_surface.get_surface_override_material(0)
		if current_colliding_surface.mesh.get_surface_count() == 1:
			return current_colliding_surface.get_active_material(0)
		if current_colliding_surface.mesh.get_surface_count() > 1:
			return _get_material_by_face(face_index, current_colliding_surface)

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

func _get_material_by_face(face_index: int, mesh_instance: MeshInstance3D) -> Material:
	_build_mesh_data_tools(mesh_instance)

	var override_material_index: int = 0

	for mdt: MeshDataTool in _mdt_array:
		if face_index >= mdt.get_face_count():
			face_index -= mdt.get_face_count()
			override_material_index += 1
			continue

		if mesh_instance.get_surface_override_material(override_material_index):
			return mesh_instance.get_surface_override_material(override_material_index)

		return mdt.get_material()

	return null
