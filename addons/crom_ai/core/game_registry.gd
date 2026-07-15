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
			
	var instructions := {
		"pong": "Crie um jogo Pong clássico de 2D. Deve possuir raquetes (uma controlada pelo jogador com W/S ou setas, e outra com IA básica simples que segue a bola), uma bola física com vetor de velocidade que ricocheteia nas bordas e raquetes, e sistema de pontuação (placar) exibido na tela.",
		"flappy": "Crie um clone de Flappy Bird 2D. O jogador controla um pássaro que cai com gravidade e pula ao clicar na tela ou pressionar Espaço. Canos duplos (topo e base) devem surgir proceduralmente do lado direito e mover-se para a esquerda. O jogo termina ao colidir com o chão ou canos, marcando pontos ao passar por eles.",
		"snake": "Crie um jogo Snake 2D clássico em grade. A cobra se move continuamente em uma direção e o jogador altera o rumo com as setas. Comidas surgem em posições aleatórias da grade. Ao comer, o placar aumenta e o corpo da cobra cresce. O jogo termina se a cobra colidir com as bordas da tela ou consigo mesma.",
		"breakout": "Crie um jogo Breakout / Arkanoid 2D. Deve possuir uma raquete na parte inferior controlada pelas teclas A/D ou mouse, uma bola física que ricocheteia, e uma grade de tijolos ColorRect coloridos na parte superior. Ao colidir com a bola, os tijolos devem sumir e somar pontos.",
		"space_invaders": "Crie um jogo Space Invaders 2D. O jogador controla uma nave na base que se move horizontalmente e atira projéteis para cima. Uma grade de naves invasoras deve mover-se lateralmente no topo, descendo um nível ao atingir a borda da tela. Se os invasores atingirem a base ou a nave do jogador, o jogo termina.",
		"tetris": "Crie um jogo Tetris 2D clássico. Implemente uma grade de matriz de 10x20. Peças clássicas (I, O, T, L, J, S, Z) formadas por blocos devem cair de forma constante. O jogador pode rotacionar, mover lateralmente e acelerar a queda. Ao preencher uma linha inteira, ela deve ser eliminada e somar pontos.",
		"platformer": "Crie um jogo de plataforma 2D simples (Super Mario style). O jogador controla um CharacterBody2D que corre e pula com gravidade. Coloque plataformas sólidas no cenário e moedas flutuantes que somam pontos ao serem coletadas.",
		"racing_topdown": "Crie um jogo de corrida Top-Down 2D. O jogador controla um carro visto de cima. Implemente aceleração, freio, direção e uma simulação simples de drift/derrapagem. Adicione uma pista simples e um timer de voltas.",
		"tower_defense": "Crie um mini Tower Defense 2D. Inimigos devem surgir em ondas e andar por um caminho predefinido. O jogador pode posicionar torres de defesa que atiram projéteis automaticamente nos inimigos dentro de seu raio de alcance.",
		"asteroid_shooter": "Crie um jogo Asteroids 2D clássico. O jogador controla uma nave espacial no centro que gira 360 graus e atira. Asteroides surgem das bordas da tela e movem-se em direções aleatórias. Se atingidos, eles devem se dividir em pedaços menores.",
		"memory_puzzle": "Crie um jogo da memória UI. Apresente uma grade 4x3 de cartas viradas para baixo. Ao clicar em uma carta, ela revela sua cor ou figura. O jogador deve clicar em duas cartas consecutivas para tentar achar o par. Se iguais, ficam reveladas; se diferentes, desviram após um breve delay.",
		"flappy_3d": "Crie um Flappy Bird em 3D puros. Utilize Camera3D, RigidBody3D/CharacterBody3D para o pássaro e cilindros/caixas 3D posicionados proceduralmente como canos/obstáculos. O jogador pula com cliques e os canos se movem horizontalmente no espaço 3D.",
		"rolling_ball_3d": "Crie um jogo 3D de bola rolando. O jogador controla uma esfera RigidBody3D usando as teclas W/A/S/D para aplicar forças. Coloque plataformas 3D suspensas com rampas, obstáculos físicos e itens colecionáveis espalhados no cenário 3D.",
		"isometric_shooter": "Crie um jogo de tiro isométrico 3D. Posicione a câmera em ângulo isométrico focando o jogador. O jogador se move no plano e atira na direção do cursor do mouse/teclado. Inimigos devem surgir e caçar o jogador pela arena.",
		"raycaster_3d": "Crie um pseudo-3D Raycaster clássico (estilo Wolfenstein 3D). Implemente um algoritmo de Raycasting na CPU usando DDA para desenhar fatias de parede verticais texturizadas ou coloridas com base em um mapa de matriz 2D."
	}
	
	# Criar pastas para cada jogo listado no registry
	for g in _games:
		var sub_path = "res://games/" + g["id"]
		if not DirAccess.dir_exists_absolute(sub_path):
			DirAccess.make_dir_recursive_absolute(sub_path)
			
		# Criar o README.md específico com as instruções do jogo
		var file_path = sub_path + "/README.md"
		if not FileAccess.file_exists(file_path):
			var f_game := FileAccess.open(file_path, FileAccess.WRITE)
			if f_game:
				var desc = instructions.get(g["id"], "Crie o jogo " + g["name"] + ".")
				var content = "# CromAI Minijogo - " + g["name"] + "\n\n## Instruções para o Agente:\n" + desc + "\n\n## Arquivos Esperados:\n- Script principal: `res://games/" + g["id"] + "/" + g["id"] + ".gd`\n- Cena principal: `res://games/" + g["id"] + "/" + g["id"] + ".tscn`\n"
				f_game.store_string(content)
				f_game.close()
				
	# Criar README.md geral com instruções completas
	var f := FileAccess.open("res://games/README.md", FileAccess.WRITE)
	if f:
		f.store_string("# CromAI Benchmark - 15 Jogos procedurais\n\nEste diretório contém o ambiente para os minijogos procedurais do CromAI Hub. O Agente ReAct deve criar as cenas (.tscn) e scripts (.gd) para cada jogo conforme listado abaixo:\n\n1. **pong** (res://games/pong/pong.tscn)\n2. **flappy** (res://games/flappy/flappy.tscn)\n3. **snake** (res://games/snake/snake.tscn)\n4. **breakout** (res://games/breakout/breakout.tscn)\n5. **space_invaders** (res://games/space_invaders/space_invaders.tscn)\n6. **tetris** (res://games/tetris/tetris.tscn)\n7. **platformer** (res://games/platformer/platformer.tscn)\n8. **racing_topdown** (res://games/racing_topdown/racing_topdown.tscn)\n9. **tower_defense** (res://games/tower_defense/tower_defense.tscn)\n10. **asteroid_shooter** (res://games/asteroid_shooter/asteroid_shooter.tscn)\n11. **memory_puzzle** (res://games/memory_puzzle/memory_puzzle.tscn)\n12. **flappy_3d** (res://games/flappy_3d/flappy_3d.tscn)\n13. **rolling_ball_3d** (res://games/rolling_ball_3d/rolling_ball_3d.tscn)\n14. **isometric_shooter** (res://games/isometric_shooter/isometric_shooter.tscn)\n15. **raycaster_3d** (res://games/raycaster_3d/raycaster_3d.tscn)\n")
		f.close()

