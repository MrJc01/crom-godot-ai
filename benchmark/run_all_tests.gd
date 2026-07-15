extends SceneTree

# ==============================================================================
# Harness Automatizado: Roda os 15 Jogos Sequencialmente em Modo Headless/Test
# ==============================================================================

var game_paths: Array[String] = [
	"res://games/pong/pong.tscn",
	"res://games/flappy/flappy.tscn",
	"res://games/snake/snake.tscn",
	"res://games/breakout/breakout.tscn",
	"res://games/space_invaders/space_invaders.tscn",
	"res://games/tetris/tetris.tscn",
	"res://games/platformer/platformer.tscn",
	"res://games/racing_topdown/racing_topdown.tscn",
	"res://games/tower_defense/tower_defense.tscn",
	"res://games/asteroid_shooter/asteroid_shooter.tscn",
	"res://games/memory_puzzle/memory_puzzle.tscn",
	"res://games/flappy_3d/flappy_3d.tscn",
	"res://games/rolling_ball_3d/rolling_ball_3d.tscn",
	"res://games/isometric_shooter/isometric_shooter.tscn",
	"res://games/raycaster_3d/raycaster_3d.tscn"
]

var current_index: int = 0
var current_scene_node: Node = null
var monitor: Node = null
var all_reports: Array[Dictionary] = []

func _initialize() -> void:
	print("\n=================================================================")
	print("[CromTestHarness] Iniciando bateria automatizada de 15 minijogos!")
	print("=================================================================")
	
	var MonClass = load("res://benchmark/benchmark_monitor.gd")
	if MonClass:
		monitor = MonClass.new()
		root.add_child(monitor)
		monitor.benchmark_finished.connect(_on_benchmark_finished)
		
	_run_next_game()

func _run_next_game() -> void:
	if current_scene_node:
		current_scene_node.queue_free()
		current_scene_node = null
		
	if current_index >= game_paths.size():
		_finish_all_tests()
		return
		
	var path = game_paths[current_index]
	var game_id = path.get_file().get_basename()
	print("\n--- Testando (%d/%d): %s ---" % [current_index + 1, game_paths.size(), game_id])
	
	if not ResourceLoader.exists(path):
		print("[Aviso] Cena ainda não criada: %s. Pulando..." % path)
		current_index += 1
		_run_next_game()
		return
		
	var scene_res = load(path) as PackedScene
	if scene_res:
		current_scene_node = scene_res.instantiate()
		root.add_child(current_scene_node)
		if monitor and monitor.has_method("start_benchmark"):
			monitor.start_benchmark(game_id, 3.0) # 3s por jogo na bateria rápida
	else:
		print("[Erro] Falha ao carregar cena PackedScene: %s" % path)
		current_index += 1
		_run_next_game()

func _on_benchmark_finished(_game_id: String, report: Dictionary) -> void:
	all_reports.append(report)
	current_index += 1
	_run_next_game()

func _finish_all_tests() -> void:
	print("\n=================================================================")
	print("[CromTestHarness] Todos os %d testes de jogos concluídos!" % all_reports.size())
	print("=================================================================")
	
	_save_consolidated_summary()
	quit()

func _save_consolidated_summary() -> void:
	var dir_path = "user://benchmark_logs"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var summary_path = dir_path + "/summary_report.md"
	
	var md = "# 🏆 Relatório Consolidado de Desempenho (Suíte de 15 Jogos)\n\n"
	md += "Gerado pelo `run_all_tests.gd` em: **%s**\n\n" % Time.get_datetime_string_from_system()
	md += "| # | Jogo (`ID`) | FPS Médio | Delta Média | Memória Pico | Nós na Cena | Avaliação |\n"
	md += "|---|---|---|---|---|---|---|\n"
	
	for idx in range(all_reports.size()):
		var rep = all_reports[idx]
		var status_emoji = "✅ Excelente" if rep["fps"]["average"] >= 58.0 else "⚠️ Atenção"
		md += "| %d | `%s` | **%.1f** | `%.2f ms` | `%.2f MB` | `%d` | %s |\n" % [
			idx + 1,
			rep["game_id"],
			rep["fps"]["average"],
			rep["frame_time_ms"]["average"],
			rep["memory_mb"]["peak"],
			rep["scene_nodes"],
			status_emoji
		]
		
	md += "\n---\n*Para ver os insights de otimização individuais, consulte os arquivos `{game_id}_report.md` na pasta `user://benchmark_logs`.*"
	
	var f = FileAccess.open(summary_path, FileAccess.WRITE)
	if f:
		f.store_string(md)
		f.close()
		print("[CromTestHarness] Relatório consolidado salvo em: %s" % summary_path)
