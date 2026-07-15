extends Control

# ==============================================================================
# CromAI ReAct Arcade Hub & Telemetry Suite
# Interface elegante para o usuário testar os 15 jogos, acionar o Agente IA e rodar Benchmarks!
# ==============================================================================

var game_list: Array[Dictionary] = [
	{"id": "game_01_pong", "name": "Pong Clássico", "type": "Procedural", "tscn": "res://games/game_01_pong/pong.tscn"},
	{"id": "game_02_snake", "name": "Snake Grid", "type": "Procedural", "tscn": "res://games/game_02_snake/snake.tscn"},
	{"id": "game_03_flappy", "name": "Flappy Bird Clone", "type": "Assets SVG", "tscn": "res://games/game_03_flappy/flappy.tscn"},
	{"id": "game_04_breakout", "name": "Breakout Arkanoid", "type": "Procedural", "tscn": "res://games/game_04_breakout/breakout.tscn"},
	{"id": "game_05_space_invaders", "name": "Space Invaders", "type": "Assets SVG", "tscn": "res://games/game_05_space_invaders/space_invaders.tscn"},
	{"id": "game_06_asteroids", "name": "Asteroids Vetorial", "type": "Procedural", "tscn": "res://games/game_06_asteroids/asteroids.tscn"},
	{"id": "game_07_tetris", "name": "Crom-Blocks Tetris", "type": "Procedural", "tscn": "res://games/game_07_tetris/tetris.tscn"},
	{"id": "game_08_endless_runner", "name": "Endless Dino Runner", "type": "Procedural", "tscn": "res://games/game_08_endless_runner/runner.tscn"},
	{"id": "game_09_topdown_dungeon", "name": "Top-Down Dungeon", "type": "Assets SVG", "tscn": "res://games/game_09_topdown_dungeon/dungeon.tscn"},
	{"id": "game_10_platformer", "name": "Super Crom Bros", "type": "Assets SVG", "tscn": "res://games/game_10_platformer/platformer.tscn"},
	{"id": "game_11_tower_defense", "name": "Tower Defense Mini", "type": "Procedural", "tscn": "res://games/game_11_tower_defense/tower_defense.tscn"},
	{"id": "game_12_clicker_idle", "name": "Crom Tycoon Idle", "type": "Procedural", "tscn": "res://games/game_12_clicker_idle/clicker.tscn"},
	{"id": "game_13_memory_match", "name": "Card Memory Game", "type": "Assets SVG", "tscn": "res://games/game_13_memory_match/memory.tscn"},
	{"id": "game_14_raycaster", "name": "2D/3D CPU Raycaster", "type": "Procedural", "tscn": "res://games/game_14_raycaster/raycaster.tscn"},
	{"id": "game_15_3d_rolling_ball", "name": "3D Rolling Ball", "type": "Assets 3D/SVG", "tscn": "res://games/game_15_3d_rolling_ball/rolling_ball.tscn"}
]

var active_game_node: Node = null
var active_game_info: Dictionary = {}
var engine: Node = null
var monitor: Node = null

var games_container: VBoxContainer
var viewport_sub: SubViewport
var log_box: RichTextLabel
var status_label: Label
var stats_label: Label

func _ready() -> void:
	_setup_theme_and_layout()
	_init_agent_and_monitor()
	_populate_games_list()
	if game_list.size() > 0:
		_load_game(game_list[0])

