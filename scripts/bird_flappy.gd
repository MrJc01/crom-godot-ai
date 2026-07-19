extends CharacterBody2D

@export var gravity: float = 800.0
@export var jump_force: float = -350.0

func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	if Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		velocity.y = jump_force
	move_and_slide()

func game_over() -> void:
	print("💥 Game Over! Colisão com cano.")
	position = Vector2(150, 300)
	velocity = Vector2.ZERO
