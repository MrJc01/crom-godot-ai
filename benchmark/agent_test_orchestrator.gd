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
		"id": "game_01_pong",
		"name": "Pong Clássico",
		"prompt": "Verifique o arquivo res://games/game_01_pong/pong.gd usando read_project_file. Se precisar de algum ajuste para o jogo rodar com perfeição, use modify_project_file. Em seguida confirme que o jogo está pronto para o teste de desempenho."
	},
	{
		"id": "game_02_snake",
		"name": "Snake Grid",
		"prompt": "Verifique o arquivo res://games/game_02_snake/snake.gd usando read_project_file. Se precisar de ajustes na grade ou nas maçãs, use modify_project_file e me avise."
	},
	{
		"id": "game_03_flappy",
		"name": "Flappy Bird Clone",
		"prompt": "Verifique o arquivo res://games/game_03_flappy/flappy.gd com read_project_file. Certifique-se que usa res://assets/sprites/flappy_bird.svg e pipe.svg. Faça melhorias se necessário via modify_project_file."
	},
	{
		"id": "game_04_breakout",
		"name": "Breakout Arkanoid",
		"prompt": "Use modify_project_file para criar o script completo res://games/game_04_breakout/breakout.gd. O jogo deve ter uma raquete controlada por teclado/mouse, uma bolinha com ricochete em paredes e raquete, e uma matriz 8x5 de tijolos destrutíveis em ColorRect. Depois crie a cena res://games/game_04_breakout/breakout.tscn se necessário."
	},
	{
		"id": "game_05_space_invaders",
		"name": "Space Invaders",
		"prompt": "Use modify_project_file para criar o script res://games/game_05_space_invaders/space_invaders.gd utilizando o asset res://assets/sprites/invader.svg e res://assets/sprites/hero.svg. O jogo deve ter nave do jogador na base atirando projéteis e uma matriz 6x4 de invasores que se move de lado e desce."
	},
	{
		"id": "game_06_asteroids",
		"name": "Asteroids Vetorial",
		"prompt": "Use modify_project_file para criar o script res://games/game_06_asteroids/asteroids.gd com nave giratória em 360 graus, impulso vetorial em espaço toroidal (tela sem bordas) e asteroides que se dividem ao levar tiros."
	},
	{
		"id": "game_07_tetris",
		"name": "Crom-Blocks Tetris",
		"prompt": "Use modify_project_file para criar o script res://games/game_07_tetris/tetris.gd implementando matriz 10x20, rotação de peças (I, O, T, L, J, S, Z), detecção e limpeza de linhas completas e pontuação."
	},
	{
		"id": "game_08_endless_runner",
		"name": "Endless Dino Runner",
		"prompt": "Use modify_project_file para criar o script res://games/game_08_endless_runner/runner.gd com rolagem de chão/obstáculos, salto com gravidade e pontuação crescente com o tempo."
	},
	{
		"id": "game_09_topdown_dungeon",
		"name": "Top-Down Dungeon",
		"prompt": "Use modify_project_file para criar o script res://games/game_09_topdown_dungeon/dungeon.gd utilizando res://assets/sprites/hero.svg. Movimento em 4 direções (W/A/S/D), ataque de espada, e coleta de moedas (res://assets/sprites/coin.svg)."
	},
	{
		"id": "game_10_platformer",
		"name": "Super Crom Bros Platformer",
		"prompt": "Use modify_project_file para criar res://games/game_10_platformer/platformer.gd com gravidade, pulo com coyote time, plataformas sólidas e moedas para coletar."
	},
	{
		"id": "game_11_tower_defense",
		"name": "Tower Defense Mini",
		"prompt": "Use modify_project_file para criar res://games/game_11_tower_defense/tower_defense.gd com um caminho predefinido onde inimigos se movem em fila e torres posicionadas atiram automaticamente em inimigos no raio de alcance."
	},
	{
		"id": "game_12_clicker_idle",
		"name": "Crom Tycoon Idle Clicker",
		"prompt": "Use modify_project_file para criar res://games/game_12_clicker_idle/clicker.gd com botão de clique que gera moedas, multiplicadores de cliques automáticos por segundo (CPS) e formatação de números grandes."
	},
	{
		"id": "game_13_memory_match",
		"name": "Card Memory Game",
		"prompt": "Use modify_project_file para criar res://games/game_13_memory_match/memory.gd utilizando res://assets/sprites/card_back.svg e card_front_1 a 6.svg. Grade 4x3 com lógica de virar 2 cartas, checar par, travar se correto ou desvirar com delay."
	},
	{
		"id": "game_14_raycaster",
		"name": "2D/3D CPU Raycaster",
		"prompt": "Use modify_project_file para criar res://games/game_14_raycaster/raycaster.gd implementando algoritmo de Raycasting DDA simples em matriz 2D, desenhando fatias verticais coloridas para simular visão 3D em primeira pessoa."
	},
	{
		"id": "game_15_3d_rolling_ball",
		"name": "3D Rolling Ball Physics",
		"prompt": "Use modify_project_file para criar res://games/game_15_3d_rolling_ball/rolling_ball.gd com nós 3D puros (Camera3D, DirectionalLight3D, RigidBody3D em uma rampa/plataforma MeshInstance3D) permitindo rolar a esfera com W/A/S/D."
	}
]

var current_task_index: int = 0
var active_scene_node: Node = null

func _initialize() -> void:
	print("\n=========================================================================")
	print("[CromAgentOrchestrator] Conectando Agente Gemini 2.5 à Bateria de 15 Testes")
	print("=========================================================================")
	
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
	print("\n>>> [AGENTE INICIANDO TESTE %d/15] %s (%s) <<<" % [current_task_index + 1, test_tasks.size(), task["name"], task["id"]])
	
	# Envia prompt ao Agente
	engine.send_user_prompt(task["prompt"])

func _on_agent_finished_task(final_answer: String) -> void:
	if current_task_index >= test_tasks.size():
		return
	var task = test_tasks[current_task_index]
	print("\n[Agente Concluiu Tarefa %s]:\n%s" % [task["id"], final_answer.substr(0, 200)])
	
	# Garante que a cena exista
	var tscn_path = "res://games/" + task["id"] + "/" + task["id"].split("_")[-1] + ".tscn"
	if not ResourceLoader.exists(tscn_path):
		var gd_path = "res://games/" + task["id"] + "/" + task["id"].split("_")[-1] + ".gd"
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