func _setup_theme_and_layout() -> void:
	# Fundo Escuro Elegante (Glassmorphism / Dark Palette)
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.09)
	add_child(bg)
	
	# Top Header Bar
	var header = Panel.new()
	header.position = Vector2(0, 0)
	header.size = Vector2(1152, 64)
	add_child(header)
	
	var title = Label.new()
	title.position = Vector2(24, 12)
	title.size = Vector2(800, 40)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	title.text = "⚡ CromAI ReAct Arcade Hub & Telemetry Suite (15 Jogos)"
	header.add_child(title)
	
	# Painel Esquerdo: Lista de Jogos
	var left_scroll = ScrollContainer.new()
	left_scroll.position = Vector2(16, 76)
	left_scroll.size = Vector2(280, 556)
	add_child(left_scroll)
	
	games_container = VBoxContainer.new()
	games_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(games_container)
	
	# Centro: SubViewport onde os minijogos rodam
	var center_panel = PanelContainer.new()
	center_panel.position = Vector2(308, 76)
	center_panel.size = Vector2(536, 380)
	add_child(center_panel)
	
	viewport_sub = SubViewport.new()
	viewport_sub.size = Vector2i(1152, 648)
	viewport_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_sub.handle_input_locally = false
	add_child(viewport_sub)
	
	center_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var game_display = TextureRect.new()
	game_display.texture = viewport_sub.get_texture()
	game_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_panel.add_child(game_display)
	
	# Centro Baixo: Logs do Agente IA e do Monitor
	var log_panel = Panel.new()
	log_panel.position = Vector2(308, 466)
	log_panel.size = Vector2(536, 166)
	add_child(log_panel)
	
	log_box = RichTextLabel.new()
	log_box.position = Vector2(8, 8)
	log_box.size = Vector2(520, 150)
	log_box.scroll_following = true
	log_box.add_theme_font_size_override("normal_font_size", 14)
	log_box.append_text("[color=#89b4fa]✨ Arcade Hub Inicializado.[/color]\nSelecione um jogo à esquerda para jogar ou acionar o Agente Gemini 2.5!\n")
	log_panel.add_child(log_box)
	
	# Painel Direito: Ações IA e Telemetria
	var right_panel = Panel.new()
	right_panel.position = Vector2(856, 76)
	right_panel.size = Vector2(280, 556)
	add_child(right_panel)
	
	var right_box = VBoxContainer.new()
	right_box.position = Vector2(12, 12)
	right_box.size = Vector2(256, 532)
	right_panel.add_child(right_box)
	
	var actions_title = Label.new()
	actions_title.text = "🤖 Controle do Agente"
	actions_title.add_theme_font_size_override("font_size", 20)
	actions_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	right_box.add_child(actions_title)
	
	var btn_agent_inspect = Button.new()
	btn_agent_inspect.text = "🔍 Agente: Inspecionar Jogo"
	btn_agent_inspect.custom_minimum_size = Vector2(0, 40)
	btn_agent_inspect.pressed.connect(_on_btn_agent_inspect)
	right_box.add_child(btn_agent_inspect)
	
	var btn_agent_play = Button.new()
	btn_agent_play.text = "🎮 Agente: Jogar/Testar"
	btn_agent_play.custom_minimum_size = Vector2(0, 40)
	btn_agent_play.pressed.connect(_on_btn_agent_play)
	right_box.add_child(btn_agent_play)
	
	var btn_agent_refactor = Button.new()
	btn_agent_refactor.text = "🛠️ Agente: Otimizar Código"
	btn_agent_refactor.custom_minimum_size = Vector2(0, 40)
	btn_agent_refactor.pressed.connect(_on_btn_agent_refactor)
	right_box.add_child(btn_agent_refactor)
	
	right_box.add_child(HSeparator.new())
	
	var tele_title = Label.new()
	tele_title.text = "📊 Telemetria ao Vivo"
	tele_title.add_theme_font_size_override("font_size", 20)
	tele_title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	right_box.add_child(tele_title)
	
	stats_label = Label.new()
	stats_label.text = "FPS: 60.0\nMemória: -- MB\nNós na Cena: --"
	right_box.add_child(stats_label)

func _init_agent_and_monitor() -> void:
	var MonClass = load("res://benchmark/benchmark_monitor.gd")
	if MonClass:
		monitor = MonClass.new()
		add_child(monitor)
		monitor.benchmark_finished.connect(func(g_id, rep):
			_log("[color=#a6e3a1]✅ Benchmark concluído para %s: %.1f FPS (Pico: %.1f MB)[/color]" % [g_id, rep["fps"]["average"], rep["memory_mb"]["peak"]])
		)
		
	var ProcClass = load("res://addons/crom_ai/command_processor.gd")
	var proc = ProcClass.new(null)
	add_child(proc)
	
	var EngineClass = load("res://addons/crom_ai/native_react_engine.gd")
	if EngineClass:
		engine = EngineClass.new(proc)
		add_child(engine)
		engine.set_config("openrouter", "google/gemini-2.5-flash", "sk-or-v1-key-removed-by-antigravity")
		engine.message_added.connect(func(role, text):
			if role == "tool_call":
				_log("[color=#fab387]🤖 Ferramenta Acionada:[/color] " + text.substr(0, 100))
		)
		engine.react_finished.connect(func(ans):
			_log("[color=#cba6f7]🤖 Resposta Final do Agente:[/color]\n" + ans)
		)

