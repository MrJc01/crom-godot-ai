@tool
extends SceneTree

const CommandProcessor = preload("res://addons/crom_ai/command_processor.gd")

func _init() -> void:
	print("\n==================================================")
	print("🐦 INICIANDO CONSTRUÇÃO AUTÔNOMA DO FLAPPY BIRD 2D")
	print("==================================================\n")
	
	var cp = CommandProcessor.new()
	
	if not DirAccess.dir_exists_absolute("res://scenes"):
		DirAccess.make_dir_recursive_absolute("res://scenes")
	if not DirAccess.dir_exists_absolute("res://scripts"):
		DirAccess.make_dir_recursive_absolute("res://scripts")
		
	# 1. Input Actions
	print("1. Configurando Ação de Pulo (jump / space)...")
	cp.process_command(JSON.stringify({
		"action": "add_input_action",
		"params": { "action_name": "jump", "key": "Space" }
	}))

	# 2. Criar cena res://scenes/flappy_test.tscn
	print("2. Criando cena res://scenes/flappy_test.tscn...")
	var res_create = cp.process_command(JSON.stringify({
		"action": "create_scene",
		"params": {
			"root_name": "FlappyTest",
			"root_type": "Node2D",
			"scene_path": "res://scenes/flappy_test.tscn"
		}
	}))
	print("  Result: ", res_create)

	# 3. Adicionar Bird (CharacterBody2D)
	print("3. Adicionando Bird (CharacterBody2D)...")
	cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": ".",
			"node_type": "CharacterBody2D",
			"node_name": "Bird"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "Bird",
			"property": "position",
			"value": [150, 300]
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": "Bird",
			"node_type": "ColorRect",
			"node_name": "Visual"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "Bird/Visual",
			"property": "size",
			"value": [30, 30]
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "Bird/Visual",
			"property": "color",
			"value": [1.0, 0.9, 0.1, 1.0] # Amarelo Flappy
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": "Bird",
			"node_type": "CollisionShape2D",
			"node_name": "CollisionShape2D"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "setup_physics_body",
		"params": {
			"node_path": "Bird",
			"body_type": "CharacterBody2D",
			"shape_type": "RectangleShape2D",
			"size": [30, 30],
			"collision_layer": 1,
			"collision_mask": 2
		}
	}))

	# 4. Script do Pássaro
	print("4. Anexando script do Bird (bird_flappy.gd)...")
	var bird_code := """extends CharacterBody2D

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
"""
	cp.process_command(JSON.stringify({
		"action": "create_and_attach_script",
		"params": {
			"node_path": "Bird",
			"script_path": "res://scripts/bird_flappy.gd",
			"script_content": bird_code
		}
	}))

	# 5. Adicionar Canos (Obstáculos Area2D)
	print("5. Criando Canos (PipeTop e PipeBottom)...")
	cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": ".",
			"node_type": "Area2D",
			"node_name": "PipeTop"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "PipeTop",
			"property": "position",
			"value": [600, 100]
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": "PipeTop",
			"node_type": "ColorRect",
			"node_name": "Visual"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "PipeTop/Visual",
			"property": "size",
			"value": [60, 200]
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "PipeTop/Visual",
			"property": "color",
			"value": [0.1, 0.8, 0.3, 1.0] # Verde Cano
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": "PipeTop",
			"node_type": "CollisionShape2D",
			"node_name": "CollisionShape2D"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "setup_physics_body",
		"params": {
			"node_path": "PipeTop",
			"body_type": "Area2D",
			"shape_type": "RectangleShape2D",
			"size": [60, 200],
			"collision_layer": 2,
			"collision_mask": 1
		}
	}))

	# 6. Script do Cano
	var pipe_code := """extends Area2D

@export var speed: float = 180.0

func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x < -100:
		position.x = 800

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("game_over"):
		body.game_over()
"""
	cp.process_command(JSON.stringify({
		"action": "create_and_attach_script",
		"params": {
			"node_path": "PipeTop",
			"script_path": "res://scripts/pipe_obstacle.gd",
			"script_content": pipe_code
		}
	}))

	# 7. Conectar Sinal do Cano -> Bird
	print("6. Conectando colisão do Cano com o Bird...")
	cp.process_command(JSON.stringify({
		"action": "connect_signal",
		"params": {
			"source_node_path": "PipeTop",
			"signal_name": "body_entered",
			"target_node_path": "PipeTop",
			"method_name": "_on_body_entered"
		}
	}))

	# 8. HUD
	print("7. Criando HUD (CanvasLayer)...")
	cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": ".",
			"node_type": "CanvasLayer",
			"node_name": "HUD"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": "HUD",
			"node_type": "Label",
			"node_name": "Title"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "HUD/Title",
			"property": "text",
			"value": "🐦 Flappy Bird 2D — CromAI Live Test"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "HUD/Title",
			"property": "position",
			"value": [30, 20]
		}
	}))

	# 9. Salvar cena e definir como principal
	print("8. Salvando cena e definindo como Main Scene...")
	cp.process_command(JSON.stringify({
		"action": "save_scene",
		"params": {}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_main_scene",
		"params": {
			"scene_path": "res://scenes/flappy_test.tscn"
		}
	}))

	print("\n✨ CONSTRUÇÃO DO FLAPPY BIRD 2D CONCLUÍDA COM SUCESSO!")
