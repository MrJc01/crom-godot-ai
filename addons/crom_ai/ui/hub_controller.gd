extends Control

# ==============================================================================
# Hub Controller — Controller/Router principal do CromAI Hub
# Monta as 5 zonas semânticas e roteia entre as 5 páginas.
# Usa preload explícito para garantir que todas as classes sejam encontradas.
# ==============================================================================

const _ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const _StyleFactory = preload("res://addons/crom_ai/core/style_factory.gd")
const _IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")
const _GameRegistry = preload("res://addons/crom_ai/core/game_registry.gd")
const _ProjectService = preload("res://addons/crom_ai/core/project_service.gd")
const _PlaytestService = preload("res://addons/crom_ai/core/playtest_service.gd")

const _ActivityBar = preload("res://addons/crom_ai/ui/activity_bar.gd")
const _SidebarPanel = preload("res://addons/crom_ai/ui/sidebar_panel.gd")
const _TerminalPanel = preload("res://addons/crom_ai/ui/terminal_panel.gd")
const _StatusBar = preload("res://addons/crom_ai/ui/status_bar.gd")

const _HomePage = preload("res://addons/crom_ai/ui/pages/home_page.gd")
const _ProjectsPage = preload("res://addons/crom_ai/ui/pages/projects_page.gd")
const _PlaytestPage = preload("res://addons/crom_ai/ui/pages/playtest_page.gd")
const _SettingsPage = preload("res://addons/crom_ai/ui/pages/settings_page.gd")
const _BenchmarkPage = preload("res://addons/crom_ai/ui/pages/benchmark_page.gd")

var _activity_bar: Control
var _sidebar: Control
var _terminal: Control
var _status_bar_node: Control

var _pages: Dictionary = {}
var _current_page: String = "home"

var _engine: Node
var _monitor: Node
var _playtest_svc: Node

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layout()
	_init_services()
	_navigate_to("home")

func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = _ThemeConstants.BG_EDITOR
	add_child(bg)
	
	var main_hbox := HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_bottom = -_ThemeConstants.STATUS_BAR_HEIGHT
	main_hbox.add_theme_constant_override("separation", 0)
	add_child(main_hbox)
	
	# ZONA 1: Activity Bar
	_activity_bar = _ActivityBar.new()
	_activity_bar.page_selected.connect(_navigate_to)
	main_hbox.add_child(_activity_bar)
	
	# ZONA 2: Primary Side Bar
	_sidebar = _SidebarPanel.new()
	_sidebar.sidebar_action.connect(_on_sidebar_action)
	main_hbox.add_child(_sidebar)
	
	# ZONAS 3+4: Editor Group + Terminal Panel
	var vsplit := VSplitContainer.new()
	vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vsplit.split_offset = 380
	main_hbox.add_child(vsplit)
	
	var editor_group := VBoxContainer.new()
	editor_group.add_theme_constant_override("separation", 0)
	vsplit.add_child(editor_group)
	
	# Tab bar
	var tab_bar := PanelContainer.new()
	tab_bar.custom_minimum_size = Vector2(0, _ThemeConstants.TAB_BAR_HEIGHT)
	tab_bar.add_theme_stylebox_override("panel", _StyleFactory.tab_bar())
	editor_group.add_child(tab_bar)
	
	# Canvas
	var canvas := Control.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_group.add_child(canvas)
	
	# Instanciar páginas
	var home_page: Control = _HomePage.new()
	var projects_page: Control = _ProjectsPage.new()
	var playtest_page: Control = _PlaytestPage.new()
	var settings_page: Control = _SettingsPage.new()
	var benchmark_page: Control = _BenchmarkPage.new()
	
	home_page.navigate_requested.connect(_navigate_to)
	home_page.open_project_requested.connect(func(path):
		_log("Abrindo Editor em: " + path)
		_ProjectService.open_in_editor(path)
	)
	projects_page.log_requested.connect(_log)
	playtest_page.log_requested.connect(_log)
	settings_page.log_requested.connect(_log)
	settings_page.test_connectivity_requested.connect(_on_test_connectivity)
	benchmark_page.log_requested.connect(_log)
	
	_pages = {
		"home": home_page,
		"projects": projects_page,
		"playtest": playtest_page,
		"settings": settings_page,
		"benchmark": benchmark_page,
	}
	
	for page_id in _pages:
		var page: Control = _pages[page_id]
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.visible = false
		canvas.add_child(page)
	
	# Terminal Panel
	_terminal = _TerminalPanel.new()
	_terminal.action_requested.connect(_on_terminal_action)
	vsplit.add_child(_terminal)
	
	# Status Bar
	_status_bar_node = _StatusBar.new()
	_status_bar_node.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(_status_bar_node)

func _navigate_to(page_id: String) -> void:
	_current_page = page_id
	for id in _pages:
		_pages[id].visible = (id == page_id)
	_activity_bar.set_active_page(page_id)
	_sidebar.set_page(page_id)

