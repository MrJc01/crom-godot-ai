extends SceneTree

# ==============================================================================
# Agent Test Orchestrator: Bateria de 15 Testes Gerenciada Pelo Agente (Gemini 2.5)
# O agente nativo do Godot executa a criação, verificação e testes dos jogos!
# ==============================================================================

var engine: Node
var proc: Node
var monitor: Node

var test_tasks: Array[Dictionary] = [
	{
		"id": "pong",
		"name": "Crom Pong ReAct",
		"prompt": "Use modify_project_file para criar o script completo res://games/pong/pong.gd e a cena res://games/pong/pong.tscn. O jogo deve ter raquetes para 2 jogadores (ou jogador contra IA básica), uma bolinha física que ricocheteia e placar."
	},
	{
		"id": "flappy",
		"name": "Flappy AI Bird",
		"prompt": "Use modify_project_file para criar o script completo res://games/flappy/flappy.gd e a cena res://games/flappy/flappy.tscn com física simples de gravidade, pulo com clique e canos gerados proceduralmente como obstáculos."
	},
	{
		"id": "snake",
		"name": "Snake Cyber Grid",
		"prompt": "Use modify_project_file para criar o script completo res://games/snake/snake.gd e a cena res://games/snake/snake.tscn implementando movimento em grade, comida que surge aleatoriamente e cauda que cresce."
	},
	{
		"id": "breakout",
		"name": "Neon Breakout",
		"prompt": "Use modify_project_file para criar o script completo res://games/breakout/breakout.gd e a cena res://games/breakout/breakout.tscn com raquete, bolinha quicando e tijolos ColorRect destrutíveis."
	},
	{
		"id": "space_invaders",
		"name": "Space AI Invaders",
		"prompt": "Use modify_project_file para criar o script completo res://games/space_invaders/space_invaders.gd e a cena res://games/space_invaders/space_invaders.tscn com nave de jogador atirando e grid de invasores se movendo lateralmente."
	},
	{
		"id": "tetris",
		"name": "Block Matrix",
		"prompt": "Use modify_project_file para criar o script completo res://games/tetris/tetris.gd e a cena res://games/tetris/tetris.tscn com grid 10x20, rotação de peças clássicas, queda automática e limpeza de linhas."
	},
	{
		"id": "platformer",
		"name": "Cyber Runner 2D",
		"prompt": "Use modify_project_file para criar o script completo res://games/platformer/platformer.gd e a cena res://games/platformer/platformer.tscn com CharacterBody2D, controle de corrida/pulo com gravidade básica e chão sólido."
	},
	{
		"id": "racing_topdown",
		"name": "Turbo Drift 2D",
		"prompt": "Use modify_project_file para criar o script completo res://games/racing_topdown/racing_topdown.gd e a cena res://games/racing_topdown/racing_topdown.tscn com carro visto de cima, física simples de aceleração/derrapagem por teclado e pista."
	},
	{
		"id": "tower_defense",
		"name": "AI Turret Defense",
		"prompt": "Use modify_project_file para criar o script completo res://games/tower_defense/tower_defense.gd e a cena res://games/tower_defense/tower_defense.tscn com caminho predefinido de inimigos e torres que atiram neles."
	},
	{
		"id": "asteroid_shooter",
		"name": "Asteroid Blaster",
		"prompt": "Use modify_project_file para criar o script completo res://games/asteroid_shooter/asteroid_shooter.gd e a cena res://games/asteroid_shooter/asteroid_shooter.tscn com nave no centro rotacionando em 360 graus e asteroides vindo de todas as direções."
	},
	{
		"id": "memory_puzzle",
		"name": "ReAct Memory Grid",
		"prompt": "Use modify_project_file para criar o script completo res://games/memory_puzzle/memory_puzzle.gd e a cena res://games/memory_puzzle/memory_puzzle.tscn com grade de cartas viradas para baixo e lógica clássica de par correspondente."
	},
	{
		"id": "flappy_3d",
		"name": "Flappy Cyber 3D",
		"prompt": "Use modify_project_file para criar o script completo res://games/flappy_3d/flappy_3d.gd e a cena res://games/flappy_3d/flappy_3d.tscn usando nós 3D, uma câmera 3D, gravidade simples e obstáculos 3D procedurais."
	},
	{
		"id": "rolling_ball_3d",
		"name": "Rolling Sphere 3D",
		"prompt": "Use modify_project_file para criar o script completo res://games/rolling_ball_3d/rolling_ball_3d.gd e a cena res://games/rolling_ball_3d/rolling_ball_3d.tscn com RigidBody3D de esfera controlado pelo jogador, plataformas 3D e luz."
	},
	{
		"id": "isometric_shooter",
		"name": "Iso Mech Arena",
		"prompt": "Use modify_project_file para criar o script completo res://games/isometric_shooter/isometric_shooter.gd e a cena res://games/isometric_shooter/isometric_shooter.tscn com câmera isométrica, personagem se movendo no plano e atirando em inimigos."
	},
	{
		"id": "raycaster_3d",
		"name": "Retro Raycaster 3D",
		"prompt": "Use modify_project_file para criar o script completo res://games/raycaster_3d/raycaster_3d.gd e a cena res://games/raycaster_3d/raycaster_3d.tscn desenhando fatias verticais para criar visual pseudo-3D Wolfenstein no Godot."
	}
]

