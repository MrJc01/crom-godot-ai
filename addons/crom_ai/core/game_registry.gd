class_name GameRegistry

# ==============================================================================
# Game Registry — Dados puros dos 15 minijogos procedurais
# Responsabilidade única: armazenar e consultar metadados de jogos.
# Nenhuma lógica de UI aqui.
# ==============================================================================

static var _games: Array[Dictionary] = [
	{"id": "pong",              "name": "Crom Pong ReAct",     "type": "2D", "tscn": "res://games/pong/pong.tscn"},
	{"id": "flappy",            "name": "Flappy AI Bird",      "type": "2D", "tscn": "res://games/flappy/flappy.tscn"},
	{"id": "snake",             "name": "Snake Cyber Grid",    "type": "2D", "tscn": "res://games/snake/snake.tscn"},
	{"id": "breakout",          "name": "Neon Breakout",       "type": "2D", "tscn": "res://games/breakout/breakout.tscn"},
	{"id": "space_invaders",    "name": "Space AI Invaders",   "type": "2D", "tscn": "res://games/space_invaders/space_invaders.tscn"},
	{"id": "tetris",            "name": "Block Matrix",        "type": "2D", "tscn": "res://games/tetris/tetris.tscn"},
	{"id": "platformer",        "name": "Cyber Runner 2D",     "type": "2D", "tscn": "res://games/platformer/platformer.tscn"},
	{"id": "racing_topdown",    "name": "Turbo Drift 2D",      "type": "2D", "tscn": "res://games/racing_topdown/racing_topdown.tscn"},
	{"id": "tower_defense",     "name": "AI Turret Defense",   "type": "2D", "tscn": "res://games/tower_defense/tower_defense.tscn"},
	{"id": "asteroid_shooter",  "name": "Asteroid Blaster",    "type": "2D", "tscn": "res://games/asteroid_shooter/asteroid_shooter.tscn"},
	{"id": "memory_puzzle",     "name": "ReAct Memory Grid",   "type": "UI", "tscn": "res://games/memory_puzzle/memory_puzzle.tscn"},
	{"id": "flappy_3d",         "name": "Flappy Cyber 3D",     "type": "3D", "tscn": "res://games/flappy_3d/flappy_3d.tscn"},
	{"id": "rolling_ball_3d",   "name": "Rolling Sphere 3D",   "type": "3D", "tscn": "res://games/rolling_ball_3d/rolling_ball_3d.tscn"},
	{"id": "isometric_shooter", "name": "Iso Mech Arena",      "type": "3D", "tscn": "res://games/isometric_shooter/isometric_shooter.tscn"},
	{"id": "raycaster_3d",      "name": "Retro Raycaster 3D",  "type": "3D", "tscn": "res://games/raycaster_3d/raycaster_3d.tscn"},
]

static func get_all() -> Array[Dictionary]:
	return _games

static func get_by_id(id: String) -> Dictionary:
	for g in _games:
		if g["id"] == id:
			return g
	return {}

static func get_available() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for g in _games:
		if FileAccess.file_exists(g["tscn"]):
			result.append(g)
	return result

static func get_available_count() -> int:
	return get_available().size()

static func get_total_count() -> int:
	return _games.size()

static func is_available(id: String) -> bool:
	var g := get_by_id(id)
	if g.is_empty():
		return false
	return FileAccess.file_exists(g["tscn"])

static func setup_benchmark_directories() -> void:
	if not DirAccess.dir_exists_absolute("res://games"):
		DirAccess.make_dir_recursive_absolute("res://games")
		
	if not DirAccess.dir_exists_absolute("res://benchmark"):
		DirAccess.make_dir_recursive_absolute("res://benchmark")
		var master_bench := "/home/j/Documentos/GitHub/crom-godot-ai/benchmark"
		if DirAccess.dir_exists_absolute(master_bench):
			OS.execute("cp", ["-rf", master_bench + "/.", ProjectSettings.globalize_path("res://benchmark/")])
			
	# Criar pastas para cada jogo listado no registry
	for g in _games:
		var sub_path = "res://games/" + g["id"]
		if not DirAccess.dir_exists_absolute(sub_path):
			DirAccess.make_dir_recursive_absolute(sub_path)
			
	# Criar README.md com instruções completas
	var f := FileAccess.open("res://games/README.md", FileAccess.WRITE)
	if f:
		f.store_string("# CromAI Benchmark - 15 Jogos procedurais\n\nEste diretório contém o ambiente para os minijogos procedurais do CromAI Hub. O Agente ReAct deve criar as cenas (.tscn) e scripts (.gd) para cada jogo conforme listado abaixo:\n\n1. **pong** (res://games/pong/pong.tscn)\n2. **flappy** (res://games/flappy/flappy.tscn)\n3. **snake** (res://games/snake/snake.tscn)\n4. **breakout** (res://games/breakout/breakout.tscn)\n5. **space_invaders** (res://games/space_invaders/space_invaders.tscn)\n6. **tetris** (res://games/tetris/tetris.tscn)\n7. **platformer** (res://games/platformer/platformer.tscn)\n8. **racing_topdown** (res://games/racing_topdown/racing_topdown.tscn)\n9. **tower_defense** (res://games/tower_defense/tower_defense.tscn)\n10. **asteroid_shooter** (res://games/asteroid_shooter/asteroid_shooter.tscn)\n11. **memory_puzzle** (res://games/memory_puzzle/memory_puzzle.tscn)\n12. **flappy_3d** (res://games/flappy_3d/flappy_3d.tscn)\n13. **rolling_ball_3d** (res://games/rolling_ball_3d/rolling_ball_3d.tscn)\n14. **isometric_shooter** (res://games/isometric_shooter/isometric_shooter.tscn)\n15. **raycaster_3d** (res://games/raycaster_3d/raycaster_3d.tscn)\n")
		f.close()