func _on_sidebar_action(action: String, data: Variant) -> void:
	match action:
		"create_project":
			_navigate_to("projects")
		"load_game":
			if data is Dictionary:
				_pages["playtest"].load_game(data)
				_navigate_to("playtest")
		"run_benchmark":
			_log("[color=#fab387]Benchmark iniciado...[/color]")

func _on_terminal_action(action_id: String) -> void:
	match action_id:
		"inspect": _on_agent_inspect()
		"refactor": _on_agent_refactor()
		"playtest": _on_agent_playtest()
		"benchmark_quick": _on_benchmark_quick()

func _init_services() -> void:
	var MonClass = load("res://benchmark/benchmark_monitor.gd")
	if MonClass:
		_monitor = MonClass.new()
		add_child(_monitor)
		_monitor.benchmark_finished.connect(func(g_id, rep):
			_log("[color=#a6e3a1]Telemetria de %s: %.1f FPS (Peak: %.1f MB)[/color]" % [g_id, rep["fps"]["average"], rep["memory_mb"]["peak"]])
		)
	
	var ProcClass: Variant = load("res://addons/crom_ai/command_processor.gd")
	if ProcClass:
		var proc: Variant = ProcClass.new(null)
		add_child(proc)
		var EngineClass = load("res://addons/crom_ai/native_react_engine.gd")
		if EngineClass:
			_engine = EngineClass.new(proc)
			add_child(_engine)
			var ai_cfg := _load_agent_config()
			_engine.set_config(ai_cfg["provider"], ai_cfg["model"], ai_cfg["api_key"])
			_engine.message_added.connect(func(role, text):
				if role == "tool_call": _log("[color=#fab387]Tool:[/color] " + text.substr(0, 120))
			)
			_engine.react_finished.connect(func(ans): _log("[color=#cba6f7]Agent:[/color] " + ans))
	
	_playtest_svc = _PlaytestService.new()
	add_child(_playtest_svc)
	var pt_page: Variant = _pages.get("playtest")
	if pt_page and _engine:
		_playtest_svc.setup(_engine, pt_page.get_playtest_viewport())
		_playtest_svc.playtest_finished.connect(func(game_id, report):
			_log("[color=#a6e3a1]Playtest completo para %s[/color]" % game_id)
			pt_page.show_playtest_report(report)
		)

func _on_agent_inspect() -> void:
	var pt: Variant = _pages.get("playtest")
	if not _engine or not pt or pt.get_active_game_info().is_empty():
		_log("[color=#f38ba8]Selecione um jogo na aba Playtest primeiro.[/color]")
		return
	var info: Dictionary = pt.get_active_game_info()
	_log("Agente inspecionando %s..." % info["name"])
	_engine.send_user_prompt("Chame capture_screenshot e analise a responsividade do jogo '%s'." % info["name"])

func _on_agent_refactor() -> void:
	var pt: Variant = _pages.get("playtest")
	if not _engine or not pt or pt.get_active_game_info().is_empty():
		_log("[color=#f38ba8]Selecione um jogo na aba Playtest primeiro.[/color]")
		return
	var info: Dictionary = pt.get_active_game_info()
	_log("Agente refatorando %s..." % info["name"])
	_engine.send_user_prompt("Otimize o script do jogo '%s' usando modify_project_file." % info["name"])

func _on_agent_playtest() -> void:
	var pt: Variant = _pages.get("playtest")
	if not _engine or not pt or pt.get_active_game_info().is_empty():
		_log("[color=#f38ba8]Selecione um jogo na aba Playtest primeiro.[/color]")
		return
	_log("Iniciando playtest com IA para %s..." % pt.get_active_game_info()["name"])
	_playtest_svc.start_playtest(pt.get_active_game_info())

func _on_benchmark_quick() -> void:
	var pt: Variant = _pages.get("playtest")
	if not _monitor or not pt or pt.get_active_game_info().is_empty():
		_log("[color=#f38ba8]Selecione um jogo na aba Playtest primeiro.[/color]")
		return
	_log("Rodando telemetria rápida (3s)...")
	_monitor.start_benchmark(pt.get_active_game_info()["id"], 3.0)

func _on_test_connectivity() -> void:
	if _engine:
		_log("Testando conectividade com Motor ReAct...")
		_engine.send_user_prompt("Responda em 1 frase confirmando que você está ativo e pronto.")
	else:
		_log("[color=#f38ba8]Motor ReAct não inicializado.[/color]")

func _log(msg: String) -> void:
	if _terminal:
		_terminal.log_message(msg)

# Lê a config salva pelo painel do Crom Agente (user://crom_ai_config.cfg).
# Sem chave hardcoded: se não houver configuração, as ações de IA pedem setup.
func _load_agent_config() -> Dictionary:
	var result := { "provider": "openrouter", "model": "google/gemini-2.5-flash", "api_key": "" }
	var cfg := ConfigFile.new()
	if cfg.load("user://crom_ai_config.cfg") == OK:
		result["provider"] = str(cfg.get_value("ai", "provider", result["provider"]))
		result["model"] = str(cfg.get_value("ai", "model", result["model"]))
		result["api_key"] = str(cfg.get_value("ai", "api_key", ""))
	return result