var current_task_index: int = 0
var active_scene_node: Node = null

func _initialize() -> void:
	print("\n=========================================================================")
	print("[CromAgentOrchestrator] Conectando Agente Gemini 2.5 à Bateria de 15 Testes")
	print("=========================================================================")
	
	# Prepara diretórios e arquivos README de cada jogo
	var game_registry = load("res://addons/crom_ai/core/game_registry.gd")
	if game_registry:
		game_registry.setup_benchmark_directories()
	
	var MonClass = load("res://benchmark/benchmark_monitor.gd")
	monitor = MonClass.new()
	root.add_child(monitor)
	monitor.benchmark_finished.connect(_on_benchmark_done)
	
	var ProcClass = load("res://addons/crom_ai/command_processor.gd")
	proc = ProcClass.new(null)
	proc.name = "CommandProcessor"
	root.add_child(proc)
	
	var EngineClass = load("res://addons/crom_ai/native_react_engine.gd")
	engine = EngineClass.new(proc)
	engine.name = "NativeReActEngine"
	root.add_child(engine)
	
	engine.set_config("openrouter", "google/gemini-2.5-flash", "sk-or-v1-key-removed-by-antigravity")
	
	engine.message_added.connect(func(role, text):
		if role == "tool_call" or role == "tool_res":
			print("   -> [%s]: %s" % [role.to_upper(), text.substr(0, 140)])
	)
	
	engine.react_finished.connect(_on_agent_finished_task)
	engine.error_occurred.connect(_on_agent_error)
	
	await process_frame
	_start_next_test_task()

func _start_next_test_task() -> void:
	if active_scene_node:
		active_scene_node.queue_free()
		active_scene_node = null
		
	if current_task_index >= test_tasks.size():
		print("\n=========================================================================")
		print("🏆 TODOS OS 15 TESTES DE JOGOS FORAM PROCESSADOS PELO AGENTE GEMINI 2.5!")
		print("=========================================================================")
		quit()
		return
		
	var task = test_tasks[current_task_index]
	print("\n>>> [AGENTE INICIANDO TESTE %d/15] %s (%s) <<<" % [current_task_index + 1, task["name"], task["id"]])
	
	# Envia prompt dinâmico instruindo a leitura do README correspondente
	var readme_path = "res://games/" + task["id"] + "/README.md"
	var prompt = "Você é o Agente ReAct Godot na IDE. Sua tarefa atual é: " + task["prompt"] + "\n"
	prompt += "ATENÇÃO OBRIGATÓRIA:\n"
	prompt += "- Você DEVE ler as especificações exatas e completas do jogo no arquivo: " + readme_path + " ANTES de criar os códigos.\n"
	prompt += "- Crie a cena e scripts seguindo estritamente as regras desse arquivo README.\n"
	engine.send_user_prompt(prompt)

func _on_agent_finished_task(final_answer: String) -> void:
	if current_task_index >= test_tasks.size():
		return
	var task = test_tasks[current_task_index]
	print("\n[Agente Concluiu Tarefa %s]:\n%s" % [task["id"], final_answer.substr(0, 200)])
	
	# Garante que a cena exista
	var tscn_path = "res://games/" + task["id"] + "/" + task["id"] + ".tscn"
	if not ResourceLoader.exists(tscn_path):
		var gd_path = "res://games/" + task["id"] + "/" + task["id"] + ".gd"
		# Se não existir .tscn mas existir .gd, tenta instanciar via script ou criar cena básica
		var s_res = load(gd_path)
		if s_res:
			print("[Orquestrador] Instanciando cena a partir do script gerado pelo agente: %s" % gd_path)
			var temp_node = Node2D.new()
			temp_node.set_script(s_res)
			active_scene_node = temp_node
			root.add_child(active_scene_node)
	else:
		var scene_res = load(tscn_path) as PackedScene
		if scene_res:
			active_scene_node = scene_res.instantiate()
			root.add_child(active_scene_node)
			
	# Inicia o Benchmark Telemetria do Jogo (3 segundos por jogo)
	monitor.start_benchmark(task["id"], 3.0)

func _on_benchmark_done(game_id: String, report: Dictionary) -> void:
	print("📊 [Benchmark Concluído para %s] FPS Médio: %.1f | Memória: %.2f MB | Delta Spike: %.2f ms" % [
		game_id, report["fps"]["average"], report["memory_mb"]["peak"], report["frame_time_ms"]["max_spike"]
	])
	current_task_index += 1
	_start_next_test_task()

func _on_agent_error(err_msg: String) -> void:
	if current_task_index >= test_tasks.size():
		return
	print("\n⚠️ [Erro no Agente durante teste %d]: %s" % [current_task_index + 1, err_msg])
	# Pula para o próximo teste ou tenta rodar o benchmark
	current_task_index += 1
	_start_next_test_task()
