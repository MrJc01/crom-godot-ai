extends Node3D

func _ready() -> void:
	print("==============================================")
	print("[MainScene] Cena Principal iniciada no Godot.")
	if Engine.has_singleton("CromWorldManager") or has_node("/root/CromWorldManager"):
		print("[MainScene] CromWorldManager conectado.")
	print("==============================================")
