@tool
extends SceneTree

const CommandProcessor = preload("res://addons/crom_ai/command_processor.gd")

func _init() -> void:
	print("\n==================================================")
	print("🎮 INICIANDO CONSTRUÇÃO AUTÔNOMA DO JOGO DE TESTE")
	print("==================================================\n")
	
	var cp = CommandProcessor.new()
	
	# 1. Criar pasta res://scenes se não existir
	if not DirAccess.dir_exists_absolute("res://scenes"):
		DirAccess.make_dir_recursive_absolute("res://scenes")
	if not DirAccess.dir_exists_absolute("res://scripts"):
		DirAccess.make_dir_recursive_absolute("res://scripts")
		
	# 2. Configurar InputMap
	print("1. Configurando InputMap...")
	cp.process_command(JSON.stringify({
		"action": "add_input_action",
		"params": { "action_name": "move_left", "key": "A" }
	}))
	cp.process_command(JSON.stringify({
		"action": "add_input_action",
		"params": { "action_name": "move_right", "key": "D" }
	}))
	cp.process_command(JSON.stringify({
		"action": "add_input_action",
		"params": { "action_name": "move_up", "key": "W" }
	}))
	cp.process_command(JSON.stringify({
		"action": "add_input_action",
		"params": { "action_name": "move_down", "key": "S" }
	}))

	# 3. Criar a cena principal res://scenes/space_dodger.tscn
	print("2. Criando cena principal res://scenes/space_dodger.tscn...")
	var res_create = cp.process_command(JSON.stringify({
		"action": "create_scene",
		"params": {
			"root_name": "SpaceDodger",
			"root_type": "Node2D",
			"scene_path": "res://scenes/space_dodger.tscn"
		}
	}))
	print("  Result: ", res_create)

	# 4. Adicionar Player (CharacterBody2D)
	print("3. Adicionando Player (CharacterBody2D)...")
	var res_player = cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": ".",
			"node_type": "CharacterBody2D",
			"node_name": "Player"
		}
	}))
	print("  Result: ", res_player)

	# 5. Adicionar Visual do Player (ColorRect)
	cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": "Player",
			"node_type": "ColorRect",
			"node_name": "Visual"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "Player/Visual",
			"property": "size",
			"value": [32, 32]
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "Player/Visual",
			"property": "color",
			"value": [0.2, 0.8, 1.0, 1.0] # Azul neon
		}
	}))

	# 6. Adicionar Colisão do Player (CollisionShape2D)
	cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": "Player",
			"node_type": "CollisionShape2D",
			"node_name": "CollisionShape2D"
		}
	}))
	
	# Usar setup_physics_body para configurar colisão do Player
	cp.process_command(JSON.stringify({
		"action": "setup_physics_body",
		"params": {
			"node_path": "Player",
			"body_type": "CharacterBody2D",
			"shape_type": "RectangleShape2D",
			"size": [32, 32],
			"collision_layer": 1,
			"collision_mask": 2
		}
	}))

	# 7. Criar e Anexar Script ao Player
	print("4. Criando e anexando script do Player...")
	var player_script_code := """extends CharacterBody2D

@export var speed: float = 300.0
var score: int = 0

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		direction.y += 1.0
		
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		
	velocity = direction * speed
	move_and_slide()

func add_score(amount: int) -> void:
	score += amount
	print("Score atual: ", score)
"""
	cp.process_command(JSON.stringify({
		"action": "create_and_attach_script",
		"params": {
			"node_path": "Player",
			"script_path": "res://scripts/player_controller.gd",
			"script_content": player_script_code
		}
	}))

	# 8. Adicionar Inimigo (Area2D)
	print("5. Adicionando Inimigo (Area2D)...")
	cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": ".",
			"node_type": "Area2D",
			"node_name": "Enemy"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "Enemy",
			"property": "position",
			"value": [400, 50]
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": "Enemy",
			"node_type": "ColorRect",
			"node_name": "Visual"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "Enemy/Visual",
			"property": "size",
			"value": [28, 28]
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "Enemy/Visual",
			"property": "color",
			"value": [1.0, 0.2, 0.2, 1.0] # Vermelho neon
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "add_node",
		"params": {
			"parent_path": "Enemy",
			"node_type": "CollisionShape2D",
			"node_name": "CollisionShape2D"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "setup_physics_body",
		"params": {
			"node_path": "Enemy",
			"body_type": "Area2D",
			"shape_type": "RectangleShape2D",
			"size": [28, 28],
			"collision_layer": 2,
			"collision_mask": 1
		}
	}))

	# 9. Script do Inimigo
	print("6. Anexando script do Inimigo...")
	var enemy_script_code := """extends Area2D

@export var fall_speed: float = 150.0

func _process(delta: float) -> void:
	position.y += fall_speed * delta
	if position.y > 650:
		position.y = -30
		position.x = randf_range(50, 750)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("add_score"):
		print("⚡ Colisão detectada entre Inimigo e Player!")
		body.add_score(10)
"""
	cp.process_command(JSON.stringify({
		"action": "create_and_attach_script",
		"params": {
			"node_path": "Enemy",
			"script_path": "res://scripts/enemy_behavior.gd",
			"script_content": enemy_script_code
		}
	}))

	# 10. Conectar sinal body_entered do Enemy -> _on_body_entered do Enemy
	print("7. Conectando sinal de colisão...")
	cp.process_command(JSON.stringify({
		"action": "connect_signal",
		"params": {
			"source_node_path": "Enemy",
			"signal_name": "body_entered",
			"target_node_path": "Enemy",
			"method_name": "_on_body_entered"
		}
	}))

	# 11. Adicionar UI (CanvasLayer + Label)
	print("8. Adicionando Interface de HUD (CanvasLayer)...")
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
			"node_name": "TitleLabel"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "HUD/TitleLabel",
			"property": "text",
			"value": "🚀 Space Dodger 2D — CromAI Test"
		}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_node_property",
		"params": {
			"node_path": "HUD/TitleLabel",
			"property": "position",
			"value": [20, 20]
		}
	}))

	# 12. Salvar cena e definir como principal
	print("9. Salvando cena e definindo como Main Scene...")
	cp.process_command(JSON.stringify({
		"action": "save_scene",
		"params": {}
	}))
	cp.process_command(JSON.stringify({
		"action": "set_main_scene",
		"params": {
			"scene_path": "res://scenes/space_dodger.tscn"
		}
	}))

	# 13. Executar Validação Automatizada de Jogabilidade (verify_playable)
	print("\n🧪 10. EXECUTANDO LAÇO DE VERIFICAÇÃO AUTOMÁTICA (verify_playable)...")
	var verify_res = cp.process_command(JSON.stringify({
		"action": "verify_playable",
		"params": {
			"scene_path": "res://scenes/space_dodger.tscn",
			"test_duration_frames": 180,
			"simulate_input": "Right"
		}
	}))
	print("==================================================")
	print("VEREDITO DA VERIFICAÇÃO JOGÁVEL:")
	print(JSON.stringify(verify_res, "  "))
	print("==================================================\n")

	quit(0)
