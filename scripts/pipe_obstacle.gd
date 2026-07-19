extends Area2D

@export var speed: float = 180.0

func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x < -100:
		position.x = 800

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("game_over"):
		body.game_over()