func _populate_games_list() -> void:
	for c in games_container.get_children(): c.queue_free()
	for g in game_list:
		var exists = FileAccess.file_exists(g["tscn"])
		var status_icon = "✅" if exists else "⏳"
		var btn = Button.new()
		btn.text = "%s [%s] %s" % [g["name"], g["type"], status_icon]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 34)
		btn.disabled = not exists
		if exists:
			btn.pressed.connect(func(): _load_game(g))
		games_container.add_child(btn)

func _load_game(info: Dictionary) -> void:
	active_game_info = info
	if active_game_node:
		active_game_node.queue_free()
		active_game_node = null
		
	_log("[color=#89b4fa]Carregando jogo:[/color] [b]%s[/b] (%s)" % [info["name"], info["tscn"]])
	var scene_res = load(info["tscn"]) as PackedScene
	if scene_res:
		active_game_node = scene_res.instantiate()
		viewport_sub.add_child(active_game_node)
	else:
		_log("[color=#f38ba8]Erro ao carregar cena:[/color] %s" % info["tscn"])

func _input(event: InputEvent) -> void:
	if viewport_sub and is_instance_valid(viewport_sub):
		if event is InputEventKey:
			viewport_sub.push_input(event)
		elif (event is InputEventMouseButton or event is InputEventMouseMotion):
			if Rect2(Vector2(308, 76), Vector2(536, 380)).has_point(event.global_position):
				viewport_sub.push_input(event)

func _process(_delta: float) -> void:
	if stats_label and is_inside_tree():
		var fps = Engine.get_frames_per_second()
		var mem = OS.get_static_memory_usage() / 1048576.0
		stats_label.text = "FPS Atual: %d\nMemória: %.2f MB\nNós na Cena: %d\nIA Provedor: OpenRouter" % [
			fps, mem, get_tree().get_node_count()
		]

func _on_btn_agent_inspect() -> void:
	if not engine or active_game_info.is_empty(): return
	_log("[color=#f9e231]🤖 Acionando Agente Gemini 2.5 (Visão + Código) para inspecionar %s...[/color]" % active_game_info["name"])
	var prompt = "Você é o Agente ReAct Godot. O usuário abriu o jogo '%s' (%s). PRIMEIRO, chame a ferramenta capture_screenshot para tirar um print e ver como a tela do jogo está enquadrada. DEPOIS, verifique se a responsividade está perfeita e analise o código." % [active_game_info["name"], active_game_info["tscn"]]
	engine.send_user_prompt(prompt)

func _on_btn_agent_play() -> void:
	if not engine or active_game_info.is_empty(): return
	_log("[color=#f9e231]🤖 Agente tirando print e verificando jogabilidade de %s...[/color]" % active_game_info["name"])
	var prompt = "Chame a ferramenta capture_screenshot AGORA para ver o jogo '%s' rodando ao vivo na tela. Me diga o que você enxerga na imagem (posição do jogador, pontuação, inimigos) e se a responsividade está 100%%." % active_game_info["name"]
	engine.send_user_prompt(prompt)

func _on_btn_agent_refactor() -> void:
	if not engine or active_game_info.is_empty(): return
	_log("[color=#f9e231]🤖 Agente refatorando %s...[/color]" % active_game_info["name"])
	var prompt = "Analise e refatore o script do jogo '%s' para maximizar o FPS e a legibilidade do código usando modify_project_file se necessário." % active_game_info["name"]
	engine.send_user_prompt(prompt)

func _on_btn_benchmark() -> void:
	if not monitor or active_game_info.is_empty(): return
	_log("[color=#a6e3a1]⏱️ Rodando teste de telemetria de 3.0s em %s...[/color]" % active_game_info["name"])
	monitor.start_benchmark(active_game_info["id"], 3.0)

func _log(msg: String) -> void:
	if log_box:
		log_box.append_text(msg + "\n")
