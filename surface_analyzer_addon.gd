@tool
extends EditorPlugin


func _enable_plugin() -> void:
	add_autoload_singleton("SurfaceAnalyzer", "surface_analyzer.gd")


func _disable_plugin() -> void:
	remove_autoload_singleton("SurfaceAnalyzer")
