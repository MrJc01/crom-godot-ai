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
